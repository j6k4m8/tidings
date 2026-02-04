import 'package:flutter/material.dart';

import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../state/send_queue.dart';
import 'email_provider.dart';

class MockEmailProvider extends EmailProvider {
  MockEmailProvider({required this.accountId}) {
    _sendQueue = SendQueue(
      accountKey: accountId,
      onChanged: notifyListeners,
      sendNow: _sendQueuedMessage,
      saveDraft: _saveQueuedDraft,
    );
  }

  final String accountId;
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
    final filtered = _threads.where((thread) {
      return _threadFolders[thread.id] == _selectedFolderPath;
    }).toList();
    final active = filtered.isNotEmpty
        ? filtered
        : (_selectedFolderPath == 'INBOX' ? _threads : <EmailThread>[]);
    active.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return active;
  }

  @override
  String get selectedFolderPath => _selectedFolderPath;

  @override
  bool isFolderLoading(String path) => false;

  ProviderStatus _status = ProviderStatus.idle;
  String? _errorMessage;
  String _selectedFolderPath = 'INBOX';
  late final SendQueue _sendQueue;

  @override
  Future<void> initialize() async {
    await _sendQueue.initialize();
    if (_status == ProviderStatus.ready) {
      return;
    }
    _status = ProviderStatus.loading;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _status = ProviderStatus.ready;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    await initialize();
  }

  @override
  Future<void> selectFolder(String path) async {
    if (_selectedFolderPath == path) {
      return;
    }
    _selectedFolderPath = path;
    notifyListeners();
  }

  @override
  List<EmailMessage> messagesForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final item = _outboxItemForThread(threadId);
      if (item == null) {
        return const [];
      }
      return [_outboxMessage(item, threadIdOverride: threadId)];
    }
    final base = _messages[threadId] ?? const [];
    return _mergeOutboxMessages(threadId, base);
  }

  @override
  EmailMessage? latestMessageForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final item = _outboxItemForThread(threadId);
      if (item == null) {
        return null;
      }
      return _outboxMessage(item, threadIdOverride: threadId);
    }
    final messages = _messages[threadId];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.last;
  }

  @override
  List<FolderSection> get folderSections => _withOutboxSection(_folderSections);

  @override
  int get outboxCount => _sendQueue.pendingCount;

  static const EmailAddress _you = EmailAddress(
    name: 'You',
    email: 'jordan@tidings.dev',
  );
  static const EmailAddress _ari = EmailAddress(
    name: 'Ari',
    email: 'ari@tidings.dev',
  );
  static const EmailAddress _sam = EmailAddress(
    name: 'Sam',
    email: 'sam@tidings.dev',
  );
  static const EmailAddress _priya = EmailAddress(
    name: 'Priya',
    email: 'priya@tidings.dev',
  );
  static const EmailAddress _maya = EmailAddress(
    name: 'Maya',
    email: 'maya@tidings.dev',
  );
  static const EmailAddress _dev = EmailAddress(
    name: 'Dev',
    email: 'dev@tidings.dev',
  );
  static const EmailAddress _sasha = EmailAddress(
    name: 'Sasha',
    email: 'sasha@tidings.dev',
  );

  final List<EmailThread> _threads = _buildThreads();
  final Map<String, List<EmailMessage>> _messages = _buildMessages();
  final Map<String, String> _threadFolders = Map<String, String>.from(
    _seedThreadFolders,
  );

  static List<EmailThread> _buildThreads() {
    final now = DateTime.now();
    return [
      EmailThread(
        id: 'thread-01',
        subject: 'Kitchenette smell: first guess (spoiler: wrong)',
        participants: [_ari, _sam, _you],
        time: '8:42 AM',
        unread: true,
        starred: true,
        receivedAt: now.subtract(const Duration(minutes: 18)),
      ),
      EmailThread(
        id: 'thread-02',
        subject: 'Smell triage plan (and our next false lead)',
        participants: [_priya, _you],
        time: '7:18 AM',
        unread: true,
        starred: false,
        receivedAt: now.subtract(const Duration(hours: 2)),
      ),
      EmailThread(
        id: 'thread-06',
        subject: 'HTML-heavy newsletter preview',
        participants: [_maya, _you],
        time: '8:55 AM',
        unread: true,
        starred: false,
        receivedAt: now.subtract(const Duration(minutes: 6)),
      ),
      EmailThread(
        id: 'thread-03',
        subject: 'Kitchenette smell: status update + suspects',
        participants: [_maya, _you],
        time: 'Yesterday',
        unread: false,
        starred: false,
        receivedAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      EmailThread(
        id: 'thread-04',
        subject: 'We thought it was the fridge... it was not',
        participants: [_dev, _you],
        time: 'Mon',
        unread: false,
        starred: false,
        receivedAt: now.subtract(const Duration(days: 3, hours: 2)),
      ),
      EmailThread(
        id: 'thread-05',
        subject: 'Final attempt: is it the sink trap?',
        participants: [_sasha, _you],
        time: 'Mon',
        unread: false,
        starred: false,
        receivedAt: now.subtract(const Duration(days: 4, hours: 1)),
      ),
    ];
  }

  static const Map<String, String> _seedThreadFolders = {
    'thread-01': 'INBOX',
    'thread-02': 'INBOX',
    'thread-06': 'INBOX',
    'thread-03': 'Press',
    'thread-04': 'Product',
    'thread-05': 'Product/Launch notes',
  };

  static const Map<String, List<EmailMessage>> _seedMessages = {
    'thread-01': [
      EmailMessage(
        id: 'msg-01-1',
        threadId: 'thread-01',
        subject: 'Kitchenette smell: first guess (spoiler: wrong)',
        from: _ari,
        to: [_you],
        time: '8:32 AM',
        bodyText:
            'I think the smell is coming from the compost bin. I wrapped it and moved it outside. If the odor’s gone by 10, we found it.',
        isMe: false,
        isUnread: true,
      ),
      EmailMessage(
        id: 'msg-01-2',
        threadId: 'thread-01',
        subject: 'Kitchenette smell: first guess (spoiler: wrong)',
        from: _sam,
        to: [_you],
        time: '8:42 AM',
        bodyText:
            'Update: compost is innocent. Smell is still aggressively present. I’m opening windows and blaming the vents now.',
        isMe: false,
        isUnread: true,
      ),
    ],
    'thread-02': [
      EmailMessage(
        id: 'msg-02-1',
        threadId: 'thread-02',
        subject: 'Smell triage plan (and our next false lead)',
        from: _priya,
        to: [_you],
        time: '7:18 AM',
        bodyText:
            'Proposed plan: 1) fridge purge, 2) run disposal with citrus, 3) check sink trap. If smell persists, we escalate to facilities.',
        isMe: false,
        isUnread: true,
      ),
      EmailMessage(
        id: 'msg-02-2',
        threadId: 'thread-02',
        subject: 'Smell triage plan (and our next false lead)',
        from: _you,
        to: [_priya],
        time: '7:22 AM',
        bodyText:
            'Agree on the plan. I’ll handle the disposal (again). If we “fix” it and the smell returns, we’ll log it as a false lead.',
        isMe: true,
        isUnread: false,
      ),
    ],
    'thread-06': [
      EmailMessage(
        id: 'msg-06-1',
        threadId: 'thread-06',
        subject: 'Newsletter for this week',
        from: _maya,
        to: [_you],
        time: '8:55 AM',
        bodyHtml: '''
<!doctype html>
<html>
  <body>
    <h2 style="margin:0 0 8px 0;">Weekly Brief — Jan 29, 2026</h2>
    <p style="margin:0 0 12px 0;">
      Hey team — here's a quick update.
    </p>
    <ul>
      <li><b>Status:</b> <span style="color:#1a73e8;">STILL THERES A SMELL</span></li>
      <li><b>Open items:</b> find smell; identify smell; figure out where smell coming from</li>
      <li><b>Next sync:</b> Friday at 10:00 AM</li>
    </ul>
    <hr />
    <table style="border-collapse:collapse; width:100%; margin:12px 0;">
      <tr>
        <th style="text-align:left; border-bottom:1px solid #ddd; padding:6px;">Owner</th>
        <th style="text-align:left; border-bottom:1px solid #ddd; padding:6px;">Task</th>
        <th style="text-align:left; border-bottom:1px solid #ddd; padding:6px;">Status</th>
      </tr>
      <tr>
        <td style="padding:6px;">jordan</td>
        <td style="padding:6px;">making less smells</td>
        <td style="padding:6px;">In progress</td>
      </tr>
      <tr>
        <td style="padding:6px;">alice</td>
        <td style="padding:6px;">smells dashboard</td>
        <td style="padding:6px;">Blocked</td>
      </tr>
    </table>
  </body>
</html>
''',
        isMe: false,
        isUnread: true,
      ),
    ],
    'thread-03': [
      EmailMessage(
        id: 'msg-03-1',
        threadId: 'thread-03',
        subject: 'Kitchenette smell: status update + suspects',
        from: _maya,
        to: [_you],
        time: 'Yesterday',
        bodyHtml: '''
<p>Smell report, day 2:</p>
<p><b>Suspects we cleared</b></p>
<ul>
  <li>Compost bin (empty, sanitized)</li>
  <li>Fridge shelves (wiped, no leaks)</li>
  <li>Microwave (surprisingly innocent)</li>
</ul>
<p><b>New suspects</b></p>
<ul>
  <li>Sink trap</li>
  <li>Dishwasher filter</li>
  <li>The mysterious “drawer of sauces”</li>
</ul>
<p>We thought it was the fridge door seal, but the smell came back an hour later.</p>
''',
        isMe: false,
        isUnread: false,
      ),
    ],
    'thread-04': [
      EmailMessage(
        id: 'msg-04-1',
        threadId: 'thread-04',
        subject: 'We thought it was the fridge... it was not',
        from: _dev,
        to: [_you],
        time: 'Mon',
        bodyText:
            'We pulled everything out of the fridge. Smell vanished for 15 minutes, then returned even stronger. False lead #3?',
        isMe: false,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-04-2',
        threadId: 'thread-04',
        subject: 'We thought it was the fridge... it was not',
        from: _you,
        to: [_dev],
        time: 'Mon',
        bodyText:
            'Yep, that was a decoy. Let’s try the sink trap next and document the timeline so we stop gaslighting ourselves.',
        isMe: true,
        isUnread: false,
      ),
    ],
    'thread-05': [
      EmailMessage(
        id: 'msg-05-1',
        threadId: 'thread-05',
        subject: 'Final attempt: is it the sink trap?',
        from: _sasha,
        to: [_you],
        time: 'Mon',
        bodyText:
            'I poured hot water + baking soda down the trap. Smell dipped for ~20 minutes, then came back. Either the trap isn’t it, or it’s trolling us.',
        isMe: false,
        isUnread: false,
      ),
    ],
  };

  static const List<FolderSection> _folderSections = [
    FolderSection(
      title: 'Mailboxes',
      kind: FolderSectionKind.mailboxes,
      items: [
        FolderItem(
          index: 0,
          name: 'Inbox',
          path: 'INBOX',
          unreadCount: 12,
          icon: Icons.inbox_rounded,
        ),
        FolderItem(
          index: 1,
          name: 'Archive',
          path: 'Archive',
          unreadCount: 0,
          icon: Icons.archive_rounded,
        ),
        FolderItem(
          index: 2,
          name: 'Drafts',
          path: 'Drafts',
          unreadCount: 3,
          icon: Icons.drafts_rounded,
        ),
        FolderItem(
          index: 3,
          name: 'Sent',
          path: 'Sent',
          unreadCount: 0,
          icon: Icons.send_rounded,
        ),
      ],
    ),
    FolderSection(
      title: 'Folders',
      kind: FolderSectionKind.folders,
      items: [
        FolderItem(index: 4, name: 'Product', path: 'Product', unreadCount: 6),
        FolderItem(
          index: 5,
          name: 'Launch notes',
          path: 'Product/Launch notes',
          depth: 1,
          unreadCount: 2,
        ),
        FolderItem(index: 6, name: 'Hiring', path: 'Hiring', unreadCount: 1),
        FolderItem(index: 7, name: 'Press', path: 'Press', unreadCount: 0),
        FolderItem(
          index: 8,
          name: 'Receipts',
          path: 'Receipts',
          unreadCount: 0,
        ),
      ],
    ),
    FolderSection(
      title: 'Labels',
      kind: FolderSectionKind.labels,
      items: [
        FolderItem(index: 9, name: 'VIP', path: 'Label/VIP', unreadCount: 4),
        FolderItem(
          index: 10,
          name: 'Later',
          path: 'Label/Later',
          unreadCount: 1,
        ),
        FolderItem(
          index: 11,
          name: 'Follow up',
          path: 'Label/Follow up',
          unreadCount: 2,
        ),
      ],
    ),
  ];

  static Map<String, List<EmailMessage>> _buildMessages() {
    final map = <String, List<EmailMessage>>{};
    for (final entry in _seedMessages.entries) {
      map[entry.key] = List<EmailMessage>.from(entry.value);
    }
    return map;
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
    if (toLine.trim().isEmpty) {
      throw StateError('No recipients provided.');
    }
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
      ),
    );
  }

  @override
  Future<bool> cancelSend(String outboxId) async {
    await _sendQueue.initialize();
    return _sendQueue.cancel(outboxId);
  }

  Future<void> _sendQueuedMessage(OutboxItem item) async {
    final thread =
        item.threadId == null ? null : _findThread(item.threadId!);
    await _sendMessageNow(
      thread: thread,
      toLine: item.toLine,
      ccLine: item.ccLine,
      bccLine: item.bccLine,
      subject: item.subject,
      bodyHtml: item.bodyHtml,
      bodyText: item.bodyText,
    );
  }

  Future<void> _saveQueuedDraft(OutboxItem item) async {
    final thread =
        item.threadId == null ? null : _findThread(item.threadId!);
    await _saveDraftNow(
      thread: thread,
      toLine: item.toLine,
      ccLine: item.ccLine,
      bccLine: item.bccLine,
      subject: item.subject,
      bodyHtml: item.bodyHtml,
      bodyText: item.bodyText,
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
  }) async {
    final now = DateTime.now();
    final timeLabel = _formatTime(now);
    final recipients = _parseRecipients(toLine);
    final ccRecipients = _parseRecipients(ccLine ?? '');
    final bccRecipients = _parseRecipients(bccLine ?? '');
    if (thread == null) {
      final threadId = 'thread-${now.microsecondsSinceEpoch}';
      final newThread = EmailThread(
        id: threadId,
        subject: subject,
        participants: [_you, ...recipients, ...ccRecipients, ...bccRecipients],
        time: timeLabel,
        unread: false,
        starred: false,
        receivedAt: now,
      );
      _threads.insert(0, newThread);
      _threadFolders[threadId] = 'Sent';
      _messages[threadId] = [
        EmailMessage(
          id: 'msg-${now.microsecondsSinceEpoch}',
          threadId: threadId,
          subject: subject,
          from: _you,
          to: recipients,
          cc: ccRecipients,
          bcc: bccRecipients,
          time: timeLabel,
          bodyText: bodyText,
          bodyHtml: bodyHtml,
          isMe: true,
          isUnread: false,
          receivedAt: now,
        ),
      ];
      notifyListeners();
      return;
    }

    final list = _messages.putIfAbsent(thread.id, () => []);
    list.add(
      EmailMessage(
        id: 'msg-${now.microsecondsSinceEpoch}',
        threadId: thread.id,
        subject: subject,
        from: _you,
        to: recipients,
        cc: ccRecipients,
        bcc: bccRecipients,
        time: timeLabel,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        isMe: true,
        isUnread: false,
        receivedAt: now,
      ),
    );
    final threadIndex = _threads.indexWhere((item) => item.id == thread.id);
    if (threadIndex != -1) {
      _threads[threadIndex] = EmailThread(
        id: thread.id,
        subject: subject,
        participants: thread.participants,
        time: timeLabel,
        unread: thread.unread,
        starred: thread.starred,
        receivedAt: now,
      );
    }
    notifyListeners();
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
  }) async {
    final now = DateTime.now();
    final timeLabel = _formatTime(now);
    final recipients = _parseRecipients(toLine);
    final ccRecipients = _parseRecipients(ccLine ?? '');
    final bccRecipients = _parseRecipients(bccLine ?? '');
    final threadId = thread?.id ?? 'draft-${now.microsecondsSinceEpoch}';
    final isNewThread = thread == null || !_messages.containsKey(threadId);
    if (isNewThread) {
      final newThread = EmailThread(
        id: threadId,
        subject: subject,
        participants: [_you, ...recipients, ...ccRecipients, ...bccRecipients],
        time: timeLabel,
        unread: false,
        starred: false,
        receivedAt: now,
      );
      _threads.insert(0, newThread);
      _threadFolders[threadId] = 'Drafts';
      _messages[threadId] = [];
    }
    _messages[threadId]?.add(
      EmailMessage(
        id: 'draft-${now.microsecondsSinceEpoch}',
        threadId: threadId,
        subject: subject,
        from: _you,
        to: recipients,
        cc: ccRecipients,
        bcc: bccRecipients,
        time: timeLabel,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        isMe: true,
        isUnread: false,
        receivedAt: now,
      ),
    );
    notifyListeners();
  }

  @override
  Future<String?> setThreadUnread(EmailThread thread, bool isUnread) async {
    if (thread.id.startsWith('outbox-')) {
      return 'Cannot mark outbox messages.';
    }
    final index = _threads.indexWhere((item) => item.id == thread.id);
    if (index == -1) {
      return 'Thread not found.';
    }
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
    final messages = _messages[thread.id];
    if (messages != null) {
      _messages[thread.id] = messages
          .map((message) => _copyMessageWithUnread(message, isUnread))
          .toList();
    }
    notifyListeners();
    return null;
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

  @override
  Future<String?> archiveThread(EmailThread thread) async {
    final index = _threads.indexWhere((item) => item.id == thread.id);
    if (index == -1) {
      return 'Thread not found.';
    }
    _threads.removeAt(index);
    _messages.remove(thread.id);
    _threadFolders.remove(thread.id);
    notifyListeners();
    return null;
  }

  List<EmailAddress> _parseRecipients(String raw) {
    final parts = raw
        .split(RegExp(r'[;,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return const [_you];
    }
    return parts
        .map((email) => EmailAddress(name: email, email: email))
        .toList();
  }

  List<EmailAddress> _parseRecipientAddresses(String raw) {
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
        ..._parseRecipientAddresses(item.toLine),
        ..._parseRecipientAddresses(item.ccLine ?? ''),
        ..._parseRecipientAddresses(item.bccLine ?? ''),
      ];
      final createdAt = item.createdAt.toLocal();
      threads.add(
        EmailThread(
          id: _outboxThreadId(item),
          subject: item.subject,
          participants: [_you, ...recipients],
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
    final to = _parseRecipientAddresses(item.toLine);
    final cc = _parseRecipientAddresses(item.ccLine ?? '');
    final bcc = _parseRecipientAddresses(item.bccLine ?? '');
    final createdAt = item.createdAt.toLocal();
    return EmailMessage(
      id: 'outbox-${item.id}',
      threadId: threadIdOverride ?? item.threadId ?? _outboxThreadId(item),
      subject: item.subject,
      from: _you,
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
    return null;
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

  String _formatTime(DateTime timestamp) {
    var hour = timestamp.hour;
    final minute = timestamp.minute;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final minuteLabel = minute.toString().padLeft(2, '0');
    return '$hour:$minuteLabel $suffix';
  }

  @override
  void dispose() {
    _sendQueue.dispose();
    super.dispose();
  }
}
