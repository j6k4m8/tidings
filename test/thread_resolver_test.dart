import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/providers/thread_resolver.dart';

void main() {
  group('ThreadResolver', () {
    test('unrelated messages sharing a subject are NOT threaded together', () {
      final r = ThreadResolver();
      final a = r.resolve(subject: 'Fwd: lunch?', messageId: '<a@x>');
      final b = r.resolve(subject: 'Fwd: lunch?', messageId: '<b@y>');
      expect(a, isNot(b));
    });

    test('a reply joins its parent via In-Reply-To', () {
      final r = ThreadResolver();
      final parent = r.resolve(subject: 'Plan', messageId: '<p@x>');
      final reply = r.resolve(
        subject: 'Re: Plan',
        messageId: '<r@x>',
        inReplyTo: '<p@x>',
      );
      expect(reply, parent);
    });

    test('a reply chain stays in one thread (in order)', () {
      final r = ThreadResolver();
      final a = r.resolve(subject: 'Plan', messageId: '<a@x>');
      final b = r.resolve(
        subject: 'Re: Plan',
        messageId: '<b@x>',
        inReplyTo: '<a@x>',
      );
      final c = r.resolve(
        subject: 'Re: Plan',
        messageId: '<c@x>',
        inReplyTo: '<b@x>',
      );
      expect(b, a);
      expect(c, a);
    });

    test('a reply chain links up even when fetched out of order', () {
      final r = ThreadResolver();
      // Newest first: C (replies B), then B (replies A), then A.
      final c = r.resolve(
        subject: 'Re: Plan',
        messageId: '<c@x>',
        inReplyTo: '<b@x>',
      );
      final b = r.resolve(
        subject: 'Re: Plan',
        messageId: '<b@x>',
        inReplyTo: '<a@x>',
      );
      final a = r.resolve(subject: 'Plan', messageId: '<a@x>');
      expect(b, c);
      expect(a, c);
    });

    test('resolution is stable across repeated calls', () {
      final r = ThreadResolver();
      final first = r.resolve(subject: 'Hi', messageId: '<m@x>');
      final second = r.resolve(subject: 'Hi', messageId: '<m@x>');
      expect(second, first);
    });

    test('falls back to subject only when there is no Message-ID', () {
      final r = ThreadResolver();
      final a = r.resolve(subject: 'Re: status');
      final b = r.resolve(subject: 'status');
      // No Message-IDs at all → last-resort subject grouping (prefix-insensitive).
      expect(a, b);
    });
  });
}
