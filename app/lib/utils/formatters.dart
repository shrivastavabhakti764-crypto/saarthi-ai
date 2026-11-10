import 'package:flutter/material.dart';

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "08:30" -> TimeOfDay(8, 30)
TimeOfDay parseHm(String hm) {
  final parts = hm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// TimeOfDay(8, 30) -> "08:30"
String toHm(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// "20:00" -> "8:00 PM" (in the phone's own style)
String formatHm(BuildContext context, String hm) =>
    parseHm(hm).format(context);

/// "Mon 9 Nov"
String formatDay(DateTime date) =>
    '${weekdayNames[date.weekday - 1]} ${date.day} ${_monthNames[date.month - 1]}';

/// "Mon 9 Nov, 3:30 PM"
String formatDateTime(BuildContext context, DateTime moment) {
  final local = moment.toLocal();
  return '${formatDay(local)}, ${TimeOfDay.fromDateTime(local).format(context)}';
}

/// [1,2,3,4,5,6,7] -> "Every day", [1,3] -> "Mon, Wed"
String formatDays(List<int> days) {
  final sorted = [...days]..sort();
  if (sorted.length == 7) return 'Every day';
  return sorted.map((d) => weekdayNames[d - 1]).join(', ');
}