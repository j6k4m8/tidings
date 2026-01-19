import 'dart:ui';

import 'package:flutter/material.dart';

enum GlassVariant {
  panel,
  sheet,
  nav,
  pill,
  action,
}

@immutable
class GlassStyle {
  const GlassStyle({
    required this.fill,
    required this.border,
    required this.highlight,
    required this.shadow,
    required this.blur,
  });

  final Color fill;
  final Color border;
  final LinearGradient highlight;
  final List<BoxShadow> shadow;
  final double blur;
}

class GlassTheme {
  const GlassTheme._();

  static GlassStyle resolve(
    BuildContext context, {
    GlassVariant variant = GlassVariant.panel,
    Color? accent,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final spec = _specFor(variant, isDark);
    final effectiveAccent = accent ?? scheme.primary;
    final tintBoost = selected ? spec.selectedTintBoost : 0.0;
    final tintColor = selected
        ? effectiveAccent.withValues(alpha: spec.tintOpacity + tintBoost)
        : Colors.transparent;
    final fill = Color.alphaBlend(
      tintColor,
      scheme.surface.withValues(alpha: spec.fillOpacity),
    );
    final borderColor = selected ? effectiveAccent : scheme.onSurface;
    final border = borderColor.withValues(
      alpha: spec.borderOpacity + (selected ? spec.selectedBorderBoost : 0.0),
    );
    final highlight = _highlightGradient(
      brightness: brightness,
      strength: spec.highlightStrength,
    );
    final shadow = spec.shadowOpacity <= 0
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: spec.shadowOpacity),
              blurRadius: spec.shadowBlur,
              offset: Offset(0, spec.shadowOffset),
            ),
          ];
    return GlassStyle(
      fill: fill,
      border: border,
      highlight: highlight,
      shadow: shadow,
      blur: spec.blur,
    );
  }

  static _GlassSpec _specFor(GlassVariant variant, bool isDark) {
    switch (variant) {
      case GlassVariant.sheet:
        return _GlassSpec(
          blur: isDark ? 30 : 24,
          fillOpacity: isDark ? 0.62 : 0.9,
          tintOpacity: isDark ? 0.12 : 0.06,
          borderOpacity: isDark ? 0.2 : 0.14,
          highlightStrength: isDark ? 0.75 : 0.7,
          shadowOpacity: isDark ? 0.32 : 0.12,
          shadowBlur: isDark ? 30 : 20,
          shadowOffset: isDark ? 18 : 12,
          selectedTintBoost: 0.06,
          selectedBorderBoost: 0.12,
        );
      case GlassVariant.nav:
        return _GlassSpec(
          blur: isDark ? 26 : 22,
          fillOpacity: isDark ? 0.56 : 0.86,
          tintOpacity: isDark ? 0.1 : 0.05,
          borderOpacity: isDark ? 0.18 : 0.12,
          highlightStrength: isDark ? 0.7 : 0.6,
          shadowOpacity: isDark ? 0.26 : 0.1,
          shadowBlur: isDark ? 26 : 18,
          shadowOffset: isDark ? 14 : 10,
          selectedTintBoost: 0.05,
          selectedBorderBoost: 0.1,
        );
      case GlassVariant.pill:
        return _GlassSpec(
          blur: isDark ? 18 : 16,
          fillOpacity: isDark ? 0.48 : 0.82,
          tintOpacity: isDark ? 0.08 : 0.04,
          borderOpacity: isDark ? 0.16 : 0.1,
          highlightStrength: isDark ? 0.6 : 0.55,
          shadowOpacity: isDark ? 0.18 : 0.06,
          shadowBlur: isDark ? 16 : 12,
          shadowOffset: isDark ? 8 : 6,
          selectedTintBoost: 0.08,
          selectedBorderBoost: 0.14,
        );
      case GlassVariant.action:
        return _GlassSpec(
          blur: isDark ? 32 : 28,
          fillOpacity: isDark ? 0.58 : 0.9,
          tintOpacity: isDark ? 0.16 : 0.1,
          borderOpacity: isDark ? 0.26 : 0.16,
          highlightStrength: isDark ? 0.85 : 0.75,
          shadowOpacity: isDark ? 0.38 : 0.16,
          shadowBlur: isDark ? 32 : 22,
          shadowOffset: isDark ? 20 : 14,
          selectedTintBoost: 0.1,
          selectedBorderBoost: 0.18,
        );
      case GlassVariant.panel:
        return _GlassSpec(
          blur: isDark ? 28 : 22,
          fillOpacity: isDark ? 0.58 : 0.88,
          tintOpacity: isDark ? 0.1 : 0.05,
          borderOpacity: isDark ? 0.18 : 0.12,
          highlightStrength: isDark ? 0.7 : 0.6,
          shadowOpacity: isDark ? 0.3 : 0.1,
          shadowBlur: isDark ? 26 : 18,
          shadowOffset: isDark ? 16 : 10,
          selectedTintBoost: 0.06,
          selectedBorderBoost: 0.12,
        );
    }
  }

  static LinearGradient _highlightGradient({
    required Brightness brightness,
    required double strength,
  }) {
    final isDark = brightness == Brightness.dark;
    final top = Colors.white.withValues(alpha: (isDark ? 0.24 : 0.36) * strength);
    final mid = Colors.white.withValues(alpha: (isDark ? 0.08 : 0.18) * strength);
    final bottom = Colors.black.withValues(alpha: (isDark ? 0.32 : 0.14) * strength);
    return LinearGradient(
      begin: const Alignment(-0.9, -0.9),
      end: const Alignment(0.9, 0.9),
      stops: const [0.0, 0.55, 1.0],
      colors: [
        top,
        mid,
        bottom,
      ],
    );
  }
}

class _GlassSpec {
  const _GlassSpec({
    required this.blur,
    required this.fillOpacity,
    required this.tintOpacity,
    required this.borderOpacity,
    required this.highlightStrength,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.selectedTintBoost,
    required this.selectedBorderBoost,
  });

  final double blur;
  final double fillOpacity;
  final double tintOpacity;
  final double borderOpacity;
  final double highlightStrength;
  final double shadowOpacity;
  final double shadowBlur;
  final double shadowOffset;
  final double selectedTintBoost;
  final double selectedBorderBoost;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding,
    this.variant = GlassVariant.panel,
    this.accent,
    this.selected = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final GlassVariant variant;
  final Color? accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = GlassTheme.resolve(
      context,
      variant: variant,
      accent: accent,
      selected: selected,
    );
    final content = padding == null
        ? child
        : Padding(
            padding: padding!,
            child: child,
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur),
        child: Container(
          decoration: BoxDecoration(
            color: style.fill,
            borderRadius: borderRadius,
            border: Border.all(color: style.border),
            boxShadow: style.shadow,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: style.highlight),
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
