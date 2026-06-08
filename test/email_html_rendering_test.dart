import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:tidings/utils/email_html_sanitizer.dart';

void main() {
  testWidgets(
    'sanitized table images render without FlutterError suppression',
    (tester) async {
      final sanitized = sanitizeEmailHtml('''
      <table>
        <tr>
          <td>
            <img
              src="data:image/gif;base64,R0lGODlhAQABAAAAACw="
              width="640"
              height="320"
              style="width:640px; height:320px; color:red">
          </td>
        </tr>
      </table>
      ''', loadRemoteContent: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: HtmlWidget(sanitized.html)),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(sanitized.html, contains('<table>'));
      expect(sanitized.html, contains('<td>'));
      expect(sanitized.html, isNot(contains('width=')));
      expect(sanitized.html, isNot(contains('height=')));
      expect(sanitized.html, isNot(contains('width:640px')));
      expect(sanitized.html, isNot(contains('height:320px')));
    },
  );

  testWidgets('blocked remote images render as text, not image spinners', (
    tester,
  ) async {
    final sanitized = sanitizeEmailHtml('''
      <table>
        <tr>
          <td>
            <img src="https://tracker.example/pixel.png" width="1" height="1">
          </td>
        </tr>
      </table>
      ''');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: HtmlWidget(sanitized.html)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(sanitized.html, contains('[remote image blocked]'));
    expect(sanitized.html, isNot(contains('<img')));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
