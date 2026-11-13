import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../services/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/saarthi_avatar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>(
      create: (_) => ChatProvider(
        api: ApiClient(),
        auth: context.read<AuthProvider>(),
      ),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ChatProvider>().loadHistory();
      _scrollToEnd();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final chat = context.read<ChatProvider>();
    final text = _controller.text.trim();
    if (text.isEmpty || chat.sending) return;
    _controller.clear();
    final future = chat.send(text);
    _scrollToEnd();
    final ok = await future;
    if (!mounted) return;
    if (!ok) _controller.text = text;
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Saarthi')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            SaarthiAvatar(emotion: chat.emotion),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: chat.sending
                  ? Text('Saarthi is typing...', style: textTheme.bodySmall)
                  : null,
            ),
            Expanded(
              child: chat.loading && chat.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : chat.messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Say hello to Saarthi!',
                              style: textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: chat.messages.length,
                          itemBuilder: (_, i) =>
                              _Bubble(message: chat.messages[i]),
                        ),
            ),
            if (chat.escalation != null)
              _CheckInCard(
                busy: chat.responding,
                onAnswer: (answer) async {
                  await context.read<ChatProvider>().answerCheckIn(answer);
                  _scrollToEnd();
                },
              )
            else if (chat.notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(chat.notice!,
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center),
              ),
            if (chat.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(chat.error!, style: textTheme.bodyMedium),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: textTheme.bodyLarge,
                      decoration:
                          const InputDecoration(hintText: 'Type a message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: chat.sending ? null : _send,
                    iconSize: 28,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Are you okay?" with two big buttons.
class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.busy, required this.onAnswer});

  final bool busy;
  final void Function(String answer) onAnswer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Are you okay?',
              style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  onPressed: busy ? null : () => onAnswer('ok'),
                  child: const Text("I'm okay"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : () => onAnswer('need_help'),
                  child: const Text('I need help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isSenior;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Text(message.text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}