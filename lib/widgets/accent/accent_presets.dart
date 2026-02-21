import 'package:flutter/material.dart';

class AccentPreset {
  const AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

// Ordered around the color wheel so the first 6 quick-pick dots are maximally
// distinct: red → amber → green → teal → blue → violet.
const List<AccentPreset> accentPresets = [
  AccentPreset('Red',    Color(0xFFE85252)),
  AccentPreset('Amber',  Color(0xFFFFB347)),
  AccentPreset('Green',  Color(0xFF4CAF72)),
  AccentPreset('Teal',   Color(0xFF35B7C3)),
  AccentPreset('Blue',   Color(0xFF4A9FFF)),
  AccentPreset('Violet', Color(0xFF9B6DFF)),
  // extras shown in the full picker
  AccentPreset('Coral',  Color(0xFFFF7A59)),
  AccentPreset('Rose',   Color(0xFFF06292)),
  AccentPreset('Indigo', Color(0xFF6F7BFF)),
  AccentPreset('Sky',    Color(0xFF3DBCF0)),
  AccentPreset('Sand',   Color(0xFFB89060)),
  AccentPreset('Slate',  Color(0xFF7B8FA1)),
];
