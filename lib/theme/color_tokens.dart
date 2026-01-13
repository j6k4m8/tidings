import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Shared color helpers for light/dark surfaces.
class ColorTokens {
  static double _glassOpacity(Brightness brightness, double opacity) {
    final bump = brightness == Brightness.dark ? 0.04 : 0.03;
    return (opacity + bump).clamp(0.0, 0.6);
  }

  /// Gradient colors for the app background.
  static List<Color> backgroundGradient(BuildContext context) {
    final palette = Theme.of(context).extension<TidingsPalette>();
    if (palette != null) {
      return palette.backgroundGradient;
    }
    if (Theme.of(context).brightness == Brightness.dark) {
      return const [
        Color(0xFF0D1117),
        Color(0xFF0C1118),
        Color(0xFF0A0E13),
      ];
    }
    return const [
      Color(0xFFF5F6FA),
      Color(0xFFEFF2F7),
      Color(0xFFE9ECF4),
    ];
  }

  /// Background for app side panels.
  static Color panelBackground(BuildContext context) {
    final palette = Theme.of(context).extension<TidingsPalette>();
    if (palette != null && palette.backgroundGradient.isNotEmpty) {
      final gradient = palette.backgroundGradient;
      return gradient.length > 1 ? gradient[1] : gradient.first;
    }
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF10141C)
        : const Color(0xFFF4F5FA);
  }

  /// Divider/border tone.
  static Color border(BuildContext context, [double opacity = 0.16]) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(opacity);
  }

  /// Card fill for tiles.
  static Color cardFill(BuildContext context, [double opacity = 0.08]) {
    final brightness = Theme.of(context).brightness;
    final resolvedOpacity = _glassOpacity(brightness, opacity);
    return brightness == Brightness.dark
        ? Colors.white.withOpacity(resolvedOpacity)
        : Colors.white.withOpacity(resolvedOpacity * 0.95);
  }

  /// Stronger card fill for artwork placeholders.
  static Color cardFillStrong(BuildContext context, [double opacity = 0.14]) {
    final brightness = Theme.of(context).brightness;
    final resolvedOpacity = _glassOpacity(brightness, opacity);
    return brightness == Brightness.dark
        ? Colors.white.withOpacity(resolvedOpacity)
        : Colors.white.withOpacity(resolvedOpacity);
  }

  /// Primary text tone.
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Secondary text tone.
  static Color textSecondary(BuildContext context, [double opacity = 0.6]) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(opacity);
  }

  /// Active row highlight.
  static Color activeRow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
  }

  /// Hover row highlight.
  static Color hoverRow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
  }

  /// Section header background gradient.
  static List<Color> heroGradient(BuildContext context) {
    final palette = Theme.of(context).extension<TidingsPalette>();
    if (palette != null) {
      return palette.heroGradient;
    }
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return [
        const Color(0xFF151A24),
        Colors.white.withOpacity(0.06),
      ];
    }
    return const [
      Color(0xFFFFFFFF),
      Color(0xFFEFF2F9),
    ];
  }
}
