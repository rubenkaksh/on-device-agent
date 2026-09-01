import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

/// Stop tokens for Gemma models — generation halts when any is emitted.
const List<String> _stopTokens = [
  '<end_of_turn>',
  '<eos>',
  '<start_of_turn>',
];

/// Service wrapping flutter_gemma for on-device Gemma inference.
///
/// Handles model installation, loading, and chat with streaming responses.
/// Supports stop-token guardrails and generation cancellation.
class GemmaService {
  InferenceModel? _model;
  InferenceChat? _chat;

  bool _isInitialized = false;
  bool _isModelLoaded = false;

  /// Whether a generation stream is currently active.
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  /// Controller exposed so callers can cancel an in-flight stream.
  StreamController<String>? _activeController;

  /// Whether the service has been initialized (FlutterGemma.initialize called).
  bool get isInitialized => _isInitialized;

  /// Whether a model is loaded and ready for inference.
  bool get isModelLoaded => _isModelLoaded;

  /// Initialize the FlutterGemma plugin. Call once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken: const String.fromEnvironment('HF_TOKEN'),
      inferenceEngines: [
        MediaPipeEngine(), // Handles .task and .bin files
        LiteRtLmEngine(), // Handles .litertltm
      ],
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

    _model = await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: PreferredBackend.cpu,
    );
    _chat = await _model!.createChat(temperature: 0.2, randomSeed: 1, topK: 40);
  }

  /// Send a user message and get a streaming response with stop-token guardrails.
  ///
  /// Returns a [Stream] of text tokens. Generation stops when a stop token
  /// (`<end_of_turn>`, `<eos>`, `<start_of_turn>`) is detected — the literal
  /// stop-token text is stripped from the output.
  ///
  /// Call [stopGeneration] to cancel an in-flight stream.
  Stream<String> sendMessageStream(String userMessage) {
    if (_chat == null) {
      throw StateError('Call loadChat() first.');
    }

    final controller = StreamController<String>();
    _activeController = controller;
    _isGenerating = true;

    () async {
      try {
        await _chat!.addQuery(Message.text(text: userMessage, isUser: true));

        await for (final response in _chat!.generateChatResponseAsync()) {
          if (controller.isClosed) break;

          if (response is TextResponse) {
            var token = response.token;

            // Check if the token contains or is a stop token.
            bool hitStop = false;
            for (final stop in _stopTokens) {
              if (token.contains(stop)) {
                // Strip the stop token from the token text.
                token = token.replaceAll(stop, '');
                hitStop = true;
                break;
              }
            }

            // Emit any remaining text before stopping.
            if (token.isNotEmpty) {
              controller.add(token);
            }

            if (hitStop) {
              debugPrint('GemmaService: Stop token detected — halting generation.');
              break;
            }
          }
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        _isGenerating = false;
        _activeController = null;
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return controller.stream;
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

  /// Cancel the current generation stream.
  ///
  /// Signals the native engine to stop and closes the token stream controller.
  /// Safe to call when no generation is active (no-op).
  Future<void> stopGeneration() async {
    if (!_isGenerating) return;

    // Signal the native engine to stop producing tokens.
    try {
      await _chat?.stopGeneration();
    } catch (e) {
      debugPrint('GemmaService: stopGeneration native call failed: $e');
    }

    // Close the local stream controller.
    if (_activeController != null && !_activeController!.isClosed) {
      await _activeController!.close();
    }
    _isGenerating = false;
    _activeController = null;
  }

  /// Clear conversation history and reset the chat session.
  Future<void> clearChat() async {
    if (_chat != null) {
      await _chat!.clearHistory();
    }
  }

  /// Dispose of model and chat resources.
  Future<void> dispose() async {
    await stopGeneration();
    if (_model != null) {
      await _model!.close();
      _model = null;
      _chat = null;
      _isModelLoaded = false;
    }
  }
}
