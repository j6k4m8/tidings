String normalizeContactName(String raw) {
  var cleaned = raw.trim();
  if (cleaned.isEmpty) {
    return cleaned;
  }
  cleaned = cleaned.replaceAll(RegExp("[\"']"), '');
  if (cleaned.contains(',')) {
    final parts = cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      cleaned = '${parts.sublist(1).join(' ')} ${parts.first}'.trim();
    }
  }
  return cleaned.replaceAll(RegExp(r'\s+'), ' ');
}

String avatarInitial(String raw) {
  final cleaned = normalizeContactName(raw);
  if (cleaned.isEmpty) {
    return '?';
  }
  final parts = cleaned.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    final first = parts.first;
    final second = parts[1];
    return '${first.substring(0, 1)}${second.substring(0, 1)}'.toUpperCase();
  }
  return cleaned.substring(0, 1).toUpperCase();
}
