import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_provider.dart';
import 'services/links_provider.dart';
import 'services/notification_answers.dart';
import 'services/notification_service.dart';
import 'services/reminders_provider.dart';
import 'services/token_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notifications = NotificationService();
  try {
    await notifications.init();
  } catch (e) {
    // The app still works without reminders ringing; init is retried later.
    debugPrint('Notifications could not start: $e');
  }

  final api = ApiClient();
  final auth = AuthProvider(api: api, tokenStore: SecureTokenStore());
  final links = LinksProvider(api: api, auth: auth);
  final reminders =
      RemindersProvider(api: api, auth: auth, scheduler: notifications);

  // After a Taken/Skipped button press, refresh the Today list on screen.
  onNotificationAnswered = () => unawaited(reminders.load());

  unawaited(auth.restoreSession());
  runApp(SaarthiApp(auth: auth, links: links, reminders: reminders));
}

class SaarthiApp extends StatelessWidget {
  const SaarthiApp({
    super.key,
    required this.auth,
    required this.links,
    required this.reminders,
  });

  final AuthProvider auth;
  final LinksProvider links;
  final RemindersProvider reminders;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LinksProvider>.value(value: links),
        ChangeNotifierProvider<RemindersProvider>.value(value: reminders),
      ],
      child: MaterialApp(
        title: 'Saarthi.AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
}