bool fuzzyMatch(String query, String text) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return true;
  }
  final haystack = text.toLowerCase();
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.every((part) => haystack.contains(part));
}
