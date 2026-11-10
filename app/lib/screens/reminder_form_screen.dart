import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reminder.dart';
import '../services/api_client.dart';
import '../services/reminders_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

final _compactButton = TextButton.styleFrom(minimumSize: const Size(64, 56));

/// Add a reminder, or edit/delete an existing one.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.existing, this.seniorId});

  final Reminder? existing;

  /// Only a nominee passes this: the senior the reminder is for.
  final int? seniorId;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _dosage;
  late String _kind;
  late List<String> _times;
  late Set<int> _days;
  late bool _isActive;
  DateTime? _oneOffAt;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final reminder = widget.existing;
    _title = TextEditingController(text: reminder?.title ?? '');
    _dosage = TextEditingController(text: reminder?.dosage ?? '');
    _kind = reminder?.kind ?? 'medicine';
    _times = [...?reminder?.times];
    _days = {...(reminder?.days ?? const [1, 2, 3, 4, 5, 6, 7])};
    _oneOffAt = reminder?.oneOffAt?.toLocal();
    _isActive = reminder?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _dosage.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final hm = toHm(picked);
    setState(() {
      if (!_times.contains(hm)) {
        _times = [..._times, hm]..sort();
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _oneOffAt;
    final initial = (current != null && current.isAfter(today)) ? current : today;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(() {
      _oneOffAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    String? problem;
    if (_kind == 'medicine') {
      if (_times.isEmpty) {
        problem = 'Add at least one time';
      } else if (_days.isEmpty) {
        problem = 'Choose at least one day';
      }
    } else if (_oneOffAt == null) {
      problem = 'Choose the date and time';
    }
    if (!formOk || problem != null) {
      setState(() => _error = problem);
      return;
    }

    final reminders = context.read<RemindersProvider>();
    final isMedicine = _kind == 'medicine';
    final dosage = _dosage.text.trim();
    final draft = ReminderDraft(
      kind: _kind,
      title: _title.text.trim(),
      dosage: isMedicine && dosage.isNotEmpty ? dosage : null,
      times: isMedicine ? _times : const [],
      days: isMedicine ? (_days.toList()..sort()) : const [1, 2, 3, 4, 5, 6, 7],
      oneOffAt: isMedicine ? null : _oneOffAt,
      isActive: _isActive,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await reminders.create(draft, seniorId: widget.seniorId);
      } else {
        await reminders.update(existing.id, draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _delete() async {
    final reminders = context.read<RemindersProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this reminder?'),
        content: const Text('It will be removed for good.'),
        actions: [
          TextButton(
            style: _compactButton,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: _compactButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await reminders.delete(widget.existing!.id);
      if (!mounted) return;
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
    final editing = widget.existing != null;
    final isMedicine = _kind == 'medicine';

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
                Text(editing ? 'Edit reminder' : 'New reminder',
                    style: textTheme.headlineMedium),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final option in const [
                      ('medicine', 'Medicine'),
                      ('appointment', 'Appointment'),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        labelStyle: textTheme.bodyLarge,
                        selected: _kind == option.$1,
                        selectedColor: AppColors.primary,
                        checkmarkColor: AppColors.textDark,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _kind = option.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: isMedicine
                        ? 'Medicine name'
                        : 'What is the appointment?',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                if (isMedicine) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dosage,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    style: textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Dose (optional, for example 1 tablet)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Times', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hm in _times)
                        InputChip(
                          label: Text(formatHm(context, hm)),
                          labelStyle: textTheme.bodyLarge,
                          onDeleted: _busy
                              ? null
                              : () => setState(() =>
                                  _times = _times.where((t) => t != hm).toList()),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add),
                        label: const Text('Add a time'),
                        labelStyle: textTheme.bodyLarge,
                        onPressed: _busy ? null : _addTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Days', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(weekdayNames[day - 1]),
                          labelStyle: textTheme.bodyMedium,
                          selected: _days.contains(day),
                          selectedColor: AppColors.primary,
                          checkmarkColor: AppColors.textDark,
                          onSelected: _busy
                              ? null
                              : (selected) => setState(() {
                                    if (selected) {
                                      _days.add(day);
                                    } else {
                                      _days.remove(day);
                                    }
                                  }),
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Text('Date and time', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickDateTime,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    icon: const Icon(Icons.event),
                    label: Text(
                      _oneOffAt == null
                          ? 'Choose date and time'
                          : formatDateTime(context, _oneOffAt!),
                      style: textTheme.bodyLarge,
                    ),
                  ),
                ],
                if (editing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Reminder is on', style: textTheme.bodyLarge),
                    value: _isActive,
                    onChanged:
                        _busy ? null : (value) => setState(() => _isActive = value),
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
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Save reminder'),
                ),
                if (editing) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    child: const Text('Delete this reminder'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}