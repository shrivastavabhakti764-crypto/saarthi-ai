import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../services/auth_provider.dart';

/// Temporary home. Replaced by the real Senior Home / Nominee Home later.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final roleLabel = user.isSenior ? UserRole.senior.label : UserRole.nominee.label;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome, ${user.name}',
                  style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(roleLabel,
                  style: textTheme.bodyLarge, textAlign: TextAlign.center),
              Text(user.phone,
                  style: textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}