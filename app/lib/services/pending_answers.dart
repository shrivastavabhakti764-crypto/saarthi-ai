import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A Taken/Skipped answer that could not reach the server yet.
class PendingAnswer {
  const PendingAnswer({
    required this.reminderId,
    required this.scheduledFor,
    required this.status,
  });

  final int reminderId;
  final DateTime scheduledFor;

  /// 'taken' or 'skipped'.
  final String status;

  bool sameSlot(PendingAnswer other) =>
      reminderId == other.reminderId &&
      scheduledFor.isAtSameMomentAs(other.scheduledFor);

  Map<String, Object?> toJson() => {
        'reminder_id': reminderId,
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'status': status,
      };

  factory PendingAnswer.fromJson(Map<String, dynamic> json) => PendingAnswer(
        reminderId: json['reminder_id'] as int,
        scheduledFor: DateTime.parse(json['scheduled_for'] as String).toUtc(),
        status: json['status'] as String,
      );
}

/// Where unsent answers wait. One answer per slot: the latest one wins.
abstract class PendingAnswerStore {
  Future<List<PendingAnswer>> all();
  Future<void> add(PendingAnswer answer);
  Future<void> remove(PendingAnswer answer);
}

class SecurePendingAnswerStore implements PendingAnswerStore {
  SecurePendingAnswerStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'pending_answers';
  final FlutterSecureStorage _storage;

  Future<void> _save(List<PendingAnswer> answers) => _storage.write(
        key: _key,
        value: jsonEncode(answers.map((a) => a.toJson()).toList()),
      );

  @override
  Future<List<PendingAnswer>> all() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List<dynamic>) return [];
      return data
          .map((item) => PendingAnswer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // unreadable: start fresh rather than crash
    }
  }

  @override
  Future<void> add(PendingAnswer answer) async {
    final answers = await all();
    answers.removeWhere((a) => a.sameSlot(answer));
    answers.add(answer);
    await _save(answers);
  }

  @override
  Future<void> remove(PendingAnswer answer) async {
    final answers = await all();
    answers.removeWhere((a) => a.sameSlot(answer));
    await _save(answers);
  }
}