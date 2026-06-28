import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/inference/inference_engine.dart';
import '../../core/inference/inference_provider.dart';

/// Minimal streaming chat UI. Demonstrates token-by-token rendering and
/// disabling input while the model decodes. Conversation context is held by
/// the engine's session; "Reset" clears it.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatTurn> _messages = [];
  String _streaming = '';
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    final provider = context.read<InferenceProvider>();
    setState(() {
      _messages.add(ChatTurn(text: text, isUser: true));
      _controller.clear();
      _busy = true;
      _streaming = '';
    });
    _scrollToBottom();

    try {
      await for (final chunk in provider.chat([_messages.last])) {
        setState(() => _streaming += chunk);
        _scrollToBottom();
      }
      setState(() {
        _messages.add(ChatTurn(text: _streaming, isUser: false));
        _streaming = '';
      });
    } catch (e) {
      setState(() => _messages
          .add(ChatTurn(text: '⚠️ ${e.toString()}', isUser: false)));
    } finally {
      setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InferenceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text('On-device chat · ${provider.activeModel?.displayName ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Reset conversation',
            icon: const Icon(Icons.refresh),
            onPressed: _busy
                ? null
                : () async {
                    await provider.resetConversation();
                    setState(_messages.clear);
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_streaming.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return _Bubble(text: _streaming, isUser: false);
                }
                final m = _messages[i];
                return _Bubble(text: m.text, isUser: m.isUser);
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Ask something — nothing leaves the device',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _busy ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text.isEmpty ? '…' : text),
      ),
    );
  }
}
