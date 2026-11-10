import 'package:flutter/foundation.dart';

import '../models/reminder.dart';
import 'api_client.dart';
import 'auth_provider.dart';

/// Reminders, and (for a senior) today's schedule with Taken/Skipped answers.
class RemindersProvider extends ChangeNotifier {
  RemindersProvider({required this._api, required this._auth}) {
    _auth.addListener(_onAuthChanged);
  }

  final ApiClient _api;
  final AuthProvider _auth;

  List<Reminder> _reminders = const [];
  List<TodaySlot> _today = const [];
  bool _loading = false;
  String? _error;

  List<Reminder> get reminders => _reminders;
  List<TodaySlot> get today => _today;
  bool get loading => _loading;
  String? get error => _error;

  bool get _isSenior => _auth.user?.isSenior ?? false;

  String _token() {
    final token = _auth.token;
    if (token == null) throw ApiException('Please log in again.');
    return token;
  }

  /// When the user logs out, forget everything about their reminders.
  void _onAuthChanged() {
    if (!_auth.isLoggedIn && (_reminders.isNotEmpty || _today.isNotEmpty)) {
      _reminders = const [];
      _today = const [];
      _error = null;
      notifyListeners();
    }
  }

  /// Reloads the reminders (a nominee may pick one senior) and, for a senior,
  /// today's schedule. A failure is kept in [error] so a screen can show it.
  Future<void> load({int? seniorId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _reminders = await _api.listReminders(_token(), seniorId: seniorId);
      if (_isSenior) _today = await _api.todaySlots(_token());
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// A senior's schedule changes when reminders change; keep the old one if
  /// refreshing fails.
  Future<void> _refreshToday() async {
    if (!_isSenior) return;
    try {
      _today = await _api.todaySlots(_token());
      notifyListeners();
    } on ApiException {
      // keep what we had
    }
  }

  Future<Reminder> create(ReminderDraft draft, {int? seniorId}) async {
    final reminder =
        await _api.createReminder(_token(), draft, seniorId: seniorId);
    _reminders = [..._reminders, reminder];
    notifyListeners();
    await _refreshToday();
    return reminder;
  }

  Future<Reminder> update(int reminderId, ReminderDraft draft) async {
    final updated = await _api.updateReminder(_token(), reminderId, draft);
    _reminders = [
      for (final r in _reminders) if (r.id == reminderId) updated else r,
    ];
    notifyListeners();
    await _refreshToday();
    return updated;
  }

  Future<void> delete(int reminderId) async {
    await _api.deleteReminder(_token(), reminderId);
    _reminders = _reminders.where((r) => r.id != reminderId).toList();
    notifyListeners();
    await _refreshToday();
  }

  /// A senior answers one slot: 'taken' or 'skipped'.
  Future<TodaySlot> logSlot({
    required int reminderId,
    required DateTime scheduledFor,
    required String status,
  }) async {
    final updated = await _api.logSlot(
      _token(),
      reminderId: reminderId,
      scheduledFor: scheduledFor,
      status: status,
    );
    _today = [
      for (final s in _today)
        if (s.reminderId == reminderId &&
            s.scheduledFor.isAtSameMomentAs(updated.scheduledFor))
          updated
        else
          s,
    ];
    notifyListeners();
    return updated;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}