import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/models/reminder.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/auth_provider.dart';
import 'package:saarthi_ai/services/reminder_scheduler.dart';
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

/// Remembers what the provider asked the phone to do.
class _FakeScheduler implements ReminderScheduler {
  final synced = <List<Reminder>>[];
  int clears = 0;
  int permissionAsks = 0;

  @override
  Future<void> sync(List<Reminder> reminders) async => synced.add(reminders);

  @override
  Future<void> clear() async => clears++;

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return true;
  }

  @override
  Future<void> sendTest() async {}
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

MockClient _backend(String role) => MockClient((request) async {
      switch ('${request.method} ${request.url.path}') {
        case 'POST /auth/login':
          return _json({
            'access_token': 'abc123',
            'token_type': 'bearer',
            'user': {
              'id': role == 'senior' ? 1 : 2,
              'name': 'Asha',
              'phone': '+919876543210',
              'role': role,
              'consent_accepted_at': '2026-11-06T12:00:00+05:30',
              'created_at': '2026-11-05T11:29:11+05:30',
            },
          });
        case 'GET /reminders':
          return _json([
            {
              'id': 1,
              'senior_id': 1,
              'kind': 'medicine',
              'title': 'BP tablet',
              'dosage': '1 tablet',
              'reminder_times': ['08:00:00'],
              'days_of_week': [1, 2, 3, 4, 5, 6, 7],
              'one_off_at': null,
              'is_active': true,
              'created_at': '2026-11-09T10:00:00+05:30',
            },
          ]);
        case 'GET /reminders/today':
          return _json([]);
        case 'DELETE /reminders/1':
          return http.Response('', 204);
      }
      return http.Response('not found', 404);
    });

Future<({AuthProvider auth, RemindersProvider reminders, _FakeScheduler scheduler})>
    _setup(String role) async {
  final api = ApiClient(client: _backend(role));
  final auth = AuthProvider(api: api, tokenStore: _MemoryTokenStore());
  await auth.login(phone: '9876543210', pin: '1234');
  final scheduler = _FakeScheduler();
  return (
    auth: auth,
    reminders: RemindersProvider(api: api, auth: auth, scheduler: scheduler),
    scheduler: scheduler,
  );
}

void main() {
  test('a senior load sets the alarms and asks for permission once', () async {
    final s = await _setup('senior');

    await s.reminders.load();
    await s.reminders.load();

    expect(s.scheduler.synced, hasLength(2));
    expect(s.scheduler.synced.first.single.title, 'BP tablet');
    expect(s.scheduler.permissionAsks, 1);
  });

  test('a nominee load never touches the alarms', () async {
    final s = await _setup('nominee');

    await s.reminders.load(seniorId: 1);

    expect(s.scheduler.synced, isEmpty);
    expect(s.scheduler.permissionAsks, 0);
  });

  test('deleting a reminder sets the alarms again', () async {
    final s = await _setup('senior');
    await s.reminders.load();

    await s.reminders.delete(1);

    expect(s.scheduler.synced, hasLength(2));
    expect(s.scheduler.synced.last, isEmpty);
  });

  test('logging out removes the alarms', () async {
    final s = await _setup('senior');
    await s.reminders.load();

    await s.auth.logout();

    expect(s.scheduler.clears, 1);
  });

  test('an unreachable server at app start keeps the alarms', () async {
    final store = _MemoryTokenStore()..token = 'saved-token';
    final api = ApiClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final auth = AuthProvider(api: api, tokenStore: store);
    final scheduler = _FakeScheduler();
    RemindersProvider(api: api, auth: auth, scheduler: scheduler);

    await auth.restoreSession();

    expect(auth.isLoggedIn, isFalse);
    expect(scheduler.clears, 0);
  });
}