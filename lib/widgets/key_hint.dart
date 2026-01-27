import 'package:flutter/material.dart';

import '../state/tidings_settings.dart';

/// A keyboard key hint widget styled like a physical key.
/// Use this for showing keyboard shortcuts throughout the app.
class KeyHint extends StatelessWidget {
  const KeyHint({
    super.key,
    required this.keyLabel,
    this.small = false,
  });

  final String keyLabel;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space(small ? 5 : 6),
        vertical: context.space(small ? 1 : 2),
      ),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surface.withValues(alpha: 0.8)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(context.radius(4)),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        keyLabel,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          fontFamily: 'SF Mono',
          color: scheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// A hint message with a key and description text.
/// Example: [esc] to return to inbox
class KeyHintMessage extends StatelessWidget {
  const KeyHintMessage({
    super.key,
    required this.keyLabel,
    required this.message,
  });

  final String keyLabel;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyHint(keyLabel: keyLabel, small: true),
        SizedBox(width: context.space(6)),
        Text(
          message,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }
}
