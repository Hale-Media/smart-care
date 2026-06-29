import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

enum ModelState { notInstalled, installing, loading, ready, error }

/// Gemma 3 270M IT — requires HuggingFace token + gating approval.
/// Repo: litert-community/gemma-3-270m-it  File: gemma3-270m-it-q8.task (304 MB)
const kGemma3Url =
    'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task';

/// FunctionGemma 270M — public repo, no token required
const kFunctionGemmaUrl =
    'https://huggingface.co/sasha-denisov/function-gemma-270M-it/resolve/main/functiongemma-270M-it.task';

class ChatMsg {
  final String text;
  final bool isUser;
  const ChatMsg({required this.text, required this.isUser});
}

class AiProvider extends ChangeNotifier {
  ModelState _state = ModelState.notInstalled;
  String? _error;
  int _progress = 0;

  InferenceModel? _model;
  InferenceChat? _chat;
  CancelToken? _cancelToken;

  final List<ChatMsg> _messages = [];
  bool _generating = false;

  ModelState get state => _state;
  String? get error => _error;
  int get progress => _progress;
  List<ChatMsg> get messages => List.unmodifiable(_messages);
  bool get generating => _generating;

  AiProvider() {
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    if (FlutterGemma.hasActiveModel()) {
      await _loadModel();
    }
  }

  Future<void> installFromUrl(
    String url, {
    String? token,
    ModelType modelType = ModelType.gemmaIt,
  }) async {
    _cancelToken = CancelToken();
    _state = ModelState.installing;
    _progress = 0;
    _error = null;
    notifyListeners();
    try {
      await FlutterGemma.installModel(modelType: modelType)
          .fromNetwork(url, token: token?.isNotEmpty == true ? token : null)
          .withProgress((p) {
            _progress = p;
            notifyListeners();
          })
          .withCancelToken(_cancelToken!)
          .install();
      await _loadModel();
    } catch (e, st) {
      dev.log('installFromUrl failed', name: 'AiProvider', error: e, stackTrace: st);
      final cancelled = e.toString().toLowerCase().contains('cancel');
      _state = ModelState.notInstalled;
      _error = cancelled ? null : e.toString();
      _progress = 0;
      notifyListeners();
    } finally {
      _cancelToken = null;
    }
  }

  Future<void> installFromFile(String filePath) async {
    _cancelToken = CancelToken();
    _state = ModelState.installing;
    _progress = 0;
    _error = null;
    notifyListeners();
    try {
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromFile(filePath)
          .withCancelToken(_cancelToken!)
          .install();
      _progress = 100;
      notifyListeners();
      await _loadModel();
    } catch (e, st) {
      dev.log('installFromFile failed', name: 'AiProvider', error: e, stackTrace: st);
      final cancelled = e.toString().toLowerCase().contains('cancel');
      _state = ModelState.notInstalled;
      _error = cancelled ? null : e.toString();
      _progress = 0;
      notifyListeners();
    } finally {
      _cancelToken = null;
    }
  }

  void cancelInstall() {
    _cancelToken?.cancel('User cancelled');
  }

  void resetToSetup() {
    _state = ModelState.notInstalled;
    _error = null;
    _progress = 0;
    notifyListeners();
  }

  Future<void> _loadModel() async {
    _state = ModelState.loading;
    _error = null;
    notifyListeners();
    try {
      _model = await FlutterGemma.getActiveModel(maxTokens: 1024);
      _chat = await _model!.createChat(
        systemInstruction: _kSystemInstruction,
        temperature: 0.3,
        topK: 20,
      );
      _state = ModelState.ready;
      notifyListeners();
    } catch (e, st) {
      dev.log('_loadModel failed', name: 'AiProvider', error: e, stackTrace: st);
      _state = ModelState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Send a message to the model.
  ///
  /// [text] is shown in the chat UI. [promptText] is what the model actually
  /// receives — pass a RAG-augmented prompt here and the display stays clean.
  Future<void> send(String text, {String? promptText}) async {
    if (_chat == null || _generating) return;

    final llmText = promptText ?? text;
    _messages.add(ChatMsg(text: text, isUser: true));
    final int responseIndex = _messages.length;
    _messages.add(const ChatMsg(text: '', isUser: false));
    _generating = true;
    notifyListeners();

    final buffer = StringBuffer();
    try {
      // Each RAG prompt is self-contained — clear model history so the
      // previous turn's records don't double the context window.
      await _chat!.clearHistory();
      await _chat!.addQuery(Message(text: llmText, isUser: true));
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
          final text = buffer.toString().trimLeft();
          _messages[responseIndex] = ChatMsg(text: text, isUser: false);
          notifyListeners();
          // Detect repetition: 60-char window appearing twice = looping.
          if (text.length > 200) {
            final window = text.substring(text.length - 60);
            final count = RegExp(RegExp.escape(window)).allMatches(text).length;
            if (count >= 2) {
              try { await _chat!.stopGeneration(); } catch (_) {}
              break;
            }
          }
        }
      }
    } catch (e, st) {
      dev.log('send failed', name: 'AiProvider', error: e, stackTrace: st);
      _messages[responseIndex] = ChatMsg(text: 'Error: $e', isUser: false);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  Future<void> stopGeneration() async {
    await _chat?.stopGeneration();
    _generating = false;
    notifyListeners();
  }

  void setMessages(List<ChatMsg> msgs) {
    _messages
      ..clear()
      ..addAll(msgs);
    notifyListeners();
  }

  Future<void> clearChat() async {
    if (_chat == null) return;
    await _chat!.clearHistory();
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _chat?.close();
    super.dispose();
  }
}

const _kSystemInstruction =
    'You are a helpful AI assistant for a UK care home. '
    'When care home records are provided to you, read them carefully and '
    'use them to answer questions accurately and factually. '
    'You can discuss residents, their documented conditions, medications, '
    'care notes, and handover summaries based on what the records say. '
    'Be concise and professional. Always prioritise resident safety. '
    'Do not prescribe new medications or make new clinical diagnoses — '
    'for new clinical decisions advise consulting a nurse or GP.';
