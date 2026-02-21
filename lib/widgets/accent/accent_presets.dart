import 'package:flutter/material.dart';

class AccentPreset {
  const AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

const List<AccentPreset> accentPresets = [
  // Blues / purples
  AccentPreset('Indigo',   Color(0xFF6F7BFF)),
  AccentPreset('Violet',   Color(0xFF9B6DFF)),
  AccentPreset('Lavender', Color(0xFFB48EFF)),
  AccentPreset('Blue',     Color(0xFF4A9FFF)),
  AccentPreset('Sky',      Color(0xFF3DBCF0)),
  // Greens / teals
  AccentPreset('Teal',     Color(0xFF35B7C3)),
  AccentPreset('Mint',     Color(0xFF45D6B4)),
  AccentPreset('Sage',     Color(0xFF6BBF8E)),
  AccentPreset('Green',    Color(0xFF4CAF72)),
  // Warm tones
  AccentPreset('Coral',    Color(0xFFFF7A59)),
  AccentPreset('Rose',     Color(0xFFF06292)),
  AccentPreset('Pink',     Color(0xFFE85D9A)),
  AccentPreset('Red',      Color(0xFFE85252)),
  // Neutrals / earth
  AccentPreset('Amber',    Color(0xFFFFB347)),
  AccentPreset('Gold',     Color(0xFFD4A017)),
  AccentPreset('Sand',     Color(0xFFB89060)),
  AccentPreset('Slate',    Color(0xFF7B8FA1)),
  AccentPreset('Graphite', Color(0xFF6E7A8A)),
];
