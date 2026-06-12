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

    test('static deviceSupportsTouch reflects the latest instance', () {
      TouchCapability(initialHasTouch: true);
      expect(TouchCapability.deviceSupportsTouch, isTrue);

      final off = TouchCapability(initialHasTouch: false);
      expect(TouchCapability.deviceSupportsTouch, isFalse);

      // A runtime touch upgrade is visible through the static accessor too.
      off.reportPointerKind(PointerDeviceKind.touch);
      expect(TouchCapability.deviceSupportsTouch, isTrue);
    });

    test('static falls back to the platform seed after dispose', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final cap = TouchCapability(initialHasTouch: false);
      expect(TouchCapability.deviceSupportsTouch, isFalse);

      cap.dispose();
      // No live instance -> platform seed (android is touch-first).
      expect(TouchCapability.deviceSupportsTouch, isTrue);
    });

    test('trackpad starts off and flips on a trackpad gesture', () {
      final capability = TouchCapability(initialHasTouch: false);
      var notifications = 0;
      capability.addListener(() => notifications++);
      expect(capability.hasTrackpad, isFalse);

      // A mouse is neither touch nor trackpad.
      capability.reportPointerKind(PointerDeviceKind.mouse);
      expect(capability.hasTrackpad, isFalse);
      expect(notifications, 0);

      capability.reportPointerKind(PointerDeviceKind.trackpad);
      expect(capability.hasTrackpad, isTrue);
      expect(capability.hasTouch, isFalse); // trackpad is not touch
      expect(notifications, 1);
    });

    test('static deviceSupportsTrackpad reflects the latest instance', () {
      TouchCapability(initialHasTouch: false);
      expect(TouchCapability.deviceSupportsTrackpad, isFalse);

      final cap = TouchCapability(initialHasTouch: false)
        ..reportPointerKind(PointerDeviceKind.trackpad);
      expect(cap.hasTrackpad, isTrue);
      expect(TouchCapability.deviceSupportsTrackpad, isTrue);
    });
  });
}
