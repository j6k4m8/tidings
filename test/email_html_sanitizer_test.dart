import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/utils/email_html_sanitizer.dart';

void main() {
  group('sanitizeEmailHtml', () {
    test('blocks remote media and removes unsafe HTML by default', () {
      final result = sanitizeEmailHtml('''
        <p onclick="steal()">
          Hello
          <script>alert('x')</script>
          <iframe src="https://evil.example/frame"></iframe>
          <img src="https://tracker.example/pixel.png" width="1" height="1">
          <a href="javascript:alert(1)" onmouseover="steal()">bad link</a>
        </p>
      ''');

      expect(result.hasBlockedRemoteContent, isTrue);
      expect(result.blockedRemoteContentCount, 1);
      expect(result.blockedRemoteDomains, {'tracker.example'});
      expect(result.removedUnsafeContentCount, greaterThanOrEqualTo(4));
      expect(result.html, isNot(contains('<script')));
      expect(result.html, isNot(contains('<iframe')));
      expect(result.html, isNot(contains('onclick')));
      expect(result.html, isNot(contains('onmouseover')));
      expect(result.html, isNot(contains('javascript:')));
      expect(result.html, isNot(contains('https://tracker.example')));
      expect(result.html, isNot(contains('width=')));
      expect(result.html, isNot(contains('height=')));
      expect(result.html, contains('[remote image blocked]'));
    });

    test('allows remote media only when explicitly requested', () {
      final blocked = sanitizeEmailHtml(
        '<img src="https://example.com/a.png" '
        'srcset="https://example.com/a.png 1x, https://example.com/b.png 2x">',
      );
      expect(blocked.html, isNot(contains('https://example.com/a.png')));
      expect(blocked.blockedRemoteContentCount, 3);

      final loaded = sanitizeEmailHtml(
        '<img src="https://example.com/a.png" '
        'srcset="https://example.com/a.png 1x, https://example.com/b.png 2x">',
        loadRemoteContent: true,
      );
      expect(loaded.html, contains('src="https://example.com/a.png"'));
      expect(loaded.html, contains('srcset='));
      expect(loaded.blockedRemoteContentCount, 0);
    });

    test(
      'loads exact allowed remote domains while reporting blocked hosts',
      () {
        final result = sanitizeEmailHtml(
          '<img src="https://img.example.com/a.png" '
          'srcset="https://img.example.com/a.png 1x, '
          'https://cdn.example.com/b.png 2x"> '
          '<img src="//tracking.example.com/pixel.png">',
          allowedRemoteContentDomains: {'IMG.EXAMPLE.COM.'},
        );

        expect(result.html, contains('https://img.example.com/a.png'));
        expect(result.html, contains('srcset='));
        expect(result.html, isNot(contains('https://cdn.example.com/b.png')));
        expect(result.html, isNot(contains('tracking.example.com')));
        expect(result.blockedRemoteContentCount, 2);
        expect(result.blockedRemoteDomains, {
          'cdn.example.com',
          'tracking.example.com',
        });
      },
    );

    test('keeps safe links and strips unsafe links', () {
      final result = sanitizeEmailHtml('''
        <a href="https://example.com">web</a>
        <a href="mailto:test@example.com">mail</a>
        <a href="tel:+15551212">phone</a>
        <a href="#section">jump</a>
        <a href="data:text/html,boom">data</a>
        <a href="/relative">relative</a>
      ''');

      expect(result.html, contains('href="https://example.com"'));
      expect(result.html, contains('href="mailto:test@example.com"'));
      expect(result.html, contains('href="tel:+15551212"'));
      expect(result.html, contains('href="#section"'));
      expect(result.html, isNot(contains('data:text/html')));
      expect(result.html, isNot(contains('href="/relative"')));
    });

    test('sanitizes inline styles without dropping safe declarations', () {
      final result = sanitizeEmailHtml(
        '<img src="cid:inline-image" width="320" height="200" '
        'style="width:320px; height:200px; color:red; '
        'background:url(https://tracker.example/bg.png)">',
      );

      expect(result.html, contains('src="cid:inline-image"'));
      expect(result.html, contains('style="color:red"'));
      expect(result.html, isNot(contains('width=')));
      expect(result.html, isNot(contains('height=')));
      expect(result.html, isNot(contains('background')));
      expect(result.html, isNot(contains('tracker.example')));
    });
  });

  group('isSafeEmailLink', () {
    test('allows only explicit external-safe schemes and fragments', () {
      expect(isSafeEmailLink('https://example.com'), isTrue);
      expect(isSafeEmailLink('http://example.com'), isTrue);
      expect(isSafeEmailLink('mailto:test@example.com'), isTrue);
      expect(isSafeEmailLink('tel:+15551212'), isTrue);
      expect(isSafeEmailLink('#reply'), isTrue);

      expect(isSafeEmailLink('javascript:alert(1)'), isFalse);
      expect(isSafeEmailLink('data:text/html,boom'), isFalse);
      expect(isSafeEmailLink('file:///etc/passwd'), isFalse);
      expect(isSafeEmailLink('/relative'), isFalse);
    });
  });
}
