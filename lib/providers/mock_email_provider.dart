import 'package:flutter/material.dart';

import '../models/email_models.dart';
import '../models/folder_models.dart';
import 'email_provider.dart';

class MockEmailProvider extends EmailProvider {
  @override
  ProviderStatus get status => _status;

  @override
  String? get errorMessage => _errorMessage;

  @override
  List<EmailThread> get threads {
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

  ProviderStatus _status = ProviderStatus.idle;
  String? _errorMessage;
  String _selectedFolderPath = 'INBOX';

  @override
  Future<void> initialize() async {
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
  List<FolderSection> get folderSections => _folderSections;

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

  static final List<EmailThread> _threads = _buildThreads();

  static List<EmailThread> _buildThreads() {
    final now = DateTime.now();
    return [
      EmailThread(
      id: 'thread-01',
      subject: 'Launch playlist visuals for the beta build',
      participants: [_ari, _sam, _you],
      time: '8:42 AM',
      unread: true,
      starred: true,
      receivedAt: now.subtract(const Duration(minutes: 18)),
    ),
    EmailThread(
      id: 'thread-02',
      subject: 'Roadmap sync with mobile team',
      participants: [_priya, _you],
      time: '7:18 AM',
      unread: true,
      starred: false,
      receivedAt: now.subtract(const Duration(hours: 2)),
    ),
    EmailThread(
      id: 'thread-03',
      subject: 'Press kit update for Tidings',
      participants: [_maya, _you],
      time: 'Yesterday',
      unread: false,
      starred: false,
      receivedAt: now.subtract(const Duration(days: 1, hours: 3)),
    ),
    EmailThread(
      id: 'thread-04',
      subject: 'Follow up on the onboarding flow copy',
      participants: [_dev, _you],
      time: 'Mon',
      unread: false,
      starred: false,
      receivedAt: now.subtract(const Duration(days: 3, hours: 2)),
    ),
    EmailThread(
      id: 'thread-05',
      subject: 'Invite list for private alpha',
      participants: [_sasha, _you],
      time: 'Mon',
      unread: false,
      starred: false,
      receivedAt: now.subtract(const Duration(days: 4, hours: 1)),
    ),
    ];
  }

  static const Map<String, String> _threadFolders = {
    'thread-01': 'INBOX',
    'thread-02': 'INBOX',
    'thread-03': 'Press',
    'thread-04': 'Product',
    'thread-05': 'Product/Launch notes',
  };

  static const Map<String, List<EmailMessage>> _messages = {
    'thread-01': [
      EmailMessage(
        id: 'msg-01-1',
        threadId: 'thread-01',
        subject: 'Launch playlist visuals for the beta build',
        from: _ari,
        to: [_you],
        time: '8:32 AM',
        bodyText:
            'We need the new playlist visuals before the beta build goes out.',
        isMe: false,
        isUnread: true,
      ),
      EmailMessage(
        id: 'msg-01-2',
        threadId: 'thread-01',
        subject: 'Launch playlist visuals for the beta build',
        from: _sam,
        to: [_you],
        time: '8:42 AM',
        bodyText:
            'I can ship the new renders this afternoon if we approve the palette.',
        isMe: false,
        isUnread: true,
      ),
    ],
    'thread-02': [
      EmailMessage(
        id: 'msg-02-1',
        threadId: 'thread-02',
        subject: 'Roadmap sync with mobile team',
        from: _priya,
        to: [_you],
        time: '7:18 AM',
        bodyText:
            'Can we align on the roadmap for the mobile rollout? I have the deck ready.',
        isMe: false,
        isUnread: true,
      ),
      EmailMessage(
        id: 'msg-02-2',
        threadId: 'thread-02',
        subject: 'Roadmap sync with mobile team',
        from: _you,
        to: [_priya],
        time: '7:22 AM',
        bodyText:
            'Yes, let’s do it. I can join after the 9 AM standup.',
        isMe: true,
        isUnread: false,
      ),
    ],
    'thread-03': [
      EmailMessage(
        id: 'msg-03-1',
        threadId: 'thread-03',
        subject: 'Press kit update for Tidings',
        from: _maya,
        to: [_you],
        time: 'Yesterday',
        bodyHtml: '''
<p>New press assets are ready to review.</p>
<p><b>Highlights</b></p>
<ul>
  <li>Updated brand mark set</li>
  <li>Fresh UI mockups</li>
  <li>Founder quotes approved</li>
</ul>
<p><a href="https://tidings.dev/press">Review the kit</a> and let me know any edits.</p>
''',
        isMe: false,
        isUnread: false,
      ),
    ],
    'thread-04': [
      EmailMessage(
        id: 'msg-04-1',
        threadId: 'thread-04',
        subject: 'Follow up on the onboarding flow copy',
        from: _dev,
        to: [_you],
        time: 'Mon',
        bodyText:
            'Did you want the onboarding flow to be more playful, or keep it tight?',
        isMe: false,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-04-2',
        threadId: 'thread-04',
        subject: 'Follow up on the onboarding flow copy',
        from: _you,
        to: [_dev],
        time: 'Mon',
        bodyText:
            'Let’s keep it crisp. Two sentences max, and emphasize focus.',
        isMe: true,
        isUnread: false,
      ),
    ],
    'thread-05': [
      EmailMessage(
        id: 'msg-05-1',
        threadId: 'thread-05',
        subject: 'Invite list for private alpha',
        from: _sasha,
        to: [_you],
        time: 'Mon',
        bodyText: 'Added 12 new invites. We can onboard them Friday.',
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
        FolderItem(
          index: 4,
          name: 'Product',
          path: 'Product',
          unreadCount: 6,
        ),
        FolderItem(
          index: 5,
          name: 'Launch notes',
          path: 'Product/Launch notes',
          depth: 1,
          unreadCount: 2,
        ),
        FolderItem(
          index: 6,
          name: 'Hiring',
          path: 'Hiring',
          unreadCount: 1,
        ),
        FolderItem(
          index: 7,
          name: 'Press',
          path: 'Press',
          unreadCount: 0,
        ),
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
        FolderItem(
          index: 9,
          name: 'VIP',
          path: 'Label/VIP',
          unreadCount: 4,
        ),
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
}
