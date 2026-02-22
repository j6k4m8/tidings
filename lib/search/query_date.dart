/// Parses date expressions into [DateTime] values.
///
/// Supported formats:
///   Short codes : 1d  2w  3mo  1y  (days / weeks / months / years ago)
///   Natural     : today, yesterday, last week, last month, last year,
///                 this week, this month, this year
///   ISO date    : yyyy-mm-dd
///
/// Returns null if the expression is not recognised.
DateTime? parseQueryDate(String raw) {
  final s = raw.trim().toLowerCase();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // ── Natural language ─────────────────────────────────────────────────────
  switch (s) {
    case 'today':
      return today;
    case 'yesterday':
      return today.subtract(const Duration(days: 1));
    case 'last week':
    case 'lastweek':
      return today.subtract(const Duration(days: 7));
    case 'this week':
    case 'thisweek':
      return today.subtract(Duration(days: today.weekday - 1));
    case 'last month':
    case 'lastmonth':
      return DateTime(now.year, now.month - 1, now.day);
    case 'this month':
    case 'thismonth':
      return DateTime(now.year, now.month, 1);
    case 'last year':
    case 'lastyear':
      return DateTime(now.year - 1, now.month, now.day);
    case 'this year':
    case 'thisyear':
      return DateTime(now.year, 1, 1);
  }

  // ── Short codes (e.g. 2w, 3mo, 1y, 7d) ──────────────────────────────────
  final shortCode = RegExp(r'^(\d+)(d|w|mo|m|y)$').firstMatch(s);
  if (shortCode != null) {
    final n = int.parse(shortCode.group(1)!);
    final unit = shortCode.group(2)!;
    return switch (unit) {
      'd' => today.subtract(Duration(days: n)),
      'w' => today.subtract(Duration(days: n * 7)),
      'mo' || 'm' => DateTime(now.year, now.month - n, now.day),
      'y' => DateTime(now.year - n, now.month, now.day),
      _ => null,
    };
  }

  // ── ISO 8601 date (yyyy-mm-dd) ────────────────────────────────────────────
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  return null;
}
