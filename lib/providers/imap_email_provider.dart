import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import 'email_provider.dart';

class ImapEmailProvider extends EmailProvider {
  ImapEmailProvider({
    required this.config,
    required this.email,
  });

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
  String _currentMailboxPath = 'INBOX';

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
      await _loadFolders();
      await _loadMailbox(_currentMailboxPath);
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
    _status = ProviderStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await _loadFolders();
      await _loadMailbox(_currentMailboxPath);
      _status = ProviderStatus.ready;
      notifyListeners();
    } catch (error) {
      _status = ProviderStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
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
    if (_currentMailboxPath == path || _status == ProviderStatus.loading) {
      return;
    }
    _currentMailboxPath = path;
    _status = ProviderStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await _loadMailbox(_currentMailboxPath);
      _status = ProviderStatus.ready;
      notifyListeners();
    } catch (error) {
      _status = ProviderStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> _loadMailbox(String path) async {
    final client = _client;
    if (client == null) {
      throw StateError('IMAP client not connected.');
    }
    final mailbox = await client.selectMailboxByPath(path);
    if (mailbox.messagesExists <= 0) {
      _threads.clear();
      _messages.clear();
      return;
    }
    final end = mailbox.messagesExists;
    final start = end > 50 ? end - 49 : 1;
    final fetchResult = await client.fetchMessages(
      MessageSequence.fromRange(start, end),
      '(FLAGS ENVELOPE BODYSTRUCTURE BODY.PEEK[])',
    );
    _threads.clear();
    _messages.clear();

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
      final to = envelope.to
              ?.map(
                (recipient) => EmailAddress(
                  name: recipient.personalName ?? '',
                  email: recipient.email,
                ),
              )
              .toList() ??
          const [];
      final timestamp = envelope.date?.toLocal();
      final timeLabel = timestamp == null
          ? ''
          : _formatTime(timestamp);
      final isUnread =
          !(message.flags?.contains(MessageFlags.seen) ?? false);
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
        time: timeLabel,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        isMe: from.email == email,
        isUnread: isUnread,
        receivedAt: timestamp,
        messageId: messageId,
        inReplyTo: inReplyTo,
      );
      _messages.putIfAbsent(threadId, () => []).add(messageModel);
    }

    for (final entry in _messages.entries) {
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
      final participants = {
        latest.from,
        ...latest.to,
      }.toList();
      _threads.add(
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

    _threads.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  Future<void> _loadFolders() async {
    final client = _client;
    if (client == null) {
      throw StateError('IMAP client not connected.');
    }
    final boxes = await client.listMailboxes(recursive: true);
    _folderSections.clear();
    final mailboxItems = <FolderItem>[];
    final folderItems = <FolderItem>[];
    var index = 0;

    for (final box in boxes) {
      if (box.flags.contains(MailboxFlag.noSelect)) {
        continue;
      }
      final status = await client.statusMailbox(
        box,
        [StatusFlags.unseen],
      );
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

  @override
  void dispose() {
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
