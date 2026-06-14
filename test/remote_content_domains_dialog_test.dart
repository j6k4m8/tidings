import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/models/email_models.dart';
import 'package:tidings/screens/home/thread_detail.dart';
import 'package:tidings/state/tidings_settings.dart';

void main() {
  testWidgets('remote content domains dialog opens without layout errors', (
    tester,
  ) async {
    final settings = TidingsSettings(persistEnabled: false);
    final message = EmailMessage(
      id: 'message-1',
      threadId: 'thread-1',
      subject: 'Remote images',
      from: const EmailAddress(name: 'News', email: 'news@example.com'),
      to: const [EmailAddress(name: 'Jordan', email: 'me@example.com')],
      time: 'Now',
      isMe: false,
      isUnread: false,
      bodyHtml:
          '<p>Hello</p>'
          '<img src="https://cdn.example.com/a.png">'
          '<img src="https://img.example.com/b.png">',
    );

    await tester.pumpWidget(
      TidingsSettingsScope(
        settings: settings,
        child: MaterialApp(
          home: Scaffold(
            body: MessageCard(
              message: message,
              accent: Colors.blue,
              threadIsUnread: false,
              expanded: true,
              onToggleExpanded: () {},
              isSelected: false,
              remoteContentAccountKey: 'account-1',
              onLoadRemoteContent: () {},
            ),
          ),
        ),
      ),
    );

    // "See domains" is now a compact icon button in the notice row.
    await tester.tap(find.byTooltip('See blocked domains'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Remote content domains'), findsOneWidget);
    expect(find.text('cdn.example.com'), findsOneWidget);
    expect(find.text('img.example.com'), findsOneWidget);

    await tester.tap(find.text('Allow').first);

    expect(settings.remoteContentAllowedDomains('account-1').length, 1);
  });
}
