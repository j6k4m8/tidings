import 'query_token.dart';

/// Tokenises a query string into a flat list of [QueryToken]s.
///
/// Grammar overview:
///   query    := token*
///   token    := field_tok | operator | paren | free_text
///   field_tok:= FIELD_NAME ':' value
///   value    := quoted_string | bare_word
///   operator := 'AND' | 'OR' | 'NOT'
///   paren    := '(' | ')'
class QueryLexer {
  QueryLexer(this._input);

  final String _input;
  int _pos = 0;

  List<QueryToken> tokenize() {
    final tokens = <QueryToken>[];
    while (!_done) {
      _skipWhitespace();
      if (_done) break;

      final tok = _nextToken();
      if (tok != null) tokens.add(tok);
    }
    return tokens;
  }

  bool get _done => _pos >= _input.length;
  String get _current => _input[_pos];

  void _skipWhitespace() {
    while (!_done && _current == ' ' || !_done && _current == '\t') {
      _pos++;
    }
  }

  QueryToken? _nextToken() {
    final start = _pos;
    final ch = _current;

    // Parentheses
    if (ch == '(') {
      _pos++;
      return QueryToken(kind: TokenKind.openParen, raw: '(', start: start, end: _pos);
    }
    if (ch == ')') {
      _pos++;
      return QueryToken(kind: TokenKind.closeParen, raw: ')', start: start, end: _pos);
    }

    // Quoted string (free-text or field value — caller decides)
    if (ch == '"') {
      return _readQuoted(start);
    }

    // Bare word — could be field:value, operator, or free text
    final word = _readBareWord();
    if (word.isEmpty) {
      // Unknown character — skip it
      _pos++;
      return null;
    }

    // Check for field:value
    if (!_done && _current == ':') {
      final fieldName = word.toLowerCase();
      if (kQueryFields.contains(fieldName)) {
        _pos++; // consume ':'
        final value = _readValue();
        if (value != null) {
          // Emit two tokens: the field qualifier and the value
          // But we need to return them; use a small hack — stash extra tokens.
          // Actually, let's return a single combined token for simplicity and
          // let the parser split on the colon.
          final raw = '$word:${value.raw}';
          return QueryToken(
            kind: TokenKind.field,
            raw: raw,
            start: start,
            end: _pos,
          );
        } else {
          // Dangling "field:" with no value — return it as-is, the parser
          // will treat the missing value as empty.
          return QueryToken(
            kind: TokenKind.field,
            raw: '$word:',
            start: start,
            end: _pos,
          );
        }
      }
      // Not a known field — treat the colon as part of free text and let the
      // value be a separate word on the next iteration.
      return QueryToken(kind: TokenKind.freeText, raw: word, start: start, end: _pos);
    }

    // Boolean operators (case-insensitive)
    switch (word.toUpperCase()) {
      case 'AND':
        return QueryToken(kind: TokenKind.and, raw: word, start: start, end: _pos);
      case 'OR':
        return QueryToken(kind: TokenKind.or, raw: word, start: start, end: _pos);
      case 'NOT':
        return QueryToken(kind: TokenKind.not, raw: word, start: start, end: _pos);
    }

    return QueryToken(kind: TokenKind.freeText, raw: word, start: start, end: _pos);
  }

  /// Read a bare word: everything up to whitespace, ':', '(', ')'.
  String _readBareWord() {
    final buf = StringBuffer();
    while (!_done) {
      final c = _current;
      if (c == ' ' || c == '\t' || c == ':' || c == '(' || c == ')' || c == '"') break;
      buf.write(c);
      _pos++;
    }
    return buf.toString();
  }

  /// Read a field value: quoted string or bare word.
  QueryToken? _readValue() {
    _skipWhitespace();
    if (_done) return null;
    final start = _pos;
    if (_current == '"') return _readQuoted(start);
    final word = _readBareWord();
    if (word.isEmpty) return null;
    return QueryToken(kind: TokenKind.fieldValue, raw: word, start: start, end: _pos);
  }

  /// Read a double-quoted string (may contain spaces).
  QueryToken _readQuoted(int start) {
    _pos++; // opening quote
    final buf = StringBuffer('"');
    while (!_done && _current != '"') {
      if (_current == '\\' && _pos + 1 < _input.length) {
        _pos++; // skip backslash
        buf.write(_current);
      } else {
        buf.write(_current);
      }
      _pos++;
    }
    if (!_done) {
      buf.write('"');
      _pos++; // closing quote
    }
    return QueryToken(kind: TokenKind.freeText, raw: buf.toString(), start: start, end: _pos);
  }
}
