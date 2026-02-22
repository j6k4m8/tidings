import 'query_ast.dart';
import 'query_date.dart' as qd;

/// Serializes a [QueryNode] AST into provider-specific query strings.

// ── Gmail ─────────────────────────────────────────────────────────────────

/// Produces a Gmail search query string from a [QueryNode].
///
/// Gmail query syntax: https://support.google.com/mail/answer/7190
String toGmailQuery(QueryNode node) {
  return switch (node) {
    MatchAllNode() => '',
    AndNode(:final left, :final right) =>
        '${toGmailQuery(left)} ${toGmailQuery(right)}'.trim(),
    OrNode(:final left, :final right) =>
        '{${toGmailQuery(left)} ${toGmailQuery(right)}}',
    NotNode(:final child) => '-${_gmailAtom(child)}',
    FreeTextNode(:final text) => _quote(text),
    FieldNode(:final field, :final value) => _gmailField(field, value),
  };
}

String _gmailAtom(QueryNode node) {
  final q = toGmailQuery(node);
  // Wrap compound expressions in parens so negation applies correctly
  if (node is AndNode || node is OrNode) return '($q)';
  return q;
}

String _gmailField(String field, String value) {
  return switch (field) {
    'from' => 'from:${_quote(value)}',
    'to' => 'to:${_quote(value)}',
    'cc' => 'cc:${_quote(value)}',
    'bcc' => 'bcc:${_quote(value)}',
    'subject' => 'subject:${_quote(value)}',
    'before' => 'before:${_gmailDate(value)}',
    'after' => 'after:${_gmailDate(value)}',
    'date' => 'after:${_gmailDate(value)} before:${_gmailDatePlusOne(value)}',
    'in' => 'in:${_quote(value)}',
    'label' => 'label:${_quote(value)}',
    'has' => _gmailHas(value),
    'is' => _gmailIs(value),
    // account: is client-side only — omit from server query
    _ => _quote(value),
  };
}

String _gmailHas(String value) => switch (value) {
  'attachment' || 'attachments' => 'has:attachment',
  'link' || 'links' => 'has:link',
  _ => '',
};

String _gmailIs(String value) => switch (value) {
  'unread' => 'is:unread',
  'read' => 'is:read',
  'starred' => 'is:starred',
  'unstarred' => '-is:starred',
  'sent' || 'me' => 'from:me',
  _ => '',
};

/// Converts a relative/natural date expression to Gmail's yyyy/mm/dd format.
String _gmailDate(String value) {
  final dt = _parseDate(value);
  if (dt == null) return value;
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

String _gmailDatePlusOne(String value) {
  final dt = _parseDate(value);
  if (dt == null) return value;
  final next = dt.add(const Duration(days: 1));
  return '${next.year}/${next.month.toString().padLeft(2, '0')}/${next.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDate(String value) => qd.parseQueryDate(value);

String _quote(String value) {
  if (value.contains(' ')) return '"$value"';
  return value;
}

// ── IMAP SEARCH ──────────────────────────────────────────────────────────────

/// Produces IMAP SEARCH criteria from a [QueryNode].
///
/// Returns a list of criterion strings (to be joined with spaces).
/// Complex boolean logic uses IMAP extensions (OR, NOT) where available.
String toImapSearch(QueryNode node) {
  return switch (node) {
    MatchAllNode() => 'ALL',
    AndNode(:final left, :final right) =>
        '${toImapSearch(left)} ${toImapSearch(right)}'.trim(),
    OrNode(:final left, :final right) =>
        'OR (${toImapSearch(left)}) (${toImapSearch(right)})',
    NotNode(:final child) => 'NOT (${toImapSearch(child)})',
    FreeTextNode(:final text) => 'TEXT "${_escapeImap(text)}"',
    FieldNode(:final field, :final value) => _imapField(field, value),
  };
}

String _imapField(String field, String value) {
  return switch (field) {
    'from' => 'FROM "${_escapeImap(value)}"',
    'to' => 'TO "${_escapeImap(value)}"',
    'cc' => 'CC "${_escapeImap(value)}"',
    'subject' || 'label' => 'SUBJECT "${_escapeImap(value)}"',
    'before' => 'BEFORE ${_imapDate(value)}',
    'after' => 'SINCE ${_imapDate(value)}',
    'date' => 'ON ${_imapDate(value)}',
    'is' => _imapIs(value),
    'has' => _imapHas(value),
    // in:/account: are client-side or provider-level — skip for IMAP SEARCH
    _ => 'TEXT "${_escapeImap(value)}"',
  };
}

String _imapIs(String value) => switch (value) {
  'unread' => 'UNSEEN',
  'read' => 'SEEN',
  'starred' => 'FLAGGED',
  'unstarred' => 'UNFLAGGED',
  _ => 'ALL',
};

String _imapHas(String value) => switch (value) {
  // IMAP doesn't have a native "has attachment" criterion without extensions;
  // fall back to a body search hint.
  'attachment' || 'attachments' => 'ALL',
  _ => 'ALL',
};

/// DD-Mon-YYYY format required by IMAP SEARCH.
String _imapDate(String value) {
  final dt = _parseImapDate(value);
  if (dt == null) return value;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day}-${months[dt.month - 1]}-${dt.year}';
}

DateTime? _parseImapDate(String value) => qd.parseQueryDate(value);

String _escapeImap(String s) => s.replaceAll('"', '\\"');
