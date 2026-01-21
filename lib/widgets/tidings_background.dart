import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';

class TidingsBackground extends StatelessWidget {
  const TidingsBackground({
    super.key,
    required this.accent,
    required this.child,
  });

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = ColorTokens.panelBackground(context);
    final topShade = Color.alphaBlend(
      Colors.white.withValues(alpha: isDark ? 0.015 : 0.06),
      base,
    );
    final bottomShade = Color.alphaBlend(
      Colors.black.withValues(alpha: isDark ? 0.03 : 0.02),
      base,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topShade, bottomShade],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
