import 'package:flutter/material.dart';

import '../../search/query_lexer.dart';
import '../../search/query_token.dart';

/// Palette for coloring query tokens.
class _TokenPalette {
  static Color field(bool isDark) =>
      isDark ? const Color(0xFF7EC8E3) : const Color(0xFF0074A8);
  static Color operator_(bool isDark) =>
      isDark ? const Color(0xFFE08E6D) : const Color(0xFFB94F1C);
  static Color paren(bool isDark) =>
      isDark ? const Color(0xFFCCAA55) : const Color(0xFF7A6020);
}

/// A [TextEditingController] that colorizes query tokens inline.
///
/// Recognized tokens receive a colored [TextStyle]; everything else is
/// rendered with the base [textStyle] passed in [buildTextSpan].
class TokenColoringController extends TextEditingController {
  TokenColoringController({this.accent});

  /// Used for the field token color in case we want accent-tinted fields.
  Color? accent;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = QueryLexer(text).tokenize();
    if (tokens.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final token in tokens) {
      // Gap between tokens (whitespace / unknown chars) — unstyled
      if (token.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, token.start),
          style: style,
        ));
      }

      final color = _colorForToken(token, isDark);
      if (color != null) {
        spans.add(TextSpan(
          text: token.raw,
          style: style?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(text: token.raw, style: style));
      }

      cursor = token.end;
    }

    // Trailing text after last token
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return TextSpan(children: spans, style: style);
  }

  Color? _colorForToken(QueryToken token, bool isDark) {
    return switch (token.kind) {
      TokenKind.field => _TokenPalette.field(isDark),
      TokenKind.and || TokenKind.or || TokenKind.not =>
          _TokenPalette.operator_(isDark),
      TokenKind.openParen || TokenKind.closeParen =>
          _TokenPalette.paren(isDark),
      _ => null,
    };
  }
}
