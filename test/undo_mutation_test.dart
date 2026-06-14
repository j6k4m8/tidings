import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/providers/email_provider.dart';
import 'package:tidings/providers/mock_email_provider.dart';
import 'package:tidings/state/tidings_settings.dart';

void main() {
  group('undoWindowSeconds setting', () {
    test('defaults to 5', () {
      expect(TidingsSettings(persistEnabled: false).undoWindowSeconds, 5);
    });

    test('setter clamps to 1..30 and notifies on change', () {
      final settings = TidingsSettings(persistEnabled: false);
      var notifications = 0;
      settings.addListener(() => notifications++);

      settings.setUndoWindowSeconds(10);
      expect(settings.undoWindowSeconds, 10);
      expect(notifications, 1);

      settings.setUndoWindowSeconds(999);
      expect(settings.undoWindowSeconds, 30);

      settings.setUndoWindowSeconds(0);
      expect(settings.undoWindowSeconds, 1);
    });

    test('round-trips through the QR transfer map', () {
      final source = TidingsSettings(persistEnabled: false)
        ..setUndoWindowSeconds(15);
      final map = source.transferableSettingsMap();
      expect(map['undoWindowSeconds'], 15);

      final target = TidingsSettings(persistEnabled: false)..applyFromQr(map);
      expect(target.undoWindowSeconds, 15);
    });
  });

  group('PendingThreadMutation', () {
    test('commit runs once and blocks a later undo', () async {
      var committed = 0;
      var undone = 0;
      final mutation = PendingThreadMutation(
        onCommit: () async {
          committed++;
          return null;
        },
        onUndo: () => undone++,
      );

      expect(await mutation.commit(), isNull);
      expect(committed, 1);

      mutation.undo();
      expect(undone, 0); // already settled by commit

      expect(await mutation.commit(), isNull); // no-op
      expect(committed, 1);
    });

    test('undo runs once and blocks a later commit', () async {
      var committed = 0;
      var undone = 0;
      final mutation = PendingThreadMutation(
        onCommit: () async {
          committed++;
          return null;
        },
        onUndo: () => undone++,
      );

      mutation.undo();
      expect(undone, 1);

      expect(await mutation.commit(), isNull); // blocked
      expect(committed, 0);
    });
  });

  group('MockEmailProvider.beginArchive', () {
    test('removes the thread optimistically and undo restores it', () {
      final provider = MockEmailProvider(accountId: 'test');
      final thread = provider.threads.first;

      final mutation = provider.beginArchive(thread);
      expect(
        provider.threads.any((t) => t.id == thread.id),
        isFalse,
        reason: 'thread should disappear immediately',
      );

      mutation.undo();
      expect(
        provider.threads.any((t) => t.id == thread.id),
        isTrue,
        reason: 'undo should bring the thread back',
      );
    });

    test('commit keeps the thread removed and a later undo is a no-op', () async {
      final provider = MockEmailProvider(accountId: 'test');
      final thread = provider.threads.first;

      final mutation = provider.beginArchive(thread);
      expect(await mutation.commit(), isNull);
      expect(provider.threads.any((t) => t.id == thread.id), isFalse);

      mutation.undo(); // settled — must not resurrect the thread
      expect(provider.threads.any((t) => t.id == thread.id), isFalse);
    });
  });
}
