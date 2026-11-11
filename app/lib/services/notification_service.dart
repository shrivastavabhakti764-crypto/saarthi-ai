import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import 'reminder_scheduler.dart';
import 'schedule_planner.dart';

/// Puts reminders on the Android alarm clock using flutter_local_notifications.
class NotificationService implements ReminderScheduler {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _android = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Medicine and appointment reminders',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const _details = NotificationDetails(android: _android);

  /// Call once at app start, before anything is scheduled.
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // The app is for India only, like the server's schedule.
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    await init();
    return await _androidPlugin?.requestNotificationsPermission() ?? false;
  }

  Future<bool> _canScheduleExact() async {
    try {
      return await _androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  AndroidScheduleMode _mode({required bool exact}) => exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  @override
  Future<void> sync(List<Reminder> reminders) async {
    await init();
    await _plugin.cancelAllPendingNotifications();
    final exact = await _canScheduleExact();
    final plan = planNotifications(reminders, DateTime.now().toUtc());
    for (final item in plan) {
      try {
        final DateTimeComponents? repeat = switch (item.repeat) {
          Repeat.once => null,
          Repeat.daily => DateTimeComponents.time,
          Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        };
        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          payload: item.payload,
          scheduledDate: tz.TZDateTime.from(item.at, tz.local),
          notificationDetails: _details,
          androidScheduleMode: _mode(exact: exact),
          matchDateTimeComponents: repeat,
        );
      } catch (e) {
        // One bad alarm must not stop the others.
        debugPrint('Could not schedule alarm ${item.id}: $e');
      }
    }
  }

  @override
  Future<void> clear() async {
    await init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> sendTest() async {
    await init();
    final exact = await _canScheduleExact();
    await _plugin.zonedSchedule(
      id: testNotificationId,
      title: 'Test reminder',
      body: 'If you can see this, your reminders will reach you.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: _details,
      androidScheduleMode: _mode(exact: exact),
    );
  }
}