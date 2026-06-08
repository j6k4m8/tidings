import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/state/tidings_settings.dart';

void main() {
  group('remote content allowlists', () {
    test('are normalized and scoped per account', () {
      final settings = TidingsSettings(persistEnabled: false);

      settings.allowRemoteContentSender(
        accountKey: 'Me@Example.COM',
        senderEmail: ' News@Example.com ',
      );
      settings.allowRemoteContentDomain(
        accountKey: 'Me@Example.COM',
        domain: 'HTTPS://IMG.Example.com./pixel.png',
      );

      expect(
        settings.isRemoteContentSenderAllowed(
          accountKey: 'me@example.com',
          senderEmail: 'news@example.com',
        ),
        isTrue,
      );
      expect(
        settings.isRemoteContentDomainAllowed(
          accountKey: 'me@example.com',
          domain: 'img.example.com',
        ),
        isTrue,
      );
      expect(settings.remoteContentAllowedDomains('ME@example.com'), {
        'img.example.com',
      });

      expect(
        settings.isRemoteContentSenderAllowed(
          accountKey: 'other@example.com',
          senderEmail: 'news@example.com',
        ),
        isFalse,
      );
      expect(
        settings.isRemoteContentDomainAllowed(
          accountKey: 'other@example.com',
          domain: 'img.example.com',
        ),
        isFalse,
      );
    });
  });
}
