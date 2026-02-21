import '../models/email_models.dart';

/// Splits a comma- or semicolon-separated string of plain email addresses
/// into [EmailAddress] objects.  Display names are left empty — callers that
/// need RFC 2822 `Display Name <addr>` parsing should use [parseAddressList].
///
/// Used by mock/IMAP/unified providers for outbox display and SMTP recipient
/// building.
List<EmailAddress> splitEmailAddresses(String raw) {
  final parts = raw
      .split(RegExp(r'[;,]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.map((email) => EmailAddress(name: '', email: email)).toList();
}

/// Parses a single RFC 2822 address string, supporting both
/// `"Display Name <addr>"` and bare `addr` forms.
EmailAddress parseAddress(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(r'^(.*?)<([^>]+)>$').firstMatch(trimmed);
  if (match != null) {
    final name =
        match.group(1)?.trim().replaceAll(RegExp(r'^"|"$'), '') ?? '';
    final addr = match.group(2)?.trim() ?? '';
    return EmailAddress(name: name, email: addr);
  }
  return EmailAddress(name: '', email: trimmed);
}

/// Parses a comma-separated RFC 2822 address list, correctly handling commas
/// inside angle-brackets (e.g. `"Foo, Bar" <foo@bar.com>`).
List<EmailAddress> parseAddressList(String raw) {
  if (raw.isEmpty) return const [];
  final parts = <String>[];
  var depth = 0;
  final current = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    if (ch == '<') depth++;
    if (ch == '>') depth--;
    if (ch == ',' && depth == 0) {
      parts.add(current.toString().trim());
      current.clear();
    } else {
      current.write(ch);
    }
  }
  if (current.isNotEmpty) parts.add(current.toString().trim());
  return parts.where((p) => p.isNotEmpty).map(parseAddress).toList();
}
