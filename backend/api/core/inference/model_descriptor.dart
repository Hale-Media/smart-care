import 'inference_engine.dart';

/// Which native runtime a model file targets. Drives both the download
/// destination and which [InferenceEngine] implementation can load it.
enum ModelRuntime { gemma }

/// On-device model file formats.
///
/// - [task]      MediaPipe LLM Inference bundle. Works on Android, iOS, Web.
/// - [litertlm]  LiteRT-LM bundle. Required for desktop / NPU paths.
enum ModelFormat { task, litertlm }

/// Static metadata describing one model the app can run. Keep these in a
/// catalogue (see [kModelCatalogue]) so the model-setup UI can list options
/// without hardcoding URLs throughout the codebase.
class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.downloadUrl,
    required this.format,
    required this.runtime,
    required this.approxSizeMb,
    this.requiresAuthToken = false,
    this.defaultConfig = const GenerationConfig(),
    this.notes,
  });

  /// Stable slug used as the on-disk folder and preference key.
  final String id;
  final String displayName;
  final String fileName;
  final String downloadUrl;
  final ModelFormat format;
  final ModelRuntime runtime;
  final int approxSizeMb;

  /// Some hosts (e.g. Hugging Face gated repos) need a bearer token on the
  /// download request. Never bake the token into source — inject at runtime.
  final bool requiresAuthToken;

  final GenerationConfig defaultConfig;
  final String? notes;
}

/// The models offered to the user. Sizes are indicative; verify against the
/// actual artifact before shipping so the download progress UI is honest.
///
/// Smaller models (270M–0.6B) are the realistic default for mid-range phones;
/// E2B/E4B are flagship-only and should be opt-in over Wi-Fi.
const List<ModelDescriptor> kModelCatalogue = [
  ModelDescriptor(
    id: 'gemma3-270m-it',
    displayName: 'Gemma 3 270M (Instruct)',
    fileName: 'gemma3-270m-it.task',
    // Replace with the concrete artifact URL you are licensed to distribute.
    downloadUrl: 'https://example.com/models/gemma3-270m-it.task',
    format: ModelFormat.task,
    runtime: ModelRuntime.gemma,
    approxSizeMb: 300,
    requiresAuthToken: true,
    defaultConfig: GenerationConfig(maxTokens: 1024, temperature: 0.6),
    notes: 'Fast, tiny footprint. Best for classification/extraction, '
        'weaker at open-ended chat.',
  ),
  ModelDescriptor(
    id: 'qwen2.5-0.5b-it',
    displayName: 'Qwen 2.5 0.5B (Instruct)',
    fileName: 'qwen2.5-0.5b-it.task',
    downloadUrl: 'https://example.com/models/qwen2.5-0.5b-it.task',
    format: ModelFormat.task,
    runtime: ModelRuntime.gemma,
    approxSizeMb: 550,
    requiresAuthToken: true,
    notes: 'Good general-purpose balance for on-device chat.',
  ),
];

ModelDescriptor modelById(String id) =>
    kModelCatalogue.firstWhere((m) => m.id == id);
