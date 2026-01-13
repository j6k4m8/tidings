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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseGradient = ColorTokens.backgroundGradient(context);
    final heroGradient = ColorTokens.heroGradient(context);
    final glow = accent.withOpacity(isDark ? 0.2 : 0.14);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: baseGradient,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: heroGradient,
              ),
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -80,
          child: _GlowBlob(color: glow, size: 280),
        ),
        Positioned(
          bottom: -160,
          left: -60,
          child: _GlowBlob(
            color: scheme.secondary.withOpacity(isDark ? 0.18 : 0.12),
            size: 300,
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
