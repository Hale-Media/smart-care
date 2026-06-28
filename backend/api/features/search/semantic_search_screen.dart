import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/embedding/embedding_provider.dart';
import '../../core/embedding/semantic_search_service.dart';

/// Demo of on-device semantic search. Seeds a few sample care records, embeds
/// them locally, then lets you query by meaning ("falls", "low mood", "refused
/// food") and see relevance-ranked hits — no network involved.
class SemanticSearchScreen extends StatefulWidget {
  const SemanticSearchScreen({super.key});

  @override
  State<SemanticSearchScreen> createState() => _SemanticSearchScreenState();
}

class _SemanticSearchScreenState extends State<SemanticSearchScreen> {
  final _queryController = TextEditingController();
  List<SearchHit> _hits = [];
  bool _searching = false;
  bool _seeded = false;

  static const _sampleRecords = [
    (id: 'r1', text: 'Resident unsteady on feet this morning, near-stumble by the bathroom door.'),
    (id: 'r2', text: 'Ate a full lunch and chatted happily with staff in the lounge.'),
    (id: 'r3', text: 'Declined breakfast and dinner, seemed withdrawn and tearful.'),
    (id: 'r4', text: 'Complained of sharp pain in left hip during the hoist transfer.'),
    (id: 'r5', text: 'Slept well overnight, no call-bell use, settled mood.'),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final provider = context.read<EmbeddingProvider>();
    try {
      await provider.setup();
      for (final r in _sampleRecords) {
        await provider.index(r.id, r.text, metadata: {'type': 'care_note'});
      }
      setState(() => _seeded = true);
    } catch (_) {
      // error surfaced via provider.error
    }
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final hits = await context.read<EmbeddingProvider>().search(q, topK: 3);
      setState(() => _hits = hits);
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmbeddingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Semantic search (on-device)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !provider.isReady
            ? _SetupView(provider: provider, onSetup: _setup)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${provider.indexedCount} records indexed locally',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          decoration: const InputDecoration(
                            hintText: 'Search by meaning, e.g. "fall risk"',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _searching ? null : _search,
                        icon: _searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final h in _hits)
                          Card(
                            child: ListTile(
                              title: Text(h.text),
                              trailing: Text(h.score.toStringAsFixed(2)),
                            ),
                          ),
                        if (_hits.isEmpty && _seeded)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: Text('No results yet — try a query.')),
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

class _SetupView extends StatelessWidget {
  const _SetupView({required this.provider, required this.onSetup});

  final EmbeddingProvider provider;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'The embedder model is separate from the chat model.\n'
            'Install it once to enable on-device search.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(provider.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton.icon(
            onPressed: provider.isBusy ? null : onSetup,
            icon: provider.isBusy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(provider.isBusy ? 'Setting up…' : 'Install embedder & seed demo'),
          ),
        ],
      ),
    );
  }
}
