// =============================================================================
//  THE ONLY FILE THAT TOUCHES flutter_gemma.
// -----------------------------------------------------------------------------
//  Targets flutter_gemma ~0.13.x (MediaPipe .task / LiteRT-LM .litertlm).
//  The package's session API has shifted across 0.x releases, so if you bump
//  the dependency and the compiler complains, this is the ONLY file to
//  reconcile — everything above it codes against InferenceEngine, not Gemma.
//
//  Reconciliation checklist if the API moved:
//    * model creation:     FlutterGemmaPlugin.instance.createModel(...)
//    * session creation:   model.createSession(...)  /  model.createChat(...)
//    * adding input:       session.addQueryChunk(Message.text(...))
//    * streaming response: session.getResponseAsync()  (Stream<String>
//                          in older builds; Stream<ModelResponse> once
//                          function-calling landed — unwrap TextResponse.text)
//  Check the installed version's README/CHANGELOG and adjust the marked spots.
// =============================================================================

import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'inference_engine.dart';
import 'model_descriptor.dart';

class GemmaEngine implements InferenceEngine {
  GemmaEngine(this._descriptor);

  final ModelDescriptor _descriptor;

  InferenceModel? _model;
  InferenceModelSession? _session;
  EngineStatus _status = EngineStatus.uninitialised;

  @override
  EngineStatus get status => _status;

  @override
  Future<void> initialise({
    required String modelPath,
    GenerationConfig config = const GenerationConfig(),
  }) async {
    _status = EngineStatus.loading;
    try {
      final gemma = FlutterGemmaPlugin.instance;

      // Point the plugin at the already-downloaded file (ModelManager owns
      // acquisition; we only register the path here).
      // ignore: deprecated_member_use
      await gemma.modelManager.setModelPath(modelPath);

      _model = await gemma.createModel(
        modelType: ModelType.gemmaIt,
        // GPU where available; the plugin falls back to CPU automatically.
        preferredBackend: PreferredBackend.gpu,
        maxTokens: config.maxTokens,
      );

      _session = await _model!.createSession(
        temperature: config.temperature,
        topK: config.topK,
        randomSeed: config.randomSeed ?? 1,
      );

      _status = EngineStatus.ready;
    } catch (e) {
      _status = EngineStatus.error;
      throw InferenceException('Failed to initialise Gemma engine', e);
    }
  }

  @override
  Future<String> generate(String prompt) async {
    final buffer = StringBuffer();
    await for (final chunk in generateStream(prompt)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    final session = _requireSession();
    _status = EngineStatus.generating;
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      // ── version-sensitive: older builds yield String tokens directly. ──
      yield* session.getResponseAsync();
    } catch (e) {
      _status = EngineStatus.error;
      throw InferenceException('Generation failed', e);
    } finally {
      if (_status == EngineStatus.generating) _status = EngineStatus.ready;
    }
  }

  @override
  Stream<String> chatStream(List<ChatTurn> turns) async* {
    final session = _requireSession();
    _status = EngineStatus.generating;
    try {
      for (final turn in turns) {
        await session.addQueryChunk(
          Message.text(text: turn.text, isUser: turn.isUser),
        );
      }
      yield* session.getResponseAsync();
    } catch (e) {
      _status = EngineStatus.error;
      throw InferenceException('Chat generation failed', e);
    } finally {
      if (_status == EngineStatus.generating) _status = EngineStatus.ready;
    }
  }

  @override
  Future<void> resetSession() async {
    await _session?.close();
    final config = _descriptor.defaultConfig;
    _session = await _model?.createSession(
      temperature: config.temperature,
      topK: config.topK,
    );
    _status = _model != null ? EngineStatus.ready : EngineStatus.uninitialised;
  }

  @override
  Future<void> dispose() async {
    await _session?.close();
    await _model?.close();
    _session = null;
    _model = null;
    _status = EngineStatus.uninitialised;
  }

  InferenceModelSession _requireSession() {
    final session = _session;
    if (session == null) {
      throw InferenceException('Engine not initialised — call initialise()');
    }
    return session;
  }
}
