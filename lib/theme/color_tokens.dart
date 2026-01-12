import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Shared color helpers for light/dark surfaces.
class ColorTokens {
  static double _glassOpacity(Brightness brightness, double opacity) {
    final bump = brightness == Brightness.dark ? 0.04 : 0.03;
    return (opacity + bump).clamp(0.0, 0.6);
  }

  /// Subtle highlight gradient for glass surfaces.
  static LinearGradient glassHighlight(
    BuildContext context, [
    double strength = 0.6,
  ]) {
    final brightness = Theme.of(context).brightness;
    final top = brightness == Brightness.dark
        ? Colors.white.withOpacity(0.18 * strength)
        : Colors.white.withOpacity(0.28 * strength);
    final bottom = brightness == Brightness.dark
        ? Colors.black.withOpacity(0.22 * strength)
        : Colors.black.withOpacity(0.08 * strength);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        top,
        Colors.transparent,
        bottom,
      ],
    );
  }

  /// Gradient colors for the app background.
  static List<Color> backgroundGradient(BuildContext context) {
    final palette = Theme.of(context).extension<TidingsPalette>();
    if (palette != null) {
      return palette.backgroundGradient;
    }
    if (Theme.of(context).brightness == Brightness.dark) {
      return const [
        Color(0xFF0E1016),
        Color(0xFF141A23),
        Color(0xFF0B0D12),
      ];
    }
    return const [
      Color(0xFFF6F4EE),
      Color(0xFFF1F3F8),
      Color(0xFFEFF2FA),
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
        const Color(0xFF1F2433),
        Colors.white.withOpacity(0.03),
      ];
    }
    return const [
      Color(0xFFFFFFFF),
      Color(0xFFF0F2F9),
    ];
  }
}
