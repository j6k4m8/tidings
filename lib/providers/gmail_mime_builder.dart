import 'dart:convert';

/// Builds the RFC 2822 message submitted to Gmail's raw send/draft APIs.
///
/// Gmail uses the submitted Bcc header to route hidden recipients and strips it
/// from delivered copies. Keep that header structured and validated here so it
/// cannot be used to inject additional headers.
String buildGmailRfc2822({
  required String from,
  required String to,
  String? cc,
  String? bcc,
  required String subject,
  required String bodyHtml,
  required String bodyText,
  String? replyMessageId,
  String? replyInReplyTo,
  bool requireRecipient = false,
}) {
  final headers = _normalizeHeaders(
    from: from,
    to: to,
    cc: cc,
    bcc: bcc,
    subject: subject,
    replyMessageId: replyMessageId,
    replyInReplyTo: replyInReplyTo,
    requireRecipient: requireRecipient,
  );
  final boundary = 'tidings_${DateTime.now().microsecondsSinceEpoch}';
  final buf = StringBuffer();

  _writeHeader(buf, 'From', headers.from);
  _writeOptionalHeader(buf, 'To', headers.to);
  _writeOptionalHeader(buf, 'Cc', headers.cc);
  _writeOptionalHeader(buf, 'Bcc', headers.bcc);
  _writeHeader(buf, 'Subject', _encodedWord(headers.subject));
  _writeHeader(buf, 'MIME-Version', '1.0');
  _writeOptionalHeader(buf, 'In-Reply-To', headers.replyMessageId);

  final references = [
    if (headers.replyInReplyTo != null) headers.replyInReplyTo!,
    if (headers.replyMessageId != null) headers.replyMessageId!,
  ].join(' ');
  _writeOptionalHeader(buf, 'References', references);

  _writeHeader(
    buf,
    'Content-Type',
    'multipart/alternative; boundary="$boundary"',
  );
  _writeBlankLine(buf);

  if (bodyText.isNotEmpty) {
    _writeMimePart(
      buf,
      boundary: boundary,
      contentType: 'text/plain; charset=UTF-8',
      body: bodyText,
    );
  }

  _writeMimePart(
    buf,
    boundary: boundary,
    contentType: 'text/html; charset=UTF-8',
    body: bodyHtml,
  );

  buf.write('--$boundary--\r\n');
  return buf.toString();
}

/// Validates the same headers [buildGmailRfc2822] will write.
void validateGmailRfc2822Headers({
  required String from,
  required String to,
  String? cc,
  String? bcc,
  required String subject,
  String? replyMessageId,
  String? replyInReplyTo,
  bool requireRecipient = false,
}) {
  _normalizeHeaders(
    from: from,
    to: to,
    cc: cc,
    bcc: bcc,
    subject: subject,
    replyMessageId: replyMessageId,
    replyInReplyTo: replyInReplyTo,
    requireRecipient: requireRecipient,
  );
}

final _lineBreaks = RegExp(r'[\r\n]');
final _controlCharacters = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
final _linearWhitespace = RegExp(r'[ \t]+');

class _NormalizedHeaders {
  const _NormalizedHeaders({
    required this.from,
    required this.subject,
    this.to,
    this.cc,
    this.bcc,
    this.replyMessageId,
    this.replyInReplyTo,
  });

  final String from;
  final String? to;
  final String? cc;
  final String? bcc;
  final String subject;
  final String? replyMessageId;
  final String? replyInReplyTo;
}

_NormalizedHeaders _normalizeHeaders({
  required String from,
  required String to,
  String? cc,
  String? bcc,
  required String subject,
  String? replyMessageId,
  String? replyInReplyTo,
  bool requireRecipient = false,
}) {
  final cleanFrom = _normalizeHeaderValue(
    from,
    headerName: 'From',
    isRequired: true,
  )!;
  final cleanTo = _normalizeHeaderValue(to, headerName: 'To');
  final cleanCc = _normalizeHeaderValue(cc, headerName: 'Cc');
  final cleanBcc = _normalizeHeaderValue(bcc, headerName: 'Bcc');
  if (requireRecipient &&
      cleanTo == null &&
      cleanCc == null &&
      cleanBcc == null) {
    throw const FormatException('At least one recipient is required.');
  }

  return _NormalizedHeaders(
    from: cleanFrom,
    to: cleanTo,
    cc: cleanCc,
    bcc: cleanBcc,
    subject:
        _normalizeHeaderValue(
          subject,
          headerName: 'Subject',
          allowEmpty: true,
        ) ??
        '',
    replyMessageId: _normalizeHeaderValue(
      replyMessageId,
      headerName: 'In-Reply-To',
    ),
    replyInReplyTo: _normalizeHeaderValue(
      replyInReplyTo,
      headerName: 'References',
    ),
  );
}

String? _normalizeHeaderValue(
  String? value, {
  required String headerName,
  bool isRequired = false,
  bool allowEmpty = false,
}) {
  final raw = value?.trim() ?? '';
  if (_lineBreaks.hasMatch(raw)) {
    throw FormatException('$headerName header cannot contain line breaks.');
  }

  final clean = raw
      .replaceAll(_controlCharacters, '')
      .replaceAll('\u2028', ' ')
      .replaceAll('\u2029', ' ')
      .replaceAll(_linearWhitespace, ' ')
      .trim();

  if (clean.isEmpty && isRequired) {
    throw FormatException('$headerName header cannot be empty.');
  }
  if (clean.isEmpty && !allowEmpty) {
    return null;
  }
  return clean;
}

String _encodedWord(String value) {
  return '=?UTF-8?B?${base64Encode(utf8.encode(value))}?=';
}

void _writeOptionalHeader(StringBuffer buf, String name, String? value) {
  if (value == null || value.isEmpty) return;
  _writeHeader(buf, name, value);
}

void _writeHeader(StringBuffer buf, String name, String value) {
  buf
    ..write(name)
    ..write(': ')
    ..write(value)
    ..write('\r\n');
}

void _writeBlankLine(StringBuffer buf) {
  buf.write('\r\n');
}

void _writeMimePart(
  StringBuffer buf, {
  required String boundary,
  required String contentType,
  required String body,
}) {
  buf.write('--$boundary\r\n');
  _writeHeader(buf, 'Content-Type', contentType);
  _writeHeader(buf, 'Content-Transfer-Encoding', 'base64');
  _writeBlankLine(buf);
  _writeWrappedBase64(buf, body);
}

void _writeWrappedBase64(StringBuffer buf, String value) {
  final encoded = base64Encode(utf8.encode(value));
  if (encoded.isEmpty) {
    _writeBlankLine(buf);
    return;
  }
  for (var index = 0; index < encoded.length; index += 76) {
    final end = index + 76 > encoded.length ? encoded.length : index + 76;
    buf.write(encoded.substring(index, end));
    buf.write('\r\n');
  }
}
