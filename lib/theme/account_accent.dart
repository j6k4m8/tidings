import 'package:flutter/material.dart';

Color accentFromAccount(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = unit + ((hash << 5) - hash);
  }
  final hue = (hash % 360).abs().toDouble();
  return HSLColor.fromAHSL(1, hue, 0.62, 0.58).toColor();
}

Color resolveAccent(Color base, Brightness brightness) {
  final hsl = HSLColor.fromColor(base);
  final target = brightness == Brightness.dark ? 0.74 : 0.42;
  final blended = hsl.lightness + (target - hsl.lightness) * 0.65;
  final clamped = brightness == Brightness.dark
      ? blended.clamp(0.62, 0.82)
      : blended.clamp(0.32, 0.52);
  return hsl.withLightness(clamped.toDouble()).toColor();
}

@immutable
class AccentTokens {
  const AccentTokens({
    required this.base,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.track,
  });

  final Color base;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color track;
}

AccentTokens resolveAccentTokens(Color accent, Brightness brightness) {
  final hsl = HSLColor.fromColor(accent);
  final targetText = brightness == Brightness.dark ? 0.86 : 0.28;
  final textLightness = (hsl.lightness + (targetText - hsl.lightness) * 0.7)
      .clamp(brightness == Brightness.dark ? 0.74 : 0.22,
          brightness == Brightness.dark ? 0.9 : 0.5)
      .toDouble();
  final targetMuted = brightness == Brightness.dark ? 0.72 : 0.38;
  final mutedLightness = (hsl.lightness + (targetMuted - hsl.lightness) * 0.55)
      .clamp(brightness == Brightness.dark ? 0.62 : 0.26,
          brightness == Brightness.dark ? 0.84 : 0.56)
      .toDouble();
  final base = accent;
  return AccentTokens(
    base: base,
    onSurface: hsl.withLightness(textLightness).toColor(),
    onSurfaceMuted: hsl.withLightness(mutedLightness).toColor(),
    track: base.withValues(
      alpha: brightness == Brightness.dark ? 0.4 : 0.32,
    ),
  );
}

AccentTokens accentTokensFor(BuildContext context, Color accent) {
  return resolveAccentTokens(accent, Theme.of(context).brightness);
}
