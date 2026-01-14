import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import 'email_provider.dart';

class ImapSmtpEmailProvider extends EmailProvider {
  ImapSmtpEmailProvider({required this.config, required this.email});

  final ImapAccountConfig config;
  final String email;

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
  int _loadCounter = 0;
  String _currentMailboxPath = 'INBOX';
  String? _sentMailboxPath;
  String? _draftsMailboxPath;
  Duration _inboxRefreshInterval = const Duration(minutes: 5);
  Timer? _inboxRefreshTimer;

  @override
  ProviderStatus get status => _status;

  @override
  String? get errorMessage => _errorMessage;

  @override
  List<EmailThread> get threads => List.unmodifiable(_threads);

  @override
  List<FolderSection> get folderSections => List.unmodifiable(_folderSections);

  @override
  String get selectedFolderPath => _currentMailboxPath;

  @override
  Future<void> initialize() async {
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
      _scheduleInboxRefresh();
      await _loadFolders();
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
    return _messages[threadId] ?? const [];
  }

  @override
  EmailMessage? latestMessageForThread(String threadId) {
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.last;
  }

  @override
  Future<void> selectFolder(String path) async {
    if (_currentMailboxPath == path) {
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

    final original = _replySource(thread);
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
    final replyHeaders = _replyHeaders(thread);
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
    final original = _replySource(thread);
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

  Map<String, String> _replyHeaders(EmailThread? thread) {
    if (thread == null) {
      return {};
    }
    final latest = latestMessageForThread(thread.id);
    if (latest == null || latest.messageId == null) {
      return {};
    }
    final headers = <String, String>{
      MailConventions.headerInReplyTo: latest.messageId!,
    };
    if (latest.inReplyTo != null) {
      headers[MailConventions.headerInReplyTo] = latest.inReplyTo!;
      headers[MailConventions.headerReferences] =
          '${latest.inReplyTo} ${latest.messageId}';
    } else {
      headers[MailConventions.headerReferences] = latest.messageId!;
    }
    return headers;
  }

  Future<void> _loadMailbox(String path) async {
    final data = await _fetchMailboxData(path);
    _applyMailboxData(data);
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
    final mailboxItems = <FolderItem>[];
    final folderItems = <FolderItem>[];
    var index = 0;

    for (final box in boxes) {
      if (box.flags.contains(MailboxFlag.noSelect)) {
        continue;
      }
      if (box.flags.contains(MailboxFlag.sent)) {
        _sentMailboxPath ??= box.path;
      }
      if (box.flags.contains(MailboxFlag.drafts)) {
        _draftsMailboxPath ??= box.path;
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
      final bodyText = message.decodeTextPlainPart();
      final bodyHtml = message.decodeTextHtmlPart();
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

  MimeMessage? _replySource(EmailThread? thread) {
    if (thread == null) {
      return null;
    }
    final latest = latestMessageForThread(thread.id);
    if (latest == null || latest.messageId == null) {
      return null;
    }
    final source = MimeMessage();
    source.addHeader(MailConventions.headerMessageId, latest.messageId!);
    if (latest.inReplyTo != null) {
      source.addHeader(MailConventions.headerInReplyTo, latest.inReplyTo!);
    }
    final references = [
      if (latest.inReplyTo != null) latest.inReplyTo!,
      latest.messageId!,
    ].join(' ');
    source.addHeader(MailConventions.headerReferences, references);
    return source;
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
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      return _messageIdToThreadId[inReplyTo] ?? inReplyTo;
    }
    if (messageId != null && messageId.isNotEmpty) {
      final existing = _messageIdToThreadId[messageId];
      if (existing != null) {
        return existing;
      }
      _messageIdToThreadId[messageId] = messageId;
      return messageId;
    }
    final normalized = _normalizeSubject(subject);
    final existing = _subjectThreadId[normalized];
    if (existing != null) {
      return existing;
    }
    final id = 'imap-${normalized.hashCode}';
    _subjectThreadId[normalized] = id;
    return id;
  }

  String _normalizeSubject(String subject) {
    var value = subject.toLowerCase().trim();
    value = value.replaceAll(RegExp(r'^(re|fwd|fw):\\s*'), '');
    value = value.replaceAll(RegExp(r'\\s+'), ' ').trim();
    return value;
  }

  String _formatTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  void updateInboxRefreshInterval(Duration interval) {
    _inboxRefreshInterval = interval;
    _scheduleInboxRefresh();
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
