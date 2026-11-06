import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/auth_provider.dart';
import 'package:saarthi_ai/services/links_provider.dart';
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

const _userJson = {
  'id': 1,
  'name': 'Asha',
  'phone': '+919876543210',
  'role': 'senior',
  'consent_accepted_at': '2026-11-06T12:00:00+05:30',
  'created_at': '2026-11-05T11:29:11+05:30',
};

Map<String, Object?> _linkJson({String relationship = 'son'}) => {
      'id': 1,
      'senior_id': 1,
      'senior_name': 'Asha',
      'nominee_id': 2,
      'nominee_name': 'Rohan',
      'relationship': relationship,
      'whatsapp_number': '+919876543211',
      'whatsapp_opt_in': true,
      'created_at': '2026-11-06T12:00:00+05:30',
    };

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// A tiny fake backend. Every route except login needs the right token.
Future<http.Response> _fakeBackend(http.Request request) async {
  final route = '${request.method} ${request.url.path}';
  if (route == 'POST /auth/login') {
    return _json({
      'access_token': 'abc123',
      'token_type': 'bearer',
      'user': _userJson,
    });
  }
  if (request.headers['Authorization'] != 'Bearer abc123') {
    return _json({'detail': 'Invalid or missing token'}, 401);
  }
  switch (route) {
    case 'POST /links/code':
      return _json({
        'code': '123456',
        'expires_at': '2026-11-06T12:15:00+05:30',
      }, 201);
    case 'POST /links/redeem':
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['code'] != '123456') {
        return _json({'detail': 'This code is not valid or has expired'}, 400);
      }
      return _json(_linkJson(relationship: body['relationship'] as String), 201);
    case 'GET /links':
      return _json([_linkJson()]);
    case 'DELETE /links/1':
      return http.Response('', 204);
  }
  return http.Response('not found', 404);
}

Future<({AuthProvider auth, LinksProvider links})> _setup() async {
  final api = ApiClient(client: MockClient(_fakeBackend));
  final auth = AuthProvider(api: api, tokenStore: _MemoryTokenStore());
  await auth.login(phone: '9876543210', pin: '1234');
  return (auth: auth, links: LinksProvider(api: api, auth: auth));
}

void main() {
  test('createCode keeps the code the server made', () async {
    final s = await _setup();

    final code = await s.links.createCode();

    expect(code.code, '123456');
    expect(s.links.code!.code, '123456');
  });

  test('redeem adds the new link to the list', () async {
    final s = await _setup();

    final link = await s.links.redeem(
      code: '123456',
      relationship: 'son',
      whatsappNumber: '98765 43211',
      whatsappOptIn: true,
    );

    expect(link.seniorName, 'Asha');
    expect(link.nomineeName, 'Rohan');
    expect(link.whatsappOptIn, isTrue);
    expect(s.links.links, hasLength(1));
  });

  test('a wrong code shows the server message and adds nothing', () async {
    final s = await _setup();

    await expectLater(
      s.links.redeem(code: '000000', relationship: 'son'),
      throwsA(isA<ApiException>().having(
        (e) => e.message,
        'message',
        'This code is not valid or has expired',
      )),
    );
    expect(s.links.links, isEmpty);
  });

  test('load fills the list', () async {
    final s = await _setup();

    await s.links.load();

    expect(s.links.links.single.nomineeName, 'Rohan');
    expect(s.links.loading, isFalse);
    expect(s.links.error, isNull);
  });

  test('unlink removes the link from the list', () async {
    final s = await _setup();
    await s.links.load();

    await s.links.unlink(1);

    expect(s.links.links, isEmpty);
  });

  test('logging out clears the links and the code', () async {
    final s = await _setup();
    await s.links.load();
    await s.links.createCode();

    await s.auth.logout();

    expect(s.links.links, isEmpty);
    expect(s.links.code, isNull);
  });
}