import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/state/tidings_settings.dart';

void main() {
  group('swipe action settings', () {
    test('default to enabled with archive right / read-toggle left', () {
      final settings = TidingsSettings(persistEnabled: false);

      expect(settings.swipeActionsEnabled, isTrue);
      expect(settings.swipeRightAction, SwipeAction.archive);
      expect(settings.swipeLeftAction, SwipeAction.toggleRead);
    });

    test('setters update values and notify listeners', () {
      final settings = TidingsSettings(persistEnabled: false);
      var notifications = 0;
      settings.addListener(() => notifications++);

      settings.setSwipeActionsEnabled(false);
      settings.setSwipeRightAction(SwipeAction.toggleRead);
      settings.setSwipeLeftAction(SwipeAction.none);

      expect(settings.swipeActionsEnabled, isFalse);
      expect(settings.swipeRightAction, SwipeAction.toggleRead);
      expect(settings.swipeLeftAction, SwipeAction.none);
      expect(notifications, 3);

      // Setting the same value is a no-op (no extra notification).
      settings.setSwipeRightAction(SwipeAction.toggleRead);
      expect(notifications, 3);
    });

    test('only archive removes the thread from the list', () {
      expect(SwipeAction.archive.removesThread, isTrue);
      expect(SwipeAction.toggleRead.removesThread, isFalse);
      expect(SwipeAction.none.removesThread, isFalse);
    });

    test('round-trip through the QR transfer map', () {
      final source = TidingsSettings(persistEnabled: false)
        ..setSwipeActionsEnabled(false)
        ..setSwipeRightAction(SwipeAction.none)
        ..setSwipeLeftAction(SwipeAction.archive);

      final map = source.transferableSettingsMap();
      expect(map['swipeActionsEnabled'], false);
      expect(map['swipeRightAction'], 'none');
      expect(map['swipeLeftAction'], 'archive');

      final target = TidingsSettings(persistEnabled: false)..applyFromQr(map);
      expect(target.swipeActionsEnabled, isFalse);
      expect(target.swipeRightAction, SwipeAction.none);
      expect(target.swipeLeftAction, SwipeAction.archive);
    });

    test('unknown stored swipe action falls back to the default', () {
      // Old/garbage QR payloads must never crash newer builds.
      final settings = TidingsSettings(persistEnabled: false)
        ..applyFromQr({'swipeRightAction': 'teleport'});

      expect(settings.swipeRightAction, SwipeAction.archive);
    });
  });
}
