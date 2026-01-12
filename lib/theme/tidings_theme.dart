import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'theme_palette.dart';

/// Defines the signature look and feel for Tidings.
class TidingsTheme {
  TidingsTheme._();

  /// Default accent used when no override is set.
  static const Color defaultAccent = Color(0xFF7B96FF);

  static const TextTheme _baseTextTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  );

  static TextTheme _scaledTextTheme(double scale) =>
      _baseTextTheme.apply(fontSizeFactor: scale);

  static Color _tint(Color color, Brightness brightness, double amount) {
    final overlay = brightness == Brightness.dark
        ? Colors.black.withOpacity(amount)
        : Colors.white.withOpacity(amount);
    return Color.alphaBlend(overlay, color);
  }

  static TidingsPalette _defaultPalette(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const TidingsPalette(
        backgroundGradient: [
          Color(0xFF0E1016),
          Color(0xFF141A23),
          Color(0xFF0B0D12),
        ],
        heroGradient: [
          Color(0xFF1A2130),
          Color(0x0DFFFFFF),
        ],
      );
    }
    return const TidingsPalette(
      backgroundGradient: [
        Color(0xFFF6F4EE),
        Color(0xFFF1F3F8),
        Color(0xFFEFF2FA),
      ],
      heroGradient: [
        Color(0xFFFFFFFF),
        Color(0xFFF0F2F9),
      ],
    );
  }

  static TidingsPalette _paletteFromAccent(
    Brightness brightness,
    Color accent,
  ) {
    final hsl = HSLColor.fromColor(accent);
    final secondary = hsl
        .withHue((hsl.hue + 24) % 360)
        .withSaturation((hsl.saturation * 0.85).clamp(0.3, 0.9))
        .withLightness((hsl.lightness * 0.9).clamp(0.35, 0.7))
        .toColor();
    final tertiary = hsl
        .withHue((hsl.hue + 48) % 360)
        .withSaturation((hsl.saturation * 0.7).clamp(0.25, 0.8))
        .withLightness((hsl.lightness * 0.85).clamp(0.32, 0.68))
        .toColor();
    final backgroundGradient = [
      _tint(accent, brightness, brightness == Brightness.dark ? 0.6 : 0.84),
      _tint(secondary, brightness, brightness == Brightness.dark ? 0.62 : 0.86),
      _tint(tertiary, brightness, brightness == Brightness.dark ? 0.7 : 0.9),
    ];
    final heroGradient = brightness == Brightness.dark
        ? [
            _tint(accent, brightness, 0.4),
            Colors.white.withOpacity(0.04),
          ]
        : [
            Colors.white,
            _tint(accent, brightness, 0.86),
          ];
    return TidingsPalette(
      backgroundGradient: backgroundGradient,
      heroGradient: heroGradient,
    );
  }

  static TidingsPalette _resolvePalette(
    Brightness brightness,
    ThemePaletteSource source,
    Color accent,
  ) {
    switch (source) {
      case ThemePaletteSource.accountAccent:
        return _paletteFromAccent(brightness, accent);
      case ThemePaletteSource.defaultPalette:
        return _defaultPalette(brightness);
    }
  }

  /// Dark, glassy theme tuned for Tidings surfaces.
  static ThemeData darkTheme({
    String? fontFamily = 'SpaceGrotesk',
    double fontScale = 1.0,
    double cornerRadiusScale = 1.0,
    Color? accentColor,
    ThemePaletteSource paletteSource = ThemePaletteSource.defaultPalette,
  }) {
    final accent = accentColor ?? defaultAccent;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF14171D),
    );
    final palette = _resolvePalette(Brightness.dark, paletteSource, accent);
    final textTheme = _scaledTextTheme(fontScale);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: fontFamily,
      useMaterial3: false,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF14171D).withOpacity(0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cornerRadiusScale),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF14171D).withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24 * cornerRadiusScale),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * cornerRadiusScale),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF14171D).withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * cornerRadiusScale),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * cornerRadiusScale),
            ),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3.5),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18 * cornerRadiusScale),
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [palette],
    );
  }

  /// Light theme option with warm neutrals.
  static ThemeData lightTheme({
    String? fontFamily = 'SpaceGrotesk',
    double fontScale = 1.0,
    double cornerRadiusScale = 1.0,
    Color? accentColor,
    ThemePaletteSource paletteSource = ThemePaletteSource.defaultPalette,
  }) {
    final accent = accentColor ?? defaultAccent;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F6FA),
    );
    final palette = _resolvePalette(Brightness.light, paletteSource, accent);
    final textTheme = _scaledTextTheme(fontScale);

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: fontFamily,
      useMaterial3: false,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.86),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cornerRadiusScale),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24 * cornerRadiusScale),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * cornerRadiusScale),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * cornerRadiusScale),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * cornerRadiusScale),
            ),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3.5),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18 * cornerRadiusScale),
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [palette],
    );
  }
}
