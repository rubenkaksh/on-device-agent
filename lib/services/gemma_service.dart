import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_gemma_poc/config/env_config.dart';
import 'package:flutter_gemma_poc/services/llm_service.dart';

/// Stop tokens for Gemma models — generation halts when any is emitted.
const List<String> _stopTokens = ['<end_of_turn>', '<eos>', '<start_of_turn>'];

/// Service wrapping flutter_gemma for on-device Gemma inference.
///
/// Handles model installation, loading, and chat with streaming responses.
/// Supports stop-token guardrails and generation cancellation.
class GemmaService implements LlmService {
  GemmaService();

  @visibleForTesting
  GemmaService.forTesting(InferenceChat chat) : _chat = chat;

  InferenceModel? _model;
  InferenceChat? _chat;

  bool _isInitialized = false;
  bool _isModelLoaded = false;

  /// Whether a generation stream is currently active.
  bool _isGenerating = false;
  @override
  bool get isGenerating => _isGenerating;

  Future<void>? _generationFuture;
  bool _stopRequested = false;

  static const _modelFileType = ModelFileType.litertlm;

  @override
  String get displayName => 'Gemma';

  @override
  String get defaultModelUrl =>
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm';

  /// Whether the service has been initialized (FlutterGemma.initialize called).
  @override
  bool get isInitialized => _isInitialized;

  /// Whether a model is loaded and ready for inference.
  @override
  bool get isModelLoaded => _isModelLoaded;

  /// Initialize the FlutterGemma plugin. Call once at app startup.
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    final hfToken = envValue('HF_TOKEN');
    await FlutterGemma.initialize(
      huggingFaceToken: hfToken ?? '',
      inferenceEngines: [
        MediaPipeEngine(), // Handles .task and .bin files
        LiteRtLmEngine(), // Handles .litertltm
      ],
    );
    _isInitialized = true;
  }

  /// Install and load the Gemma 2B model from a network URL.
  ///
  /// [modelUrl] — URL to the `.litertlm` model file (e.g. HuggingFace direct
  /// link).
  /// [onProgress] — optional callback with download progress 0-100.
  @override
  Future<void> installModel({
    required String modelUrl,
    void Function(int progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Call initialize() first.');
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: _modelFileType,
    ).fromNetwork(modelUrl).withProgress(onProgress ?? (_) {}).install();

    _isModelLoaded = true;
  }

  /// Check if a model is already installed (skip download).
  @override
  Future<bool> isModelInstalled() async {
    if (!_isInitialized) return false;
    if (!FlutterGemma.hasActiveModel()) return false;

    final activeModel =
        FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
    return switch (activeModel) {
      InferenceModelSpec spec => spec.fileType == _modelFileType,
      _ => false,
    };
  }

  /// Load the active model and create a chat session.
  ///
  /// Must be called after installModel() or if model is already installed.
  @override
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
  @override
  Stream<String> sendMessageStream(String userMessage) {
    if (_chat == null) {
      throw StateError('Call loadChat() first.');
    }
    if (_isGenerating) {
      throw StateError('A generation is already in progress.');
    }

    final controller = StreamController<String>();
    _isGenerating = true;
    _stopRequested = false;
    final generationCompleter = Completer<void>();
    final timer = GenerationTimer('GemmaService');
    _generationFuture = generationCompleter.future;

    () async {
      try {
        final chat = _chat;
        if (chat == null) {
          throw StateError('Call loadChat() first.');
        }

        await chat.addQuery(Message.text(text: userMessage, isUser: true));

        await for (final response in chat.generateChatResponseAsync()) {
          if (controller.isClosed) {
            _stopRequested = true;
            await _requestNativeStop();
            continue;
          }

          if (response is TextResponse) {
            timer.onChunk();
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

            // Emit any remaining text before stopping. Once cancellation has
            // been requested, drain the native stream without forwarding any
            // late tokens so its PredictDone lifecycle can finish.
            if (!_stopRequested && token.isNotEmpty) {
              controller.add(token);
            }

            if (hitStop) {
              _stopRequested = true;
              debugPrint(
                'GemmaService: Stop token detected — halting generation.',
              );
              await _requestNativeStop();
            }
          }
        }
      } catch (e) {
        // Native cancellation may surface as a stream error on some engines;
        // it is a normal completion path after a stop token or user cancel.
        if (!_stopRequested && !controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        timer.finish();
        _isGenerating = false;
        if (!controller.isClosed) {
          await controller.close();
        }
        if (!generationCompleter.isCompleted) {
          generationCompleter.complete();
        }
      }
    }();

    return controller.stream;
  }

  /// Cancel the current generation stream.
  ///
  /// Signals the native engine to stop and waits for the stream to unwind.
  /// Safe to call when no generation is active (no-op).
  @override
  Future<void> stopGeneration() async {
    if (!_isGenerating) return;

    _stopRequested = true;
    final generationFuture = _generationFuture;
    await _requestNativeStop();

    // Do not expose the next prompt until the native stream has unwound. The
    // MediaPipe session rejects addQueryChunk while its previous Predict call
    // is still completing, even if the local Dart stream was already closed.
    if (generationFuture != null) {
      await generationFuture;
    }
  }

  Future<void> _requestNativeStop() async {
    try {
      await _chat?.stopGeneration();
    } catch (e) {
      debugPrint('GemmaService: stopGeneration native call failed: $e');
    }
  }

  /// Clear conversation history and reset the chat session.
  @override
  Future<void> clearChat() async {
    if (_chat != null) {
      await _chat!.clearHistory();
    }
  }

  /// Dispose of model and chat resources.
  @override
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
