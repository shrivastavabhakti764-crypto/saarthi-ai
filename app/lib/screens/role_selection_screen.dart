import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

enum UserRole { senior, nominee }

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _select(BuildContext context, UserRole role) {
    // Temporary: the register/login screen is wired in a later step.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected: ${role.name}')),
    );
  }

  // Temporary connectivity test, removed once login is wired.
  Future<void> _checkServer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ApiClient().health();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Server: ${result['status']}, database: ${result['database']}',
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text('Saarthi.AI',
                style: textTheme.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Always here for you',
                style: AppTextStyles.tagline, textAlign: TextAlign.center),
            const SizedBox(height: 48),
            Text('Who are you?',
                style: textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.elderly,
              title: 'Senior Citizen',
              subtitle: 'I want a friendly companion and reminders',
              onTap: () => _select(context, UserRole.senior),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.family_restroom,
              title: 'Nominee (Family Member)',
              subtitle: 'I want to look after someone I love',
              onTap: () => _select(context, UserRole.nominee),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => _checkServer(context),
              child: const Text('Check server (temporary)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.amberTint,
                child: Icon(icon, size: 36, color: AppColors.textDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32, color: AppColors.textDark),
            ],
          ),
        ),
      ),
    );
  }
}