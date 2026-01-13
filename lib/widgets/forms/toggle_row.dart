import 'package:flutter/material.dart';

import '../accent_switch.dart';

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        AccentSwitch(
          accent: accent,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
