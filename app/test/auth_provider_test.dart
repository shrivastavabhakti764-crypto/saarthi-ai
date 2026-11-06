import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/auth_provider.dart';
import 'package:saarthi_ai/services/token_store.dart';

class FakeTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

const _userJson = {
  'id': 1,
  'name': 'Test Senior',
  'phone': '+919876543210',
  'role': 'senior',
  'consent_accepted_at': null,
  'created_at': '2026-11-05T11:29:11+05:30',
};

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

AuthProvider _providerWith(MockClient client, FakeTokenStore store) =>
    AuthProvider(api: ApiClient(client: client), tokenStore: store);

void main() {
  test('register saves the token and sets the user', () async {
    final store = FakeTokenStore();
    final auth = _providerWith(
      MockClient((request) async {
        expect(request.url.path, '/auth/register');
        return _json({
          'access_token': 'abc123',
          'token_type': 'bearer',
          'user': _userJson,
        }, 201);
      }),
      store,
    );

    await auth.register(
      name: 'Test Senior',
      phone: '9876543210',
      pin: '1234',
      role: 'senior',
    );

    expect(auth.isLoggedIn, isTrue);
    expect(auth.user!.name, 'Test Senior');
    expect(auth.user!.isSenior, isTrue);
    expect(store.token, 'abc123');
  });

  test('wrong PIN shows the server message and saves nothing', () async {
    final store = FakeTokenStore();
    final auth = _providerWith(
      MockClient((_) async =>
          _json({'detail': 'Incorrect phone number or PIN'}, 401)),
      store,
    );

    await expectLater(
      auth.login(phone: '9876543210', pin: '9999'),
      throwsA(isA<ApiException>().having(
        (e) => e.message,
        'message',
        'Incorrect phone number or PIN',
      )),
    );
    expect(auth.isLoggedIn, isFalse);
    expect(store.token, isNull);
  });

  test('server unreachable gives a friendly message', () async {
    final auth = _providerWith(
      MockClient((_) async => throw http.ClientException('boom')),
      FakeTokenStore(),
    );

    await expectLater(
      auth.login(phone: '9876543210', pin: '1234'),
      throwsA(isA<ApiException>().having(
        (e) => e.message,
        'message',
        'Cannot reach the server. Check your connection.',
      )),
    );
  });

  test('restoreSession logs in with a saved valid token', () async {
    final store = FakeTokenStore()..token = 'abc123';
    final auth = _providerWith(
      MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer abc123');
        return _json(_userJson, 200);
      }),
      store,
    );

    await auth.restoreSession();

    expect(auth.restored, isTrue);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.user!.id, 1);
  });

  test('restoreSession clears a token the server rejects', () async {
    final store = FakeTokenStore()..token = 'old-token';
    final auth = _providerWith(
      MockClient(
          (_) async => _json({'detail': 'Invalid or missing token'}, 401)),
      store,
    );

    await auth.restoreSession();

    expect(auth.isLoggedIn, isFalse);
    expect(store.token, isNull);
  });

  test('logout clears the token and the user', () async {
    final store = FakeTokenStore();
    final auth = _providerWith(
      MockClient((_) async => _json({
            'access_token': 'abc123',
            'token_type': 'bearer',
            'user': _userJson,
          }, 200)),
      store,
    );
    await auth.login(phone: '9876543210', pin: '1234');

    await auth.logout();

    expect(auth.isLoggedIn, isFalse);
    expect(store.token, isNull);
  });
}