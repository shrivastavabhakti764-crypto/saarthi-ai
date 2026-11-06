import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/main.dart';
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

Map<String, Object?> _userJson(String role, {bool consented = true}) => {
      'id': role == 'senior' ? 1 : 2,
      'name': role == 'senior' ? 'Asha' : 'Rohan',
      'phone': '+919876543210',
      'role': role,
      'consent_accepted_at': consented ? '2026-11-06T12:00:00+05:30' : null,
      'created_at': '2026-11-05T11:29:11+05:30',
    };

Map<String, Object?> _linkJson() => {
      'id': 1,
      'senior_id': 1,
      'senior_name': 'Asha',
      'nominee_id': 2,
      'nominee_name': 'Rohan',
      'relationship': 'son',
      'whatsapp_number': null,
      'whatsapp_opt_in': false,
      'created_at': '2026-11-06T12:00:00+05:30',
    };

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// A tiny fake backend for the screens.
MockClient _backend({
  required String role,
  bool consented = true,
  List<Map<String, Object?>> links = const [],
}) {
  return MockClient((request) async {
    switch ('${request.method} ${request.url.path}') {
      case 'POST /auth/login':
        return _json({
          'access_token': 'abc123',
          'token_type': 'bearer',
          'user': _userJson(role, consented: consented),
        });
      case 'POST /me/consent':
        return _json(_userJson(role));
      case 'GET /links':
        return _json(links);
      case 'POST /links/code':
        return _json({
          'code': '123456',
          'expires_at': '2026-11-06T12:15:00+05:30',
        }, 201);
    }
    return http.Response('not found', 404);
  });
}

Future<SaarthiApp> _loggedOutApp(WidgetTester tester) async {
  final api = ApiClient();
  final auth = AuthProvider(api: api, tokenStore: _MemoryTokenStore());
  await tester.runAsync(auth.restoreSession);
  return SaarthiApp(auth: auth, links: LinksProvider(api: api, auth: auth));
}

Future<SaarthiApp> _loggedInApp(
  WidgetTester tester, {
  required String role,
  bool consented = true,
  List<Map<String, Object?>> links = const [],
}) async {
  final api = ApiClient(
    client: _backend(role: role, consented: consented, links: links),
  );
  final auth = AuthProvider(api: api, tokenStore: _MemoryTokenStore());
  await tester.runAsync(() async {
    await auth.restoreSession();
    await auth.login(phone: '9876543210', pin: '1234');
  });
  return SaarthiApp(auth: auth, links: LinksProvider(api: api, auth: auth));
}

void main() {
  testWidgets('role screen shows both choices', (WidgetTester tester) async {
    await tester.pumpWidget(await _loggedOutApp(tester));

    expect(find.text('Saarthi.AI'), findsOneWidget);
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Senior Citizen'), findsOneWidget);
    expect(find.text('Nominee (Family Member)'), findsOneWidget);
  });

  testWidgets('tapping a role opens the register screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(await _loggedOutApp(tester));

    await tester.tap(find.text('Senior Citizen'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Registering as Senior Citizen'), findsOneWidget);
  });

  testWidgets('register form rejects empty fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(await _loggedOutApp(tester));
    await tester.tap(find.text('Nominee (Family Member)'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
    expect(find.text('PIN must be 4 to 6 digits'), findsOneWidget);
  });

  testWidgets('log in link opens the login screen and checks its fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(await _loggedOutApp(tester));

    await tester.ensureVisible(find.text('Already have an account? Log in'));
    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
    expect(find.text('PIN must be 4 to 6 digits'), findsOneWidget);
  });

  testWidgets('a senior without consent sees the consent screen first',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      await _loggedInApp(tester, role: 'senior', consented: false),
    );

    expect(find.text('Before we begin'), findsOneWidget);
    expect(find.text('I Agree'), findsOneWidget);
    expect(find.text('Welcome, Asha'), findsNothing);
  });

  testWidgets('agreeing moves the senior on to the home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      await _loggedInApp(tester, role: 'senior', consented: false),
    );

    await tester.ensureVisible(find.text('I Agree'));
    await tester.tap(find.text('I Agree'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Asha'), findsOneWidget);
    expect(find.text('Before we begin'), findsNothing);
  });

  testWidgets('a nominee skips consent and sees who they look after',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      await _loggedInApp(tester, role: 'nominee', links: [_linkJson()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Before we begin'), findsNothing);
    expect(find.text('Welcome, Rohan'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Link with a senior'), findsOneWidget);
  });

  testWidgets('a senior opens Add a family member and sees the code',
      (WidgetTester tester) async {
    await tester.pumpWidget(await _loggedInApp(tester, role: 'senior'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add a family member'));
    await tester.tap(find.text('Add a family member'));
    await tester.pumpAndSettle();

    expect(find.text('Give this code to your family'), findsOneWidget);
    expect(find.text('123 456'), findsOneWidget);
  });

  testWidgets('the link form checks the code and the relationship',
      (WidgetTester tester) async {
    await tester.pumpWidget(await _loggedInApp(tester, role: 'nominee'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Link with a senior'));
    await tester.tap(find.text('Link with a senior'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Link accounts'));
    await tester.tap(find.text('Link accounts'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.text('Please enter how you are related'), findsOneWidget);
  });
}