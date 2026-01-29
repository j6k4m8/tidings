import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';

class PaperPanel extends StatelessWidget {
  const PaperPanel({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding,
    this.fillColor,
    this.borderColor,
    this.elevated = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fillColor;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final resolvedFill = fillColor ??
        surface.withValues(alpha: isDark ? 0.94 : 0.98);
    final shadowOpacity = isDark ? 0.28 : 0.08;
    final content = padding == null
        ? child
        : Padding(
            padding: padding!,
            child: child,
          );
    return Container(
      decoration: BoxDecoration(
        color: resolvedFill,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? ColorTokens.border(context, 0.14),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: shadowOpacity),
                  blurRadius: isDark ? 26 : 18,
                  offset: Offset(0, isDark ? 16 : 10),
                ),
              ]
            : const [],
      ),
      child: content,
    );
  }
}
