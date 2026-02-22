/// Public API for the Tidings query language.
///
/// Usage:
///   final ast = SearchQuery.parse('from:jordan is:unread');
///   final matches = ast.evaluate(thread, messages);
///   final gmail = ast.toGmailQuery();
///   final imap  = ast.toImapSearch();

export 'query_ast.dart';
export 'query_date.dart';
export 'query_evaluator.dart';
export 'query_lexer.dart';
export 'query_parser.dart';
export 'query_serializer.dart';
export 'query_token.dart';
export 'search_query.dart';
