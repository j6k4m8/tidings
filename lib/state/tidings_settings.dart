import 'package:flutter/material.dart';
import 'dart:async';

import '../theme/theme_palette.dart';
import 'config_store.dart';
import 'keyboard_shortcut.dart';
import 'shortcut_definitions.dart';

class TidingsSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemePaletteSource _paletteSource = ThemePaletteSource.defaultPalette;
  LayoutDensity _layoutDensity = LayoutDensity.standard;
  CornerRadiusStyle _cornerRadiusStyle = CornerRadiusStyle.traditional;
  bool _autoExpandUnread = true;
  bool _autoExpandLatest = true;
  bool _hideThreadSubjects = false;
  bool _hideSelfInThreadList = false;
  MessageCollapseMode _messageCollapseMode = MessageCollapseMode.beforeQuotes;
  int _collapsedMaxLines = 6;
  bool _showFolderLabels = true;
  bool _showFolderUnreadCounts = true;
  bool _tintThreadListByAccountAccent = true;
  bool _sidebarCollapsed = false;
  double _threadPanelFraction = 0.58;
  final Set<String> _pinnedFolderPaths = {};
  final Map<ShortcutAction, KeyboardShortcut> _shortcutPrimary = {};
  final Map<ShortcutAction, KeyboardShortcut?> _shortcutSecondary = {};

  ThemeMode get themeMode => _themeMode;
  ThemePaletteSource get paletteSource => _paletteSource;
  LayoutDensity get layoutDensity => _layoutDensity;
  CornerRadiusStyle get cornerRadiusStyle => _cornerRadiusStyle;
  bool get autoExpandUnread => _autoExpandUnread;
  bool get autoExpandLatest => _autoExpandLatest;
  bool get hideThreadSubjects => _hideThreadSubjects;
  bool get hideSelfInThreadList => _hideSelfInThreadList;
  MessageCollapseMode get messageCollapseMode => _messageCollapseMode;
  int get collapsedMaxLines => _collapsedMaxLines;
  bool get showFolderLabels => _showFolderLabels;
  bool get showFolderUnreadCounts => _showFolderUnreadCounts;
  bool get tintThreadListByAccountAccent => _tintThreadListByAccountAccent;
  bool get sidebarCollapsed => _sidebarCollapsed;
  double get threadPanelFraction => _threadPanelFraction;
  Set<String> get pinnedFolderPaths => Set.unmodifiable(_pinnedFolderPaths);

  double get densityScale => _layoutDensity.scale;
  double get cornerRadiusScale => _cornerRadiusStyle.scale;

  Future<void> load() async {
    final config = await TidingsConfigStore.loadConfig();
    if (config != null) {
      _loadFromConfig(config);
    }
    _ensureShortcutDefaults();
    notifyListeners();
  }

  KeyboardShortcut shortcutFor(
    ShortcutAction action, {
    bool secondary = false,
  }) {
    final definition = definitionFor(action);
    if (secondary) {
      return _shortcutSecondary[action] ??
          definition.secondaryDefault ??
          definition.primaryDefault;
    }
    return _shortcutPrimary[action] ?? definition.primaryDefault;
  }

  KeyboardShortcut? secondaryShortcutFor(ShortcutAction action) {
    return _shortcutSecondary[action];
  }

  String shortcutLabel(
    ShortcutAction action, {
    bool includeSecondary = true,
  }) {
    final primary = shortcutFor(action).label();
    final secondary = secondaryShortcutFor(action);
    if (!includeSecondary || secondary == null) {
      return primary;
    }
    return '$primary / ${secondary.label()}';
  }

  void _loadFromConfig(Map<String, Object?> config) {
    final rawSettings = config['settings'];
    if (rawSettings is! Map) {
      return;
    }
    final settings = rawSettings.cast<String, Object?>();
    _themeMode = _themeModeFromStorage(settings['themeMode']);
    _paletteSource = ThemePaletteSourceMeta.fromStorage(
      settings['paletteSource'] as String?,
    );
    _layoutDensity = _layoutDensityFromStorage(settings['layoutDensity']);
    _cornerRadiusStyle =
        _cornerRadiusFromStorage(settings['cornerRadiusStyle']);
    _autoExpandUnread =
        _boolFromStorage(settings['autoExpandUnread'], _autoExpandUnread);
    _autoExpandLatest =
        _boolFromStorage(settings['autoExpandLatest'], _autoExpandLatest);
    _hideThreadSubjects =
        _boolFromStorage(settings['hideThreadSubjects'], _hideThreadSubjects);
    _hideSelfInThreadList =
        _boolFromStorage(settings['hideSelfInThreadList'], _hideSelfInThreadList);
    _messageCollapseMode =
        _collapseModeFromStorage(settings['messageCollapseMode']);
    _collapsedMaxLines =
        _intFromStorage(settings['collapsedMaxLines'], _collapsedMaxLines)
            .clamp(2, 20);
    _showFolderLabels =
        _boolFromStorage(settings['showFolderLabels'], _showFolderLabels);
    _showFolderUnreadCounts =
        _boolFromStorage(settings['showFolderUnreadCounts'], _showFolderUnreadCounts);
    _tintThreadListByAccountAccent = _boolFromStorage(
      settings['tintThreadListByAccountAccent'],
      _tintThreadListByAccountAccent,
    );
    _sidebarCollapsed =
        _boolFromStorage(settings['sidebarCollapsed'], _sidebarCollapsed);
    _threadPanelFraction = _doubleFromStorage(
      settings['threadPanelFraction'],
      _threadPanelFraction,
    ).clamp(0.3, 0.8);
    _pinnedFolderPaths
      ..clear()
      ..addAll(_stringListFromStorage(settings['pinnedFolderPaths']));

    final rawShortcuts = settings['shortcuts'];
    if (rawShortcuts is Map) {
      _loadShortcuts(rawShortcuts.cast<String, Object?>());
    }
  }

  void _loadShortcuts(Map<String, Object?> raw) {
    final primary = raw['primary'];
    final secondary = raw['secondary'];
    final primaryMap = primary is Map ? primary.cast<String, Object?>() : null;
    final secondaryMap =
        secondary is Map ? secondary.cast<String, Object?>() : null;
    for (final definition in shortcutDefinitions) {
      final primaryRaw = primaryMap?[definition.action.name] as String?;
      final secondaryRaw = secondaryMap?[definition.action.name] as String?;
      final primaryParsed = KeyboardShortcut.tryParse(primaryRaw);
      final secondaryParsed = KeyboardShortcut.tryParse(secondaryRaw);
      if (primaryParsed != null) {
        _shortcutPrimary[definition.action] = primaryParsed;
      }
      if (secondaryParsed != null) {
        _shortcutSecondary[definition.action] = secondaryParsed;
      }
    }
  }

  void _ensureShortcutDefaults() {
    for (final definition in shortcutDefinitions) {
      _shortcutPrimary.putIfAbsent(
        definition.action,
        () => definition.primaryDefault,
      );
      if (definition.secondaryDefault != null) {
        _shortcutSecondary.putIfAbsent(
          definition.action,
          () => definition.secondaryDefault,
        );
      }
    }
  }

  Future<void> _persist() async {
    final config = await TidingsConfigStore.loadConfigOrEmpty();
    config['settings'] = _settingsToMap();
    await TidingsConfigStore.writeConfig(config);
  }

  Map<String, Object?> _settingsToMap() {
    final primary = <String, String>{};
    final secondary = <String, String>{};
    for (final definition in shortcutDefinitions) {
      primary[definition.action.name] =
          shortcutFor(definition.action).serialize();
      final secondaryShortcut = secondaryShortcutFor(definition.action);
      if (secondaryShortcut != null) {
        secondary[definition.action.name] = secondaryShortcut.serialize();
      }
    }
    final pinned = _pinnedFolderPaths.toList()..sort();
    return {
      'themeMode': _themeMode.name,
      'paletteSource': _paletteSource.storageKey,
      'layoutDensity': _layoutDensity.name,
      'cornerRadiusStyle': _cornerRadiusStyle.name,
      'autoExpandUnread': _autoExpandUnread,
      'autoExpandLatest': _autoExpandLatest,
      'hideThreadSubjects': _hideThreadSubjects,
      'hideSelfInThreadList': _hideSelfInThreadList,
      'messageCollapseMode': _messageCollapseMode.name,
      'collapsedMaxLines': _collapsedMaxLines,
      'showFolderLabels': _showFolderLabels,
      'showFolderUnreadCounts': _showFolderUnreadCounts,
      'tintThreadListByAccountAccent': _tintThreadListByAccountAccent,
      'sidebarCollapsed': _sidebarCollapsed,
      'threadPanelFraction': _threadPanelFraction,
      'pinnedFolderPaths': pinned,
      'shortcuts': {
        'primary': primary,
        if (secondary.isNotEmpty) 'secondary': secondary,
      },
    };
  }

  ThemeMode _themeModeFromStorage(Object? raw) {
    final value = raw is String ? raw : null;
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  LayoutDensity _layoutDensityFromStorage(Object? raw) {
    if (raw is String) {
      for (final density in LayoutDensity.values) {
        if (density.name == raw) {
          return density;
        }
      }
    }
    return _layoutDensity;
  }

  CornerRadiusStyle _cornerRadiusFromStorage(Object? raw) {
    if (raw is String) {
      for (final style in CornerRadiusStyle.values) {
        if (style.name == raw) {
          return style;
        }
      }
    }
    return _cornerRadiusStyle;
  }

  bool _boolFromStorage(Object? raw, bool fallback) {
    return raw is bool ? raw : fallback;
  }

  int _intFromStorage(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  MessageCollapseMode _collapseModeFromStorage(Object? raw) {
    if (raw is String) {
      for (final mode in MessageCollapseMode.values) {
        if (mode.name == raw) {
          return mode;
        }
      }
    }
    return _messageCollapseMode;
  }

  double _doubleFromStorage(Object? raw, double fallback) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  List<String> _stringListFromStorage(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  void setShortcut(
    ShortcutAction action,
    KeyboardShortcut shortcut, {
    bool secondary = false,
  }) {
    if (secondary) {
      _shortcutSecondary[action] = shortcut;
    } else {
      _shortcutPrimary[action] = shortcut;
    }
    unawaited(_persist());
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    unawaited(_persist());
    notifyListeners();
  }

  void setPaletteSource(ThemePaletteSource source) {
    if (_paletteSource == source) {
      return;
    }
    _paletteSource = source;
    unawaited(_persist());
    notifyListeners();
  }

  void setLayoutDensity(LayoutDensity density) {
    if (_layoutDensity == density) {
      return;
    }
    _layoutDensity = density;
    unawaited(_persist());
    notifyListeners();
  }

  void setCornerRadiusStyle(CornerRadiusStyle style) {
    if (_cornerRadiusStyle == style) {
      return;
    }
    _cornerRadiusStyle = style;
    unawaited(_persist());
    notifyListeners();
  }

  void setAutoExpandUnread(bool value) {
    if (_autoExpandUnread == value) {
      return;
    }
    _autoExpandUnread = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setAutoExpandLatest(bool value) {
    if (_autoExpandLatest == value) {
      return;
    }
    _autoExpandLatest = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setHideThreadSubjects(bool value) {
    if (_hideThreadSubjects == value) {
      return;
    }
    _hideThreadSubjects = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setHideSelfInThreadList(bool value) {
    if (_hideSelfInThreadList == value) {
      return;
    }
    _hideSelfInThreadList = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setMessageCollapseMode(MessageCollapseMode mode) {
    if (_messageCollapseMode == mode) {
      return;
    }
    _messageCollapseMode = mode;
    unawaited(_persist());
    notifyListeners();
  }

  void setCollapsedMaxLines(int lines) {
    final clamped = lines.clamp(2, 20);
    if (_collapsedMaxLines == clamped) {
      return;
    }
    _collapsedMaxLines = clamped;
    unawaited(_persist());
    notifyListeners();
  }

  void setShowFolderLabels(bool value) {
    if (_showFolderLabels == value) {
      return;
    }
    _showFolderLabels = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setShowFolderUnreadCounts(bool value) {
    if (_showFolderUnreadCounts == value) {
      return;
    }
    _showFolderUnreadCounts = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setTintThreadListByAccountAccent(bool value) {
    if (_tintThreadListByAccountAccent == value) {
      return;
    }
    _tintThreadListByAccountAccent = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setSidebarCollapsed(bool value) {
    if (_sidebarCollapsed == value) {
      return;
    }
    _sidebarCollapsed = value;
    unawaited(_persist());
    notifyListeners();
  }

  void setThreadPanelFraction(double value) {
    final clamped = value.clamp(0.3, 0.8);
    if (_threadPanelFraction == clamped) {
      return;
    }
    _threadPanelFraction = clamped;
    unawaited(_persist());
    notifyListeners();
  }

  bool isFolderPinned(String path) {
    return _pinnedFolderPaths.contains(path);
  }

  void toggleFolderPinned(String path) {
    if (_pinnedFolderPaths.contains(path)) {
      _pinnedFolderPaths.remove(path);
    } else {
      _pinnedFolderPaths.add(path);
    }
    unawaited(_persist());
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
    required super.child,
  }) : super(notifier: settings);

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

enum MessageCollapseMode {
  maxLines,
  beforeQuotes,
}

extension MessageCollapseModeMeta on MessageCollapseMode {
  String get label {
    switch (this) {
      case MessageCollapseMode.maxLines:
        return 'Max lines';
      case MessageCollapseMode.beforeQuotes:
        return 'Before quotes';
    }
  }

  String get description {
    switch (this) {
      case MessageCollapseMode.maxLines:
        return 'Clip at a fixed number of lines';
      case MessageCollapseMode.beforeQuotes:
        return 'Clip before quoted replies';
    }
  }
}
