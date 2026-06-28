import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

enum ModelState { notInstalled, installing, loading, ready, error }

/// Gemma 3 270M — requires HuggingFace token + gating approval
const kGemma3Url =
    'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma-3-270m-it.task';

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
        temperature: 0.7,
        topK: 40,
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

  Future<void> send(String text) async {
    if (_chat == null || _generating) return;

    _messages.add(ChatMsg(text: text, isUser: true));
    final int responseIndex = _messages.length;
    _messages.add(const ChatMsg(text: '', isUser: false));
    _generating = true;
    notifyListeners();

    final buffer = StringBuffer();
    try {
      await _chat!.addQuery(Message(text: text, isUser: true));
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
          _messages[responseIndex] =
              ChatMsg(text: buffer.toString(), isUser: false);
          notifyListeners();
        }
      }
    } catch (e) {
      dev.log('send failed', name: 'AiProvider', error: e);
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
    'Help care workers with questions about resident wellbeing, care practices, '
    'medication administration, and care documentation. '
    'Be concise and professional. Always prioritise resident safety. '
    'Do not provide specific medical diagnoses or prescriptions — '
    'advise consulting a nurse or GP for clinical decisions.';
