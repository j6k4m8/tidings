import 'package:flutter_test/flutter_test.dart';
import 'package:tidings/utils/subject_utils.dart';

void main() {
  group('subjectsMatch', () {
    test('ignores reply/forward prefixes', () {
      expect(subjectsMatch('How to version', 'Re: How to version'), isTrue);
      expect(subjectsMatch('Fwd: Hello', 'Hello'), isTrue);
      expect(subjectsMatch('Re: Re: Status', 'Status'), isTrue);
    });

    test('ignores case and surrounding whitespace', () {
      expect(subjectsMatch('RE:  the   plan ', 'The Plan'), isTrue);
    });

    test('treats genuinely different subjects as non-matching', () {
      expect(subjectsMatch('How to version', 'Release notes'), isFalse);
      expect(subjectsMatch('Re: Budget', 'Re: Schedule'), isFalse);
    });
  });
}
