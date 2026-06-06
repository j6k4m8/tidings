import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
      expect(sanitized.html, isNot(contains('width=')));
      expect(sanitized.html, isNot(contains('height=')));
      expect(sanitized.html, isNot(contains('width:640px')));
      expect(sanitized.html, isNot(contains('height:320px')));
    },
  );
}
