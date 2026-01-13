import 'package:flutter/material.dart';

class AccentPreset {
  const AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

const List<AccentPreset> accentPresets = [
  AccentPreset('Indigo', Color(0xFF6F7BFF)),
  AccentPreset('Mint', Color(0xFF45D6B4)),
  AccentPreset('Coral', Color(0xFFFF7A59)),
  AccentPreset('Amber', Color(0xFFFFB347)),
  AccentPreset('Teal', Color(0xFF35B7C3)),
  AccentPreset('Rose', Color(0xFFF06292)),
];
