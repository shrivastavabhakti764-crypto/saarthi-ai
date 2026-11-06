import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/link.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../services/links_provider.dart';
import '../theme/app_theme.dart';
import 'add_nominee_screen.dart';
import 'link_code_entry_screen.dart';

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
    });
  }

  Future<void> _open(Widget screen) async {
    final links = context.read<LinksProvider>();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await links.load();
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
    final textTheme = Theme.of(context).textTheme;
    final roleLabel =
        user.isSenior ? UserRole.senior.label : UserRole.nominee.label;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Text('Welcome, ${user.name}',
                style: textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(roleLabel,
                style: textTheme.bodyLarge, textAlign: TextAlign.center),
            Text(user.phone,
                style: textTheme.bodySmall, textAlign: TextAlign.center),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleLarge),
                Text(subtitle, style: textTheme.bodyMedium),
              ],
            ),
          ),
          TextButton(
            style: _compactButton,
            onPressed: onRemove,
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}