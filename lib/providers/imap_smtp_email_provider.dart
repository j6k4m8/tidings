import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../state/send_queue.dart';
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
  String? _sentMailboxPath;
  String? _draftsMailboxPath;
  String? _archiveMailboxPath;
  final Map<int, String> _archiveYearPaths = {};
  String? _pathSeparator;
  bool _crossFolderThreadingEnabled = false;
  Duration _inboxRefreshInterval = const Duration(minutes: 5);
  Timer? _inboxRefreshTimer;
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
  List<FolderSection> get folderSections => _withOutboxSection(_folderSections);

  @override
  int get outboxCount => _sendQueue.pendingCount;

  @override
  String get selectedFolderPath => _selectedFolderPath;

  @override
  bool isFolderLoading(String path) => _loadingFolders.contains(path);

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
    if (_selectedFolderPath == path) {
      return;
    }
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
  Future<void> sendMessage({
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
    await _sendQueue.enqueue(
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
    final ids = messagesForThread(thread.id)
        .map((message) => int.tryParse(message.id))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) {
      return 'No messages to archive.';
    }
    await _ensureConnected();
    final client = _client;
    if (client == null) {
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
    _removeThreadFromCache(thread.id);
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
      fetchedAt: entry.fetchedAt,
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

  Future<_MailboxData> _fetchMailboxData(String path) async {
    final client = _client;
    if (client == null) {
      throw StateError('IMAP client not connected.');
    }
    final mailbox = await client.selectMailboxByPath(path);
    if (mailbox.messagesExists <= 0) {
      return const _MailboxData(threads: [], messages: {});
    }
    final end = mailbox.messagesExists;
    final start = end > 50 ? end - 49 : 1;
    final fetchResult = await client.fetchMessages(
      MessageSequence.fromRange(start, end),
      '(FLAGS ENVELOPE BODYSTRUCTURE BODY.PEEK[])',
    );
    final messagesByThread = <String, List<EmailMessage>>{};
    var index = 0;
    for (final message in fetchResult.messages) {
      final envelope = message.envelope;
      if (envelope == null) {
        continue;
      }
      final subject = envelope.subject ?? '(No subject)';
      final messageId = envelope.messageId;
      final inReplyTo = envelope.inReplyTo;
      final fromAddress = envelope.from?.isNotEmpty == true
          ? envelope.from!.first
          : null;
      final from = EmailAddress(
        name: fromAddress?.personalName ?? 'Unknown',
        email: fromAddress?.email ?? '',
      );
      final to =
          envelope.to
              ?.map(
                (recipient) => EmailAddress(
                  name: recipient.personalName ?? '',
                  email: recipient.email,
                ),
              )
              .toList() ??
          const [];
      final cc =
          envelope.cc
              ?.map(
                (recipient) => EmailAddress(
                  name: recipient.personalName ?? '',
                  email: recipient.email,
                ),
              )
              .toList() ??
          const [];
      final bcc =
          envelope.bcc
              ?.map(
                (recipient) => EmailAddress(
                  name: recipient.personalName ?? '',
                  email: recipient.email,
                ),
              )
              .toList() ??
          const [];
      final timestamp = envelope.date?.toLocal();
      final timeLabel = timestamp == null ? '' : _formatTime(timestamp);
      final isUnread = !(message.flags?.contains(MessageFlags.seen) ?? false);
      final threadId = _resolveThreadId(
        subject: subject,
        messageId: messageId,
        inReplyTo: inReplyTo,
      );
      var bodyText = message.decodeTextPlainPart();
      var bodyHtml = message.decodeTextHtmlPart();

      // Helper to check if text looks like HTML
      bool looksLikeHtml(String? text) {
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

      // Fix: If bodyText contains HTML, move it to bodyHtml
      if (bodyText != null && bodyText.isNotEmpty && looksLikeHtml(bodyText)) {
        if (bodyHtml == null || bodyHtml.isEmpty) {
          bodyHtml = bodyText;
        }
        bodyText = null; // Clear it since it's actually HTML
      }

      // Fallback: if no HTML part found, try alternative methods
      if (bodyHtml == null || bodyHtml.isEmpty) {
        // Try decoding content directly
        final contentText = message.decodeContentText();
        if (contentText != null && contentText.isNotEmpty) {
          // Check if it looks like HTML
          if (looksLikeHtml(contentText)) {
            bodyHtml = contentText;
          } else if (bodyText == null || bodyText.isEmpty) {
            // Use as plain text fallback
            bodyText = contentText;
          }
        }

        // Try finding HTML in body parts
        if (bodyHtml == null || bodyHtml.isEmpty) {
          for (final part in message.allPartsFlat) {
            final mediaType = part.mediaType;
            if (mediaType.sub == MediaSubtype.textHtml) {
              final decoded = part.decodeContentText();
              if (decoded != null && decoded.isNotEmpty) {
                bodyHtml = decoded;
                break;
              }
            }
          }
        }
      }
      final messageModel = EmailMessage(
        id: message.uid?.toString() ?? '${message.sequenceId}',
        threadId: threadId,
        subject: subject,
        from: from,
        to: to,
        cc: cc,
        bcc: bcc,
        time: timeLabel,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        isMe: from.email == email,
        isUnread: isUnread,
        receivedAt: timestamp,
        messageId: messageId,
        inReplyTo: inReplyTo,
      );
      messagesByThread.putIfAbsent(threadId, () => []).add(messageModel);
      index += 1;
      if (index % 5 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final threads = <EmailThread>[];
    for (final entry in messagesByThread.entries) {
      final messages = entry.value;
      if (messages.isEmpty) {
        continue;
      }
      messages.sort((a, b) {
        final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      final latest = messages.last;
      final participants = {latest.from, ...latest.to}.toList();
      threads.add(
        EmailThread(
          id: entry.key,
          subject: latest.subject,
          participants: participants,
          time: latest.time,
          unread: messages.any((message) => message.isUnread),
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
    return _MailboxData(threads: threads, messages: messagesByThread);
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
    try {
      final data = await _fetchMailboxData(path);
      if (_loadTokens[path] != token) {
        return;
      }
      _folderCache[path] = _FolderCacheEntry(
        data: data,
        fetchedAt: DateTime.now(),
      );
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
    } catch (error) {
      if (_loadTokens[path] != token) {
        return;
      }
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

  Future<void> _loadMailboxAndCache(String path) async {
    final data = await _fetchMailboxData(path);
    _folderCache[path] = _FolderCacheEntry(
      data: data,
      fetchedAt: DateTime.now(),
    );
    _applyMailboxData(data);
  }

  List<MailAddress> _parseRecipients(String raw) {
    final parts = raw
        .split(RegExp(r'[;,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.map((email) => MailAddress(null, email)).toList();
  }

  List<EmailAddress> _parseEmailAddresses(String raw) {
    final parts = raw
        .split(RegExp(r'[;,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts
        .map((email) => EmailAddress(name: email, email: email))
        .toList();
  }

  List<EmailThread> _outboxThreads() {
    final items = _sendQueue.items;
    if (items.isEmpty) {
      return const [];
    }
    final threads = <EmailThread>[];
    for (final item in items) {
      final recipients = <EmailAddress>[
        ..._parseEmailAddresses(item.toLine),
        ..._parseEmailAddresses(item.ccLine ?? ''),
        ..._parseEmailAddresses(item.bccLine ?? ''),
      ];
      final createdAt = item.createdAt.toLocal();
      threads.add(
        EmailThread(
          id: _outboxThreadId(item),
          subject: item.subject,
          participants: [EmailAddress(name: email, email: email), ...recipients],
          time: _formatTime(createdAt),
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
    final to = _parseEmailAddresses(item.toLine);
    final cc = _parseEmailAddresses(item.ccLine ?? '');
    final bcc = _parseEmailAddresses(item.bccLine ?? '');
    final createdAt = item.createdAt.toLocal();
    return EmailMessage(
      id: 'outbox-${item.id}',
      threadId: threadIdOverride ?? item.threadId ?? _outboxThreadId(item),
      subject: item.subject,
      from: EmailAddress(name: email, email: email),
      to: to,
      cc: cc,
      bcc: bcc,
      time: _formatTime(createdAt),
      bodyText: item.bodyText.isEmpty ? null : item.bodyText,
      bodyHtml: item.bodyHtml.isEmpty ? null : item.bodyHtml,
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

  String _formatTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
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

  List<FolderSection> _withOutboxSection(List<FolderSection> sections) {
    if (sections.isEmpty) {
      return [
        FolderSection(
          title: 'Mailboxes',
          kind: FolderSectionKind.mailboxes,
          items: [
            FolderItem(
              index: -1,
              name: 'Outbox',
              path: kOutboxFolderPath,
              unreadCount: _sendQueue.pendingCount,
              icon: Icons.outbox_rounded,
            ),
          ],
        ),
      ];
    }
    final updated = <FolderSection>[];
    for (final section in sections) {
      if (section.kind != FolderSectionKind.mailboxes) {
        updated.add(section);
        continue;
      }
      final hasOutbox = section.items.any(
        (item) => item.path == kOutboxFolderPath,
      );
      if (hasOutbox) {
        updated.add(section);
        continue;
      }
      final items = [
        FolderItem(
          index: -1,
          name: 'Outbox',
          path: kOutboxFolderPath,
          unreadCount: _sendQueue.pendingCount,
          icon: Icons.outbox_rounded,
        ),
        ...section.items,
      ];
      updated.add(
        FolderSection(
          title: section.title,
          kind: section.kind,
          items: items,
        ),
      );
    }
    return updated;
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
