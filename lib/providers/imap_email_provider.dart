import 'package:enough_mail/enough_mail.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
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
  ProviderStatus _status = ProviderStatus.idle;
  String? _errorMessage;
  ImapClient? _client;

  @override
  ProviderStatus get status => _status;

  @override
  String? get errorMessage => _errorMessage;

  @override
  List<EmailThread> get threads => List.unmodifiable(_threads);

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
      await _loadInbox();
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
      await _loadInbox();
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

  Future<void> _loadInbox() async {
    final client = _client;
    if (client == null) {
      throw StateError('IMAP client not connected.');
    }
    final mailbox = await client.selectMailboxByPath('INBOX');
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
      final threadId = _threadIdFromSubject(subject);
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
      );
      _messages.putIfAbsent(threadId, () => []).add(messageModel);
    }

    for (final entry in _messages.entries) {
      final messages = entry.value;
      if (messages.isEmpty) {
        continue;
      }
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
        ),
      );
    }

    _threads.sort((a, b) => b.time.compareTo(a.time));
  }

  String _threadIdFromSubject(String subject) {
    final normalized = subject.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return 'imap-${normalized.hashCode}';
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
