import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert_item.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

/// The nominee's list of updates about the senior(s) they look after.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertItem> _alerts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    try {
      if (token == null) throw ApiException('Please log in again.');
      final list = await ApiClient().listAlerts(token);
      if (!mounted) return;
      setState(() {
        _alerts = list;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _when(DateTime t) {
    final time = TimeOfDay.fromDateTime(t).format(context);
    return '${t.day}/${t.month}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Text(_error!, style: textTheme.bodyMedium)
                    else if (_alerts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          'No alerts. If Saarthi needs to tell you something '
                          'about the person you look after, it will show here.',
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final alert in _alerts) _AlertCard(
                        alert: alert,
                        when: _when(alert.createdAt),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.when});

  final AlertItem alert;
  final String when;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.seniorName, style: textTheme.titleLarge),
          Text(when, style: textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(alert.summary, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}