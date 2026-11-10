/// A medicine or appointment reminder as the server stores it.
class Reminder {
  const Reminder({
    required this.id,
    required this.seniorId,
    required this.kind,
    required this.title,
    required this.times,
    required this.days,
    required this.isActive,
    required this.createdAt,
    this.dosage,
    this.oneOffAt,
  });

  final int id;
  final int seniorId;

  /// 'medicine' or 'appointment'.
  final String kind;
  final String title;
  final String? dosage;

  /// Daily times as "HH:mm" (medicine only).
  final List<String> times;

  /// 1 = Monday ... 7 = Sunday (medicine only).
  final List<int> days;

  /// The one date and time of an appointment.
  final DateTime? oneOffAt;
  final bool isActive;
  final DateTime createdAt;

  bool get isMedicine => kind == 'medicine';

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final oneOff = json['one_off_at'] as String?;
    return Reminder(
      id: json['id'] as int,
      seniorId: json['senior_id'] as int,
      kind: json['kind'] as String,
      title: json['title'] as String,
      dosage: json['dosage'] as String?,
      // The server sends "08:00:00"; the app works with "08:00".
      times: (json['reminder_times'] as List<dynamic>)
          .map((t) => (t as String).substring(0, 5))
          .toList(),
      days: (json['days_of_week'] as List<dynamic>)
          .map((d) => d as int)
          .toList(),
      oneOffAt: oneOff == null ? null : DateTime.parse(oneOff),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// What the add/edit form sends to the server.
class ReminderDraft {
  const ReminderDraft({
    required this.kind,
    required this.title,
    this.dosage,
    this.times = const [],
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.oneOffAt,
    this.isActive = true,
  });

  /// Starts an edit form from an existing reminder.
  factory ReminderDraft.fromReminder(Reminder reminder) {
    return ReminderDraft(
      kind: reminder.kind,
      title: reminder.title,
      dosage: reminder.dosage,
      times: reminder.times,
      days: reminder.days,
      oneOffAt: reminder.oneOffAt,
      isActive: reminder.isActive,
    );
  }

  final String kind;
  final String title;
  final String? dosage;
  final List<String> times;
  final List<int> days;
  final DateTime? oneOffAt;
  final bool isActive;

  Map<String, Object?> toJson({int? seniorId}) => {
        'kind': kind,
        'title': title,
        'dosage': dosage,
        'reminder_times': times,
        'days_of_week': days,
        'one_off_at': oneOffAt?.toUtc().toIso8601String(),
        'is_active': isActive,
        'senior_id': ?seniorId,
      };
}

/// One moment on today's schedule, with what the senior answered.
class TodaySlot {
  const TodaySlot({
    required this.reminderId,
    required this.kind,
    required this.title,
    required this.scheduledFor,
    required this.status,
    this.dosage,
    this.respondedAt,
  });

  final int reminderId;
  final String kind;
  final String title;
  final String? dosage;
  final DateTime scheduledFor;

  /// 'pending', 'taken', 'skipped' or 'missed'.
  final String status;
  final DateTime? respondedAt;

  bool get isPending => status == 'pending';

  factory TodaySlot.fromJson(Map<String, dynamic> json) {
    final responded = json['responded_at'] as String?;
    return TodaySlot(
      reminderId: json['reminder_id'] as int,
      kind: json['kind'] as String,
      title: json['title'] as String,
      dosage: json['dosage'] as String?,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String).toLocal(),
      status: json['status'] as String,
      respondedAt: responded == null ? null : DateTime.parse(responded).toLocal(),
    );
  }
}