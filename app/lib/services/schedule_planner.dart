import 'dart:convert';

import '../models/reminder.dart';

enum Repeat { once, daily, weekly }

/// One alarm the phone should hold.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.at,
    required this.repeat,
  });

  final int id;
  final String title;
  final String body;

  /// Says which reminder this alarm belongs to (JSON text).
  final String payload;

  /// The first moment it should ring (a UTC time).
  final DateTime at;
  final Repeat repeat;
}

const _ist = Duration(hours: 5, minutes: 30);

/// Used by the "Send a test reminder" button.
const testNotificationId = 2000000000;

/// A medicine alarm: reminderId * 1000 + timeIndex * 10 + dayCode,
/// where dayCode is 0 for every day or 1 (Monday) to 7 (Sunday).
int notificationId(int reminderId, int timeIndex, int dayCode) =>
    reminderId * 1000 + timeIndex * 10 + dayCode;

/// The next moment (UTC) after [now] when the Indian clock shows [hm]
/// ("HH:mm"), only on [isoWeekday] if one is given (1 = Monday).
DateTime nextMoment(DateTime now, String hm, {int? isoWeekday}) {
  final parts = hm.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  // A UTC-flagged DateTime that holds the Indian wall-clock time.
  final nowIst = now.toUtc().add(_ist);
  final today = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, hour, minute);
  for (var i = 0; i <= 7; i++) {
    final candidate = today.add(Duration(days: i));
    if (isoWeekday != null && candidate.weekday != isoWeekday) continue;
    if (candidate.isAfter(nowIst)) return candidate.subtract(_ist);
  }
  throw StateError('No next moment found for $hm');
}

/// Works out every alarm for these reminders. Paused reminders and past
/// appointments get none.
List<PlannedNotification> planNotifications(
  List<Reminder> reminders,
  DateTime now,
) {
  final plan = <PlannedNotification>[];
  for (final reminder in reminders) {
    if (!reminder.isActive) continue;

    if (reminder.isMedicine) {
      final dosage = reminder.dosage;
      final body = dosage == null ? reminder.title : '${reminder.title} · $dosage';
      final everyDay = reminder.days.toSet().length == 7;
      for (var i = 0; i < reminder.times.length; i++) {
        final hm = reminder.times[i];
        final payload = jsonEncode({'reminder_id': reminder.id, 'hm': hm});
        if (everyDay) {
          plan.add(PlannedNotification(
            id: notificationId(reminder.id, i, 0),
            title: 'Time for your medicine',
            body: body,
            payload: payload,
            at: nextMoment(now, hm),
            repeat: Repeat.daily,
          ));
        } else {
          for (final day in reminder.days) {
            plan.add(PlannedNotification(
              id: notificationId(reminder.id, i, day),
              title: 'Time for your medicine',
              body: body,
              payload: payload,
              at: nextMoment(now, hm, isoWeekday: day),
              repeat: Repeat.weekly,
            ));
          }
        }
      }
    } else {
      final at = reminder.oneOffAt;
      if (at == null || !at.isAfter(now)) continue;
      plan.add(PlannedNotification(
        id: reminder.id * 1000 + 999,
        title: 'Appointment',
        body: reminder.title,
        payload: jsonEncode({
          'reminder_id': reminder.id,
          'at': at.toUtc().toIso8601String(),
        }),
        at: at.toUtc(),
        repeat: Repeat.once,
      ));
    }
  }
  return plan;
}