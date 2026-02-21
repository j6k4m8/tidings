import 'package:flutter/material.dart';

import '../utils/contact_utils.dart';

enum MessageSendStatus {
  queued,
  sending,
  failed,
}

@immutable
class EmailAddress {
  const EmailAddress({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  String get displayName => normalizeContactName(name.isNotEmpty ? name : email);

  String get initial {
    return avatarInitial(displayName.isNotEmpty ? displayName : email);
  }

  String get normalizedDisplayName => displayName;
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
    this.receivedAt,
  });

  final String id;
  final String subject;
  final List<EmailAddress> participants;
  final String time;
  final bool unread;
  final bool starred;
  final DateTime? receivedAt;

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
    this.cc = const [],
    this.bcc = const [],
    this.replyTo = const [],
    required this.time,
    required this.isMe,
    required this.isUnread,
    this.bodyText,
    this.bodyHtml,
    this.receivedAt,
    this.messageId,
    this.inReplyTo,
    this.sendStatus,
    this.folderPath,
  });

  final String id;
  final String threadId;
  final String subject;
  final EmailAddress from;
  final List<EmailAddress> to;
  final List<EmailAddress> cc;
  final List<EmailAddress> bcc;
  /// Addresses from the RFC 5322 `Reply-To` header. Empty when not present.
  final List<EmailAddress> replyTo;
  final String time;
  final bool isMe;
  final bool isUnread;
  final String? bodyText;
  final String? bodyHtml;
  final DateTime? receivedAt;
  final String? messageId;
  final String? inReplyTo;
  final MessageSendStatus? sendStatus;
  /// The IMAP folder path this message was loaded from.
  final String? folderPath;

  String get toSummary {
    return to.map((recipient) => recipient.displayName).join(', ');
  }

  String get bodyPlainText {
    if (bodyText != null && bodyText!.isNotEmpty) {
      return bodyText!;
    }
    if (bodyHtml != null && bodyHtml!.isNotEmpty) {
      return _stripHtml(bodyHtml!);
    }
    return '';
  }
}

String _stripHtml(String html) {
  var text = html;

  // Remove doctype
  text = text.replaceAll(RegExp(r'<!doctype[^>]*>', caseSensitive: false), '');

  // Remove HTML comments (including conditional comments like <!-- [if gte mso 9]> -->)
  text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

  // Remove style blocks entirely
  text = text.replaceAll(
    RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
    '',
  );

  // Remove script blocks entirely
  text = text.replaceAll(
    RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
    '',
  );

  // Remove head section entirely
  text = text.replaceAll(
    RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false),
    '',
  );

  // Convert line breaks
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</tr>', caseSensitive: false), '\n');

  // Strip remaining tags
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');

  // Unescape HTML entities after stripping tags
  text = _unescapeHtml(text);

  // Collapse multiple newlines/spaces
  text = text.replaceAll(RegExp(r'\n\s*\n'), '\n');
  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

  return text.trim();
}

String _unescapeHtml(String input) {
  var text = input;
  text = text.replaceAll('&nbsp;', ' ');
  text = text.replaceAll('&amp;', '&');
  text = text.replaceAll('&lt;', '<');
  text = text.replaceAll('&gt;', '>');
  text = text.replaceAll('&quot;', '"');
  text = text.replaceAll('&#39;', "'");
  return text;
}
