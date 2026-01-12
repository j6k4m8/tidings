import 'package:flutter/material.dart';

import '../theme/theme_palette.dart';

class TidingsSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemePaletteSource _paletteSource = ThemePaletteSource.defaultPalette;
  LayoutDensity _layoutDensity = LayoutDensity.standard;
  CornerRadiusStyle _cornerRadiusStyle = CornerRadiusStyle.traditional;
  bool _autoExpandUnread = true;
  bool _autoExpandLatest = true;

  ThemeMode get themeMode => _themeMode;
  ThemePaletteSource get paletteSource => _paletteSource;
  LayoutDensity get layoutDensity => _layoutDensity;
  CornerRadiusStyle get cornerRadiusStyle => _cornerRadiusStyle;
  bool get autoExpandUnread => _autoExpandUnread;
  bool get autoExpandLatest => _autoExpandLatest;

  double get densityScale => _layoutDensity.scale;
  double get cornerRadiusScale => _cornerRadiusStyle.scale;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  void setPaletteSource(ThemePaletteSource source) {
    if (_paletteSource == source) {
      return;
    }
    _paletteSource = source;
    notifyListeners();
  }

  void setLayoutDensity(LayoutDensity density) {
    if (_layoutDensity == density) {
      return;
    }
    _layoutDensity = density;
    notifyListeners();
  }

  void setCornerRadiusStyle(CornerRadiusStyle style) {
    if (_cornerRadiusStyle == style) {
      return;
    }
    _cornerRadiusStyle = style;
    notifyListeners();
  }

  void setAutoExpandUnread(bool value) {
    if (_autoExpandUnread == value) {
      return;
    }
    _autoExpandUnread = value;
    notifyListeners();
  }

  void setAutoExpandLatest(bool value) {
    if (_autoExpandLatest == value) {
      return;
    }
    _autoExpandLatest = value;
    notifyListeners();
  }
}

enum LayoutDensity {
  compact,
  standard,
  spacious,
}

extension LayoutDensityMeta on LayoutDensity {
  String get label {
    switch (this) {
      case LayoutDensity.compact:
        return 'Sardinemode';
      case LayoutDensity.standard:
        return 'Default';
      case LayoutDensity.spacious:
        return 'Spacious';
    }
  }

  double get scale {
    switch (this) {
      case LayoutDensity.compact:
        return 0.88;
      case LayoutDensity.standard:
        return 1.0;
      case LayoutDensity.spacious:
        return 1.12;
    }
  }
}

enum CornerRadiusStyle {
  pointy,
  traditional,
  babyProofed,
}

extension CornerRadiusStyleMeta on CornerRadiusStyle {
  String get label {
    switch (this) {
      case CornerRadiusStyle.pointy:
        return 'Pointy';
      case CornerRadiusStyle.traditional:
        return 'Traditional';
      case CornerRadiusStyle.babyProofed:
        return 'Babyproofed';
    }
  }

  double get scale {
    switch (this) {
      case CornerRadiusStyle.pointy:
        return 0.0;
      case CornerRadiusStyle.traditional:
        return 0.9;
      case CornerRadiusStyle.babyProofed:
        return 1.18;
    }
  }
}

class TidingsSettingsScope extends InheritedNotifier<TidingsSettings> {
  const TidingsSettingsScope({
    super.key,
    required TidingsSettings settings,
    required Widget child,
  }) : super(notifier: settings, child: child);

  static TidingsSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TidingsSettingsScope>();
    final settings = scope?.notifier;
    if (settings == null) {
      throw StateError('TidingsSettingsScope not found in context.');
    }
    return settings;
  }
}

extension TidingsSettingsContext on BuildContext {
  TidingsSettings get tidingsSettings => TidingsSettingsScope.of(this);

  double space(double value) => value * tidingsSettings.densityScale;

  double gutter(double value) => value * tidingsSettings.densityScale;

  double radius(double value) => value * tidingsSettings.cornerRadiusScale;
}
