/// Returns a short quoted label for [subject], truncated to [maxLen] chars.
/// Used in toast messages like `Archived "My Subject…"`.
String subjectLabel(String subject, {int maxLen = 30}) {
  final s = subject.trim();
  if (s.isEmpty) return '"(No subject)"';
  return s.length <= maxLen ? '"$s"' : '"${s.substring(0, maxLen)}…"';
}

final _replyPrefix = RegExp(r'^(re|fwd|fw)\s*:\s*', caseSensitive: false);

/// Normalizes a subject for comparison: strips leading reply/forward prefixes
/// (`Re:`, `Fwd:`, `Fw:`, possibly repeated), collapses whitespace, lowercases.
String normalizeSubject(String subject) {
  var s = subject.trim();
  while (_replyPrefix.hasMatch(s)) {
    s = s.replaceFirst(_replyPrefix, '');
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

/// Whether two subjects refer to the same conversation subject, ignoring
/// reply/forward prefixes, case, and whitespace.
bool subjectsMatch(String a, String b) =>
    normalizeSubject(a) == normalizeSubject(b);
