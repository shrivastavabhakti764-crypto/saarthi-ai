import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saarthi_ai/main.dart';
import 'package:saarthi_ai/services/api_client.dart';
import 'package:saarthi_ai/services/auth_provider.dart';
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

Future<AuthProvider> _loggedOutAuth(WidgetTester tester) async {
  final auth = AuthProvider(api: ApiClient(), tokenStore: _MemoryTokenStore());
  await tester.runAsync(auth.restoreSession);
  return auth;
}

Map<String, Object?> _seniorJson({required bool consented}) => {
      'id': 1,
      'name': 'Test Senior',
      'phone': '+919876543210',
      'role': 'senior',
      'consent_accepted_at': consented ? '2026-11-06T12:00:00+05:30' : null,
      'created_at': '2026-11-05T11:29:11+05:30',
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

/// A senior who is logged in but has not given consent yet (fake backend).
Future<AuthProvider> _seniorWithoutConsent(WidgetTester tester) async {
  final client = MockClient((request) async {
    if (request.url.path == '/auth/login') {
      return _json({
        'access_token': 'abc123',
        'token_type': 'bearer',
        'user': _seniorJson(consented: false),
      });
    }
    if (request.url.path == '/me/consent') {
      return _json(_seniorJson(consented: true));
    }
    return http.Response('not found', 404);
  });
  final auth = AuthProvider(
    api: ApiClient(client: client),
    tokenStore: _MemoryTokenStore(),
  );
  await tester.runAsync(() async {
    await auth.restoreSession();
    await auth.login(phone: '9876543210', pin: '1234');
  });
  return auth;
}

void main() {
  testWidgets('role screen shows both choices', (WidgetTester tester) async {
    await tester.pumpWidget(SaarthiApp(auth: await _loggedOutAuth(tester)));

    expect(find.text('Saarthi.AI'), findsOneWidget);
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Senior Citizen'), findsOneWidget);
    expect(find.text('Nominee (Family Member)'), findsOneWidget);
  });

  testWidgets('tapping a role opens the register screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(SaarthiApp(auth: await _loggedOutAuth(tester)));

    await tester.tap(find.text('Senior Citizen'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Registering as Senior Citizen'), findsOneWidget);
  });

  testWidgets('register form rejects empty fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(SaarthiApp(auth: await _loggedOutAuth(tester)));
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
    await tester.pumpWidget(SaarthiApp(auth: await _loggedOutAuth(tester)));

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
      SaarthiApp(auth: await _seniorWithoutConsent(tester)),
    );

    expect(find.text('Before we begin'), findsOneWidget);
    expect(find.text('I Agree'), findsOneWidget);
    expect(find.text('Welcome, Test Senior'), findsNothing);
  });

  testWidgets('agreeing moves the senior on to the home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      SaarthiApp(auth: await _seniorWithoutConsent(tester)),
    );

    await tester.ensureVisible(find.text('I Agree'));
    await tester.tap(find.text('I Agree'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Test Senior'), findsOneWidget);
    expect(find.text('Before we begin'), findsNothing);
  });
}