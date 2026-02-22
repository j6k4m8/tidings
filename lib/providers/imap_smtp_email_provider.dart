import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../search/search_query.dart';
import '../search/query_serializer.dart';
import '../state/send_queue.dart';
import '../utils/email_address_utils.dart';
import '../utils/outbox_section.dart';
import 'email_provider.dart';

class ImapSmtpEmailProvider extends EmailProvider {
  ImapSmtpEmailProvider({
    required this.config,
    required this.email,
    required this.accountId,
  }) {
    _sendQueue = SendQueue(
      accountKey: accountId,
      onChanged: notifyListeners,
      sendNow: _sendQueuedMessage,
      saveDraft: _saveQueuedDraft,
    );
  }

  final ImapAccountConfig config;
  final String email;
  final String accountId;

  final List<EmailThread> _threads = [];
  final Map<String, List<EmailMessage>> _messages = {};
  final List<FolderSection> _folderSections = [];
  ProviderStatus _status = ProviderStatus.idle;
  String? _errorMessage;
  ImapClient? _client;
  final Map<String, String> _messageIdToThreadId = {};
  final Map<String, String> _subjectThreadId = {};
  final Map<String, _FolderCacheEntry> _folderCache = {};
  final Map<String, int> _loadTokens = {};
  final Set<String> _loadingFolders = {};
  int _loadCounter = 0;
  String _selectedFolderPath = 'INBOX';
  String _currentMailboxPath = 'INBOX';
  String? _priorFolderPath; // folder to restore after clearing search
  SearchQuery? _activeSearch;
  bool _isSearchLoading = false;
  String? _sentMailboxPath;
  String? _draftsMailboxPath;
  String? _archiveMailboxPath;
  final Map<int, String> _archiveYearPaths = {};
  String? _pathSeparator;
  bool _crossFolderThreadingEnabled = false;
  Duration _inboxRefreshInterval = const Duration(minutes: 5);
  Timer? _inboxRefreshTimer;
  // Set whenever a local mutation (move/archive) patches the cache directly.
  // A background fetch that completes *before* this timestamp is discarded so
  // it cannot resurrect threads we've already removed locally.
  DateTime? _lastMutationAt;
  late final SendQueue _sendQueue;

  @override
  ProviderStatus get status {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return ProviderStatus.ready;
    }
    return _status;
  }

  @override
  String? get errorMessage => _errorMessage;

  @override
  List<EmailThread> get threads {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return _outboxThreads();
    }
    return List.unmodifiable(_threads);
  }

  @override
  List<FolderSection> get folderSections =>
      withOutboxSection(_folderSections, _sendQueue);

  @override
  int get outboxCount => _sendQueue.pendingCount;

  @override
  String get selectedFolderPath => _selectedFolderPath;

  @override
  bool isFolderLoading(String path) => _loadingFolders.contains(path);

  @override
  SearchQuery? get activeSearch => _activeSearch;

  @override
  bool get isSearchLoading => _isSearchLoading;

  @override
  Future<void> initialize() async {
    await _sendQueue.initialize();
    if (_status == ProviderStatus.ready || _status == ProviderStatus.loading) {
      return;
    }
    _status = ProviderStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _client = ImapClient(isLogEnabled: false);
      await _client!.connectToServer(
        config.server,
        config.port,
        isSecure: config.useTls,
      );
      await _client!.login(config.username, config.password);
      _inboxRefreshInterval =
          Duration(minutes: config.checkMailIntervalMinutes);
      _crossFolderThreadingEnabled = config.crossFolderThreadingEnabled;
      _scheduleInboxRefresh();
      await _loadFolders();
      _warmThreadingFolders();
      await _loadMailboxAndCache(_currentMailboxPath);
      _status = ProviderStatus.ready;
      notifyListeners();
    } catch (error) {
      _status = ProviderStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  @override
  Future<void> refresh() async {
    if (_status == ProviderStatus.loading) {
      return;
    }
    if (_selectedFolderPath == kOutboxFolderPath) {
      _errorMessage = null;
      notifyListeners();
      return;
    }
    final cached = _folderCache[_currentMailboxPath];
    _errorMessage = null;
    if (cached == null) {
      _status = ProviderStatus.loading;
      notifyListeners();
    }
    _startFolderLoad(_currentMailboxPath, showErrors: cached == null);
    await _loadFolders();
  }

  @override
  List<EmailMessage> messagesForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final outboxItem = _outboxItemForThread(threadId);
      if (outboxItem == null) {
        return const [];
      }
      return [_outboxMessage(outboxItem, threadIdOverride: threadId)];
    }
    if (!_crossFolderThreadingEnabled &&
        _sentMailboxPath == null &&
        _draftsMailboxPath == null) {
      final base = _messages[threadId] ?? const [];
      return _mergeOutboxMessages(threadId, base);
    }
    final merged = <String, EmailMessage>{};
    void addAll(List<EmailMessage>? messages) {
      if (messages == null) {
        return;
      }
      for (final message in messages) {
        merged[message.id] = message;
      }
    }
    addAll(_messages[threadId]);
    final includedPaths = _threadingFolderPaths(
      includeOtherFolders: _crossFolderThreadingEnabled,
    );
    for (final path in includedPaths) {
      final entry = _folderCache[path];
      if (entry == null) {
        continue;
      }
      addAll(entry.data.messages[threadId]);
    }
    _mergeOutboxIntoMap(merged, threadId);
    final list = merged.values.toList();
    list.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return list;
  }

  @override
  EmailMessage? latestMessageForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final outboxItem = _outboxItemForThread(threadId);
      if (outboxItem == null) {
        return null;
      }
      return _outboxMessage(outboxItem, threadIdOverride: threadId);
    }
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.last;
  }

  @override
  Future<void> selectFolder(String path) async {
    if (_selectedFolderPath == path && _activeSearch == null) {
      return;
    }
    // Clear any active search when navigating to a real folder.
    _activeSearch = null;
    _isSearchLoading = false;
    _priorFolderPath = null;
    _selectedFolderPath = path;
    if (path == kOutboxFolderPath) {
      _errorMessage = null;
      _status = ProviderStatus.ready;
      notifyListeners();
      return;
    }
    _currentMailboxPath = path;
    _errorMessage = null;
    final cached = _folderCache[path];
    if (cached != null) {
      _applyMailboxData(cached.data);
      _status = ProviderStatus.ready;
      notifyListeners();
    } else {
      _status = ProviderStatus.loading;
      notifyListeners();
    }
    _startFolderLoad(path, showErrors: cached == null);
    _warmThreadingFolders();
  }

  @override
  Future<void> search(SearchQuery? query) async {
    if (query == null) {
      // Clear search — return to prior folder.
      final prior = _priorFolderPath ?? _currentMailboxPath;
      _activeSearch = null;
      _isSearchLoading = false;
      _priorFolderPath = null;
      await selectFolder(prior);
      return;
    }
    _priorFolderPath ??= _selectedFolderPath == kSearchFolderPath
        ? (_priorFolderPath ?? _currentMailboxPath)
        : _selectedFolderPath;
    _activeSearch = query;
    _selectedFolderPath = kSearchFolderPath;
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
    if (_loadingFolders.add(kSearchFolderPath)) notifyListeners();
    _loadSearchInBackground(query, token);
  }

  Future<void> _loadSearchInBackground(SearchQuery query, int token) async {
    try {
      final data = await _fetchSearchResults(query);
      if (_loadTokens[kSearchFolderPath] != token) return;
      if (_selectedFolderPath == kSearchFolderPath) {
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
      if (_selectedFolderPath == kSearchFolderPath) {
        _status = ProviderStatus.error;
        _errorMessage = error.toString();
        _isSearchLoading = false;
        notifyListeners();
      }
    } finally {
      if (_loadTokens[kSearchFolderPath] == token &&
          _loadingFolders.remove(kSearchFolderPath)) {
        notifyListeners();
      }
    }
  }

  Future<_MailboxData> _fetchSearchResults(SearchQuery query) async {
    final client = _client;
    if (client == null) throw StateError('IMAP client not connected.');

    // Search across INBOX (and cross-folder paths if enabled).
    final paths = [_currentMailboxPath];
    if (_crossFolderThreadingEnabled) {
      paths.addAll(_threadingFolderPaths(includeOtherFolders: true)
          .where((p) => !paths.contains(p)));
    }

    final imapCriteria = query.toImapSearch();
    final allThreads = <String, List<EmailMessage>>{};

    for (final path in paths) {
      try {
        final mailbox = await client.selectMailboxByPath(path);
        if (mailbox.messagesExists <= 0) continue;

        // Use IMAP SEARCH to get matching sequence numbers, then fetch them.
        final searchResult = await client.searchMessages(
          searchCriteria: imapCriteria,
        );
        final matchingSeq = searchResult.matchingSequence;
        if (matchingSeq == null || matchingSeq.isEmpty) continue;

        // Fetch headers for matched messages.
        final seq = matchingSeq;
        final fetchResult = await client.fetchMessages(
          seq,
          '(UID FLAGS ENVELOPE)',
        );

        for (final message in fetchResult.messages) {
          if (message.envelope == null) continue;
          final uid = message.uid;
          final threadId = _resolveThreadId(
            subject: message.envelope!.subject ?? '(No subject)',
            messageId: message.envelope!.messageId,
            inReplyTo: message.envelope!.inReplyTo,
          );
          final emailMsg = _buildEmailMessage(message, includeBody: false);
          if (uid != null) {
            allThreads.putIfAbsent(threadId, () => []).add(emailMsg);
          }
        }
      } catch (_) {
        // Skip folders that error out during search.
      }
    }

    if (allThreads.isEmpty) {
      return const _MailboxData(threads: [], messages: {});
    }

    final threads = _buildThreads(allThreads);
    return _MailboxData(threads: threads, messages: allThreads);
  }

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
    await _sendQueue.initialize();
    final recipients = _parseRecipients(toLine);
    if (recipients.isEmpty) {
      throw StateError('No recipients provided.');
    }
    final replySnapshot = _captureReplySnapshot(thread);
    return _sendQueue.enqueue(
      OutboxDraft(
        accountKey: accountId,
        threadId: thread?.id,
        toLine: toLine,
        ccLine: ccLine,
        bccLine: bccLine,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
        replyMessageId: replySnapshot?.messageId,
        replyInReplyTo: replySnapshot?.inReplyTo,
      ),
    );
  }

  @override
  Future<bool> cancelSend(String outboxId) async {
    await _sendQueue.initialize();
    return _sendQueue.cancel(outboxId);
  }

  Future<void> _sendQueuedMessage(OutboxItem item) async {
    final thread = item.threadId == null ? null : _findThread(item.threadId!);
    await _sendMessageNow(
      thread: thread,
      toLine: item.toLine,
      ccLine: item.ccLine,
      bccLine: item.bccLine,
      subject: item.subject,
      bodyHtml: item.bodyHtml,
      bodyText: item.bodyText,
      replyMessageId: item.replyMessageId,
      replyInReplyTo: item.replyInReplyTo,
    );
  }

  Future<void> _saveQueuedDraft(OutboxItem item) async {
    final thread = item.threadId == null ? null : _findThread(item.threadId!);
    await _saveDraftNow(
      thread: thread,
      toLine: item.toLine,
      ccLine: item.ccLine,
      bccLine: item.bccLine,
      subject: item.subject,
      bodyHtml: item.bodyHtml,
      bodyText: item.bodyText,
      replyMessageId: item.replyMessageId,
      replyInReplyTo: item.replyInReplyTo,
    );
  }

  Future<void> _sendMessageNow({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
    String? replyMessageId,
    String? replyInReplyTo,
  }) async {
    final smtpServer = config.smtpServer.isNotEmpty
        ? config.smtpServer
        : config.server;
    final smtpUsername = config.smtpUseImapCredentials
        ? config.username
        : config.smtpUsername;
    final smtpPassword = config.smtpUseImapCredentials
        ? config.password
        : config.smtpPassword;
    final recipients = _parseRecipients(toLine);
    final ccRecipients = _parseRecipients(ccLine ?? '');
    final bccRecipients = _parseRecipients(bccLine ?? '');
    if (recipients.isEmpty) {
      throw StateError('No recipients provided.');
    }

    final from = MailAddress(null, email);
    final builder =
      MessageBuilder.prepareMultipartAlternativeMessage(
            plainText: bodyText,
            htmlText: bodyHtml,
          )
          ..from = [from]
          ..to = recipients
          ..subject = subject;
    if (ccRecipients.isNotEmpty) {
      builder.cc = ccRecipients;
    }
    if (bccRecipients.isNotEmpty) {
      builder.bcc = bccRecipients;
    }

    final original = _replySource(
      thread: thread,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
    );
    if (original != null) {
      builder.originalMessage = original;
    }

    final message = builder.buildMimeMessage();
    final smtpServerConfig = SmtpServer(
      smtpServer,
      port: config.smtpPort,
      ssl: config.smtpPort == 465,
      allowInsecure: !config.smtpUseTls,
      username: smtpUsername,
      password: smtpPassword,
      ignoreBadCertificate: false,
    );
    final mailerMessage = Message()
      ..from = Address(email)
      ..recipients = recipients.map((recipient) {
        return Address(recipient.email, recipient.personalName);
      }).toList()
      ..subject = subject
      ..text = bodyText
      ..html = bodyHtml;
    if (ccRecipients.isNotEmpty) {
      mailerMessage.ccRecipients = ccRecipients.map((recipient) {
        return Address(recipient.email, recipient.personalName);
      }).toList();
    }
    if (bccRecipients.isNotEmpty) {
      mailerMessage.bccRecipients = bccRecipients.map((recipient) {
        return Address(recipient.email, recipient.personalName);
      }).toList();
    }
    final replyHeaders = _replyHeaders(
      thread: thread,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
    );
    if (replyHeaders.isNotEmpty) {
      mailerMessage.headers.addAll(replyHeaders);
    }
    await _withTimeout(
      send(mailerMessage, smtpServerConfig),
      const Duration(seconds: 30),
      'SMTP send timed out.',
    );

    try {
      await _withTimeout(
        _appendToSentWithRetry(message),
        const Duration(seconds: 12),
        'Saving to Sent timed out.',
      );
    } catch (error) {
      _errorMessage = 'Sent, but saving to Sent failed: $error';
      notifyListeners();
    }
    try {
      await _withTimeout(
        refresh(),
        const Duration(seconds: 12),
        'Refreshing after send timed out.',
      );
    } catch (_) {}
  }

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
    await _saveDraftNow(
      thread: thread,
      toLine: toLine,
      ccLine: ccLine,
      bccLine: bccLine,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
    );
  }

  Future<void> _saveDraftNow({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
    String? replyMessageId,
    String? replyInReplyTo,
  }) async {
    final recipients = _parseRecipients(toLine);
    final ccRecipients = _parseRecipients(ccLine ?? '');
    final bccRecipients = _parseRecipients(bccLine ?? '');
    final from = MailAddress(null, email);
    final builder =
        MessageBuilder.prepareMultipartAlternativeMessage(
            plainText: bodyText,
            htmlText: bodyHtml,
          )
          ..from = [from]
          ..to = recipients
          ..subject = subject;
    if (ccRecipients.isNotEmpty) {
      builder.cc = ccRecipients;
    }
    if (bccRecipients.isNotEmpty) {
      builder.bcc = bccRecipients;
    }
    final original = _replySource(
      thread: thread,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
    );
    if (original != null) {
      builder.originalMessage = original;
    }
    final message = builder.buildMimeMessage();
    await _withTimeout(
      _appendToDrafts(message),
      const Duration(seconds: 12),
      'Saving draft timed out.',
    );
    try {
      await _withTimeout(
        refresh(),
        const Duration(seconds: 12),
        'Refreshing after draft timed out.',
      );
    } catch (_) {}
  }

  @override
  Future<String?> archiveThread(EmailThread thread) async {
    final targetPath = _resolveArchivePath(thread);
    if (targetPath == null || targetPath.isEmpty) {
      return 'Archive folder not found.';
    }
    final allMessages = messagesForThread(thread.id);
    final ids = allMessages
        .map((message) => int.tryParse(message.id))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) {
      return 'No messages to archive.';
    }
    // Snapshot for rollback.
    final threadIndex = _threads.indexWhere((t) => t.id == thread.id);
    final savedMessages = List<EmailMessage>.from(allMessages);
    // Optimistic remove — UI updates immediately.
    _removeThreadFromCache(thread.id);
    notifyListeners();
    try {
      await _ensureConnected();
      final client = _client;
      if (client == null) {
        _restoreThreadToCache(thread, savedMessages, threadIndex);
        notifyListeners();
        return 'IMAP client not connected.';
      }
      await client.selectMailboxByPath(_currentMailboxPath);
      final sequence = MessageSequence.fromIds(ids, isUid: true);
      if (client.serverInfo.supports(ImapServerInfo.capabilityMove)) {
        await client.uidMove(sequence, targetMailboxPath: targetPath);
      } else {
        await client.uidCopy(sequence, targetMailboxPath: targetPath);
        await client.uidStore(
          sequence,
          [MessageFlags.deleted],
          action: StoreAction.add,
        );
        await client.expunge();
      }
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
    final allMessages = messagesForThread(thread.id);
    final toMove = singleMessage != null ? [singleMessage] : allMessages;
    final ids = toMove
        .map((m) => int.tryParse(m.id))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) {
      return 'No messages to move.';
    }
    // Snapshot for rollback.
    final threadIndex = _threads.indexWhere((t) => t.id == thread.id);
    final savedMessages = List<EmailMessage>.from(allMessages);
    // Optimistic remove.
    if (singleMessage == null) {
      _removeThreadFromCache(thread.id);
    } else {
      _removeSingleMessageFromCache(thread.id, singleMessage.id);
    }
    notifyListeners();
    try {
      await _ensureConnected();
      final client = _client;
      if (client == null) {
        _restoreThreadToCache(thread, savedMessages, threadIndex);
        notifyListeners();
        return 'IMAP client not connected.';
      }
      await client.selectMailboxByPath(_currentMailboxPath);
      final sequence = MessageSequence.fromIds(ids, isUid: true);
      if (client.serverInfo.supports(ImapServerInfo.capabilityMove)) {
        await client.uidMove(sequence, targetMailboxPath: targetPath);
      } else {
        await client.uidCopy(sequence, targetMailboxPath: targetPath);
        await client.uidStore(
          sequence,
          [MessageFlags.deleted],
          action: StoreAction.add,
        );
        await client.expunge();
      }
      return null;
    } catch (e) {
      // Server failed — roll back.
      _restoreThreadToCache(thread, savedMessages, threadIndex);
      notifyListeners();
      return e.toString();
    }
  }

  void _removeSingleMessageFromCache(String threadId, String messageId) {
    final messages = _messages[threadId];
    if (messages == null) {
      return;
    }
    final remaining =
        messages.where((m) => m.id != messageId).toList();
    if (remaining.isEmpty) {
      _removeThreadFromCache(threadId); // also sets _lastMutationAt
      return;
    }
    _lastMutationAt = DateTime.now();
    _messages[threadId] = remaining;
    final entry = _folderCache[_currentMailboxPath];
    if (entry == null) {
      return;
    }
    final nextMessages = Map<String, List<EmailMessage>>.from(
      entry.data.messages,
    )..[threadId] = remaining;
    _folderCache[_currentMailboxPath] = _FolderCacheEntry(
      data: _MailboxData(threads: entry.data.threads, messages: nextMessages),
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<String?> setThreadUnread(EmailThread thread, bool isUnread) async {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return 'Cannot mark outbox messages.';
    }
    final ids = messagesForThread(thread.id)
        .map((message) => int.tryParse(message.id))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) {
      return 'No messages to update.';
    }
    await _ensureConnected();
    final client = _client;
    if (client == null) {
      return 'IMAP client not connected.';
    }
    await client.selectMailboxByPath(_currentMailboxPath);
    final sequence = MessageSequence.fromIds(ids, isUid: true);
    await client.uidStore(
      sequence,
      [MessageFlags.seen],
      action: isUnread ? StoreAction.remove : StoreAction.add,
    );
    _updateThreadReadState(thread.id, isUnread);
    notifyListeners();
    return null;
  }

  Future<T> _withTimeout<T>(
    Future<T> future,
    Duration timeout,
    String message,
  ) {
    return future.timeout(
      timeout,
      onTimeout: () {
        throw StateError(message);
      },
    );
  }

  String? _resolveArchivePath(EmailThread thread) {
    final latest = latestMessageForThread(thread.id);
    final year = latest?.receivedAt?.year;
    if (year != null) {
      final byYear = _archiveYearPaths[year];
      if (byYear != null && byYear.isNotEmpty) {
        return byYear;
      }
    }
    return _archiveMailboxPath;
  }

  void _removeThreadFromCache(String threadId) {
    _lastMutationAt = DateTime.now();
    _threads.removeWhere((thread) => thread.id == threadId);
    _messages.remove(threadId);
    final entry = _folderCache[_currentMailboxPath];
    if (entry == null) {
      return;
    }
    final nextThreads =
        entry.data.threads.where((thread) => thread.id != threadId).toList();
    final nextMessages = Map<String, List<EmailMessage>>.from(
      entry.data.messages,
    )..remove(threadId);
    _folderCache[_currentMailboxPath] = _FolderCacheEntry(
      data: _MailboxData(threads: nextThreads, messages: nextMessages),
      fetchedAt: DateTime.now(),
    );
  }

  /// Re-inserts a thread and its messages after a failed optimistic remove.
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
    // Also restore the folder cache entry.
    final entry = _folderCache[_currentMailboxPath];
    if (entry != null && !entry.data.threads.any((t) => t.id == thread.id)) {
      final insertAt = index.clamp(0, entry.data.threads.length);
      final restoredThreads = List<EmailThread>.from(entry.data.threads)
        ..insert(insertAt, thread);
      final restoredMessages = Map<String, List<EmailMessage>>.from(
        entry.data.messages,
      );
      if (messages.isNotEmpty) restoredMessages[thread.id] = messages;
      _folderCache[_currentMailboxPath] = _FolderCacheEntry(
        data: _MailboxData(threads: restoredThreads, messages: restoredMessages),
        fetchedAt: entry.fetchedAt,
      );
    }
  }

  void _updateThreadReadState(String threadId, bool isUnread) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      final current = _threads[index];
      _threads[index] = EmailThread(
        id: current.id,
        subject: current.subject,
        participants: current.participants,
        time: current.time,
        unread: isUnread,
        starred: current.starred,
        receivedAt: current.receivedAt,
      );
    }
    final messages = _messages[threadId];
    if (messages != null) {
      _messages[threadId] = messages
          .map((message) => _copyMessageWithUnread(message, isUnread))
          .toList();
    }
    final entry = _folderCache[_currentMailboxPath];
    if (entry == null) {
      return;
    }
    final updatedThreads = entry.data.threads
        .map(
          (thread) => thread.id == threadId
              ? EmailThread(
                  id: thread.id,
                  subject: thread.subject,
                  participants: thread.participants,
                  time: thread.time,
                  unread: isUnread,
                  starred: thread.starred,
                  receivedAt: thread.receivedAt,
                )
              : thread,
        )
        .toList();
    final updatedMessages = Map<String, List<EmailMessage>>.from(
      entry.data.messages,
    );
    final cachedMessages = updatedMessages[threadId];
    if (cachedMessages != null) {
      updatedMessages[threadId] = cachedMessages
          .map((message) => _copyMessageWithUnread(message, isUnread))
          .toList();
    }
    _folderCache[_currentMailboxPath] = _FolderCacheEntry(
      data: _MailboxData(threads: updatedThreads, messages: updatedMessages),
      fetchedAt: entry.fetchedAt,
    );
  }

  EmailMessage _copyMessageWithUnread(EmailMessage message, bool isUnread) {
    return EmailMessage(
      id: message.id,
      threadId: message.threadId,
      subject: message.subject,
      from: message.from,
      to: message.to,
      cc: message.cc,
      bcc: message.bcc,
      replyTo: message.replyTo,
      time: message.time,
      isMe: message.isMe,
      isUnread: isUnread,
      bodyText: message.bodyText,
      bodyHtml: message.bodyHtml,
      receivedAt: message.receivedAt,
      messageId: message.messageId,
      inReplyTo: message.inReplyTo,
      sendStatus: message.sendStatus,
    );
  }

  Map<String, String> _replyHeaders({
    required EmailThread? thread,
    String? replyMessageId,
    String? replyInReplyTo,
  }) {
    final resolved = _resolveReplySnapshot(
      thread: thread,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
    );
    if (resolved == null || resolved.messageId == null) {
      return {};
    }
    final messageId = resolved.messageId!;
    final inReplyTo = resolved.inReplyTo;
    final headers = <String, String>{
      MailConventions.headerInReplyTo: messageId,
    };
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      headers[MailConventions.headerReferences] = '$inReplyTo $messageId';
    } else {
      headers[MailConventions.headerReferences] = messageId;
    }
    return headers;
  }

  Future<void> _loadFolders() async {
    final client = _client;
    if (client == null) {
      throw StateError('IMAP client not connected.');
    }
    final boxes = await client.listMailboxes(recursive: true);
    _folderSections.clear();
    _sentMailboxPath = null;
    _draftsMailboxPath = null;
    _archiveMailboxPath = null;
    _archiveYearPaths.clear();
    _pathSeparator = null;
    final mailboxItems = <FolderItem>[];
    final folderItems = <FolderItem>[];
    var index = 0;

    for (final box in boxes) {
      if (box.flags.contains(MailboxFlag.noSelect)) {
        continue;
      }
      _pathSeparator ??= box.pathSeparator;
      if (box.flags.contains(MailboxFlag.sent)) {
        _sentMailboxPath ??= box.path;
      }
      if (box.flags.contains(MailboxFlag.drafts)) {
        _draftsMailboxPath ??= box.path;
      }
      if (box.flags.contains(MailboxFlag.archive)) {
        _archiveMailboxPath ??= box.path;
      }
      final segments = box.pathSeparator.isEmpty
          ? <String>[box.path]
          : box.path.split(box.pathSeparator);
      if (segments.isNotEmpty) {
        final last = segments.last.toLowerCase();
        if (_archiveMailboxPath == null && last == 'archive') {
          _archiveMailboxPath = box.path;
        }
        if (segments.length >= 2) {
          final parent = segments[segments.length - 2].toLowerCase();
          final year = int.tryParse(segments.last);
          if (parent == 'archives' && year != null) {
            _archiveYearPaths[year] = box.path;
          }
        }
      }
      final status = await client.statusMailbox(box, [StatusFlags.unseen]);
      final unread = status.messagesUnseen;
      final depth = _pathDepth(box.path, box.pathSeparator);
      final item = FolderItem(
        index: index++,
        name: box.name,
        path: box.path,
        depth: depth,
        unreadCount: unread,
        icon: _iconForMailbox(box.flags),
      );
      if (_isSystemMailbox(box.flags)) {
        mailboxItems.add(item);
      } else {
        folderItems.add(item);
      }
    }

    mailboxItems.sort((a, b) => a.name.compareTo(b.name));
    folderItems.sort((a, b) {
      final aPath = a.path.toLowerCase();
      final bPath = b.path.toLowerCase();
      if (aPath == bPath) {
        return a.depth.compareTo(b.depth);
      }
      return aPath.compareTo(bPath);
    });

    _folderSections.add(
      FolderSection(
        title: 'Mailboxes',
        kind: FolderSectionKind.mailboxes,
        items: mailboxItems,
      ),
    );
    if (folderItems.isNotEmpty) {
      _folderSections.add(
        FolderSection(
          title: 'Folders',
          kind: FolderSectionKind.folders,
          items: folderItems,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Two-phase fetch helpers
  // ---------------------------------------------------------------------------

  // Returns true if [text] looks like HTML markup.
  bool _looksLikeHtml(String? text) {
    if (text == null || text.isEmpty) return false;
    return text.contains('<html') ||
        text.contains('<body') ||
        text.contains('<div') ||
        text.contains('<table') ||
        text.contains('<p>') ||
        text.contains('<br') ||
        text.contains('<!DOCTYPE') ||
        text.contains('<span') ||
        text.contains('<td');
  }

  // Extracts body text / HTML from a fully-fetched MimeMessage.
  (String? bodyText, String? bodyHtml) _decodeBodies(MimeMessage message) {
    var bodyText = message.decodeTextPlainPart();
    var bodyHtml = message.decodeTextHtmlPart();

    if (bodyText != null && bodyText.isNotEmpty && _looksLikeHtml(bodyText)) {
      bodyHtml ??= bodyText;
      bodyText = null;
    }

    if (bodyHtml == null || bodyHtml.isEmpty) {
      final contentText = message.decodeContentText();
      if (contentText != null && contentText.isNotEmpty) {
        if (_looksLikeHtml(contentText)) {
          bodyHtml = contentText;
        } else if (bodyText == null || bodyText.isEmpty) {
          bodyText = contentText;
        }
      }
      if (bodyHtml == null || bodyHtml.isEmpty) {
        for (final part in message.allPartsFlat) {
          if (part.mediaType.sub == MediaSubtype.textHtml) {
            final decoded = part.decodeContentText();
            if (decoded != null && decoded.isNotEmpty) {
              bodyHtml = decoded;
              break;
            }
          }
        }
      }
    }
    return (bodyText, bodyHtml);
  }

  // Builds an EmailMessage from a MimeMessage that has at least ENVELOPE+FLAGS.
  // Pass [includeBody]=false for the fast header-only phase.
  EmailMessage _buildEmailMessage(
    MimeMessage message, {
    required bool includeBody,
  }) {
    final envelope = message.envelope!;
    final subject = envelope.subject ?? '(No subject)';
    final messageId = envelope.messageId;
    final inReplyTo = envelope.inReplyTo;
    final fromAddress =
        envelope.from?.isNotEmpty == true ? envelope.from!.first : null;
    final from = EmailAddress(
      name: fromAddress?.personalName ?? '',
      email: fromAddress?.email ?? '',
    );
    final to =
        envelope.to
            ?.map(
              (r) => EmailAddress(name: r.personalName ?? '', email: r.email),
            )
            .toList() ??
        const [];
    final cc =
        envelope.cc
            ?.map(
              (r) => EmailAddress(name: r.personalName ?? '', email: r.email),
            )
            .toList() ??
        const [];
    final bcc =
        envelope.bcc
            ?.map(
              (r) => EmailAddress(name: r.personalName ?? '', email: r.email),
            )
            .toList() ??
        const [];
    // RFC 5322 Reply-To header — available from IMAP ENVELOPE field 4.
    final replyTo =
        envelope.replyTo
            ?.map(
              (r) => EmailAddress(name: r.personalName ?? '', email: r.email),
            )
            .toList() ??
        const <EmailAddress>[];
    final timestamp = envelope.date?.toUtc();
    const timeLabel = '';
    final isUnread = !(message.flags?.contains(MessageFlags.seen) ?? false);
    final threadId = _resolveThreadId(
      subject: subject,
      messageId: messageId,
      inReplyTo: inReplyTo,
    );
    final (bodyText, bodyHtml) =
        includeBody ? _decodeBodies(message) : (null, null);
    return EmailMessage(
      id: message.uid?.toString() ?? '${message.sequenceId}',
      threadId: threadId,
      subject: subject,
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      replyTo: replyTo,
      time: timeLabel,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      isMe: from.email == email,
      isUnread: isUnread,
      receivedAt: timestamp,
      messageId: messageId,
      inReplyTo: inReplyTo,
    );
  }

  // Assembles threads from a messagesByThread map.
  List<EmailThread> _buildThreads(
    Map<String, List<EmailMessage>> messagesByThread,
  ) {
    final threads = <EmailThread>[];
    for (final entry in messagesByThread.entries) {
      final messages = entry.value;
      if (messages.isEmpty) continue;
      messages.sort((a, b) {
        final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      final latest = messages.last;
      threads.add(
        EmailThread(
          id: entry.key,
          subject: latest.subject,
          participants: {latest.from, ...latest.to}.toList(),
          time: latest.time,
          unread: messages.any((m) => m.isUnread),
          starred: false,
          receivedAt: latest.receivedAt,
        ),
      );
    }
    threads.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return threads;
  }

  // Phase 1: fetch headers only — returns quickly, no body decoding.
  Future<({_MailboxData data, MessageSequence uidSequence})>
  _fetchHeaders(String path) async {
    final client = _client;
    if (client == null) throw StateError('IMAP client not connected.');
    final mailbox = await client.selectMailboxByPath(path);
    if (mailbox.messagesExists <= 0) {
      return (
        data: const _MailboxData(threads: [], messages: {}),
        uidSequence: MessageSequence(),
      );
    }
    final end = mailbox.messagesExists;
    final start = end > 50 ? end - 49 : 1;
    final fetchResult = await client.fetchMessages(
      MessageSequence.fromRange(start, end),
      '(UID FLAGS ENVELOPE)',
    );
    final messagesByThread = <String, List<EmailMessage>>{};
    final uids = <int>[];
    for (final message in fetchResult.messages) {
      if (message.envelope == null) continue;
      final uid = message.uid;
      if (uid != null) uids.add(uid);
      messagesByThread
          .putIfAbsent(
            _resolveThreadId(
              subject: message.envelope!.subject ?? '(No subject)',
              messageId: message.envelope!.messageId,
              inReplyTo: message.envelope!.inReplyTo,
            ),
            () => [],
          )
          .add(_buildEmailMessage(message, includeBody: false));
    }
    return (
      data: _MailboxData(
        threads: _buildThreads(messagesByThread),
        messages: messagesByThread,
      ),
      uidSequence: uids.isEmpty
          ? MessageSequence()
          : MessageSequence.fromIds(uids, isUid: true),
    );
  }

  // Phase 2: fetch full bodies for the UIDs returned by phase 1.
  // Returns updated _MailboxData with bodies filled in, or null on empty/error.
  Future<_MailboxData?> _fetchBodies(
    _MailboxData headerData,
    MessageSequence uidSequence,
  ) async {
    final client = _client;
    if (client == null) throw StateError('IMAP client not connected.');
    if (uidSequence.isEmpty) return null;
    final fetchResult = await client.uidFetchMessages(
      uidSequence,
      '(UID FLAGS BODYSTRUCTURE BODY.PEEK[])',
    );
    // Build a UID→header-message lookup so we can copy envelope fields.
    final headerById = <String, EmailMessage>{};
    for (final msgs in headerData.messages.values) {
      for (final m in msgs) {
        headerById[m.id] = m;
      }
    }
    final messagesByThread =
        Map<String, List<EmailMessage>>.from(headerData.messages).map(
          (k, v) => MapEntry(k, List<EmailMessage>.from(v)),
        );
    for (final message in fetchResult.messages) {
      final uid = message.uid?.toString() ?? '${message.sequenceId}';
      final header = headerById[uid];
      if (header == null) continue;
      final (bodyText, bodyHtml) = _decodeBodies(message);
      final updated = EmailMessage(
        id: header.id,
        threadId: header.threadId,
        subject: header.subject,
        from: header.from,
        to: header.to,
        cc: header.cc,
        bcc: header.bcc,
        replyTo: header.replyTo,
        time: header.time,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        isMe: header.isMe,
        isUnread: header.isUnread,
        receivedAt: header.receivedAt,
        messageId: header.messageId,
        inReplyTo: header.inReplyTo,
      );
      final list = messagesByThread[header.threadId];
      if (list == null) continue;
      final idx = list.indexWhere((m) => m.id == uid);
      if (idx >= 0) list[idx] = updated;
    }
    return _MailboxData(
      threads: headerData.threads,
      messages: messagesByThread,
    );
  }

  void _applyMailboxData(_MailboxData data) {
    _threads
      ..clear()
      ..addAll(data.threads);
    _messages
      ..clear()
      ..addAll(data.messages);
    _folderCache[_currentMailboxPath] =
        _FolderCacheEntry(data: data, fetchedAt: DateTime.now());
  }

  void _startFolderLoad(String path, {required bool showErrors}) {
    final token = ++_loadCounter;
    _loadTokens[path] = token;
    if (_loadingFolders.add(path)) {
      notifyListeners();
    }
    _loadMailboxInBackground(path, token, showErrors: showErrors);
  }

  Future<void> _loadMailboxInBackground(
    String path,
    int token, {
    required bool showErrors,
  }) async {
    // Snapshot the mutation clock so we can detect mid-fetch local mutations.
    final mutationAtStart = _lastMutationAt;

    void applyData(_MailboxData data, {required bool updateCache}) {
      if (_loadTokens[path] != token) return;
      final mutated = _lastMutationAt != mutationAtStart;
      if (mutated) {
        _status = ProviderStatus.ready;
        notifyListeners();
        return;
      }
      if (updateCache) {
        _folderCache[path] = _FolderCacheEntry(
          data: data,
          fetchedAt: DateTime.now(),
        );
      }
      if (path == _currentMailboxPath) {
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
      // --- Phase 1: headers only (fast) — paints thread list immediately ---
      final (:data, :uidSequence) = await _fetchHeaders(path);
      applyData(data, updateCache: false);

      // --- Phase 2: bodies (slow) — infills content without blocking UI ---
      if (_loadTokens[path] != token) return;
      final fullData = await _fetchBodies(data, uidSequence);
      if (fullData != null) {
        applyData(fullData, updateCache: true);
      }
    } catch (error) {
      if (_loadTokens[path] != token) return;
      if (showErrors && path == _currentMailboxPath) {
        _status = ProviderStatus.error;
        _errorMessage = error.toString();
        notifyListeners();
      }
    } finally {
      if (_loadTokens[path] == token && _loadingFolders.remove(path)) {
        notifyListeners();
      }
    }
  }

  // Used for initial load — same two-phase approach so the UI paints fast.
  Future<void> _loadMailboxAndCache(String path) async {
    final (:data, :uidSequence) = await _fetchHeaders(path);
    _folderCache[path] = _FolderCacheEntry(
      data: data,
      fetchedAt: DateTime.now(),
    );
    _applyMailboxData(data);
    final fullData = await _fetchBodies(data, uidSequence);
    if (fullData != null) {
      _folderCache[path] = _FolderCacheEntry(
        data: fullData,
        fetchedAt: DateTime.now(),
      );
      _applyMailboxData(fullData);
    }
  }

  List<MailAddress> _parseRecipients(String raw) {
    final parts = raw
        .split(RegExp(r'[;,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.map((email) => MailAddress(null, email)).toList();
  }


  List<EmailThread> _outboxThreads() {
    final items = _sendQueue.items;
    if (items.isEmpty) {
      return const [];
    }
    final threads = <EmailThread>[];
    for (final item in items) {
      final recipients = <EmailAddress>[
        ...splitEmailAddresses(item.toLine),
        ...splitEmailAddresses(item.ccLine ?? ''),
        ...splitEmailAddresses(item.bccLine ?? ''),
      ];
      final createdAt = item.createdAt.toLocal();
      threads.add(
        EmailThread(
          id: _outboxThreadId(item),
          subject: item.subject,
          participants: [EmailAddress(name: email, email: email), ...recipients],
          time: '',
          unread: false,
          starred: false,
          receivedAt: createdAt,
        ),
      );
    }
    threads.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return threads;
  }

  String _outboxThreadId(OutboxItem item) {
    return 'outbox-${item.id}';
  }

  OutboxItem? _outboxItemForThread(String threadId) {
    if (!threadId.startsWith('outbox-')) {
      return null;
    }
    final id = threadId.substring('outbox-'.length);
    for (final item in _sendQueue.items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  EmailMessage _outboxMessage(
    OutboxItem item, {
    String? threadIdOverride,
  }) {
    final to = splitEmailAddresses(item.toLine);
    final cc = splitEmailAddresses(item.ccLine ?? '');
    final bcc = splitEmailAddresses(item.bccLine ?? '');
    final createdAt = item.createdAt.toLocal();
    return EmailMessage(
      id: 'outbox-${item.id}',
      threadId: threadIdOverride ?? item.threadId ?? _outboxThreadId(item),
      subject: item.subject,
      from: EmailAddress(name: email, email: email),
      to: to,
      cc: cc,
      bcc: bcc,
      time: '',
      bodyText: item.bodyTextOrNull,
      bodyHtml: item.bodyHtmlOrNull,
      isMe: true,
      isUnread: false,
      receivedAt: createdAt,
      inReplyTo: item.replyMessageId,
      sendStatus: _statusForOutbox(item.status),
    );
  }

  List<EmailMessage> _mergeOutboxMessages(
    String threadId,
    List<EmailMessage> base,
  ) {
    final merged = <String, EmailMessage>{
      for (final message in base) message.id: message,
    };
    _mergeOutboxIntoMap(merged, threadId);
    final list = merged.values.toList();
    list.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return list;
  }

  void _mergeOutboxIntoMap(
    Map<String, EmailMessage> merged,
    String threadId,
  ) {
    for (final item in _sendQueue.items) {
      if (item.threadId != threadId) {
        continue;
      }
      final message = _outboxMessage(item, threadIdOverride: threadId);
      merged[message.id] = message;
    }
  }

  MessageSendStatus _statusForOutbox(OutboxStatus status) {
    switch (status) {
      case OutboxStatus.queued:
        return MessageSendStatus.queued;
      case OutboxStatus.sending:
        return MessageSendStatus.sending;
      case OutboxStatus.failed:
        return MessageSendStatus.failed;
    }
  }

  EmailThread? _findThread(String threadId) {
    for (final thread in _threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    for (final entry in _folderCache.values) {
      for (final thread in entry.data.threads) {
        if (thread.id == threadId) {
          return thread;
        }
      }
    }
    return null;
  }

  MimeMessage? _replySource({
    required EmailThread? thread,
    String? replyMessageId,
    String? replyInReplyTo,
  }) {
    final resolved = _resolveReplySnapshot(
      thread: thread,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
    );
    if (resolved == null || resolved.messageId == null) {
      return null;
    }
    final messageId = resolved.messageId!;
    final inReplyTo = resolved.inReplyTo;
    final source = MimeMessage();
    source.addHeader(MailConventions.headerMessageId, messageId);
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      source.addHeader(MailConventions.headerInReplyTo, inReplyTo);
    }
    final references = [
      if (inReplyTo != null && inReplyTo.isNotEmpty) inReplyTo,
      messageId,
    ].join(' ');
    source.addHeader(MailConventions.headerReferences, references);
    return source;
  }

  _ReplySnapshot? _resolveReplySnapshot({
    required EmailThread? thread,
    String? replyMessageId,
    String? replyInReplyTo,
  }) {
    if (replyMessageId != null && replyMessageId.isNotEmpty) {
      return _ReplySnapshot(
        messageId: replyMessageId,
        inReplyTo: replyInReplyTo,
      );
    }
    if (thread == null) {
      return null;
    }
    final latest = latestMessageForThread(thread.id);
    if (latest == null || latest.messageId == null) {
      return null;
    }
    return _ReplySnapshot(
      messageId: latest.messageId,
      inReplyTo: latest.inReplyTo,
    );
  }

  _ReplySnapshot? _captureReplySnapshot(EmailThread? thread) {
    return _resolveReplySnapshot(thread: thread);
  }

  Future<void> _appendToSentWithRetry(MimeMessage message) async {
    await _ensureConnected();
    final path = _sentMailboxPath ?? _draftsMailboxPath;
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      await _client!.appendMessage(
        message,
        flags: const [MessageFlags.seen],
        targetMailboxPath: path,
      );
    } catch (_) {
      await _reconnect();
      await _client!.appendMessage(
        message,
        flags: const [MessageFlags.seen],
        targetMailboxPath: path,
      );
    }
  }

  Future<void> _appendToDrafts(MimeMessage message) async {
    await _ensureConnected();
    final path = _draftsMailboxPath ?? _sentMailboxPath;
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      await _client!.appendMessage(
        message,
        flags: const [MessageFlags.draft],
        targetMailboxPath: path,
      );
    } catch (_) {}
  }

  Future<void> _ensureConnected() async {
    if (_client != null && _client!.isConnected && _client!.isLoggedIn) {
      return;
    }
    await _reconnect();
  }

  Future<void> _reconnect() async {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = ImapClient(isLogEnabled: false);
    await _client!.connectToServer(
      config.server,
      config.port,
      isSecure: config.useTls,
    );
    await _client!.login(config.username, config.password);
    await _loadFolders();
  }

  int _pathDepth(String path, String separator) {
    if (separator.isEmpty) {
      return 0;
    }
    return path.split(separator).length - 1;
  }

  bool _isSystemMailbox(List<MailboxFlag> flags) {
    return flags.any(
      (flag) =>
          flag == MailboxFlag.inbox ||
          flag == MailboxFlag.sent ||
          flag == MailboxFlag.drafts ||
          flag == MailboxFlag.archive ||
          flag == MailboxFlag.trash ||
          flag == MailboxFlag.junk,
    );
  }

  IconData? _iconForMailbox(List<MailboxFlag> flags) {
    if (flags.contains(MailboxFlag.inbox)) {
      return Icons.inbox_rounded;
    }
    if (flags.contains(MailboxFlag.sent)) {
      return Icons.send_rounded;
    }
    if (flags.contains(MailboxFlag.drafts)) {
      return Icons.drafts_rounded;
    }
    if (flags.contains(MailboxFlag.archive)) {
      return Icons.archive_rounded;
    }
    if (flags.contains(MailboxFlag.trash)) {
      return Icons.delete_rounded;
    }
    if (flags.contains(MailboxFlag.junk)) {
      return Icons.report_gmailerrorred_rounded;
    }
    return null;
  }

  String _resolveThreadId({
    required String subject,
    String? messageId,
    String? inReplyTo,
  }) {
    final normalized = _normalizeSubject(subject);
    final subjectThreadId = _subjectThreadId.putIfAbsent(
      normalized,
      () => 'imap-${normalized.hashCode}',
    );
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      final existing = _messageIdToThreadId[inReplyTo];
      if (existing != null) {
        if (messageId != null && messageId.isNotEmpty) {
          _messageIdToThreadId[messageId] = existing;
        }
        return existing;
      }
    }
    if (messageId != null && messageId.isNotEmpty) {
      final existing = _messageIdToThreadId[messageId];
      if (existing != null) {
        return existing;
      }
      _messageIdToThreadId[messageId] = subjectThreadId;
      if (inReplyTo != null && inReplyTo.isNotEmpty) {
        _messageIdToThreadId[inReplyTo] = subjectThreadId;
      }
      return subjectThreadId;
    }
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      _messageIdToThreadId[inReplyTo] = subjectThreadId;
    }
    return subjectThreadId;
  }

  String _normalizeSubject(String subject) {
    var value = subject.toLowerCase().trim();
    value = value.replaceAll(RegExp(r'^(re|fwd|fw):\s*'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  void updateCrossFolderThreading(bool enabled) {
    if (_crossFolderThreadingEnabled == enabled) {
      return;
    }
    _crossFolderThreadingEnabled = enabled;
    _warmThreadingFolders();
    _startFolderLoad(_currentMailboxPath, showErrors: false);
  }

  void updateInboxRefreshInterval(Duration interval) {
    _inboxRefreshInterval = interval;
    _scheduleInboxRefresh();
  }

  void _warmThreadingFolders() {
    final paths = _threadingFolderPaths(
      includeOtherFolders: _crossFolderThreadingEnabled,
    );
    for (final path in paths) {
      if (_folderCache.containsKey(path) || _loadingFolders.contains(path)) {
        continue;
      }
      _startFolderLoad(path, showErrors: false);
    }
  }

  Set<String> _threadingFolderPaths({
    required bool includeOtherFolders,
  }) {
    final paths = <String>{_currentMailboxPath, 'INBOX'};
    if (_sentMailboxPath != null && _sentMailboxPath!.isNotEmpty) {
      paths.add(_sentMailboxPath!);
    }
    if (_draftsMailboxPath != null && _draftsMailboxPath!.isNotEmpty) {
      paths.add(_draftsMailboxPath!);
    }
    if (includeOtherFolders) {
      paths.addAll(_folderCache.keys);
    }
    return paths;
  }

  void _scheduleInboxRefresh() {
    _inboxRefreshTimer?.cancel();
    if (_inboxRefreshInterval.inMinutes <= 0) {
      return;
    }
    _inboxRefreshTimer = Timer.periodic(_inboxRefreshInterval, (_) {
      _startFolderLoad('INBOX', showErrors: false);
    });
  }

  @override
  void dispose() {
    _inboxRefreshTimer?.cancel();
    _sendQueue.dispose();
    try {
      final client = _client;
      if (client != null && client.isConnected) {
        if (client.isLoggedIn) {
          client.logout();
        }
        client.disconnect();
      }
    } catch (_) {}
    super.dispose();
  }
}

class _MailboxData {
  const _MailboxData({
    required this.threads,
    required this.messages,
  });

  final List<EmailThread> threads;
  final Map<String, List<EmailMessage>> messages;
}

class _FolderCacheEntry {
  const _FolderCacheEntry({
    required this.data,
    required this.fetchedAt,
  });

  final _MailboxData data;
  final DateTime fetchedAt;
}

class _ReplySnapshot {
  const _ReplySnapshot({this.messageId, this.inReplyTo});

  final String? messageId;
  final String? inReplyTo;
}
