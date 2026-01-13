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
  final target = brightness == Brightness.dark ? 0.7 : 0.5;
  final adjusted = hsl.withLightness(
    (hsl.lightness + target) / 2,
  );
  final clamped = adjusted.withLightness(
    brightness == Brightness.dark
        ? adjusted.lightness.clamp(0.62, 0.78)
        : adjusted.lightness.clamp(0.42, 0.6),
  );
  return clamped.toColor();
}
