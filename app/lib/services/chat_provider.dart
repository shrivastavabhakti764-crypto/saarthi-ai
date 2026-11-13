import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import 'api_client.dart';
import 'auth_provider.dart';

/// The senior's conversation with Saarthi.
class ChatProvider extends ChangeNotifier {
  ChatProvider({required this._api, required this._auth});

  final ApiClient _api;
  final AuthProvider _auth;

  List<ChatMessage> _messages = const [];
  bool _loading = false;
  bool _sending = false;
  String? _error;
  String _emotion = 'neutral';
  bool _disposed = false;

  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;
  String get emotion => _emotion;

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
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns false when the message could not be sent (the screen then puts
  /// the text back in the box).
  Future<bool> send(String text) async {
    if (_sending) return false;
    _sending = true;
    _error = null;
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
}