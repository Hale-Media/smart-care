import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../features/ai/review/review_provider.dart';
import '../../features/ai/review/review_screen.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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
  final _tokenCtrl = TextEditingController();
  bool _useUrl = true;
  bool _showToken = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  String get _token => _tokenCtrl.text.trim();

  Future<void> _install() async {
    final value = _urlCtrl.text.trim();
    if (value.isEmpty) return;
    final ai = context.read<AiProvider>();
    if (_useUrl) {
      await ai.installFromUrl(value, token: _token.isNotEmpty ? _token : null);
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
          const SizedBox(height: 16),
          // HuggingFace token — required for gated Gemma models
          Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFFFFF8E1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.key_outlined, size: 16, color: Colors.amber),
                      SizedBox(width: 6),
                      Text(
                        'HuggingFace access token',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gemma models are gated — you need a free HuggingFace account '
                    'and a read token to download them. '
                    'Go to huggingface.co → Settings → Access Tokens.',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: !_showToken,
                    decoration: InputDecoration(
                      labelText: 'Token (hf_…)',
                      hintText: 'hf_xxxxxxxxxxxxxxxxxxxx',
                      suffixIcon: IconButton(
                        icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showToken = !_showToken),
                      ),
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Option A: public model — no token required
          _QuickInstallCard(
            title: 'FunctionGemma 270M (public)',
            subtitle: '284 MB · no login required · good general chat',
            requiresToken: false,
            onInstall: () => context.read<AiProvider>().installFromUrl(
              kFunctionGemmaUrl,
              modelType: ModelType.functionGemma,
            ),
          ),
          const SizedBox(height: 8),
          // Option B: Gemma 3 270M — requires HF token + gating approval
          _QuickInstallCard(
            title: 'Gemma 3 270M (gated)',
            subtitle: '~300 MB · requires HuggingFace token above',
            requiresToken: true,
            onInstall: () => context.read<AiProvider>().installFromUrl(
              kGemma3Url,
              token: _token.isNotEmpty ? _token : null,
            ),
          ),
          const SizedBox(height: 16),
          // Manual URL / path install
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom model source',
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
        ],
      ),
    );
  }
}

class _QuickInstallCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool requiresToken;
  final VoidCallback onInstall;

  const _QuickInstallCard({
    required this.title,
    required this.subtitle,
    required this.requiresToken,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onInstall,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Install'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
              progress < 100 ? 'Downloading model…' : 'Loading model…',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress > 0 ? progress / 100 : null),
            const SizedBox(height: 8),
            Text(
              progress > 0 ? '$progress%' : 'Starting…',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => context.read<AiProvider>().cancelInstall(),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: Colors.black54),
            ),
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
              onPressed: () => context.read<AiProvider>().resetToSetup(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
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
