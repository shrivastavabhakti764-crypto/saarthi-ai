import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/notification_answers.dart';
import 'package:saarthi_ai/services/token_store.dart';

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

final _payload = jsonEncode({'reminder_id': 1, 'hm': '10:06'});

// 10:06:05 in India on 11 November 2026.
final _tap = DateTime.utc(2026, 11, 11, 4, 36, 5);

http.Response _slot() => http.Response(
      jsonEncode({
        'reminder_id': 1,
        'kind': 'medicine',
        'title': 'BP tablet',
        'dosage': '1 tablet',
        'scheduled_for': '2026-11-11T10:06:00+05:30',
        'status': 'taken',
        'responded_at': '2026-11-11T10:06:05+05:30',
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('a Taken button tells the server which slot was answered', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return _slot();
      }),
    );

    final sent = await sendNotificationAnswer(
      actionId: 'taken',
      payload: _payload,
      api: api,
      tokenStore: _MemoryTokenStore('abc123'),
      now: _tap,
    );

    expect(sent, isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/reminders/1/log');
    expect(requests.single.headers['Authorization'], 'Bearer abc123');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['status'], 'taken');
    expect(body['scheduled_for'], '2026-11-11T04:36:00.000Z');
  });

  test('tapping the notification itself sends nothing', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return _slot();
      }),
    );

    final sent = await sendNotificationAnswer(
      actionId: null,
      payload: _payload,
      api: api,
      tokenStore: _MemoryTokenStore('abc123'),
      now: _tap,
    );

    expect(sent, isFalse);
    expect(calls, 0);
  });

  test('without a saved login nothing is sent', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return _slot();
      }),
    );

    final sent = await sendNotificationAnswer(
      actionId: 'taken',
      payload: _payload,
      api: api,
      tokenStore: _MemoryTokenStore(),
      now: _tap,
    );

    expect(sent, isFalse);
    expect(calls, 0);
  });

  test('a server error is reported as not sent', () async {
    final api = ApiClient(
      client: MockClient((request) async => http.Response(
            jsonEncode({'detail': 'That is not a scheduled time for this reminder'}),
            400,
            headers: {'content-type': 'application/json'},
          )),
    );

    final sent = await sendNotificationAnswer(
      actionId: 'skipped',
      payload: _payload,
      api: api,
      tokenStore: _MemoryTokenStore('abc123'),
      now: _tap,
    );

    expect(sent, isFalse);
  });
}