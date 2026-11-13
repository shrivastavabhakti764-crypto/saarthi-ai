/// One message in the conversation. [sender] is 'senior' for the person,
/// anything else is Saarthi.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.sender,
    required this.text,
    this.emotion,
    required this.createdAt,
  });

  final int? id;
  final String sender;
  final String text;
  final String? emotion;
  final DateTime createdAt;

  bool get isSenior => sender == 'senior';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int?,
        sender: json['sender'] as String,
        text: json['message_text'] as String,
        emotion: json['emotion'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

/// Saarthi's answer to one /chat call.
class ChatReply {
  const ChatReply({
    required this.reply,
    required this.language,
    required this.emotion,
    required this.symptomDetected,
    required this.askedForHelp,
    this.escalationId,
  });

  final String reply;
  final String language;
  final String emotion;
  final bool symptomDetected;
  final bool askedForHelp;

  /// Set when an "Are you okay?" is waiting for the senior's answer.
  final int? escalationId;

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        reply: json['reply'] as String,
        language: json['language'] as String,
        emotion: json['emotion'] as String,
        symptomDetected: json['symptom_detected'] as bool,
        askedForHelp: json['asked_for_help'] as bool,
        escalationId: json['escalation_id'] as int?,
      );
}