import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/providers/gmail_mime_builder.dart';

void main() {
  group('buildGmailRfc2822', () {
    test('writes sanitized Gmail headers including Bcc', () {
      final raw = _buildMessage(
        cc: 'copy@example.com',
        bcc: 'hidden@example.com',
        replyMessageId: '<reply@example.com>',
        replyInReplyTo: '<root@example.com>',
      );

      final headers = raw.substring(0, raw.indexOf('\r\n\r\n')).split('\r\n');
      expect(headers, contains('From: sender@example.com'));
      expect(headers, contains('To: recipient@example.com'));
      expect(headers, contains('Cc: copy@example.com'));
      expect(headers, contains('Bcc: hidden@example.com'));
      expect(headers, contains('In-Reply-To: <reply@example.com>'));
      expect(
        headers,
        contains('References: <root@example.com> <reply@example.com>'),
      );
    });

    test('rejects CRLF injection in address headers', () {
      expect(
        () => _buildMessage(to: 'recipient@example.com\r\nCc: attacker@x.test'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('To header'),
          ),
        ),
      );
      expect(
        () => _buildMessage(bcc: 'hidden@example.com\nSubject: overwritten'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Bcc header'),
          ),
        ),
      );
    });

    test('rejects CRLF injection in reply headers and subject', () {
      expect(
        () => _buildMessage(
          replyMessageId: '<reply@example.com>\r\nX-Injected: yes',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('In-Reply-To header'),
          ),
        ),
      );
      expect(
        () => _buildMessage(subject: 'Hello\r\nBcc: attacker@x.test'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Subject header'),
          ),
        ),
      );
    });

    test('requires at least one recipient for sends', () {
      expect(
        () => _buildMessage(to: '', requireRecipient: true),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('At least one recipient'),
          ),
        ),
      );

      final raw = _buildMessage(
        to: '',
        bcc: 'hidden@example.com',
        requireRecipient: true,
      );
      expect(raw, contains('Bcc: hidden@example.com'));
      expect(raw, isNot(contains('\r\nTo: ')));
    });

    test('base64 encodes message bodies', () {
      final raw = _buildMessage(
        bodyText: 'Plain body',
        bodyHtml: '<p>Hello</p>',
      );

      expect(raw, contains(base64Encode(utf8.encode('Plain body'))));
      expect(raw, contains(base64Encode(utf8.encode('<p>Hello</p>'))));
      expect(raw, isNot(contains('<p>Hello</p>')));
    });
  });
}

String _buildMessage({
  String from = 'sender@example.com',
  String to = 'recipient@example.com',
  String? cc,
  String? bcc,
  String subject = 'Hello',
  String bodyHtml = '<p>Hello</p>',
  String bodyText = 'Hello',
  String? replyMessageId,
  String? replyInReplyTo,
  bool requireRecipient = false,
}) {
  return buildGmailRfc2822(
    from: from,
    to: to,
    cc: cc,
    bcc: bcc,
    subject: subject,
    bodyHtml: bodyHtml,
    bodyText: bodyText,
    replyMessageId: replyMessageId,
    replyInReplyTo: replyInReplyTo,
    requireRecipient: requireRecipient,
  );
}
