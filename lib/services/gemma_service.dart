import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

/// Service wrapping flutter_gemma for on-device Gemma inference.
///
/// Handles model installation, loading, and chat with streaming responses.
class GemmaService {
  InferenceModel? _model;
  InferenceChat? _chat;

  bool _isInitialized = false;
  bool _isModelLoaded = false;

  /// Whether the service has been initialized (FlutterGemma.initialize called).
  bool get isInitialized => _isInitialized;

  /// Whether a model is loaded and ready for inference.
  bool get isModelLoaded => _isModelLoaded;

  /// Initialize the FlutterGemma plugin. Call once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken: const String.fromEnvironment('HF_TOKEN', defaultValue: ''),
    );
    _isInitialized = true;
  }

  /// Install and load the Gemma 2B model from a network URL.
  ///
  /// [modelUrl] — URL to the .task model file (e.g. HuggingFace direct link).
  /// [onProgress] — optional callback with download progress 0-100.
  Future<void> installModel({
    required String modelUrl,
    void Function(int progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Call initialize() first.');
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
    ).fromNetwork(modelUrl).withProgress(onProgress ?? (_) {}).install();

    _isModelLoaded = true;
  }

  /// Check if a model is already installed (skip download).
  Future<bool> isModelInstalled() async {
    if (!_isInitialized) return false;
    return FlutterGemma.hasActiveModel();
  }

  /// Load the active model and create a chat session.
  ///
  /// Must be called after installModel() or if model is already installed.
  Future<void> loadChat({int maxTokens = 1024}) async {
    if (!_isInitialized) {
      throw StateError('Call initialize() first.');
    }

    _model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    _chat = await _model!.createChat(temperature: 0.8, randomSeed: 1, topK: 1);
  }

  /// Send a user message and get a streaming response.
  ///
  /// Returns a [Stream] of text tokens as they are generated.
  /// Each event is a single token string.
  Stream<String> sendMessageStream(String userMessage) async* {
    if (_chat == null) {
      throw StateError('Call loadChat() first.');
    }

    // Add user message to chat context
    await _chat!.addQuery(Message.text(text: userMessage, isUser: true));

    // Stream response tokens
    await for (final response in _chat!.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  /// Send a user message and get the complete response (non-streaming).
  Future<String> sendMessage(String userMessage) async {
    if (_chat == null) {
      throw StateError('Call loadChat() first.');
    }

    await _chat!.addQuery(Message.text(text: userMessage, isUser: true));
    final response = await _chat!.generateChatResponse();

    if (response is TextResponse) {
      return response.token;
    }
    return '';
  }

  /// Clear conversation history and reset the chat session.
  Future<void> clearChat() async {
    if (_chat != null) {
      await _chat!.clearHistory();
    }
  }

  /// Dispose of model and chat resources.
  Future<void> dispose() async {
    if (_model != null) {
      await _model!.close();
      _model = null;
      _chat = null;
      _isModelLoaded = false;
    }
  }
}
