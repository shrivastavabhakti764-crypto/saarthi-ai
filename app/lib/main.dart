import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_provider.dart';
import 'services/token_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider(api: ApiClient(), tokenStore: SecureTokenStore());
  unawaited(auth.restoreSession());
  runApp(SaarthiApp(auth: auth));
}

class SaarthiApp extends StatelessWidget {
  const SaarthiApp({super.key, required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        title: 'Saarthi.AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
}