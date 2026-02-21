import '../state/tidings_settings.dart';

/// Formats a message timestamp for display in the UI.
///
/// Rules (all relative to the user's local wall clock):
///   - Since midnight today  →  "3:42 PM"  /  "15:42"
///   - Yesterday             →  "Yesterday 3:42 PM"
///   - This calendar year    →  "Feb 20 3:42 PM"
///   - Older                 →  "Feb 20 2025 3:42 PM"
///
/// [dateOrder] controls how the month/day/year are arranged.
/// [use24h] switches between 12-hour AM/PM and 24-hour clock.
String formatEmailTime(
  DateTime dt, {
  DateOrder dateOrder = DateOrder.mdy,
  bool use24h = false,
}) {
  final now = DateTime.now();
  final local = dt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(local.year, local.month, local.day);

  final timePart = _formatTimePart(local, use24h: use24h);

  if (msgDay == today) {
    return timePart;
  }

  final yesterday = today.subtract(const Duration(days: 1));
  if (msgDay == yesterday) {
    return 'Yesterday $timePart';
  }

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final mon = months[local.month - 1];
  final day = local.day.toString();

  if (local.year == now.year) {
    final datePart = _formatDatePart(
      dateOrder: dateOrder,
      month: mon,
      day: day,
      year: null,
    );
    return '$datePart $timePart';
  }

  final datePart = _formatDatePart(
    dateOrder: dateOrder,
    month: mon,
    day: day,
    year: '${local.year}',
  );
  return '$datePart $timePart';
}

String _formatTimePart(DateTime local, {required bool use24h}) {
  if (use24h) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}

/// Builds the date portion according to [dateOrder].
/// [year] is null when the message is from the current year.
String _formatDatePart({
  required DateOrder dateOrder,
  required String month,
  required String day,
  required String? year,
}) {
  switch (dateOrder) {
    case DateOrder.mdy:
      return year == null ? '$month $day' : '$month $day $year';
    case DateOrder.dmy:
      return year == null ? '$day $month' : '$day $month $year';
    case DateOrder.ymd:
      return year == null ? '$month $day' : '$year $month $day';
  }
}
