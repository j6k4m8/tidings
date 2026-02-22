import 'query_ast.dart';
import 'query_lexer.dart';
import 'query_token.dart';

/// Parses a flat token list into a [QueryNode] AST.
///
/// Precedence (lowest → highest):
///   OR  →  AND (implicit adjacency)  →  NOT  →  atom
class QueryParser {
  QueryParser(this._tokens);

  final List<QueryToken> _tokens;
  int _pos = 0;

  static QueryNode parse(String input) {
    final tokens = QueryLexer(input).tokenize();
    if (tokens.isEmpty) return const MatchAllNode();
    final parser = QueryParser(tokens);
    return parser._parseOr();
  }

  bool get _done => _pos >= _tokens.length;
  QueryToken get _peek => _tokens[_pos];
  QueryToken _consume() => _tokens[_pos++];

  // ── Grammar ────────────────────────────────────────────────────────────────

  /// OR has lowest precedence.
  QueryNode _parseOr() {
    var left = _parseAnd();
    while (!_done && _peek.kind == TokenKind.or) {
      _consume(); // consume OR
      final right = _parseAnd();
      left = OrNode(left, right);
    }
    return left;
  }

  /// AND is explicit (`AND` keyword) or implicit (adjacency).
  QueryNode _parseAnd() {
    var left = _parseNot();
    while (!_done && _isAndContinuation()) {
      if (_peek.kind == TokenKind.and) _consume(); // consume explicit AND
      final right = _parseNot();
      left = AndNode(left, right);
    }
    return left;
  }

  bool _isAndContinuation() {
    if (_done) return false;
    final k = _peek.kind;
    // The next token starts a new atom (implicit AND) or is an explicit AND
    return k == TokenKind.and ||
        k == TokenKind.not ||
        k == TokenKind.openParen ||
        k == TokenKind.field ||
        k == TokenKind.freeText;
  }

  /// NOT (unary).
  QueryNode _parseNot() {
    if (!_done && _peek.kind == TokenKind.not) {
      _consume();
      final child = _parseAtom();
      return NotNode(child);
    }
    return _parseAtom();
  }

  /// Atom: parenthesised group, field:value, or free text.
  QueryNode _parseAtom() {
    if (_done) return const MatchAllNode();

    final tok = _peek;

    if (tok.kind == TokenKind.openParen) {
      _consume(); // '('
      final inner = _parseOr();
      if (!_done && _peek.kind == TokenKind.closeParen) _consume(); // ')'
      return inner;
    }

    if (tok.kind == TokenKind.field) {
      _consume();
      return _parseFieldToken(tok);
    }

    if (tok.kind == TokenKind.freeText) {
      _consume();
      final text = tok.value;
      if (text.isEmpty) return const MatchAllNode();
      return FreeTextNode(text);
    }

    // Unexpected token — skip it
    _consume();
    return const MatchAllNode();
  }

  /// Splits a field token "field:value" into a [FieldNode].
  QueryNode _parseFieldToken(QueryToken tok) {
    final raw = tok.raw;
    final colonIdx = raw.indexOf(':');
    if (colonIdx < 0) return FreeTextNode(tok.value);
    final field = raw.substring(0, colonIdx).toLowerCase();
    var value = raw.substring(colonIdx + 1);
    // Strip quotes
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    value = value.toLowerCase();
    return FieldNode(field: field, value: value);
  }
}
