/// AST nodes for the query language.

sealed class QueryNode {
  const QueryNode();
}

/// Matches when both children match.
final class AndNode extends QueryNode {
  const AndNode(this.left, this.right);
  final QueryNode left;
  final QueryNode right;
}

/// Matches when either child matches.
final class OrNode extends QueryNode {
  const OrNode(this.left, this.right);
  final QueryNode left;
  final QueryNode right;
}

/// Matches when the child does NOT match.
final class NotNode extends QueryNode {
  const NotNode(this.child);
  final QueryNode child;
}

/// Matches a specific field against a value.
final class FieldNode extends QueryNode {
  const FieldNode({required this.field, required this.value});

  /// Lowercased field name, e.g. 'from', 'before', 'is'.
  final String field;

  /// The raw value string (lowercased, quotes stripped).
  final String value;
}

/// Matches free-text against all searchable fields.
final class FreeTextNode extends QueryNode {
  const FreeTextNode(this.text);
  final String text;
}

/// The trivially-true node (matches everything).
final class MatchAllNode extends QueryNode {
  const MatchAllNode();
}
