import 'package:flutter/foundation.dart';

import 'embedding_model_descriptor.dart';
import 'gemma_embedder.dart';
import 'semantic_search_service.dart';

/// App-facing state for on-device semantic search. Wraps the embedder install,
/// the search service, and exposes index/search to the UI without leaking the
/// runtime. Register alongside [InferenceProvider] in main.dart.
class EmbeddingProvider extends ChangeNotifier {
  EmbeddingProvider({EmbeddingModelDescriptor? descriptor})
    : _descriptor = descriptor ?? kEmbeddingGemma300M;

  final EmbeddingModelDescriptor _descriptor;

  GemmaEmbedder? _embedder;
  SemanticSearchService? _search;

  bool _busy = false;
  String? _error;

  bool get isReady => _search != null && (_embedder?.isReady ?? false);
  bool get isBusy => _busy;
  String? get error => _error;
  int get indexedCount => _search?.indexedCount ?? 0;

  /// Install (first run) and activate the embedder, then stand up the search
  /// service. Idempotent-ish: safe to call again after failure.
  Future<void> setup({String? authToken}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final embedder = GemmaEmbedder(_descriptor);
      await embedder.install(authToken: authToken);
      await embedder.initialise();
      _embedder = embedder;
      _search = SemanticSearchService(embedder: embedder);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> index(
    String id,
    String text, {
    Map<String, dynamic> metadata = const {},
  }) async {
    await _require().index(id, text, metadata: metadata);
    notifyListeners();
  }

  Future<List<SearchHit>> search(
    String query, {
    int topK = 5,
    double minScore = 0.35,
  }) => _require().search(query, topK: topK, minScore: minScore);

  SemanticSearchService _require() {
    final s = _search;
    if (s == null) {
      throw StateError('Embedder not ready — call setup() first.');
    }
    return s;
  }

  @override
  void dispose() {
    _embedder?.dispose();
    super.dispose();
  }
}
