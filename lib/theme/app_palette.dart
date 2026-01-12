import 'package:flutter/material.dart';

@immutable
class TidingsPalette extends ThemeExtension<TidingsPalette> {
  const TidingsPalette({
    required this.backgroundGradient,
    required this.heroGradient,
  });

  final List<Color> backgroundGradient;
  final List<Color> heroGradient;

  @override
  TidingsPalette copyWith({
    List<Color>? backgroundGradient,
    List<Color>? heroGradient,
  }) {
    return TidingsPalette(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  TidingsPalette lerp(ThemeExtension<TidingsPalette>? other, double t) {
    if (other is! TidingsPalette) {
      return this;
    }
    return TidingsPalette(
      backgroundGradient: _lerpList(backgroundGradient, other.backgroundGradient, t),
      heroGradient: _lerpList(heroGradient, other.heroGradient, t),
    );
  }

  static List<Color> _lerpList(List<Color> a, List<Color> b, double t) {
    final length = a.length > b.length ? a.length : b.length;
    return List<Color>.generate(length, (index) {
      final aColor = index < a.length ? a[index] : a.last;
      final bColor = index < b.length ? b[index] : b.last;
      return Color.lerp(aColor, bColor, t) ?? aColor;
    });
  }
}
