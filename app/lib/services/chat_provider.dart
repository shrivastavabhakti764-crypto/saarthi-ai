import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/escalation.dart';
import 'api_client.dart';
import 'auth_provider.dart';

/// The senior's conversation with Saarthi, and any "Are you okay?" waiting.
class ChatProvider extends ChangeNotifier {
  ChatProvider({required this._api, required this._auth});

  final ApiClient _api;
  final AuthProvider _auth;

  List<ChatMessage> _messages = const [];
  bool _loading = false;
  bool _sending = false;
  bool _responding = false;
  String? _error;
  String? _notice;
  String _emotion = 'neutral';
  Escalation? _escalation;
  bool _disposed = false;

  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  bool get sending => _sending;
  bool get responding => _responding;
  String? get error => _error;

  /// A short line shown after the senior answers "Are you okay?".
  String? get notice => _notice;
  String get emotion => _emotion;

  /// The "Are you okay?" waiting for an answer, or null.
  Escalation? get escalation => _escalation;

  String _token() {
    final token = _auth.token;
    if (token == null) throw ApiException('Please log in again.');
    return token;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadHistory() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _api.chatHistory(_token());
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages = list;
      final lastAi = list.reversed.where((m) => !m.isSenior).firstOrNull;
      _emotion = lastAi?.emotion ?? 'neutral';
    } on ApiException catch (e) {
      _error = e.message;
    }
    try {
      _escalation = await _api.activeEscalation(_token());
    } on ApiException {
      // The check-in card is an extra; the chat still works without it.
    }
    _loading = false;
    notifyListeners();
  }

  /// Returns false when the message could not be sent (the screen then puts
  /// the text back in the box).
  Future<bool> send(String text) async {
    if (_sending) return false;
    _sending = true;
    _error = null;
    _notice = null;
    final mine = ChatMessage(
      sender: 'senior',
      text: text,
      createdAt: DateTime.now(),
    );
    _messages = [..._messages, mine];
    notifyListeners();
    try {
      final reply = await _api.sendChat(_token(), text);
      _messages = [
        ..._messages,
        ChatMessage(
          sender: 'ai',
          text: reply.reply,
          emotion: reply.emotion,
          createdAt: DateTime.now(),
        ),
      ];
      _emotion = reply.emotion;

      if (reply.escalationId != null) {
        try {
          _escalation = await _api.activeEscalation(_token());
        } on ApiException {
          // Shown again the next time the chat is opened.
        }
      } else if (_escalation != null && reply.askedForHelp) {
        // Asking for help while "Are you okay?" was waiting: family is told now.
        _escalation = null;
        _notice = 'I have let your family know.';
      }
      return true;
    } on ApiException catch (e) {
      _messages = _messages.where((m) => !identical(m, mine)).toList();
      _error = e.message;
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// [answer] is 'ok' or 'need_help'.
  Future<void> answerCheckIn(String answer) async {
    final current = _escalation;
    if (current == null || _responding) return;
    _responding = true;
    _error = null;
    notifyListeners();
    try {
      final result =
          await _api.respondToEscalation(_token(), current.id, answer);
      _escalation = null;
      _notice = result.status == 'escalated'
          ? 'I have let your family know.'
          : 'I am glad you are okay.';
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _responding = false;
      notifyListeners();
    }
  }
}