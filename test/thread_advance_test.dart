import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/providers/mock_email_provider.dart';
import 'package:tidings/screens/home/thread_detail.dart';
import 'package:tidings/state/tidings_settings.dart';

void main() {
  testWidgets('archiving the open thread advances to the next when set', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = MockEmailProvider(accountId: 'test');
    final threads = provider.threads;
    expect(threads.length, greaterThanOrEqualTo(2));
    final first = threads[0];
    final next = threads[1];

    final settings = TidingsSettings(persistEnabled: false)
      ..setThreadActionFollowUp(ThreadActionFollowUp.advanceToNext);

    await tester.pumpWidget(
      TidingsSettingsScope(
        settings: settings,
        child: MaterialApp(
          home: ThreadScreen(
            accent: Colors.blue,
            thread: first,
            provider: provider,
            currentUserEmail: 'me@example.com',
            remoteContentAccountKey: 'test',
          ),
        ),
      ),
    );
    // Explicit pumps (not pumpAndSettle): rendered message bodies can hold a
    // never-completing image spinner in the test harness.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Archive'));
    await tester.pump(); // tap handler runs beginArchive + advances _thread
    await tester.pump(const Duration(milliseconds: 400));

    // The detail view stayed open (did not pop) and the archived thread is gone.
    expect(find.byType(ThreadScreen), findsOneWidget);
    expect(provider.threads.any((t) => t.id == first.id), isFalse);
    // It advanced in place to the next thread.
    expect(find.text(next.subject), findsWidgets);

    // Let the undo window's timer elapse so it is not pending at teardown.
    await tester.pump(const Duration(seconds: 6));
  });
}
