/// Returns a short quoted label for [subject], truncated to [maxLen] chars.
/// Used in toast messages like `Archived "My Subject…"`.
String subjectLabel(String subject, {int maxLen = 30}) {
  final s = subject.trim();
  if (s.isEmpty) return '"(No subject)"';
  return s.length <= maxLen ? '"$s"' : '"${s.substring(0, maxLen)}…"';
}
