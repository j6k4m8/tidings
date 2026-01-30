import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../../models/email_models.dart';

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
