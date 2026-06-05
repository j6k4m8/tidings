import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/state/qr_transfer.dart';

void main() {
  group('QR transfer encryption', () {
    test('encrypts IMAP credentials and decodes with the transfer code', () {
      final payload = _imapPayload();
      final export = createQrTransferExport([
        payload,
        const GmailQrPayload(email: 'person@gmail.com'),
        const SettingsQrPayload(settings: {'themeMode': 'dark'}),
      ], random: Random(1));

      expect(isEncryptedQrTransfer(export.qrData), isTrue);
      expect(export.qrData, isNot(contains('secret-imap-password')));
      expect(export.qrData, isNot(contains('secret-smtp-password')));
      expect(export.qrData, isNot(contains('imap.example.com')));

      final decoded = decodeQrTransferExport(
        export.qrData,
        transferCode: export.transferCode,
      );

      expect(decoded, hasLength(3));
      final imap = decoded!.whereType<ImapQrPayload>().single;
      expect(imap.password, 'secret-imap-password');
      expect(imap.smtpPassword, 'secret-smtp-password');
      expect(imap.toImapConfig().server, 'imap.example.com');
      expect(
        decoded.whereType<GmailQrPayload>().single.email,
        'person@gmail.com',
      );
      expect(
        decoded.whereType<SettingsQrPayload>().single.settings['themeMode'],
        'dark',
      );
    });

    test('accepts transfer code without separators or uppercase', () {
      final export = createQrTransferExport([
        _imapPayload(),
      ], random: Random(2));
      final compactLower = export.transferCode
          .replaceAll('-', '')
          .toLowerCase();

      final decoded = decodeQrTransferExport(
        export.qrData,
        transferCode: compactLower,
      );

      expect(decoded, hasLength(1));
      expect(decoded!.single, isA<ImapQrPayload>());
    });

    test('rejects incorrect transfer code', () {
      final export = createQrTransferExport([
        _imapPayload(),
      ], random: Random(3));

      final decoded = decodeQrTransferExport(
        export.qrData,
        transferCode: 'AAAA-BBBB-CCCC-DDDD',
      );

      expect(decoded, isNull);
    });

    test('rejects expired encrypted envelopes', () {
      final now = DateTime(2026, 1, 1, 12);
      final export = createQrTransferExport(
        [_imapPayload()],
        now: now,
        random: Random(4),
      );

      final decoded = decodeQrTransferExport(
        export.qrData,
        transferCode: export.transferCode,
        now: now.add(const Duration(minutes: 6)),
      );

      expect(decoded, isNull);
    });

    test('rejects legacy plaintext base64 payloads', () {
      final legacy = base64UrlEncode(
        utf8.encode(
          jsonEncode({'v': 1, 't': 'imap', 'password': 'secret-imap-password'}),
        ),
      );

      expect(isEncryptedQrTransfer(legacy), isFalse);
      expect(
        decodeQrTransferExport(legacy, transferCode: 'AAAA-BBBB-CCCC-DDDD'),
        isNull,
      );
    });
  });
}

ImapQrPayload _imapPayload() {
  return const ImapQrPayload(
    displayName: 'Work',
    email: 'person@example.com',
    server: 'imap.example.com',
    port: 993,
    username: 'person',
    password: 'secret-imap-password',
    useTls: true,
    smtpServer: 'smtp.example.com',
    smtpPort: 587,
    smtpUsername: 'person',
    smtpPassword: 'secret-smtp-password',
    smtpUseTls: true,
    smtpUseImapCredentials: false,
    checkMailIntervalMinutes: 10,
    crossFolderThreadingEnabled: true,
  );
}
