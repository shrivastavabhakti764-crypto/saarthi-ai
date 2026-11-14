/// An update for the family: a plain-language summary of a check-in that
/// the senior did not answer, or where they asked for help.
class AlertItem {
  const AlertItem({
    required this.id,
    required this.seniorId,
    required this.seniorName,
    required this.reason,
    required this.summary,
    required this.createdAt,
  });

  final int id;
  final int seniorId;
  final String seniorName;
  final String reason;
  final String summary;
  final DateTime createdAt;

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        id: json['id'] as int,
        seniorId: json['senior_id'] as int,
        seniorName: json['senior_name'] as String,
        reason: json['reason'] as String,
        summary: json['summary'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}