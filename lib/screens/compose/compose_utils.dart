import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../../models/email_models.dart';

class QuotedContent {
  const QuotedContent({
    required this.plainText,
    required this.html,
  });

  final String plainText;
  final String html;

  bool get isEmpty => plainText.trim().isEmpty;
}

String replySubject(String subject) {
  final trimmed = subject.trim();
  if (trimmed.toLowerCase().startsWith('re:')) {
    return trimmed;
  }
  return trimmed.isEmpty ? 'Re:' : 'Re: $trimmed';
}

String forwardSubject(String subject) {
  final trimmed = subject.trim();
  final lowered = trimmed.toLowerCase();
  if (lowered.startsWith('fwd:') || lowered.startsWith('fw:')) {
    return trimmed;
  }
  return trimmed.isEmpty ? 'Fwd:' : 'Fwd: $trimmed';
}

QuotedContent? buildQuotedContent(
  EmailMessage? message, {
  required bool isForward,
}) {
  if (message == null) {
    return null;
  }
  final body = message.bodyPlainText.trim();
  if (body.isEmpty) {
    return null;
  }
  if (isForward) {
    final headerLines = <String>[
      '---------- Forwarded message ----------',
      'From: ${message.from.displayName}',
      'Date: ${message.time}',
      'Subject: ${message.subject}',
      'To: ${message.toSummary}',
    ];
    final plain = [
      headerLines.join('\n'),
      '',
      body,
    ].join('\n');
    final html = [
      _linesToHtml(headerLines),
      _plainToHtml(body),
    ].join();
    return QuotedContent(plainText: plain, html: html);
  }

  final header = 'On ${message.time}, ${message.from.displayName} wrote:';
  final quotedBody = _quoteLines(body);
  final plain = '$header\n$quotedBody';
  final html = [
    '<p>${_escapeHtml(header)}</p>',
    '<blockquote>${_plainToHtml(body)}</blockquote>',
  ].join();
  return QuotedContent(plainText: plain, html: html);
}

String appendQuotedPlain(String body, QuotedContent? quote) {
  if (quote == null || quote.isEmpty) {
    return body;
  }
  final trimmed = body.trimRight();
  if (trimmed.isEmpty) {
    return quote.plainText;
  }
  return '$trimmed\n\n${quote.plainText}';
}

String appendQuotedHtml(String html, QuotedContent? quote) {
  if (quote == null || quote.isEmpty) {
    return html;
  }
  final trimmed = html.trim();
  if (trimmed.isEmpty) {
    return quote.html;
  }
  return '$trimmed<br><br>${quote.html}';
}

String _quoteLines(String text) {
  return text
      .split('\n')
      .map((line) => '> $line')
      .join('\n')
      .trimRight();
}

String _plainToHtml(String text) {
  final lines = text.split('\n');
  final buffer = StringBuffer();
  for (final line in lines) {
    buffer.write('<p>${_escapeHtml(line)}</p>');
  }
  return buffer.toString();
}

String _linesToHtml(List<String> lines) {
  return lines.map((line) => '<p>${_escapeHtml(line)}</p>').join();
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String replyRecipients(
  List<EmailAddress> participants,
  String? currentUserEmail,
) {
  final filtered = currentUserEmail == null
      ? participants
      : participants
          .where((participant) => participant.email != currentUserEmail)
          .toList();
  final list = filtered.isEmpty ? participants : filtered;
  return list.map((participant) => participant.email).join(', ');
}

String deltaToHtml(Delta delta) {
  final buffer = StringBuffer();
  var lineBuffer = StringBuffer();
  for (final op in delta.toList()) {
    final data = op.data;
    final attrs = op.attributes ?? <String, dynamic>{};
    if (data is! String) {
      continue;
    }
    var text = data;
    while (text.contains('\n')) {
      final index = text.indexOf('\n');
      final segment = text.substring(0, index);
      lineBuffer.write(_wrapInline(segment, attrs));
      buffer.write('<p>${lineBuffer.toString().trim()}</p>');
      lineBuffer = StringBuffer();
      text = text.substring(index + 1);
    }
    if (text.isNotEmpty) {
      lineBuffer.write(_wrapInline(text, attrs));
    }
  }
  final remainder = lineBuffer.toString().trim();
  if (remainder.isNotEmpty) {
    buffer.write('<p>$remainder</p>');
  }
  return buffer.toString();
}

Delta deltaFromPlainText(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final content = normalized.endsWith('\n') ? normalized : '$normalized\n';
  return Delta()..insert(content);
}

String _wrapInline(String text, Map<String, dynamic> attrs) {
  var result = text;
  if (attrs['bold'] == true) {
    result = '<strong>$result</strong>';
  }
  if (attrs['italic'] == true) {
    result = '<em>$result</em>';
  }
  if (attrs['underline'] == true) {
    result = '<u>$result</u>';
  }
  return result;
}
