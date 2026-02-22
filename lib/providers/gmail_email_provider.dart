import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../search/search_query.dart';
import '../state/send_queue.dart';
import 'email_provider.dart';
import '../utils/email_address_utils.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Gmail system label IDs that map to well-known mailboxes.
const _kInbox = 'INBOX';
const _kSent = 'SENT';
const _kDrafts = 'DRAFT';
const _kTrash = 'TRASH';
const _kSpam = 'SPAM';
const _kStarred = 'STARRED';

/// Human-readable names for system labels.
const _kSystemLabelNames = <String, String>{
  _kInbox: 'Inbox',
  _kSent: 'Sent',
  _kDrafts: 'Drafts',
  _kTrash: 'Trash',
  _kSpam: 'Spam',
  _kStarred: 'Starred',
};

/// The ordered set of system labels shown in the Mailboxes section.
const _kMailboxLabels = [_kInbox, _kSent, _kDrafts, _kTrash, _kSpam];

/// Maximum threads to fetch per label.
const _kMaxThreads = 50;

// ---------------------------------------------------------------------------
// Cache helpers
// ---------------------------------------------------------------------------

class _LabelCacheEntry {
  _LabelCacheEntry({required this.data, required this.fetchedAt});
  final _LabelData data;
  final DateTime fetchedAt;
}

class _LabelData {
  const _LabelData({required this.threads, required this.messages});
  final List<EmailThread> threads;
  final Map<String, List<EmailMessage>> messages;
  static const empty = _LabelData(threads: [], messages: {});
}

// ---------------------------------------------------------------------------
// GmailEmailProvider
// ---------------------------------------------------------------------------

class GmailEmailProvider extends EmailProvider {
  GmailEmailProvider({
    required this.email,
    required this.accountId,
    required GoogleSignIn googleSignIn,
    GoogleSignInAccount? existingAccount,
  })  : _googleSignIn = googleSignIn,
        _gsiAccount = existingAccount {
    _sendQueue = SendQueue(
      accountKey: accountId,
      onChanged: notifyListeners,
      sendNow: _sendQueuedMessage,
      saveDraft: _saveQueuedDraft,
    );
  }

  final String email;
  final String accountId;
  final GoogleSignIn _googleSignIn;

  late final SendQueue _sendQueue;
  gmail.GmailApi? _gmailApi;
  GoogleSignInAccount? _gsiAccount;

  final List<EmailThread> _threads = [];
  final Map<String, List<EmailMessage>> _messages = {};
  final List<FolderSection> _folderSections = [];
  final Map<String, _LabelCacheEntry> _labelCache = {};
  final Map<String, int> _loadTokens = {};
  final Set<String> _loadingLabels = {};
  int _loadCounter = 0;

  ProviderStatus _status = ProviderStatus.idle;
  String? _errorMessage;
  String _selectedLabelId = _kInbox;
  String? _priorLabelId; // folder to restore after clearing search
  SearchQuery? _activeSearch;
  bool _isSearchLoading = false;
  DateTime? _lastMutationAt;
  Timer? _refreshTimer;
  int _checkMailIntervalMinutes = 5;
  // ignore: unused_field
  bool _crossFolderThreadingEnabled = false;

  // ---------------------------------------------------------------------------
  // EmailProvider interface — status & data
  // ---------------------------------------------------------------------------

  @override
  ProviderStatus get status => _status;

  @override
  String? get errorMessage => _errorMessage;

  @override
  List<EmailThread> get threads {
    if (_selectedLabelId == kOutboxFolderPath) return _outboxThreads();
    return List.unmodifiable(_threads);
  }

  @override
  List<EmailMessage> messagesForThread(String threadId) {
    if (_selectedLabelId == kOutboxFolderPath) {
      return _outboxMessagesForThread(threadId);
    }
    return List.unmodifiable(_messages[threadId] ?? const []);
  }

  @override
  EmailMessage? latestMessageForThread(String threadId) {
    final msgs = _messages[threadId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last;
  }

  @override
  int get outboxCount => _sendQueue.pendingCount;

  @override
  List<FolderSection> get folderSections =>
      List.unmodifiable(_folderSections);

  @override
  String get selectedFolderPath => _selectedLabelId;

  @override
  bool isFolderLoading(String path) => _loadingLabels.contains(path);

  @override
  SearchQuery? get activeSearch => _activeSearch;

  @override
  bool get isSearchLoading => _isSearchLoading;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize() async {
    if (_status != ProviderStatus.idle) return;
    _status = ProviderStatus.loading;
    notifyListeners();
    try {
      // If we were handed an already-authenticated account (fresh add flow),
      // use it directly. Otherwise try silent re-auth (app restart).
      debugPrint('[GmailProvider] initialize: existingAccount=$_gsiAccount');
      if (_gsiAccount == null) {
        debugPrint('[GmailProvider] trying signInSilently...');
        _gsiAccount = await _googleSignIn.signInSilently();
        debugPrint('[GmailProvider] signInSilently=$_gsiAccount');
        _gsiAccount ??= await _googleSignIn.signIn();
        debugPrint('[GmailProvider] signIn=$_gsiAccount');
      }
      if (_gsiAccount == null) {
        _status = ProviderStatus.error;
        _errorMessage = 'Google sign-in was cancelled.';
        notifyListeners();
        return;
      }
      debugPrint('[GmailProvider] building API...');
      await _buildApi();
      debugPrint('[GmailProvider] loading labels...');
      await _loadLabels();
      await _sendQueue.initialize();
      _status = ProviderStatus.ready;
      debugPrint('[GmailProvider] ready!');
      notifyListeners();
      _startLabelLoad(_selectedLabelId, showErrors: true);
      _scheduleRefresh();
    } catch (error, st) {
      debugPrint('[GmailProvider] initialize error: $error\n$st');
      _status = ProviderStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  @override
  Future<void> refresh() async {
    if (_status == ProviderStatus.loading) return;
    if (_selectedLabelId == kOutboxFolderPath) {
      _errorMessage = null;
      notifyListeners();
      return;
    }
    final cached = _labelCache[_selectedLabelId];
    _errorMessage = null;
    if (cached == null) {
      _status = ProviderStatus.loading;
      notifyListeners();
    }
    _startLabelLoad(_selectedLabelId, showErrors: cached == null);
    await _loadLabels();
  }

  @override
  Future<void> selectFolder(String path) async {
    if (path == _selectedLabelId && _activeSearch == null) return;
    // Clear any active search when navigating to a real folder.
    _activeSearch = null;
    _isSearchLoading = false;
    _priorLabelId = null;
    _selectedLabelId = path;
    _errorMessage = null;
    final cached = _labelCache[path];
    if (cached != null) {
      _applyLabelData(cached.data);
    } else if (path != kOutboxFolderPath) {
      _threads.clear();
      _messages.clear();
      _status = ProviderStatus.loading;
    }
    notifyListeners();
    if (path != kOutboxFolderPath) {
      _startLabelLoad(path, showErrors: cached == null);
    }
  }

  @override
  Future<void> search(SearchQuery? query) async {
    if (query == null) {
      // Clear search — return to prior folder.
      final prior = _priorLabelId ?? _kInbox;
      _activeSearch = null;
      _isSearchLoading = false;
      _priorLabelId = null;
      await selectFolder(prior);
      return;
    }
    _priorLabelId ??= _selectedLabelId == kSearchFolderPath
        ? (_priorLabelId ?? _kInbox)
        : _selectedLabelId;
    _activeSearch = query;
    _selectedLabelId = kSearchFolderPath;
    _threads.clear();
    _messages.clear();
    _status = ProviderStatus.loading;
    _isSearchLoading = true;
    notifyListeners();
    _startSearchLoad(query);
  }

  void _startSearchLoad(SearchQuery query) {
    final token = ++_loadCounter;
    _loadTokens[kSearchFolderPath] = token;
    if (_loadingLabels.add(kSearchFolderPath)) notifyListeners();
    _loadSearchInBackground(query, token);
  }

  Future<void> _loadSearchInBackground(SearchQuery query, int token) async {
    try {
      final gmailQuery = query.toGmailQuery();
      final data = await _fetchSearchResults(gmailQuery);
      if (_loadTokens[kSearchFolderPath] != token) return;
      if (_selectedLabelId == kSearchFolderPath) {
        _threads
          ..clear()
          ..addAll(data.threads);
        _messages
          ..clear()
          ..addAll(data.messages);
        _status = ProviderStatus.ready;
        _isSearchLoading = false;
        notifyListeners();
      }
    } catch (error) {
      if (_loadTokens[kSearchFolderPath] != token) return;
      if (_selectedLabelId == kSearchFolderPath) {
        _status = ProviderStatus.error;
        _errorMessage = error.toString();
        _isSearchLoading = false;
        notifyListeners();
      }
    } finally {
      if (_loadTokens[kSearchFolderPath] == token &&
          _loadingLabels.remove(kSearchFolderPath)) {
        notifyListeners();
      }
    }
  }

  Future<_LabelData> _fetchSearchResults(String gmailQuery) async {
    final api = _gmailApi;
    if (api == null) return _LabelData.empty;

    final listResponse = await api.users.threads.list(
      'me',
      q: gmailQuery,
      maxResults: _kMaxThreads,
    );

    final threadSummaries = listResponse.threads ?? [];
    if (threadSummaries.isEmpty) return _LabelData.empty;

    // Phase 1 — placeholders.
    final threads = <EmailThread>[];
    final messages = <String, List<EmailMessage>>{};
    for (final summary in threadSummaries) {
      final id = summary.id;
      if (id == null) continue;
      threads.add(EmailThread(
        id: id,
        subject: summary.snippet ?? '(loading…)',
        participants: const [],
        time: '',
        unread: false,
        starred: false,
      ));
      messages[id] = [];
    }
    final phase1 = _LabelData(threads: threads, messages: messages);

    // Phase 2 — full bodies (reuse existing helper).
    final phase2 = await _fetchThreadBodies(phase1);
    return phase2 ?? phase1;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _sendQueue.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Send / Draft
  // ---------------------------------------------------------------------------

  @override
  Future<OutboxItem?> sendMessage({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  }) async {
    // Resolve reply headers from the thread's latest message.
    String? replyMessageId;
    String? replyInReplyTo;
    if (thread != null) {
      final msgs = messagesForThread(thread.id);
      final latest = msgs.isNotEmpty ? msgs.last : null;
      replyMessageId = latest?.messageId;
      replyInReplyTo = latest?.inReplyTo;
    }
    final draft = OutboxDraft(
      accountKey: accountId,
      threadId: thread?.id,
      toLine: toLine,
      ccLine: ccLine,
      bccLine: bccLine,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
    );
    return _sendQueue.enqueue(draft);
  }

  @override
  Future<bool> cancelSend(String outboxId) => _sendQueue.cancel(outboxId);

  @override
  Future<void> saveDraft({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  }) async {
    final api = _gmailApi;
    if (api == null) return;
    final raw = _buildRfc2822(
      from: email,
      to: toLine,
      cc: ccLine,
      bcc: bccLine,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
    );
    final encoded = base64UrlEncode(utf8.encode(raw));
    final draft = gmail.Draft()..message = (gmail.Message()..raw = encoded);
    await api.users.drafts.create(draft, 'me');
  }

  // ---------------------------------------------------------------------------
  // Thread actions
  // ---------------------------------------------------------------------------

  @override
  Future<String?> setThreadUnread(EmailThread thread, bool isUnread) async {
    final api = _gmailApi;
    if (api == null) return 'Not connected.';
    try {
      final messageIds = _allMessageIdsForThread(thread.id);
      final req = gmail.ModifyMessageRequest()
        ..addLabelIds = isUnread ? ['UNREAD'] : []
        ..removeLabelIds = isUnread ? [] : ['UNREAD'];
      for (final msgId in messageIds) {
        await api.users.messages.modify(req, 'me', msgId);
      }
      // Update local state.
      _lastMutationAt = DateTime.now();
      final msgs = _messages[thread.id];
      if (msgs != null) {
        _messages[thread.id] = msgs
            .map((m) => _copyMessageWithUnread(m, isUnread))
            .toList();
      }
      final idx = _threads.indexWhere((t) => t.id == thread.id);
      if (idx >= 0) {
        _threads[idx] = EmailThread(
          id: thread.id,
          subject: thread.subject,
          participants: thread.participants,
          time: thread.time,
          unread: isUnread,
          starred: thread.starred,
          receivedAt: thread.receivedAt,
        );
      }
      _patchLabelCache(_selectedLabelId);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<String?> archiveThread(EmailThread thread) async {
    final api = _gmailApi;
    if (api == null) return 'Not connected.';
    // Snapshot for rollback.
    final threadIndex = _threads.indexWhere((t) => t.id == thread.id);
    final savedMessages = List<EmailMessage>.from(_messages[thread.id] ?? []);
    // Optimistic remove — UI updates immediately.
    _removeThreadFromCache(thread.id);
    notifyListeners();
    try {
      final req = gmail.ModifyThreadRequest()..removeLabelIds = [_kInbox];
      await api.users.threads.modify(req, 'me', thread.id);
      return null;
    } catch (e) {
      // Server failed — roll back so the thread reappears.
      _restoreThreadToCache(thread, savedMessages, threadIndex);
      notifyListeners();
      return e.toString();
    }
  }

  @override
  Future<String?> moveToFolder(
    EmailThread thread,
    String targetPath, {
    EmailMessage? singleMessage,
  }) async {
    final api = _gmailApi;
    if (api == null) return 'Not connected.';
    if (singleMessage != null) {
      try {
        final req = gmail.ModifyMessageRequest()
          ..addLabelIds = [targetPath]
          ..removeLabelIds = [_selectedLabelId];
        await api.users.messages.modify(req, 'me', singleMessage.id);
        _removeSingleMessageFromCache(thread.id, singleMessage.id);
        notifyListeners();
        return null;
      } catch (e) {
        return e.toString();
      }
    }
    // Snapshot for rollback.
    final threadIndex = _threads.indexWhere((t) => t.id == thread.id);
    final savedMessages = List<EmailMessage>.from(_messages[thread.id] ?? []);
    // Optimistic remove.
    _removeThreadFromCache(thread.id);
    notifyListeners();
    try {
      final req = gmail.ModifyThreadRequest()
        ..addLabelIds = [targetPath]
        ..removeLabelIds = [_selectedLabelId];
      await api.users.threads.modify(req, 'me', thread.id);
      return null;
    } catch (e) {
      // Server failed — roll back.
      _restoreThreadToCache(thread, savedMessages, threadIndex);
      notifyListeners();
      return e.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — API setup
  // ---------------------------------------------------------------------------

  Future<void> _buildApi() async {
    final account = _gsiAccount;
    if (account == null) return;
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) throw Exception('Could not get authenticated HTTP client.');
    _gmailApi = gmail.GmailApi(httpClient);
  }

  // ---------------------------------------------------------------------------
  // Internal — label/folder loading
  // ---------------------------------------------------------------------------

  Future<void> _loadLabels() async {
    final api = _gmailApi;
    if (api == null) return;
    try {
      final response = await api.users.labels.list('me');
      final labels = response.labels ?? [];
      _buildFolderSections(labels);
    } catch (_) {
      // Non-fatal — use existing sections if available.
    }
  }

  void _buildFolderSections(List<gmail.Label> labels) {
    final mailboxItems = <FolderItem>[];
    final labelItems = <FolderItem>[];
    var index = 0;

    // System mailboxes in fixed order.
    for (final id in _kMailboxLabels) {
      final label = labels.firstWhere(
        (l) => l.id == id,
        orElse: () => gmail.Label()..id = id,
      );
      final unread = label.messagesUnread ?? 0;
      mailboxItems.add(FolderItem(
        index: index++,
        name: _kSystemLabelNames[id] ?? id,
        path: id,
        unreadCount: unread,
        icon: _iconForSystemLabel(id),
      ));
    }

    // Outbox virtual folder.
    mailboxItems.add(FolderItem(
      index: index++,
      name: 'Outbox',
      path: kOutboxFolderPath,
      unreadCount: outboxCount,
      icon: Icons.outbox_outlined,
    ));

    // User labels — skip system ones and internal ones (prefixed with CATEGORY_).
    final systemIds = {
      ..._kMailboxLabels,
      _kStarred,
      'UNREAD',
      'IMPORTANT',
      'CATEGORY_PERSONAL',
      'CATEGORY_SOCIAL',
      'CATEGORY_UPDATES',
      'CATEGORY_FORUMS',
      'CATEGORY_PROMOTIONS',
    };
    for (final label in labels) {
      final id = label.id;
      if (id == null) continue;
      if (systemIds.contains(id)) continue;
      if (label.type == 'system') continue;
      final name = label.name ?? id;
      // Compute nesting depth from '/' separators.
      final depth = '/'.allMatches(name).length;
      final displayName = name.split('/').last;
      labelItems.add(FolderItem(
        index: index++,
        name: displayName,
        path: id,
        depth: depth,
        unreadCount: label.messagesUnread ?? 0,
        icon: Icons.label_outline,
      ));
    }

    _folderSections
      ..clear()
      ..add(FolderSection(
        title: 'Mailboxes',
        items: mailboxItems,
        kind: FolderSectionKind.mailboxes,
      ));
    if (labelItems.isNotEmpty) {
      _folderSections.add(FolderSection(
        title: 'Labels',
        items: labelItems,
        kind: FolderSectionKind.labels,
      ));
    }
    notifyListeners();
  }

  IconData _iconForSystemLabel(String id) {
    return switch (id) {
      _kInbox => Icons.inbox_outlined,
      _kSent => Icons.send_outlined,
      _kDrafts => Icons.drafts_outlined,
      _kTrash => Icons.delete_outline,
      _kSpam => Icons.report_gmailerrorred_outlined,
      _kStarred => Icons.star_outline,
      _ => Icons.folder_outlined,
    };
  }

  // ---------------------------------------------------------------------------
  // Internal — two-phase thread loading
  // ---------------------------------------------------------------------------

  void _startLabelLoad(String labelId, {required bool showErrors}) {
    final token = ++_loadCounter;
    _loadTokens[labelId] = token;
    if (_loadingLabels.add(labelId)) notifyListeners();
    _loadLabelInBackground(labelId, token, showErrors: showErrors);
  }

  Future<void> _loadLabelInBackground(
    String labelId,
    int token, {
    required bool showErrors,
  }) async {
    final mutationAtStart = _lastMutationAt;

    void applyData(_LabelData data, {required bool updateCache}) {
      if (_loadTokens[labelId] != token) return;
      final mutated = _lastMutationAt != mutationAtStart;
      if (mutated) {
        _status = ProviderStatus.ready;
        notifyListeners();
        return;
      }
      if (updateCache) {
        _labelCache[labelId] = _LabelCacheEntry(
          data: data,
          fetchedAt: DateTime.now(),
        );
      }
      if (labelId == _selectedLabelId) {
        _threads
          ..clear()
          ..addAll(data.threads);
        _messages
          ..clear()
          ..addAll(data.messages);
        _status = ProviderStatus.ready;
        notifyListeners();
      }
    }

    try {
      // Phase 1 — thread list (snippets only, fast).
      final phase1 = await _fetchThreadList(labelId);
      applyData(phase1, updateCache: false);

      if (_loadTokens[labelId] != token) return;

      // Phase 2 — full messages (bodies).
      final phase2 = await _fetchThreadBodies(phase1);
      if (phase2 != null) applyData(phase2, updateCache: true);
    } catch (error) {
      if (_loadTokens[labelId] != token) return;
      if (showErrors && labelId == _selectedLabelId) {
        _status = ProviderStatus.error;
        _errorMessage = error.toString();
        notifyListeners();
      }
    } finally {
      if (_loadTokens[labelId] == token && _loadingLabels.remove(labelId)) {
        notifyListeners();
      }
    }
  }

  /// Phase 1: list threads, use snippet as body preview.
  Future<_LabelData> _fetchThreadList(String labelId) async {
    final api = _gmailApi;
    if (api == null) return _LabelData.empty;

    final listResponse = await api.users.threads.list(
      'me',
      labelIds: [labelId],
      maxResults: _kMaxThreads,
    );

    final threadSummaries = listResponse.threads ?? [];
    if (threadSummaries.isEmpty) return _LabelData.empty;

    final threads = <EmailThread>[];
    final messages = <String, List<EmailMessage>>{};

    for (final summary in threadSummaries) {
      final id = summary.id;
      if (id == null) continue;
      final snippet = summary.snippet ?? '';
      // Phase 1 creates a placeholder thread from snippet — no sender info yet.
      final placeholder = EmailThread(
        id: id,
        subject: snippet.isNotEmpty ? snippet : '(loading…)',
        participants: const [],
        time: '',
        unread: false,
        starred: false,
      );
      threads.add(placeholder);
      messages[id] = [];
    }
    return _LabelData(threads: threads, messages: messages);
  }

  /// Phase 2: fetch full thread data (headers + body) for each thread ID.
  /// Uses individual thread.get calls (Gmail API doesn't have a proper batch
  /// endpoint in the Dart client, so we do them concurrently with Future.wait).
  Future<_LabelData?> _fetchThreadBodies(_LabelData phase1) async {
    final api = _gmailApi;
    if (api == null) return null;
    if (phase1.threads.isEmpty) return null;

    // Fetch threads concurrently, capped to avoid rate limits.
    const batchSize = 10;
    final threadIds = phase1.threads.map((t) => t.id).toList();
    final fetchedThreads = <String, gmail.Thread>{};

    for (var i = 0; i < threadIds.length; i += batchSize) {
      final batch = threadIds.skip(i).take(batchSize);
      final results = await Future.wait(
        batch.map((id) => api.users.threads.get('me', id, format: 'full')),
      );
      for (final t in results) {
        if (t.id != null) fetchedThreads[t.id!] = t;
      }
    }

    final threads = <EmailThread>[];
    final messages = <String, List<EmailMessage>>{};

    for (final threadId in threadIds) {
      final gmailThread = fetchedThreads[threadId];
      if (gmailThread == null) continue;

      final gmailMessages = gmailThread.messages ?? [];
      if (gmailMessages.isEmpty) continue;

      final parsedMessages = gmailMessages
          .map((m) => _parseGmailMessage(m, threadId))
          .whereType<EmailMessage>()
          .toList();
      if (parsedMessages.isEmpty) continue;

      parsedMessages.sort((a, b) {
        final aT = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bT = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aT.compareTo(bT);
      });

      final latest = parsedMessages.last;
      final participants = <EmailAddress>{latest.from, ...latest.to}.toList();
      final isUnread = parsedMessages.any((m) => m.isUnread);

      threads.add(EmailThread(
        id: threadId,
        subject: latest.subject,
        participants: participants,
        time: latest.time,
        unread: isUnread,
        starred: gmailMessages.any(
          (m) => m.labelIds?.contains(_kStarred) ?? false,
        ),
        receivedAt: latest.receivedAt,
      ));
      messages[threadId] = parsedMessages;
    }

    // Preserve the original order (most recent first from Gmail).
    threads.sort((a, b) {
      final aT = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bT = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bT.compareTo(aT);
    });

    return _LabelData(threads: threads, messages: messages);
  }

  // ---------------------------------------------------------------------------
  // Internal — message parsing
  // ---------------------------------------------------------------------------

  EmailMessage? _parseGmailMessage(gmail.Message msg, String threadId) {
    final id = msg.id;
    if (id == null) return null;

    final headers = <String, String>{};
    for (final h in msg.payload?.headers ?? <gmail.MessagePartHeader>[]) {
      if (h.name != null && h.value != null) {
        headers[h.name!.toLowerCase()] = h.value!;
      }
    }

    final subject = headers['subject'] ?? '(No subject)';
    final fromRaw = headers['from'] ?? '';
    final from = parseAddress(fromRaw);
    final to = parseAddressList(headers['to'] ?? '');
    final cc = parseAddressList(headers['cc'] ?? '');
    final bcc = parseAddressList(headers['bcc'] ?? '');
    final replyTo = parseAddressList(headers['reply-to'] ?? '');
    // internalDate is milliseconds since epoch as a string — always present and
    // unambiguous. Fall back to the Date header only if missing.
    DateTime? receivedAt;
    final internalDateMs = int.tryParse(msg.internalDate ?? '');
    if (internalDateMs != null) {
      receivedAt = DateTime.fromMillisecondsSinceEpoch(internalDateMs).toUtc();
    } else {
      final dateRaw = headers['date'];
      receivedAt = dateRaw != null ? _parseRfc2822Date(dateRaw) : null;
    }
    // time label is computed at render time from receivedAt + user settings.
    // Store a plain UTC ISO string as a stable fallback for cases where
    // receivedAt is null (e.g. draft with no date header).
    const timeLabel = '';
    final messageId = headers['message-id'];
    final inReplyTo = headers['in-reply-to'];
    final isUnread = msg.labelIds?.contains('UNREAD') ?? false;

    final (bodyText, bodyHtml) = _extractBody(msg.payload);

    return EmailMessage(
      id: id,
      threadId: threadId,
      subject: subject,
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      replyTo: replyTo,
      time: timeLabel,
      isMe: from.email.toLowerCase() == email.toLowerCase(),
      isUnread: isUnread,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      receivedAt: receivedAt,
      messageId: messageId,
      inReplyTo: inReplyTo,
    );
  }

  (String? bodyText, String? bodyHtml) _extractBody(gmail.MessagePart? part) {
    if (part == null) return (null, null);
    String? bodyText;
    String? bodyHtml;
    _walkParts(part, (p) {
      final mime = p.mimeType?.toLowerCase() ?? '';
      final data = p.body?.data;
      if (data == null || data.isEmpty) return;
      final decoded = utf8.decode(base64Url.decode(data), allowMalformed: true);
      if (mime == 'text/html' && bodyHtml == null) {
        bodyHtml = decoded;
      } else if (mime == 'text/plain' && bodyText == null) {
        bodyText = decoded;
      }
    });
    return (bodyText, bodyHtml);
  }

  void _walkParts(gmail.MessagePart part, void Function(gmail.MessagePart) visit) {
    visit(part);
    for (final child in part.parts ?? <gmail.MessagePart>[]) {
      _walkParts(child, visit);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — cache mutation helpers
  // ---------------------------------------------------------------------------

  void _removeThreadFromCache(String threadId) {
    _lastMutationAt = DateTime.now();
    _threads.removeWhere((t) => t.id == threadId);
    _messages.remove(threadId);
    _patchLabelCache(_selectedLabelId);
  }

  /// Re-inserts a thread and its messages after a failed optimistic remove.
  /// Restores to [index] if valid, otherwise appends.
  void _restoreThreadToCache(
    EmailThread thread,
    List<EmailMessage> messages,
    int index,
  ) {
    if (!_threads.any((t) => t.id == thread.id)) {
      final insertAt = index.clamp(0, _threads.length);
      _threads.insert(insertAt, thread);
    }
    if (messages.isNotEmpty) {
      _messages[thread.id] = messages;
    }
    _patchLabelCache(_selectedLabelId);
  }

  void _removeSingleMessageFromCache(String threadId, String messageId) {
    final msgs = _messages[threadId];
    if (msgs == null) return;
    final remaining = msgs.where((m) => m.id != messageId).toList();
    if (remaining.isEmpty) {
      _removeThreadFromCache(threadId);
      return;
    }
    _lastMutationAt = DateTime.now();
    _messages[threadId] = remaining;
    _patchLabelCache(_selectedLabelId);
  }

  /// Writes current _threads/_messages back into the label cache so that a
  /// subsequent selectFolder() returns the mutated state.
  void _patchLabelCache(String labelId) {
    _labelCache[labelId] = _LabelCacheEntry(
      data: _LabelData(
        threads: List.from(_threads),
        messages: Map.from(_messages),
      ),
      fetchedAt: DateTime.now(),
    );
  }

  void _applyLabelData(_LabelData data) {
    _threads
      ..clear()
      ..addAll(data.threads);
    _messages
      ..clear()
      ..addAll(data.messages);
  }

  List<String> _allMessageIdsForThread(String threadId) {
    return (_messages[threadId] ?? []).map((m) => m.id).toList();
  }

  EmailMessage _copyMessageWithUnread(EmailMessage m, bool isUnread) {
    return EmailMessage(
      id: m.id,
      threadId: m.threadId,
      subject: m.subject,
      from: m.from,
      to: m.to,
      cc: m.cc,
      bcc: m.bcc,
      replyTo: m.replyTo,
      time: m.time,
      isMe: m.isMe,
      isUnread: isUnread,
      bodyText: m.bodyText,
      bodyHtml: m.bodyHtml,
      receivedAt: m.receivedAt,
      messageId: m.messageId,
      inReplyTo: m.inReplyTo,
      sendStatus: m.sendStatus,
      folderPath: m.folderPath,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal — send queue callbacks
  // ---------------------------------------------------------------------------

  Future<void> _sendQueuedMessage(OutboxItem item) async {
    final api = _gmailApi;
    if (api == null) throw Exception('Gmail API not initialised.');

    final raw = _buildRfc2822(
      from: email,
      to: item.toLine,
      cc: item.ccLine,
      bcc: item.bccLine,
      subject: item.subject,
      bodyHtml: item.bodyHtml,
      bodyText: item.bodyText,
      replyMessageId: item.replyMessageId,
      replyInReplyTo: item.replyInReplyTo,
    );
    final encoded = base64UrlEncode(utf8.encode(raw));
    final message = gmail.Message()
      ..raw = encoded
      ..threadId = item.threadId;
    await api.users.messages.send(message, 'me');
  }

  Future<void> _saveQueuedDraft(OutboxItem item) async {
    final api = _gmailApi;
    if (api == null) throw Exception('Gmail API not initialised.');
    final raw = _buildRfc2822(
      from: email,
      to: item.toLine,
      cc: item.ccLine,
      bcc: item.bccLine,
      subject: item.subject,
      bodyHtml: item.bodyHtml,
      bodyText: item.bodyText,
      replyMessageId: item.replyMessageId,
      replyInReplyTo: item.replyInReplyTo,
    );
    final encoded = base64UrlEncode(utf8.encode(raw));
    final draft = gmail.Draft()
      ..message = (gmail.Message()
        ..raw = encoded
        ..threadId = item.threadId);
    await api.users.drafts.create(draft, 'me');
  }

  // ---------------------------------------------------------------------------
  // Internal — periodic refresh
  // ---------------------------------------------------------------------------

  void updateInboxRefreshInterval(Duration interval) {
    _checkMailIntervalMinutes = interval.inMinutes.clamp(1, 60);
    _scheduleRefresh();
  }

  void updateCrossFolderThreading(bool enabled) {
    _crossFolderThreadingEnabled = enabled;
    // Gmail uses native conversation threading; this flag is stored but has no
    // effect on the Gmail API fetch logic.
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: _checkMailIntervalMinutes),
      (_) {
        _startLabelLoad(_selectedLabelId, showErrors: false);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Internal — outbox virtual folder
  // ---------------------------------------------------------------------------

  List<EmailThread> _outboxThreads() {
    return _sendQueue.items.map((item) {
      final createdAt = item.createdAt.toLocal();
      return EmailThread(
        id: _outboxThreadId(item),
        subject: item.subject,
        participants: [EmailAddress(name: email, email: email)],
        time: '',
        unread: false,
        starred: false,
        receivedAt: createdAt,
      );
    }).toList();
  }

  List<EmailMessage> _outboxMessagesForThread(String threadId) {
    for (final item in _sendQueue.items) {
      if (_outboxThreadId(item) == threadId) {
        return [
          EmailMessage(
            id: item.id,
            threadId: threadId,
            subject: item.subject,
            from: EmailAddress(name: email, email: email),
            to: parseAddressList(item.toLine),
            cc: parseAddressList(item.ccLine ?? ''),
            bcc: parseAddressList(item.bccLine ?? ''),
            time: '',
            isMe: true,
            isUnread: false,
            bodyHtml: item.bodyHtml,
            bodyText: item.bodyText,
            receivedAt: item.createdAt,
            sendStatus: _toSendStatus(item.status),
          ),
        ];
      }
    }
    return const [];
  }

  String _outboxThreadId(OutboxItem item) => 'outbox-${item.id}';

  MessageSendStatus _toSendStatus(OutboxStatus status) => switch (status) {
        OutboxStatus.queued => MessageSendStatus.queued,
        OutboxStatus.sending => MessageSendStatus.sending,
        OutboxStatus.failed => MessageSendStatus.failed,
      };

  // ---------------------------------------------------------------------------
  // Utilities — address parsing
  // ---------------------------------------------------------------------------



  // ---------------------------------------------------------------------------
  // Utilities — time formatting
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Utilities — RFC 2822 date parsing
  // ---------------------------------------------------------------------------

  DateTime? _parseRfc2822Date(String raw) {
    // Try native parse first (handles ISO-8601 and some RFC variants).
    final dt = DateTime.tryParse(raw);
    if (dt != null) return dt;
    // Gmail Date header: "Mon, 14 Apr 2025 10:23:45 +0000"
    try {
      final cleaned = raw.replaceAll(RegExp(r'\s+\(.*\)$'), '').trim();
      // Remove day-of-week prefix if present.
      final withoutDay = cleaned.replaceAll(RegExp(r'^[A-Za-z]+,\s*'), '');
      return DateTime.tryParse(withoutDay);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Utilities — RFC 2822 message building
  // ---------------------------------------------------------------------------

  String _buildRfc2822({
    required String from,
    required String to,
    String? cc,
    String? bcc,
    required String subject,
    required String bodyHtml,
    required String bodyText,
    String? replyMessageId,
    String? replyInReplyTo,
  }) {
    final boundary = 'tidings_${DateTime.now().millisecondsSinceEpoch}';
    final buf = StringBuffer();
    buf.writeln('From: $from');
    buf.writeln('To: $to');
    if (cc != null && cc.isNotEmpty) buf.writeln('Cc: $cc');
    if (bcc != null && bcc.isNotEmpty) buf.writeln('Bcc: $bcc');
    buf.writeln('Subject: =?UTF-8?B?${base64Encode(utf8.encode(subject))}?=');
    buf.writeln('MIME-Version: 1.0');
    if (replyMessageId != null) buf.writeln('In-Reply-To: $replyMessageId');
    if (replyInReplyTo != null) {
      buf.writeln('References: $replyInReplyTo $replyMessageId');
    }
    buf.writeln('Content-Type: multipart/alternative; boundary="$boundary"');
    buf.writeln();
    if (bodyText.isNotEmpty) {
      buf.writeln('--$boundary');
      buf.writeln('Content-Type: text/plain; charset=UTF-8');
      buf.writeln('Content-Transfer-Encoding: base64');
      buf.writeln();
      buf.writeln(base64Encode(utf8.encode(bodyText)));
    }
    buf.writeln('--$boundary');
    buf.writeln('Content-Type: text/html; charset=UTF-8');
    buf.writeln('Content-Transfer-Encoding: base64');
    buf.writeln();
    buf.writeln(base64Encode(utf8.encode(bodyHtml)));
    buf.writeln('--$boundary--');
    return buf.toString();
  }
}
