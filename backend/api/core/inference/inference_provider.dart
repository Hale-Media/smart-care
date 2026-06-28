import 'package:flutter/foundation.dart';

import 'inference_engine.dart';
import 'model_descriptor.dart';
import 'model_manager.dart';

/// Factory so the provider can build the right engine for a descriptor's
/// runtime without importing any concrete engine itself.
typedef EngineFactory = InferenceEngine Function(ModelDescriptor descriptor);

/// App-facing state holder. UI listens to this; it never sees flutter_gemma.
///
/// Wire it up in main.dart:
///   ChangeNotifierProvider(
///     create: (_) => InferenceProvider(
///       manager: ModelManager(),
///       engineFactory: (d) => GemmaEngine(d),
///     ),
///   )
class InferenceProvider extends ChangeNotifier {
  InferenceProvider({
    required ModelManager manager,
    required EngineFactory engineFactory,
  })  : _manager = manager,
        _engineFactory = engineFactory;

  final ModelManager _manager;
  final EngineFactory _engineFactory;

  InferenceEngine? _engine;
  ModelDescriptor? _activeModel;

  EngineStatus get status => _engine?.status ?? EngineStatus.uninitialised;
  ModelDescriptor? get activeModel => _activeModel;
  bool get isReady => status == EngineStatus.ready;

  /// The live engine, for services (e.g. ExtractionService) that need to drive
  /// it directly. Throws if no model is active.
  InferenceEngine get activeEngineOrThrow => _requireEngine();

  // ── Download state ────────────────────────────────────────────────────
  double? _downloadFraction;
  bool _downloading = false;
  String? _error;

  double? get downloadFraction => _downloadFraction;
  bool get isDownloading => _downloading;
  String? get error => _error;

  Future<bool> isInstalled(ModelDescriptor d) => _manager.isInstalled(d);

  /// SHA-256 of the active model's weights, for stamping onto exports/audits.
  Future<String?> activeModelChecksum() async {
    final model = _activeModel;
    if (model == null) return null;
    return _manager.recordedChecksum(model);
  }

  /// Download a model if needed, reporting progress to listeners.
  Future<void> ensureDownloaded(
    ModelDescriptor descriptor, {
    String? authToken,
  }) async {
    if (await _manager.isInstalled(descriptor)) return;
    _downloading = true;
    _downloadFraction = 0;
    _error = null;
    notifyListeners();
    try {
      await _manager.download(
        descriptor,
        authToken: authToken,
        onProgress: (fraction, _) {
          _downloadFraction = fraction;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  /// Load a downloaded model into memory and make it the active engine.
  Future<void> activate(ModelDescriptor descriptor) async {
    _error = null;
    notifyListeners();
    try {
      await _engine?.dispose();
      final engine = _engineFactory(descriptor);
      final path = await _manager.pathFor(descriptor);
      await engine.initialise(
        modelPath: path,
        config: descriptor.defaultConfig,
      );
      _engine = engine;
      _activeModel = descriptor;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Stream a single-prompt completion. Notifies on status transitions so the
  /// UI can disable input while generating.
  Stream<String> generate(String prompt) async* {
    final engine = _requireEngine();
    notifyListeners();
    try {
      yield* engine.generateStream(prompt);
    } finally {
      notifyListeners();
    }
  }

  Stream<String> chat(List<ChatTurn> turns) async* {
    final engine = _requireEngine();
    notifyListeners();
    try {
      yield* engine.chatStream(turns);
    } finally {
      notifyListeners();
    }
  }

  Future<void> resetConversation() async {
    await _engine?.resetSession();
    notifyListeners();
  }

  InferenceEngine _requireEngine() {
    final engine = _engine;
    if (engine == null) {
      throw InferenceException('No active model — call activate() first.');
    }
    return engine;
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }
}
