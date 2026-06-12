import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Tracks the swipe-capable input the host device supports: touch and trackpad.
///
/// [hasTouch] is seeded from the platform — phones and tablets
/// (Android / iOS / Fuchsia) are touch-first — and upgraded to `true` the first
/// time a touch or stylus pointer is observed, which catches touchscreen
/// laptops/desktops. [hasTrackpad] starts `false` (a precise pointer can't be
/// inferred from the platform) and flips to `true` the first time a trackpad
/// gesture (two-finger pan/scroll) is observed — e.g. a macOS laptop. Neither
/// ever reverts.
///
/// Both feed the thread-list swipe affordance, since a two-finger horizontal
/// trackpad pan drives the same [Dismissible] as a touch swipe. This is
/// deliberately independent of viewport size: a landscape tablet is a touch
/// device even though it is wide, and a narrow desktop window is not.
class TouchCapability extends ChangeNotifier {
  TouchCapability({bool? initialHasTouch, bool initialHasTrackpad = false})
    : _hasTouch = initialHasTouch ?? _platformIsTouchFirst(),
      _hasTrackpad = initialHasTrackpad {
    _instance = this;
  }

  /// The most recently constructed instance, used to back the context-free
  /// static accessors. The app creates exactly one (in `TidingsApp`); tests
  /// may create their own.
  static TouchCapability? _instance;

  bool _hasTouch;
  bool _hasTrackpad;

  bool get hasTouch => _hasTouch;
  bool get hasTrackpad => _hasTrackpad;

  /// Universal, context-free read of whether the device supports touch.
  ///
  /// Prefer [BuildContext.deviceSupportsTouch] inside widgets so they rebuild
  /// when touch is first detected; use this in plain business logic where no
  /// [BuildContext] is available. Falls back to the platform seed before any
  /// instance exists.
  static bool get deviceSupportsTouch =>
      _instance?._hasTouch ?? _platformIsTouchFirst();

  /// Universal, context-free read of whether a trackpad has been seen.
  static bool get deviceSupportsTrackpad => _instance?._hasTrackpad ?? false;

  /// Records the kind of an observed pointer. Flips [hasTouch] to `true` the
  /// first time a touch/stylus pointer is seen, and [hasTrackpad] the first
  /// time a trackpad pointer is seen.
  void reportPointerKind(PointerDeviceKind kind) {
    var changed = false;
    if (!_hasTouch &&
        (kind == PointerDeviceKind.touch ||
            kind == PointerDeviceKind.stylus)) {
      _hasTouch = true;
      changed = true;
    }
    if (!_hasTrackpad && kind == PointerDeviceKind.trackpad) {
      _hasTrackpad = true;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (identical(_instance, this)) {
      _instance = null;
    }
    super.dispose();
  }

  static bool _platformIsTouchFirst() => switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => true,
    TargetPlatform.macOS ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

/// Provides a [TouchCapability] to the subtree and rebuilds dependents when the
/// touch state flips.
class TouchCapabilityScope extends InheritedNotifier<TouchCapability> {
  const TouchCapabilityScope({
    super.key,
    required TouchCapability capability,
    required super.child,
  }) : super(notifier: capability);
}

extension TouchCapabilityContext on BuildContext {
  /// Whether the host supports touch input. Reading this subscribes the caller
  /// to changes, so a widget rebuilds when touch is first detected. Falls back
  /// to [TouchCapability.deviceSupportsTouch] when no [TouchCapabilityScope] is
  /// present (e.g. in tests).
  bool get deviceSupportsTouch {
    final scope = dependOnInheritedWidgetOfExactType<TouchCapabilityScope>();
    return scope?.notifier?.hasTouch ?? TouchCapability.deviceSupportsTouch;
  }

  /// Whether a trackpad gesture has been observed. Subscribes the caller to
  /// changes, so a widget rebuilds when a trackpad is first detected.
  bool get deviceSupportsTrackpad {
    final scope = dependOnInheritedWidgetOfExactType<TouchCapabilityScope>();
    return scope?.notifier?.hasTrackpad ?? TouchCapability.deviceSupportsTrackpad;
  }
}
