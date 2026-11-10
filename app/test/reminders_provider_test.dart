import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/models/reminder.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/auth_provider.dart';
import 'package:saarthi_ai/services/reminders_provider.dart';
import 'package:saarthi_ai/services/token_store.dart';

class _MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> _userJson(String role) => {
      'id': role == 'senior' ? 1 : 2,
      'name': role == 'senior' ? 'Asha' : 'Rohan',
      'phone': '+919876543210',
      'role': role,
      'consent_accepted_at': '2026-11-06T12:00:00+05:30',
      'created_at': '2026-11-05T11:29:11+05:30',
    };

Map<String, Object?> _reminderJson({String title = 'BP tablet'}) => {
      'id': 1,
      'senior_id': 1,
      'kind': 'medicine',
      'title': title,
      'dosage': '1 tablet',
      'reminder_times': ['08:00:00', '20:00:00'],
      'days_of_week': [1, 2, 3, 4, 5, 6, 7],
      'one_off_at': null,
      'is_active': true,
      'created_at': '2026-11-09T10:00:00+05:30',
    };

Map<String, Object?> _slotJson(String status) => {
      'reminder_id': 1,
      'kind': 'medicine',
      'title': 'BP tablet',
      'dosage': '1 tablet',
      'scheduled_for': '2026-11-09T08:00:00+05:30',
      'status': status,
      'responded_at': status == 'pending' ? null : '2026-11-09T08:05:00+05:30',
    };

/// A tiny fake backend that remembers every request it receives.
class _FakeBackend {
  _FakeBackend({required this.role, this.failList = false});

  final String role;
  final bool failList;
  final requests = <http.Request>[];

  Map<String, dynamic> bodyOf(String route) {
    final request =
        requests.lastWhere((r) => '${r.method} ${r.url.path}' == route);
    return jsonDecode(request.body) as Map<String, dynamic>;
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final route = '${request.method} ${request.url.path}';
    if (route == 'POST /auth/login') {
      return _json({
        'access_token': 'abc123',
        'token_type': 'bearer',
        'user': _userJson(role),
      });
    }
    if (request.headers['Authorization'] != 'Bearer abc123') {
      return _json({'detail': 'Invalid or missing token'}, 401);
    }
    switch (route) {
      case 'POST /reminders':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({
          'id': 7,
          'senior_id': body['senior_id'] ?? 1,
          'kind': body['kind'],
          'title': body['title'],
          'dosage': body['dosage'],
          'reminder_times':
              (body['reminder_times'] as List).map((t) => '$t:00').toList(),
          'days_of_week': body['days_of_week'],
          'one_off_at': body['one_off_at'],
          'is_active': body['is_active'],
          'created_at': '2026-11-09T10:00:00+05:30',
        }, 201);
      case 'GET /reminders':
        if (failList) return http.Response('boom', 500);
        return _json([_reminderJson()]);
      case 'PUT /reminders/1':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(_reminderJson(title: body['title'] as String));
      case 'DELETE /reminders/1':
        return http.Response('', 204);
      case 'GET /reminders/today':
        return _json([_slotJson('pending')]);
      case 'POST /reminders/1/log':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(_slotJson(body['status'] as String));
    }
    return http.Response('not found', 404);
  }
}

Future<({AuthProvider auth, RemindersProvider reminders, _FakeBackend backend})>
    _setup({String role = 'senior', bool failList = false}) async {
  final backend = _FakeBackend(role: role, failList: failList);
  final api = ApiClient(client: MockClient(backend.handle));
  final auth = AuthProvider(api: api, tokenStore: _MemoryTokenStore());
  await auth.login(phone: '9876543210', pin: '1234');
  return (
    auth: auth,
    reminders: RemindersProvider(api: api, auth: auth),
    backend: backend,
  );
}

void main() {
  test('create sends clean times and keeps the new reminder', () async {
    final s = await _setup();

    final reminder = await s.reminders.create(
      const ReminderDraft(
        kind: 'medicine',
        title: 'BP tablet',
        dosage: '1 tablet',
        times: ['08:00', '20:00'],
      ),
    );

    final body = s.backend.bodyOf('POST /reminders');
    expect(body['reminder_times'], ['08:00', '20:00']);
    expect(body['days_of_week'], [1, 2, 3, 4, 5, 6, 7]);
    expect(body.containsKey('senior_id'), isFalse);
    expect(reminder.times, ['08:00', '20:00']);
    expect(s.reminders.reminders, hasLength(1));
  });

  test('a nominee names the senior the reminder is for', () async {
    final s = await _setup(role: 'nominee');

    await s.reminders.create(
      const ReminderDraft(kind: 'medicine', title: 'BP tablet', times: ['08:00']),
      seniorId: 5,
    );

    expect(s.backend.bodyOf('POST /reminders')['senior_id'], 5);
  });

  test('an appointment is sent as one UTC moment and no daily times', () async {
    final s = await _setup();

    await s.reminders.create(
      ReminderDraft(
        kind: 'appointment',
        title: 'Doctor visit',
        oneOffAt: DateTime.utc(2026, 11, 12, 9, 30),
      ),
    );

    final body = s.backend.bodyOf('POST /reminders');
    expect(body['kind'], 'appointment');
    expect(body['one_off_at'], '2026-11-12T09:30:00.000Z');
    expect(body['reminder_times'], isEmpty);
  });

  test('a senior load fills the reminders and today\'s schedule', () async {
    final s = await _setup();

    await s.reminders.load();

    expect(s.reminders.reminders.single.times, ['08:00', '20:00']);
    expect(s.reminders.reminders.single.days, hasLength(7));
    expect(s.reminders.today.single.title, 'BP tablet');
    expect(s.reminders.today.single.status, 'pending');
    expect(s.reminders.loading, isFalse);
    expect(s.reminders.error, isNull);
  });

  test('a nominee load picks one senior and skips the daily schedule', () async {
    final s = await _setup(role: 'nominee');

    await s.reminders.load(seniorId: 5);

    final listRequest =
        s.backend.requests.lastWhere((r) => r.url.path == '/reminders');
    expect(listRequest.url.queryParameters['senior_id'], '5');
    expect(
      s.backend.requests.any((r) => r.url.path == '/reminders/today'),
      isFalse,
    );
    expect(s.reminders.reminders, hasLength(1));
    expect(s.reminders.today, isEmpty);
  });

  test('update replaces the reminder in the list', () async {
    final s = await _setup();
    await s.reminders.load();

    await s.reminders.update(
      1,
      const ReminderDraft(kind: 'medicine', title: 'Sugar tablet', times: ['09:00']),
    );

    expect(s.reminders.reminders.single.title, 'Sugar tablet');
  });

  test('delete removes the reminder from the list', () async {
    final s = await _setup();
    await s.reminders.load();

    await s.reminders.delete(1);

    expect(s.reminders.reminders, isEmpty);
  });

  test('marking a slot as taken updates it and tells the server', () async {
    final s = await _setup();
    await s.reminders.load();
    final slot = s.reminders.today.single;

    await s.reminders.logSlot(
      reminderId: slot.reminderId,
      scheduledFor: slot.scheduledFor,
      status: 'taken',
    );

    final body = s.backend.bodyOf('POST /reminders/1/log');
    expect(body['status'], 'taken');
    expect(body['scheduled_for'], '2026-11-09T02:30:00.000Z');
    expect(s.reminders.today.single.status, 'taken');
    expect(s.reminders.today.single.respondedAt, isNotNull);
  });

  test('a failed load keeps a friendly error', () async {
    final s = await _setup(failList: true);

    await s.reminders.load();

    expect(s.reminders.error, 'Something went wrong (code 500). Please try again.');
    expect(s.reminders.reminders, isEmpty);
    expect(s.reminders.loading, isFalse);
  });

  test('logging out clears the reminders and the schedule', () async {
    final s = await _setup();
    await s.reminders.load();

    await s.auth.logout();

    expect(s.reminders.reminders, isEmpty);
    expect(s.reminders.today, isEmpty);
  });
}