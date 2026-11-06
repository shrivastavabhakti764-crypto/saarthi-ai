import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

/// Shown once to a senior before the home screen. Plain words, one main button.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _agree() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.acceptConsent();
      // On success the gate swaps this screen for the home screen.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Before we begin', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Please read this. It takes one minute.',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 24),
              const _Point(
                icon: Icons.chat_bubble_outline,
                text: 'Saarthi is a friendly companion. '
                    'It is not a doctor and does not give medical advice.',
              ),
              const _Point(
                icon: Icons.edit_note,
                text: 'If you mention a health problem, like pain or '
                    'dizziness, Saarthi writes it down.',
              ),
              const _Point(
                icon: Icons.family_restroom,
                text: 'If it seems serious, or you ask for help, Saarthi '
                    'first asks if you are okay. If there is no answer, '
                    'your family member (nominee) gets a message.',
              ),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(_error!, style: textTheme.bodyMedium),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _busy ? null : _agree,
                child: _busy
                    ? const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('I Agree'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _busy ? null : () => context.read<AuthProvider>().logout(),
                child: const Text('Not now, log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.amberTint,
            child: Icon(icon, size: 28, color: AppColors.textDark),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: textTheme.bodyLarge)),
        ],
      ),
    );
  }
}