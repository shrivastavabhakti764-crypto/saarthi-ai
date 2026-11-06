import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_provider.dart';
import 'services/links_provider.dart';
import 'services/token_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthProvider(api: api, tokenStore: SecureTokenStore());
  final links = LinksProvider(api: api, auth: auth);
  unawaited(auth.restoreSession());
  runApp(SaarthiApp(auth: auth, links: links));
}

class SaarthiApp extends StatelessWidget {
  const SaarthiApp({super.key, required this.auth, required this.links});

  final AuthProvider auth;
  final LinksProvider links;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LinksProvider>.value(value: links),
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