class LinkCode {
  const LinkCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  factory LinkCode.fromJson(Map<String, dynamic> json) {
    return LinkCode(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// A link between one senior and one nominee.
class LinkInfo {
  const LinkInfo({
    required this.id,
    required this.seniorId,
    required this.seniorName,
    required this.nomineeId,
    required this.nomineeName,
    required this.relationship,
    required this.whatsappOptIn,
    required this.createdAt,
    this.whatsappNumber,
  });

  final int id;
  final int seniorId;
  final String seniorName;
  final int nomineeId;
  final String nomineeName;
  final String relationship;
  final String? whatsappNumber;
  final bool whatsappOptIn;
  final DateTime createdAt;

  factory LinkInfo.fromJson(Map<String, dynamic> json) {
    return LinkInfo(
      id: json['id'] as int,
      seniorId: json['senior_id'] as int,
      seniorName: json['senior_name'] as String,
      nomineeId: json['nominee_id'] as int,
      nomineeName: json['nominee_name'] as String,
      relationship: json['relationship'] as String,
      whatsappNumber: json['whatsapp_number'] as String?,
      whatsappOptIn: json['whatsapp_opt_in'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}