import 'package:flutter_test/flutter_test.dart';
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
}