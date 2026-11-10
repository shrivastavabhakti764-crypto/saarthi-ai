import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/link.dart';
import '../models/reminder.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../services/links_provider.dart';
import '../services/reminders_provider.dart';
import '../theme/app_theme.dart';
import 'add_nominee_screen.dart';
import 'link_code_entry_screen.dart';
import 'reminders_screen.dart';

final _compactButton = TextButton.styleFrom(minimumSize: const Size(64, 56));

/// Temporary home. Replaced by the real Senior Home / Nominee Home later.
class HomePlaceholderScreen extends StatefulWidget {
  const HomePlaceholderScreen({super.key});

  @override
  State<HomePlaceholderScreen> createState() => _HomePlaceholderScreenState();
}

class _HomePlaceholderScreenState extends State<HomePlaceholderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinksProvider>().load();
      final user = context.read<AuthProvider>().user;
      if (user != null && user.isSenior) {
        context.read<RemindersProvider>().load();
      }
    });
  }

  Future<void> _open(Widget screen) async {
    final links = context.read<LinksProvider>();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await links.load();
  }

  Future<void> _answer(TodaySlot slot, String status) async {
    final reminders = context.read<RemindersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await reminders.logSlot(
        reminderId: slot.reminderId,
        scheduledFor: slot.scheduledFor,
        status: status,
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(LinkInfo link, String otherName) async {
    final links = context.read<LinksProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this link?'),
        content: Text('You will no longer be linked with $otherName.'),
        actions: [
          TextButton(
            style: _compactButton,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: _compactButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await links.unlink(link.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();
    final links = context.watch<LinksProvider>();
    final reminders = context.watch<RemindersProvider>();
    final textTheme = Theme.of(context).textTheme;
    final roleLabel =
        user.isSenior ? UserRole.senior.label : UserRole.nominee.label;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Welcome, ${user.name}',
                  style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(roleLabel,
                  style: textTheme.bodyLarge, textAlign: TextAlign.center),
              Text(user.phone,
                  style: textTheme.bodySmall, textAlign: TextAlign.center),
              if (user.isSenior) ...[
                const SizedBox(height: 32),
                Text('Today', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                if (reminders.loading && reminders.today.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (reminders.error != null && reminders.today.isEmpty)
                  Text(reminders.error!, style: textTheme.bodyMedium)
                else if (reminders.today.isEmpty)
                  Text('Nothing to take or attend today.',
                      style: textTheme.bodyMedium)
                else
                  for (final slot in reminders.today)
                    _SlotTile(
                      slot: slot,
                      onAnswer: (status) => _answer(slot, status),
                    ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  ),
                  child: const Text('My reminders'),
                ),
              ],
              const SizedBox(height: 32),
              Text(user.isSenior ? 'Your family' : 'People you look after',
                  style: textTheme.titleLarge),
              const SizedBox(height: 12),
              if (links.loading && links.links.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (links.error != null)
                Text(links.error!, style: textTheme.bodyMedium)
              else if (links.links.isEmpty)
                Text('No one is linked yet.', style: textTheme.bodyMedium)
              else
                for (final link in links.links)
                  _LinkTile(
                    title: user.isSenior ? link.nomineeName : link.seniorName,
                    subtitle: user.isSenior
                        ? 'Your ${link.relationship.toLowerCase()}'
                        : 'You are their ${link.relationship.toLowerCase()}',
                    onRemove: () => _remove(
                      link,
                      user.isSenior ? link.nomineeName : link.seniorName,
                    ),
                    onReminders: user.isNominee
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RemindersScreen(
                                  seniorId: link.seniorId,
                                  seniorName: link.seniorName,
                                ),
                              ),
                            )
                        : null,
                  ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _open(
                  user.isSenior
                      ? const AddNomineeScreen()
                      : const LinkCodeEntryScreen(),
                ),
                child: Text(
                  user.isSenior ? 'Add a family member' : 'Link with a senior',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
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

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.onAnswer});

  final TodaySlot slot;
  final void Function(String status) onAnswer;

  bool get _isMedicine => slot.kind == 'medicine';

  String _answerText() {
    if (slot.status == 'taken') return _isMedicine ? 'Taken' : 'Done';
    return 'Skipped';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = TimeOfDay.fromDateTime(slot.scheduledFor).format(context);
    final answered = slot.status == 'taken' || slot.status == 'skipped';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: slot.status == 'taken' ? AppColors.success : AppColors.primary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: textTheme.bodySmall),
          Text(slot.title, style: textTheme.titleLarge),
          if (slot.dosage != null)
            Text(slot.dosage!, style: textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (answered)
            Text(
              _answerText(),
              style: textTheme.labelLarge?.copyWith(
                color: slot.status == 'taken'
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
            )
          else ...[
            if (slot.status == 'missed')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Missed', style: textTheme.labelLarge),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAnswer('taken'),
                    child: Text(_isMedicine ? 'I took it' : 'I went'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  style: _compactButton,
                  onPressed: () => onAnswer('skipped'),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.onRemove,
    this.onReminders,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRemove;
  final VoidCallback? onReminders;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleLarge),
          Text(subtitle, style: textTheme.bodyMedium),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                if (onReminders != null)
                  TextButton(
                    style: _compactButton,
                    onPressed: onReminders,
                    child: const Text('Reminders'),
                  ),
                TextButton(
                  style: _compactButton,
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}