/// Runtime-agnostic contract for on-device language model inference.
///
/// Nothing above this layer (providers, services, UI) should ever import
/// `flutter_gemma` or any other runtime directly. Swap the concrete engine
/// (Gemma / llama.cpp / ONNX) by changing one binding in `main.dart`.
library;

/// A single turn in a conversation handed to the engine.
class ChatTurn {
  const ChatTurn({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// Lifecycle state of the engine, surfaced to the UI without leaking
/// runtime-specific types.
enum EngineStatus { uninitialised, loading, ready, generating, error }

/// Tuning knobs common to most on-device runtimes. Engines map these onto
/// their own session parameters and ignore anything they don't support.
class GenerationConfig {
  const GenerationConfig({
    this.temperature = 0.7,
    this.topK = 40,
    this.maxTokens = 1024,
    this.randomSeed,
  });

  final double temperature;
  final int topK;
  final int maxTokens;
  final int? randomSeed;
}

/// The one interface the rest of the app codes against.
abstract class InferenceEngine {
  EngineStatus get status;

  /// Load weights into memory and prepare a session. Must be called once the
  /// model file is present on disk (see [ModelManager]). Safe to await on a
  /// background isolate boundary if the runtime supports it.
  Future<void> initialise({
    required String modelPath,
    GenerationConfig config = const GenerationConfig(),
  });

  /// One-shot completion. Convenience wrapper over [generateStream] that
  /// collects the full response. Prefer the stream for interactive UIs.
  Future<String> generate(String prompt);

  /// Streaming completion. Yields incremental text chunks as the model
  /// decodes. Throwing inside the stream sets [status] to error.
  Stream<String> generateStream(String prompt);

  /// Multi-turn variant that preserves conversational context across calls.
  /// Each call appends [turns] and streams the assistant reply.
  Stream<String> chatStream(List<ChatTurn> turns);

  /// Clears conversational context but keeps weights resident in memory.
  Future<void> resetSession();

  /// Releases weights and native resources. Call from dispose paths.
  Future<void> dispose();
}

/// Raised for any engine-level failure so callers never catch runtime-specific
/// exception types.
class InferenceException implements Exception {
  InferenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'InferenceException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
