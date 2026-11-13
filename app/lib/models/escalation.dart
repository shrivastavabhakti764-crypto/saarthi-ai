/// An "Are you okay?" check-in waiting for the senior's answer.
class Escalation {
  const Escalation({
    required this.id,
    required this.reason,
    required this.status,
    required this.graceDeadline,
  });

  final int id;
  final String reason;
  final String status;
  final DateTime graceDeadline;

  factory Escalation.fromJson(Map<String, dynamic> json) => Escalation(
        id: json['id'] as int,
        reason: json['reason'] as String,
        status: json['status'] as String,
        graceDeadline:
            DateTime.parse(json['grace_deadline'] as String).toLocal(),
      );
}