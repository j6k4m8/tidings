/// Source for theme palette styling.
enum ThemePaletteSource {
  /// Use the default theme colors.
  defaultPalette,

  /// Use the active account accent to derive the palette.
  accountAccent,
}

extension ThemePaletteSourceMeta on ThemePaletteSource {
  /// UI label for the palette mode.
  String get label {
    switch (this) {
      case ThemePaletteSource.defaultPalette:
        return 'Default';
      case ThemePaletteSource.accountAccent:
        return 'Account accent';
    }
  }

  /// Storage key for persistence.
  String get storageKey {
    switch (this) {
      case ThemePaletteSource.defaultPalette:
        return 'default';
      case ThemePaletteSource.accountAccent:
        return 'account_accent';
    }
  }

  /// Parses a stored key into a palette source.
  static ThemePaletteSource fromStorage(String? raw) {
    switch (raw) {
      case 'account_accent':
        return ThemePaletteSource.accountAccent;
      case 'default':
      default:
        return ThemePaletteSource.defaultPalette;
    }
  }
}
