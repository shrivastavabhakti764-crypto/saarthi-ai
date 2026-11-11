import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saarthi_ai/models/reminder.dart';
import 'package:saarthi_ai/services/schedule_planner.dart';

// 10:00 in the morning in India, on Monday 9 November 2026.
final now = DateTime.utc(2026, 11, 9, 4, 30);

Reminder _reminder({
  int id = 1,
  String kind = 'medicine',
  String title = 'BP tablet',
  String? dosage = '1 tablet',
  List<String> times = const ['08:00'],
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  DateTime? oneOffAt,
  bool isActive = true,
}) =>
    Reminder(
      id: id,
      seniorId: 1,
      kind: kind,
      title: title,
      dosage: dosage,
      times: times,
      days: days,
      oneOffAt: oneOffAt,
      isActive: isActive,
      createdAt: DateTime.utc(2026, 11, 1),
    );

void main() {
  test('an every-day medicine gets one daily alarm per time', () {
    final plan = planNotifications(
      [_reminder(times: const ['08:00', '20:00'])],
      now,
    );

    expect(plan, hasLength(2));
    // 08:00 has passed today, so the first ring is tomorrow morning.
    expect(plan[0].id, 1000);
    expect(plan[0].at, DateTime.utc(2026, 11, 10, 2, 30));
    expect(plan[0].repeat, Repeat.daily);
    expect(plan[0].title, 'Time for your medicine');
    expect(plan[0].body, 'BP tablet · 1 tablet');
    expect(jsonDecode(plan[0].payload), {'reminder_id': 1, 'hm': '08:00'});
    // 20:00 is still ahead today.
    expect(plan[1].id, 1010);
    expect(plan[1].at, DateTime.utc(2026, 11, 9, 14, 30));
  });

  test('chosen days get one weekly alarm per day', () {
    final plan = planNotifications(
      [_reminder(days: const [1, 3])],
      now,
    );

    expect(plan, hasLength(2));
    // Monday 08:00 passed today, so the next Monday; Wednesday is this week.
    expect(plan[0].id, 1001);
    expect(plan[0].at, DateTime.utc(2026, 11, 16, 2, 30));
    expect(plan[0].repeat, Repeat.weekly);
    expect(plan[1].id, 1003);
    expect(plan[1].at, DateTime.utc(2026, 11, 11, 2, 30));
  });

  test('a time later today rings today, and exactly now rings tomorrow', () {
    final later = planNotifications([_reminder(times: const ['10:30'])], now);
    final exactlyNow = planNotifications([_reminder(times: const ['10:00'])], now);

    expect(later.single.at, DateTime.utc(2026, 11, 9, 5, 0));
    expect(exactlyNow.single.at, DateTime.utc(2026, 11, 10, 4, 30));
  });

  test('a time just before midnight uses the Indian date, not the UTC date', () {
    // 00:30 in India on Tuesday 10 November.
    final justAfterMidnight = DateTime.utc(2026, 11, 9, 19, 0);

    expect(
      nextMoment(justAfterMidnight, '23:50'),
      DateTime.utc(2026, 11, 10, 18, 20),
    );
  });

  test('a paused reminder gets no alarms', () {
    expect(planNotifications([_reminder(isActive: false)], now), isEmpty);
  });

  test('an appointment rings once, and a past one is ignored', () {
    final future = now.add(const Duration(days: 2));
    final plan = planNotifications(
      [
        _reminder(
          id: 2,
          kind: 'appointment',
          title: 'Doctor visit',
          dosage: null,
          times: const [],
          oneOffAt: future,
        ),
        _reminder(
          id: 3,
          kind: 'appointment',
          title: 'Old visit',
          dosage: null,
          times: const [],
          oneOffAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
      now,
    );

    expect(plan, hasLength(1));
    expect(plan.single.id, 2999);
    expect(plan.single.title, 'Appointment');
    expect(plan.single.body, 'Doctor visit');
    expect(plan.single.at, future);
    expect(plan.single.repeat, Repeat.once);
  });

  test('every alarm gets its own id', () {
    final plan = planNotifications(
      [
        _reminder(id: 1, times: const ['08:00', '13:00', '20:00']),
        _reminder(id: 2, times: const ['09:00'], days: const [1, 2, 5]),
        _reminder(
          id: 3,
          kind: 'appointment',
          times: const [],
          oneOffAt: now.add(const Duration(days: 1)),
        ),
      ],
      now,
    );

    final ids = plan.map((n) => n.id).toSet();
    expect(plan, hasLength(3 + 3 + 1));
    expect(ids, hasLength(plan.length));
  });
}