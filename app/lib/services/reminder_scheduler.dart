import '../models/reminder.dart';

/// Whatever puts reminders on the phone's alarm clock. The real one is
/// [NotificationService]; tests use a fake.
abstract class ReminderScheduler {
  /// Replaces every alarm with the ones for these reminders.
  Future<void> sync(List<Reminder> reminders);

  /// Removes every alarm and every shown notification.
  Future<void> clear();

  Future<bool> requestPermission();

  Future<void> sendTest();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> sync(List<Reminder> reminders) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sendTest() async {}
}