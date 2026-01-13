import 'package:flutter/material.dart';

Color accentFromAccount(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = unit + ((hash << 5) - hash);
  }
  final hue = 205 + (hash % 40).abs().toDouble();
  return HSLColor.fromAHSL(1, hue, 0.7, 0.68).toColor();
}
