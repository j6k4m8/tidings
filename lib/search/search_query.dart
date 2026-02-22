import '../models/email_models.dart';
import 'query_ast.dart';
import 'query_evaluator.dart';
import 'query_parser.dart';
import 'query_serializer.dart';

/// High-level wrapper around a parsed query.
///
/// Combines parsing, evaluation, and serialization in one convenient object.
class SearchQuery {
  SearchQuery._(this._ast, this.rawQuery);

  final QueryNode _ast;

  /// The original query string.
  final String rawQuery;

  /// Parses [query] into a [SearchQuery].
  factory SearchQuery.parse(String query) {
    final ast = QueryParser.parse(query);
    return SearchQuery._(ast, query);
  }

  /// Returns true if the query matches all threads (empty / trivial).
  bool get isMatchAll => _ast is MatchAllNode;

  /// Evaluates this query against a thread + its messages.
  bool evaluate(
    EmailThread thread,
    List<EmailMessage> messages, {
    List<String> accountEmails = const [],
    String? currentFolderPath,
  }) {
    final evaluator = QueryEvaluator(
      accountEmails: accountEmails,
      currentFolderPath: currentFolderPath,
    );
    return evaluator.evaluate(_ast, thread, messages);
  }

  /// Serializes this query to a Gmail search string.
  String toGmailQuery() => toGmailQuery_(_ast);

  /// Serializes this query to an IMAP SEARCH string.
  String toImapSearch() => toImapSearch_(_ast);

  @override
  String toString() => rawQuery;
}

// Renamed imports to avoid conflict with method names
String toGmailQuery_(QueryNode node) => toGmailQuery(node);
String toImapSearch_(QueryNode node) => toImapSearch(node);
