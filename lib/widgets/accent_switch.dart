import 'package:flutter/material.dart';
import '../theme/account_accent.dart';
import '../theme/color_tokens.dart';

class AccentSwitch extends StatelessWidget {
  const AccentSwitch({
    super.key,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = accentTokensFor(context, accent);
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: tokens.base,
      activeTrackColor: tokens.track,
      inactiveTrackColor: ColorTokens.cardFill(context, 0.2),
    );
  }
}
