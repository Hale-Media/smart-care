/// Metadata for an on-device embedding model. Unlike the LLM descriptor, this
/// carries a tokenizer URL too (SentencePiece), plus an iOS-specific tokenizer
/// path, because the embedder needs both files and iOS wants a pre-converted
/// JSON tokenizer.
class EmbeddingModelDescriptor {
  const EmbeddingModelDescriptor({
    required this.id,
    required this.displayName,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.dimensions,
    this.iosTokenizerUrl,
    this.requiresAuthToken = true,
    this.notes,
  });

  final String id;
  final String displayName;
  final String modelUrl;
  final String tokenizerUrl;

  /// iOS needs a JSON-converted tokenizer; the package selects this on iOS.
  final String? iosTokenizerUrl;

  /// Output vector size. EmbeddingGemma is 768 but supports Matryoshka
  /// truncation down to 128 for storage/speed tradeoffs.
  final int dimensions;

  final bool requiresAuthToken;
  final String? notes;
}

/// EmbeddingGemma 300M — the realistic default on-device embedder. Replace the
/// placeholder URLs with the concrete artifacts you're licensed to distribute.
const EmbeddingModelDescriptor kEmbeddingGemma300M = EmbeddingModelDescriptor(
  id: 'embeddinggemma-300m',
  displayName: 'EmbeddingGemma 300M',
  modelUrl: 'https://example.com/models/embeddinggemma-300m.tflite',
  tokenizerUrl: 'https://example.com/models/sentencepiece.model',
  // The package ships a converted iOS tokenizer on its release assets; point
  // at the matching version's tokenizer JSON.
  iosTokenizerUrl:
      'https://github.com/DenisovAV/flutter_gemma/releases/download/'
      'v0.13.1/embeddinggemma_tokenizer.json',
  dimensions: 768,
  requiresAuthToken: true,
  notes: '768-dim, ~200MB RAM quantised, multilingual. Truncatable to 128 '
      'via Matryoshka for tighter storage.',
);
