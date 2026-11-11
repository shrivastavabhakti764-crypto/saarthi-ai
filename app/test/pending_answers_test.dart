import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/notification_answers.dart';
import 'package:saarthi_ai/services/pending_answers.dart';
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

class _MemoryPendingStore implements PendingAnswerStore {
  final items = <PendingAnswer>[];

  @override
  Future<List<PendingAnswer>> all() async => [...items];

  @override
  Future<void> add(PendingAnswer answer) async {
    items.removeWhere((a) => a.sameSlot(answer));
    items.add(answer);
  }

  @override
  Future<void> remove(PendingAnswer answer) async {
    items.removeWhere((a) => a.sameSlot(answer));
  }
}

PendingAnswer _answer(int reminderId, String status, {int minute = 36}) =>
    PendingAnswer(
      reminderId: reminderId,
      scheduledFor: DateTime.utc(2026, 11, 11, 4, minute),
      status: status,
    );

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

http.Response _error(int status) => http.Response(
      jsonEncode({'detail': 'No'}),
      status,
      headers: {'content-type': 'application/json'},
    );

ApiClient _apiReplying(Future<http.Response> Function(int call) reply) {
  var call = 0;
  return ApiClient(client: MockClient((request) => reply(call++)));
}

void main() {
  test('a pending answer survives the JSON round trip', () {
    final original = _answer(7, 'skipped');

    final copy = PendingAnswer.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(copy.reminderId, 7);
    expect(copy.status, 'skipped');
    expect(copy.scheduledFor, original.scheduledFor);
  });

  test('the same slot answered twice keeps only the latest answer', () async {
    final store = _MemoryPendingStore();

    await store.add(_answer(1, 'skipped'));
    await store.add(_answer(1, 'taken'));

    expect(store.items, hasLength(1));
    expect(store.items.single.status, 'taken');
  });

  test('a button pressed while offline keeps the answer for later', () async {
    final store = _MemoryPendingStore();
    final api = _apiReplying((_) async => throw http.ClientException('offline'));

    final sent = await sendNotificationAnswer(
      actionId: 'taken',
      payload: _payload,
      api: api,
      tokenStore: _MemoryTokenStore('abc123'),
      pending: store,
      now: _tap,
    );

    expect(sent, isFalse);
    expect(store.items, hasLength(1));
    expect(store.items.single.reminderId, 1);
    expect(store.items.single.status, 'taken');
    expect(store.items.single.scheduledFor, DateTime.utc(2026, 11, 11, 4, 36));
  });

  test('a server error is kept, but a refusal is not', () async {
    final store = _MemoryPendingStore();

    await sendNotificationAnswer(
      actionId: 'taken',
      payload: _payload,
      api: _apiReplying((_) async => _error(503)),
      tokenStore: _MemoryTokenStore('abc123'),
      pending: store,
      now: _tap,
    );
    expect(store.items, hasLength(1));

    store.items.clear();
    await sendNotificationAnswer(
      actionId: 'taken',
      payload: _payload,
      api: _apiReplying((_) async => _error(400)),
      tokenStore: _MemoryTokenStore('abc123'),
      pending: store,
      now: _tap,
    );
    expect(store.items, isEmpty);
  });

  test('flushing sends every kept answer and empties the queue', () async {
    final store = _MemoryPendingStore()
      ..items.addAll([_answer(1, 'taken'), _answer(2, 'skipped', minute: 40)]);

    final sent = await flushPendingAnswers(
      api: _apiReplying((_) async => _slot()),
      tokenStore: _MemoryTokenStore('abc123'),
      pending: store,
    );

    expect(sent, 2);
    expect(store.items, isEmpty);
  });

  test('flushing stops at the first failure and keeps the rest', () async {
    final store = _MemoryPendingStore()
      ..items.addAll([
        _answer(1, 'taken'),
        _answer(2, 'taken', minute: 40),
        _answer(3, 'taken', minute: 45),
      ]);

    final sent = await flushPendingAnswers(
      api: _apiReplying((call) async {
        if (call == 0) return _slot();
        throw http.ClientException('offline');
      }),
      tokenStore: _MemoryTokenStore('abc123'),
      pending: store,
    );

    expect(sent, 1);
    expect(store.items.map((a) => a.reminderId), [2, 3]);
  });

  test('flushing drops an answer the server refuses and goes on', () async {
    final store = _MemoryPendingStore()
      ..items.addAll([_answer(1, 'taken'), _answer(2, 'taken', minute: 40)]);

    final sent = await flushPendingAnswers(
      api: _apiReplying((call) async => call == 0 ? _error(404) : _slot()),
      tokenStore: _MemoryTokenStore('abc123'),
      pending: store,
    );

    expect(sent, 1);
    expect(store.items, isEmpty);
  });

  test('without a saved login flushing sends nothing and keeps the answers',
      () async {
    final store = _MemoryPendingStore()..items.add(_answer(1, 'taken'));
    var calls = 0;

    final sent = await flushPendingAnswers(
      api: _apiReplying((_) async {
        calls++;
        return _slot();
      }),
      tokenStore: _MemoryTokenStore(),
      pending: store,
    );

    expect(sent, 0);
    expect(calls, 0);
    expect(store.items, hasLength(1));
  });
}