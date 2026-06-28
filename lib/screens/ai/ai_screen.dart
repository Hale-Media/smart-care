import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../features/ai/review/review_provider.dart';
import '../../features/ai/review/review_screen.dart';
import '../../providers/ai_provider.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 1 && mounted) {
        context.read<ReviewProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.chat_outlined), text: 'Assistant'),
            Tab(icon: Icon(Icons.rate_review_outlined), text: 'Review queue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_AssistantTab(), ReviewScreen()],
      ),
    );
  }
}

// ── Assistant tab ─────────────────────────────────────────────────────────────

class _AssistantTab extends StatelessWidget {
  const _AssistantTab();

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    return switch (ai.state) {
      ModelState.notInstalled => const _SetupCard(),
      ModelState.installing => _InstallingCard(progress: ai.progress),
      ModelState.loading => const _LoadingCard(),
      ModelState.error => _ErrorCard(message: ai.error),
      ModelState.ready => const _ChatView(),
    };
  }
}

// ── Setup card ────────────────────────────────────────────────────────────────

class _SetupCard extends StatefulWidget {
  const _SetupCard();

  @override
  State<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<_SetupCard> {
  final _urlCtrl = TextEditingController();
  bool _useUrl = true;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    final value = _urlCtrl.text.trim();
    if (value.isEmpty) return;
    final ai = context.read<AiProvider>();
    if (_useUrl) {
      await ai.installFromUrl(value);
    } else {
      await ai.installFromFile(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(
              Icons.psychology_outlined,
              size: 30,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'On-device AI assistant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Runs entirely on this device — resident data never leaves the app. '
            'You need a Gemma 3 .task model file (~300 MB for the 270M variant).',
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where is the model?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Download URL'),
                        icon: Icon(Icons.cloud_download_outlined),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Device path'),
                        icon: Icon(Icons.folder_outlined),
                      ),
                    ],
                    selected: {_useUrl},
                    onSelectionChanged: (s) =>
                        setState(() => _useUrl = s.first),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      labelText: _useUrl
                          ? 'Model URL (HuggingFace etc.)'
                          : 'File path on device',
                      hintText: _useUrl
                          ? 'https://huggingface.co/…/gemma3-270m-it.task'
                          : '/sdcard/Download/gemma3-270m-it.task',
                    ),
                    keyboardType: _useUrl
                        ? TextInputType.url
                        : TextInputType.text,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _install,
                    icon: const Icon(Icons.download),
                    label: Text(_useUrl ? 'Download & install' : 'Install'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ModelHelpTile(),
        ],
      ),
    );
  }
}

class _ModelHelpTile extends StatelessWidget {
  const _ModelHelpTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.info),
                SizedBox(width: 6),
                Text(
                  'Recommended model',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Gemma 3 270M IT (gemma3-270m-it-int4.task)\n'
              '~300 MB · runs on mid-range Android devices\n'
              'Available from HuggingFace: google/gemma-3-270m-it',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress / loading cards ──────────────────────────────────────────────────

class _InstallingCard extends StatelessWidget {
  final int progress;
  const _InstallingCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.download_outlined,
              size: 48,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              progress < 100 ? 'Installing model…' : 'Loading model…',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress / 100),
            const SizedBox(height: 8),
            Text('$progress%', style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading model into memory…',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String? message;
  const _ErrorCard({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.critical),
            const SizedBox(height: 12),
            const Text(
              'Model failed to load',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.read<AiProvider>().installFromFile(''),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry setup'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat view ─────────────────────────────────────────────────────────────────

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _scrollToBottom();
    await context.read<AiProvider>().send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    if (ai.messages.isEmpty && !ai.generating) {
      _scrollToBottom();
    }

    return Column(
      children: [
        Expanded(
          child: ai.messages.isEmpty
              ? const _EmptyChat()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: ai.messages.length,
                  itemBuilder: (_, i) => _Bubble(msg: ai.messages[i]),
                ),
        ),
        _InputBar(
          controller: _ctrl,
          generating: ai.generating,
          onSend: _send,
          onStop: () => context.read<AiProvider>().stopGeneration(),
          onClear: () => context.read<AiProvider>().clearChat(),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 56,
              color: Colors.black.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask me anything about care',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Medication questions · Care planning · Documentation help',
              style: TextStyle(fontSize: 12, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMsg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: msg.text.isEmpty
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.45,
                ),
              ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onClear;

  const _InputBar({
    required this.controller,
    required this.generating,
    required this.onSend,
    required this.onStop,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear chat',
              onPressed: generating ? null : onClear,
              color: Colors.black38,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: generating ? null : (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Ask something…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide(color: Color(0xFFD7E0E2)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            generating
                ? IconButton.filled(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.critical,
                    ),
                  )
                : IconButton.filled(
                    onPressed: onSend,
                    icon: const Icon(Icons.send),
                  ),
          ],
        ),
      ),
    );
  }
}
