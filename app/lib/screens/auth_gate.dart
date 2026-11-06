import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import 'home_placeholder_screen.dart';
import 'role_selection_screen.dart';

/// Decides the first screen: still checking the saved token, logged in, or logged out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.restored) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.isLoggedIn) return const HomePlaceholderScreen();
    return const RoleSelectionScreen();
  }
}