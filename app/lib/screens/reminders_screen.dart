import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reminder.dart';
import '../services/reminders_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'reminder_form_screen.dart';

/// The list of reminders. A nominee opens it for one linked senior.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, this.seniorId, this.seniorName});

  final int? seniorId;
  final String? seniorName;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RemindersProvider>().load(seniorId: widget.seniorId);
    });
  }

  void _open(Reminder? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReminderFormScreen(existing: existing, seniorId: widget.seniorId),
      ),
    );
  }

  Future<void> _sendTest() async {
    final reminders = context.read<RemindersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await reminders.requestNotificationPermission();
      await reminders.sendTestNotification();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'A test reminder will arrive in 10 seconds. '
            'Lock your phone or go to the home screen.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not set the test reminder.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<RemindersProvider>();
    final textTheme = Theme.of(context).textTheme;
    final title = widget.seniorName == null
        ? 'Your reminders'
        : 'Reminders for ${widget.seniorName}';

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
              Text(title, style: textTheme.headlineMedium),
              const SizedBox(height: 24),
              if (reminders.loading && reminders.reminders.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (reminders.error != null)
                Text(reminders.error!, style: textTheme.bodyMedium)
              else if (reminders.reminders.isEmpty)
                Text('No reminders yet.', style: textTheme.bodyMedium)
              else
                for (final reminder in reminders.reminders)
                  _ReminderTile(reminder: reminder, onTap: () => _open(reminder)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _open(null),
                child: const Text('Add a reminder'),
              ),
              if (widget.seniorId == null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _sendTest,
                  child: const Text('Send a test reminder'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.onTap});

  final Reminder reminder;
  final VoidCallback onTap;

  String _summary(BuildContext context) {
    if (reminder.isMedicine) {
      final times =
          reminder.times.map((t) => formatHm(context, t)).join(', ');
      return '$times  ·  ${formatDays(reminder.days)}';
    }
    final when = reminder.oneOffAt;
    return when == null ? 'Appointment' : formatDateTime(context, when);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reminder.title, style: textTheme.titleLarge),
                      if (reminder.dosage != null)
                        Text(reminder.dosage!, style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(_summary(context), style: textTheme.bodySmall),
                      if (!reminder.isActive)
                        Text('Off', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 32, color: AppColors.textDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}