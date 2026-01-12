import 'dart:ui';

import 'package:flutter/material.dart';

import 'color_tokens.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding,
    this.blur = 26,
    this.opacity = 0.16,
    this.borderOpacity = 0.22,
    this.highlightStrength = 0.6,
    this.borderColor,
    this.tint,
    this.boxShadow,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final double highlightStrength;
  final Color? borderColor;
  final Color? tint;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = tint ?? ColorTokens.cardFill(context, opacity);
    final resolvedBorderColor =
        borderColor ?? scheme.onSurface.withOpacity(borderOpacity);

    final content = padding == null
        ? child
        : Padding(
            padding: padding!,
            child: child,
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(color: resolvedBorderColor),
            boxShadow: boxShadow,
          ),
          child: Stack(
            children: [
              if (highlightStrength > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient:
                            ColorTokens.glassHighlight(context, highlightStrength),
                      ),
                    ),
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}
