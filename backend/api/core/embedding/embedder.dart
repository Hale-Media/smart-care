/// Runtime-agnostic contract for on-device text embedding.
///
/// As with [InferenceEngine], nothing above this layer imports the embedding
/// runtime. The vector store and search service code against this interface.
library;

/// Embedding models like EmbeddingGemma are *asymmetric*: a passage you store
/// and a question you search with are embedded with different task prefixes for
/// best retrieval quality. Surface that distinction rather than hiding it.
enum EmbeddingPurpose {
  /// For text being stored/indexed (a care note, a document chunk).
  document,

  /// For a search query being matched against stored documents.
  query,
}

abstract class Embedder {
  bool get isReady;

  /// Dimensionality of vectors this embedder produces (e.g. 768 for
  /// EmbeddingGemma; can be truncated lower via Matryoshka if supported).
  int get dimensions;

  /// Prepare the embedder. The underlying model must already be installed
  /// (the Gemma adapter handles model+tokenizer acquisition itself).
  Future<void> initialise();

  /// Embed a single string.
  Future<List<double>> embed(
    String text, {
    EmbeddingPurpose purpose = EmbeddingPurpose.document,
  });

  /// Embed many strings. Implementations should batch natively where possible.
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    EmbeddingPurpose purpose = EmbeddingPurpose.document,
  });

  Future<void> dispose();
}

class EmbeddingException implements Exception {
  EmbeddingException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'EmbeddingException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
