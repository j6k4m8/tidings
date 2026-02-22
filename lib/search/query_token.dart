/// Token types produced by the query lexer.
enum TokenKind {
  /// A field qualifier like `from:`, `to:`, `before:`, `after:`, `date:`,
  /// `account:`, `in:`, `has:`, `is:`, `subject:`.
  field,

  /// The value that follows a field qualifier (may be quoted).
  fieldValue,

  /// Boolean operators: AND, OR, NOT.
  and,
  or,
  not,

  /// Grouping parentheses.
  openParen,
  closeParen,

  /// Plain free-text word (not a field qualifier, not an operator).
  freeText,
}

/// A single lexed token from the query string.
class QueryToken {
  const QueryToken({
    required this.kind,
    required this.raw,
    required this.start,
    required this.end,
  });

  final TokenKind kind;

  /// The raw substring as it appears in the input.
  final String raw;

  /// Character offsets in the original query string (inclusive start, exclusive end).
  final int start;
  final int end;

  /// The normalised value (field values are lowercased, quotes stripped).
  String get value {
    var v = raw;
    if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
      v = v.substring(1, v.length - 1);
    }
    return v.toLowerCase();
  }

  @override
  String toString() => 'QueryToken($kind, "$raw", $start-$end)';
}

/// Known field names (left side of `field:value`).
const Set<String> kQueryFields = {
  'from',
  'to',
  'cc',
  'bcc',
  'subject',
  'before',
  'after',
  'date',
  'account',
  'in',
  'has',
  'is',
  'label',
};
