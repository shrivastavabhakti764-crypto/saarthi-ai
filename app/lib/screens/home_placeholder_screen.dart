import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/link.dart';
import '../models/reminder.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../services/links_provider.dart';
import '../services/reminders_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/saarthi_avatar.dart';
import 'add_nominee_screen.dart';
import 'alerts_screen.dart';
import 'chat_screen.dart';
import 'link_code_entry_screen.dart';
import 'reminders_screen.dart';

final _compactButton = TextButton.styleFrom(minimumSize: const Size(64, 56));

const _indigo = Color(0xFF2D3B55);
const _cream = Color(0xFFFFF8EF);

/// Home for both roles. Senior: avatar-first home. Nominee: alerts-first home.
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

  void _showFamily() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => Consumer2<LinksProvider, AuthProvider>(
        builder: (_, links, auth, _) {
          final textTheme = Theme.of(context).textTheme;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your family', style: textTheme.titleLarge),
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
                        title: link.nomineeName,
                        subtitle: 'Your ${link.relationship.toLowerCase()}',
                        onRemove: () => _remove(link, link.nomineeName),
                      ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _open(const AddNomineeScreen());
                    },
                    child: const Text('Add a family member'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();
    return user.isSenior ? _buildSenior(user) : _buildNominee(user);
  }

  Widget _buildSenior(AppUser user) {
    final reminders = context.watch<RemindersProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 12,
              24,
              28,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Namaste, ${user.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineMedium
                            ?.copyWith(color: _indigo),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: () => context.read<AuthProvider>().logout(),
                      icon: const Icon(Icons.logout_rounded, color: _indigo),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SaarthiAvatar(emotion: 'neutral', size: 170),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'How are you feeling today?',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(color: _indigo),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: _cream,
                    minimumSize: const Size.fromHeight(76),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SaarthiAvatar(emotion: 'neutral', size: 48),
                      SizedBox(width: 14),
                      Text('Talk to Saarthi'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HomeTile(
                        icon: Icons.notifications_active_rounded,
                        label: 'Reminders',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RemindersScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HomeTile(
                        icon: Icons.family_restroom_rounded,
                        label: 'My family',
                        onTap: _showFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNominee(AppUser user) {
    final links = context.watch<LinksProvider>();
    final textTheme = Theme.of(context).textTheme;
    final count = links.links.length;
    final lookingAfter = count == 0
        ? 'No one is linked yet'
        : count == 1
            ? 'Looking after 1 person'
            : 'Looking after $count people';

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 12,
              24,
              28,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Namaste, ${user.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineMedium
                            ?.copyWith(color: _indigo),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      onPressed: () => context.read<AuthProvider>().logout(),
                      icon: const Icon(Icons.logout_rounded, color: _indigo),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lookingAfter,
                  style: textTheme.bodyLarge?.copyWith(color: _indigo),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: _cream,
                    minimumSize: const Size.fromHeight(84),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AlertsScreen()),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Alerts'),
                            Text(
                              'Updates about your family',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: _cream),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (links.loading && links.links.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (links.error != null)
                  Text(links.error!, style: textTheme.bodyMedium)
                else if (links.links.isEmpty)
                  Text('Link with a senior to see their updates here.',
                      style: textTheme.bodyMedium)
                else
                  for (final link in links.links)
                    _SeniorCard(
                      name: link.seniorName,
                      subtitle:
                          'You are their ${link.relationship.toLowerCase()}',
                      onReminders: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RemindersScreen(
                            seniorId: link.seniorId,
                            seniorName: link.seniorName,
                          ),
                        ),
                      ),
                      onRemove: () => _remove(link, link.seniorName),
                    ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    foregroundColor: _indigo,
                    side: const BorderSide(color: Color(0xFFD9C9B0), width: 2),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _open(const LinkCodeEntryScreen()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Link with a senior'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 36, color: _indigo),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(color: _indigo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeniorCard extends StatelessWidget {
  const _SeniorCard({
    required this.name,
    required this.subtitle,
    required this.onReminders,
    required this.onRemove,
  });

  final String name;
  final String subtitle;
  final VoidCallback onReminders;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D3B55),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFF9E3C4),
                child: Text(
                  initial,
                  style: textTheme.titleLarge?.copyWith(color: _indigo),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: textTheme.titleLarge),
                    Text(subtitle, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onReminders,
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Reminders'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: _compactButton,
                onPressed: onRemove,
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
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
  });

  final String title;
  final String subtitle;
  final VoidCallback onRemove;

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
            child: TextButton(
              style: _compactButton,
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}