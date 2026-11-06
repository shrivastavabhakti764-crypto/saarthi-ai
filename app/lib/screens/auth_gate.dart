import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import 'consent_screen.dart';
import 'home_placeholder_screen.dart';
import 'role_selection_screen.dart';

/// Decides the first screen: still checking the saved token, logged out,
/// a senior who has not given consent yet, or the home screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.restored) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    if (user == null) return const RoleSelectionScreen();
    if (user.isSenior && user.consentAcceptedAt == null) {
      return const ConsentScreen();
    }
    return const HomePlaceholderScreen();
  }
}