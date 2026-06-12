import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Tracks whether the host device supports touch input.
///
/// The value is seeded from the platform — phones and tablets
/// (Android / iOS / Fuchsia) are touch-first — and then upgraded to `true` the
/// first time a touch or stylus pointer is observed. That runtime upgrade
/// catches touchscreen laptops and desktops that the platform alone wouldn't
/// reveal. It never reverts to `false`, so a device that has shown touch stays
/// touch-capable for the rest of the session.
///
/// This is deliberately independent of viewport size: a landscape tablet is a
/// touch device even though it is wide, and a narrow desktop window is not a
/// touch device even though it is compact.
class TouchCapability extends ChangeNotifier {
  TouchCapability({bool? initialHasTouch})
    : _hasTouch = initialHasTouch ?? _platformIsTouchFirst();

  bool _hasTouch;

  bool get hasTouch => _hasTouch;

  /// Records the kind of an observed pointer, flipping [hasTouch] to `true`
  /// the first time a touch or stylus pointer is seen.
  void reportPointerKind(PointerDeviceKind kind) {
    if (_hasTouch) {
      return;
    }
    if (kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus) {
      _hasTouch = true;
      notifyListeners();
    }
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
  /// to changes, so a widget rebuilds when touch is first detected. Defaults to
  /// `false` when no [TouchCapabilityScope] is present (e.g. in tests).
  bool get hasTouchInput {
    final scope = dependOnInheritedWidgetOfExactType<TouchCapabilityScope>();
    return scope?.notifier?.hasTouch ?? false;
  }
}
