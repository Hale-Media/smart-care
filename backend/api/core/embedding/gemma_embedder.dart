// =============================================================================
//  ONE OF TWO FILES THAT TOUCH flutter_gemma (the other is gemma_engine.dart).
// -----------------------------------------------------------------------------
//  Targets the flutter_gemma ~0.13.x embedder API (EmbeddingGemma 308M / Gecko).
//
//  Unlike the LLM path — where ModelManager does its own atomic, checksummed
//  download — the embedder needs BOTH a model file AND a SentencePiece
//  tokenizer (with a platform-specific iOS tokenizer path). The package's
//  installer handles that two-file, per-platform dance, so we lean on it here
//  rather than reimplementing it. That asymmetry is deliberate.
//
//  Reconciliation checklist if you bump the package:
//    * install:    FlutterGemma.installEmbedder().modelFromNetwork(...)
//                    .tokenizerFromNetwork(...).install()
//    * activate:   FlutterGemma.getActiveEmbedder(preferredBackend: ...)
//    * embed:      embedder.generateEmbedding(text, taskType: TaskType.xxx)
//  In 0.16.x+ the plugin went modular (flutter_gemma_embeddings) with a
//  FlutterGemma.initialize(embeddingBackends: [...]) call — if you migrate,
//  this file is the only place to change.
// =============================================================================

import 'package:flutter_gemma/flutter_gemma.dart';

import 'embedder.dart';
import 'embedding_model_descriptor.dart';

class GemmaEmbedder implements Embedder {
  GemmaEmbedder(this._descriptor);

  final EmbeddingModelDescriptor _descriptor;
  dynamic _model; // package's active embedder handle
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  int get dimensions => _descriptor.dimensions;

  /// Install (if needed) and activate the embedder. Pass a token via the
  /// descriptor for gated hosts; never hardcode it.
  Future<void> install({String? authToken}) async {
    try {
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(_descriptor.modelUrl, token: authToken)
          .tokenizerFromNetwork(
            _descriptor.tokenizerUrl,
            token: authToken,
            iosPath: _descriptor.iosTokenizerUrl,
          )
          .install();
    } catch (e) {
      throw EmbeddingException('Failed to install embedder', e);
    }
  }

  @override
  Future<void> initialise() async {
    try {
      _model = await FlutterGemma.getActiveEmbedder(
        preferredBackend: PreferredBackend.gpu,
      );
      _ready = true;
    } catch (e) {
      _ready = false;
      throw EmbeddingException('Failed to activate embedder', e);
    }
  }

  @override
  Future<List<double>> embed(
    String text, {
    EmbeddingPurpose purpose = EmbeddingPurpose.document,
  }) async {
    _require();
    try {
      // ── version-sensitive: TaskType names per installed package version. ──
      final taskType = purpose == EmbeddingPurpose.query
          ? TaskType.retrievalQuery
          : TaskType.retrievalDocument;
      final List<double> vector =
          await _model.generateEmbedding(text, taskType: taskType);
      return vector;
    } catch (e) {
      throw EmbeddingException('Embedding failed', e);
    }
  }

  @override
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    EmbeddingPurpose purpose = EmbeddingPurpose.document,
  }) async {
    // The 0.13.x embedder is single-text; sequential is fine for the modest
    // record counts a care home generates. Swap for a native batch call if a
    // later version exposes one.
    final out = <List<double>>[];
    for (final t in texts) {
      out.add(await embed(t, purpose: purpose));
    }
    return out;
  }

  @override
  Future<void> dispose() async {
    try {
      await _model?.close();
    } catch (_) {
      // best-effort
    }
    _model = null;
    _ready = false;
  }

  void _require() {
    if (!_ready) {
      throw EmbeddingException('Embedder not initialised — call initialise()');
    }
  }
}
