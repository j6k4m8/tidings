import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/state/touch_capability.dart';

void main() {
  group('TouchCapability', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('seeds true on touch-first platforms', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(TouchCapability().hasTouch, isTrue, reason: '$platform');
      }
    });

    test('seeds false on desktop platforms', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(TouchCapability().hasTouch, isFalse, reason: '$platform');
      }
    });

    test('a touch pointer upgrades a non-touch host and notifies once', () {
      final capability = TouchCapability(initialHasTouch: false);
      var notifications = 0;
      capability.addListener(() => notifications++);

      capability.reportPointerKind(PointerDeviceKind.mouse);
      expect(capability.hasTouch, isFalse);
      expect(notifications, 0);

      capability.reportPointerKind(PointerDeviceKind.touch);
      expect(capability.hasTouch, isTrue);
      expect(notifications, 1);

      // A stylus also counts as touch input.
      final stylusHost = TouchCapability(initialHasTouch: false);
      stylusHost.reportPointerKind(PointerDeviceKind.stylus);
      expect(stylusHost.hasTouch, isTrue);
    });

    test('never reverts once touch has been seen', () {
      final capability = TouchCapability(initialHasTouch: true);
      var notifications = 0;
      capability.addListener(() => notifications++);

      // Subsequent pointers (touch or mouse) must not notify or downgrade.
      capability.reportPointerKind(PointerDeviceKind.mouse);
      capability.reportPointerKind(PointerDeviceKind.touch);
      expect(capability.hasTouch, isTrue);
      expect(notifications, 0);
    });
  });
}
