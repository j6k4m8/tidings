import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/state/tidings_settings.dart';

void main() {
  group('threadActionFollowUp setting', () {
    test('defaults to advanceToNext', () {
      expect(
        TidingsSettings(persistEnabled: false).threadActionFollowUp,
        ThreadActionFollowUp.advanceToNext,
      );
    });

    test('setter updates and round-trips through QR', () {
      final source = TidingsSettings(persistEnabled: false)
        ..setThreadActionFollowUp(ThreadActionFollowUp.closePanel);
      expect(source.threadActionFollowUp, ThreadActionFollowUp.closePanel);

      final map = source.transferableSettingsMap();
      expect(map['threadActionFollowUp'], 'closePanel');

      final target = TidingsSettings(persistEnabled: false)..applyFromQr(map);
      expect(target.threadActionFollowUp, ThreadActionFollowUp.closePanel);
    });

    test('unknown stored value falls back to the default', () {
      final settings = TidingsSettings(persistEnabled: false)
        ..applyFromQr({'threadActionFollowUp': 'teleport'});
      expect(settings.threadActionFollowUp, ThreadActionFollowUp.advanceToNext);
    });
  });

  group('promptBeforeDeleting setting', () {
    test('defaults to true', () {
      expect(TidingsSettings(persistEnabled: false).promptBeforeDeleting, true);
    });

    test('setter updates and notifies, ignoring no-ops', () {
      final settings = TidingsSettings(persistEnabled: false);
      var notifications = 0;
      settings.addListener(() => notifications++);

      settings.setPromptBeforeDeleting(false);
      expect(settings.promptBeforeDeleting, false);
      expect(notifications, 1);

      settings.setPromptBeforeDeleting(false);
      expect(notifications, 1);
    });

    test('round-trips through the QR transfer map', () {
      final source = TidingsSettings(persistEnabled: false)
        ..setPromptBeforeDeleting(false);
      final map = source.transferableSettingsMap();
      expect(map['promptBeforeDeleting'], false);

      final target = TidingsSettings(persistEnabled: false)..applyFromQr(map);
      expect(target.promptBeforeDeleting, false);
    });
  });
}
