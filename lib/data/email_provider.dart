import 'package:flutter/material.dart';

@immutable
class EmailAddress {
  const EmailAddress({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  String get displayName => name.isNotEmpty ? name : email;

  String get initial {
    final value = displayName.trim();
    if (value.isEmpty) {
      return '?';
    }
    return value.substring(0, 1).toUpperCase();
  }
}

abstract class EmailProvider {
  List<EmailThread> get threads;
  List<EmailMessage> messagesForThread(String threadId);
  EmailMessage? latestMessageForThread(String threadId);
  int messageCountForThread(String threadId);
}

class MockEmailProvider implements EmailProvider {
  @override
  List<EmailThread> get threads => _threads;

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
  int messageCountForThread(String threadId) {
    return _messages[threadId]?.length ?? 0;
  }

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

  static const List<EmailThread> _threads = [
    EmailThread(
      id: 'thread-01',
      subject: 'Launch playlist visuals for the beta build',
      participants: [_ari, _sam, _you],
      time: '8:42 AM',
      unread: true,
      starred: true,
    ),
    EmailThread(
      id: 'thread-02',
      subject: 'Roadmap sync with mobile team',
      participants: [_priya, _you],
      time: '7:18 AM',
      unread: true,
      starred: false,
    ),
    EmailThread(
      id: 'thread-03',
      subject: 'Press kit update for Tidings',
      participants: [_maya, _you],
      time: 'Yesterday',
      unread: false,
      starred: false,
    ),
    EmailThread(
      id: 'thread-04',
      subject: 'Mock provider status',
      participants: [_dev, _you],
      time: 'Yesterday',
      unread: false,
      starred: true,
    ),
    EmailThread(
      id: 'thread-05',
      subject: 'Invite list for private alpha',
      participants: [_sasha, _you],
      time: 'Mon',
      unread: false,
      starred: false,
    ),
  ];

  static const Map<String, List<EmailMessage>> _messages = {
    'thread-01': [
      EmailMessage(
        id: 'msg-01-1',
        threadId: 'thread-01',
        subject: 'Launch playlist visuals for the beta build',
        from: _ari,
        to: [_you, _sam],
        time: '8:10 AM',
        body:
            'The playlist visuals are in. We can merge once the motion pass is done.',
        isMe: false,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-01-2',
        threadId: 'thread-01',
        subject: 'Re: Launch playlist visuals for the beta build',
        from: _you,
        to: [_ari, _sam],
        time: '8:22 AM',
        body: 'Perfect. I will review the light mode screens after standup.',
        isMe: true,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-01-3',
        threadId: 'thread-01',
        subject: 'Re: Launch playlist visuals for the beta build',
        from: _you,
        to: [_ari, _sam],
        time: '8:35 AM',
        body:
            'Lets do it. Make sure the new accent mapping is enabled for all accounts. '
            'I want the live preview to be visible in the thread view and in settings, '
            'and we should validate contrast across the light gradient background. '
            'If there is anything blocking, flag me before lunch so we can keep the '
            'press schedule intact.',
        isMe: true,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-01-4',
        threadId: 'thread-01',
        subject: 'Re: Launch playlist visuals for the beta build',
        from: _sam,
        to: [_you, _ari],
        time: '8:42 AM',
        body:
            'Got it. I will push a patch with the accent mapping and then verify '
            'the contrast across both themes. I will also drop a quick video into '
            'Slack so the press team can see the animation before we ship.',
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
        time: '7:10 AM',
        body:
            'We should finalize the offline queue replay semantics before mobile.',
        isMe: false,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-02-2',
        threadId: 'thread-02',
        subject: 'Re: Roadmap sync with mobile team',
        from: _priya,
        to: [_you],
        time: '7:18 AM',
        body:
            'Also, can we add a note about the send queue ordering? The mobile '
            'team wants a deterministic rule for draft updates vs. send operations '
            'when we reconnect. I can draft the section if you want.',
        isMe: false,
        isUnread: true,
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
        body: 'Updated screenshots are in the drive under /press/alpha.',
        isMe: false,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-03-2',
        threadId: 'thread-03',
        subject: 'Re: Press kit update for Tidings',
        from: _you,
        to: [_maya],
        time: 'Yesterday',
        body: 'Looks great. The new nav rail feels premium.',
        isMe: true,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-03-3',
        threadId: 'thread-03',
        subject: 'Re: Press kit update for Tidings',
        from: _maya,
        to: [_you],
        time: 'Yesterday',
        body:
            'Thanks! I will prep a second pass with dark mode focus. '
            'I am also swapping the hero background to match the new '
            'glass highlight treatment, so the light mode cards read '
            'as white without losing the gradient. I will drop a second '
            'set of exports with both light and dark in the shared folder.',
        isMe: false,
        isUnread: false,
      ),
    ],
    'thread-04': [
      EmailMessage(
        id: 'msg-04-1',
        threadId: 'thread-04',
        subject: 'Mock provider status',
        from: _dev,
        to: [_you],
        time: 'Yesterday',
        body:
            'Mock provider latency is holding at 80ms with prefetch enabled.',
        isMe: false,
        isUnread: false,
      ),
      EmailMessage(
        id: 'msg-04-2',
        threadId: 'thread-04',
        subject: 'Re: Mock provider status',
        from: _you,
        to: [_dev],
        time: 'Yesterday',
        body:
            'Nice. Lets keep the status visible in the dashboard. '
            'I would like a quick breakdown of cache hits vs. cold fetches '
            'so we can set a realistic expectation for first load times. '
            'If we can log those metrics to the console for now, we will '
            'wire them into telemetry later.',
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
        body: 'Added 12 new invites. We can onboard them Friday.',
        isMe: false,
        isUnread: false,
      ),
    ],
  };
}

@immutable
class EmailThread {
  const EmailThread({
    required this.id,
    required this.subject,
    required this.participants,
    required this.time,
    required this.unread,
    required this.starred,
  });

  final String id;
  final String subject;
  final List<EmailAddress> participants;
  final String time;
  final bool unread;
  final bool starred;

  String get participantSummary {
    return participants.map((participant) => participant.displayName).join(', ');
  }

  String get avatarLetter {
    if (participants.isEmpty) {
      return '?';
    }
    return participants.first.initial;
  }
}

@immutable
class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.threadId,
    required this.subject,
    required this.from,
    required this.to,
    required this.time,
    required this.body,
    required this.isMe,
    required this.isUnread,
  });

  final String id;
  final String threadId;
  final String subject;
  final EmailAddress from;
  final List<EmailAddress> to;
  final String time;
  final String body;
  final bool isMe;
  final bool isUnread;

  String get toSummary {
    return to.map((recipient) => recipient.displayName).join(', ');
  }
}
