import 'embedder.dart';
import 'vector_store.dart';

/// One retrieval hit: the matched text, its metadata, and relevance score.
class SearchHit {
  const SearchHit({
    required this.id,
    required this.text,
    required this.score,
    required this.metadata,
  });

  final String id;
  final String text;
  final double score;
  final Map<String, dynamic> metadata;
}

/// Couples an [Embedder] with a [VectorStore] to give the app a memory:
/// index private records on-device, then retrieve them by meaning.
///
/// This is the retrieval half of RAG. Feed the top hits back into the LLM as
/// context (see [buildContextBlock]) for grounded, private question-answering —
/// e.g. "which residents flagged a fall risk this week?" answered entirely
/// on-device against the care records you indexed.
class SemanticSearchService {
  SemanticSearchService({required Embedder embedder, VectorStore? store})
      : _embedder = embedder,
        _store = store ?? VectorStore();

  final Embedder _embedder;
  final VectorStore _store;

  VectorStore get store => _store;
  int get indexedCount => _store.length;

  /// Embed [text] as a document and add it to the index. [id] should be stable
  /// (e.g. the care-note primary key) so re-indexing upserts rather than dupes.
  Future<void> index(
    String id,
    String text, {
    Map<String, dynamic> metadata = const {},
  }) async {
    final vector = await _embedder.embed(text, purpose: EmbeddingPurpose.document);
    _store.add(VectorRecord(id: id, text: text, vector: vector, metadata: metadata));
  }

  /// Index many records efficiently, embedding them as documents in one batch.
  Future<void> indexAll(List<({String id, String text, Map<String, dynamic> metadata})> items) async {
    final vectors = await _embedder.embedBatch(
      items.map((i) => i.text).toList(),
      purpose: EmbeddingPurpose.document,
    );
    for (var i = 0; i < items.length; i++) {
      _store.add(VectorRecord(
        id: items[i].id,
        text: items[i].text,
        vector: vectors[i],
        metadata: items[i].metadata,
      ));
    }
  }

  /// Embed [query] as a query and return the best matches.
  Future<List<SearchHit>> search(
    String query, {
    int topK = 5,
    double minScore = 0.35,
  }) async {
    if (_store.length == 0) return const [];
    final queryVector =
        await _embedder.embed(query, purpose: EmbeddingPurpose.query);
    return _store
        .search(queryVector, topK: topK, minScore: minScore)
        .map((s) => SearchHit(
              id: s.record.id,
              text: s.record.text,
              score: s.score,
              metadata: s.record.metadata,
            ))
        .toList();
  }

  /// Format retrieved hits as a context block to prepend to an LLM prompt —
  /// the bridge from retrieval to generation (the "G" in RAG).
  String buildContextBlock(List<SearchHit> hits) {
    if (hits.isEmpty) return 'No relevant records found.';
    final buffer = StringBuffer('Relevant records:\n');
    for (final h in hits) {
      buffer.writeln('- ${h.text}');
    }
    return buffer.toString();
  }
}
