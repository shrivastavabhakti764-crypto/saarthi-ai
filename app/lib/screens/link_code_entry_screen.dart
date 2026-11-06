import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/links_provider.dart';
import '../theme/app_theme.dart';

/// Nominee: enter the senior's code, say how you are related, optionally add WhatsApp.
class LinkCodeEntryScreen extends StatefulWidget {
  const LinkCodeEntryScreen({super.key});

  @override
  State<LinkCodeEntryScreen> createState() => _LinkCodeEntryScreenState();
}

class _LinkCodeEntryScreenState extends State<LinkCodeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _relationship = TextEditingController();
  final _whatsapp = TextEditingController();

  bool _optIn = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _relationship.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final links = context.read<LinksProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await links.redeem(
        code: _code.text,
        relationship: _relationship.text.trim(),
        whatsappNumber: _whatsapp.text.isEmpty ? null : _whatsapp.text,
        whatsappOptIn: _optIn,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('You are now linked with ${link.seniorName}')),
      );
      Navigator.of(context).pop();
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter the code', style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Ask the senior to open "Add a family member" in their app.',
                    style: textTheme.bodyMedium),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: textTheme.bodyLarge,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                      ? null
                      : 'Enter the 6-digit code',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _relationship,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'How are you related? (for example: Son)',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter how you are related'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _whatsapp,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: textTheme.bodyLarge,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number (optional)',
                    prefixText: '+91  ',
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) {
                      return _optIn
                          ? 'Enter your WhatsApp number to get alerts there'
                          : null;
                    }
                    return RegExp(r'^[6-9]\d{9}$').hasMatch(v)
                        ? null
                        : 'Enter a 10-digit mobile number';
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  checkColor: AppColors.textDark,
                  activeColor: AppColors.primary,
                  title: Text('Also send alerts on WhatsApp',
                      style: textTheme.bodyLarge),
                  value: _optIn,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _optIn = value ?? false),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
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
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Link accounts'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}