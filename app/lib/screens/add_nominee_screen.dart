import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/links_provider.dart';
import '../theme/app_theme.dart';

/// Senior: shows a fresh 6-digit code to give to a family member.
class AddNomineeScreen extends StatefulWidget {
  const AddNomineeScreen({super.key});

  @override
  State<AddNomineeScreen> createState() => _AddNomineeScreenState();
}

class _AddNomineeScreenState extends State<AddNomineeScreen> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    final links = context.read<LinksProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await links.createCode();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final code = context.watch<LinksProvider>().code;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Give this code to your family',
                  style: textTheme.headlineMedium),
              const SizedBox(height: 24),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (code != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${code.code.substring(0, 3)} ${code.code.substring(3)}',
                        style: textTheme.headlineLarge?.copyWith(
                          fontSize: 48,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Works once, until '
                        '${TimeOfDay.fromDateTime(code.expiresAt.toLocal()).format(context)}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(_error!, style: textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: 24),
              Text('1. Ask your family member to open Saarthi.AI.',
                  style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text('2. They choose "Nominee (Family Member)" and create an account.',
                  style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text('3. They enter this code.', style: textTheme.bodyLarge),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _generate,
                child: const Text('Get a new code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}