import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;

import 'package:flutter_gemma_poc/config/env_config.dart';
import 'package:flutter_gemma_poc/services/llm_service.dart';

/// Stop tokens that should never reach the UI. nobodywho applies the model's
/// chat template natively, so these are only a safety net; a hit is logged so
/// the spike can tell whether the net is ever needed.
const List<String> _stopTokens = ['<end_of_turn>', '<eos>', '<start_of_turn>'];

/// Gemma 3n E2B GGUF served through llama.cpp. Override with `NOBODYWHO_MODEL`
/// in `.env`. Unverified: Hugging Face was unreachable when this was written.
const String _defaultModel =
    'huggingface:unsloth/gemma-3n-E2B-it-GGUF/gemma-3n-E2B-it-Q4_K_M.gguf';

/// The slice of nobodywho's `Chat` this service needs; faked in tests.
abstract interface class NobodyWhoChat {
  Stream<String> ask(String message);
  void stopGeneration();
  Future<void> resetHistory();
}

/// Loads a chat from a model path or `huggingface:` identifier.
typedef NobodyWhoChatLoader =
    Future<NobodyWhoChat> Function(
      String modelPath, {
      required int contextSize,
      required void Function(int downloaded, int total) onDownloadProgress,
    });

class _RealChat implements NobodyWhoChat {
  _RealChat(this._chat);

  final nobodywho.Chat _chat;

  @override
  Stream<String> ask(String message) => _chat.ask(message);

  @override
  void stopGeneration() => _chat.stopGeneration();

  @override
  Future<void> resetHistory() => _chat.resetHistory();
}

Future<NobodyWhoChat> _loadRealChat(
  String modelPath, {
  required int contextSize,
  required void Function(int downloaded, int total) onDownloadProgress,
}) async {
  final chat = await nobodywho.Chat.fromPath(
    modelPath: modelPath,
    contextSize: contextSize,
    sampler: nobodywho.SamplerPresets.temperature(temperature: 0.2),
    onDownloadProgress: onDownloadProgress,
  );
  return _RealChat(chat);
}

/// [LlmService] backed by nobodywho (llama.cpp, GGUF models).
///
/// nobodywho downloads and caches the model inside `Chat.fromPath`, so
/// [installModel] both downloads and loads, and [isModelInstalled] is always
/// false: the install card is shown on each launch and the "download" is a
/// fast cache hit after the first run.
class NobodyWhoService implements LlmService {
  NobodyWhoService({NobodyWhoChatLoader loader = _loadRealChat})
    : _loader = loader;

  @visibleForTesting
  NobodyWhoService.forTesting(
    NobodyWhoChat? chat, {
    NobodyWhoChatLoader loader = _loadRealChat,
  }) : _loader = loader,
       _chat = chat,
       _isInitialized = true,
       _isModelLoaded = chat != null;

  final NobodyWhoChatLoader _loader;
  NobodyWhoChat? _chat;

  bool _isInitialized = false;
  bool _isModelLoaded = false;
  bool _isGenerating = false;
  bool _stopRequested = false;
  Future<void>? _generationFuture;
  int _contextSize = 4096;

  @override
  String get displayName => 'NobodyWho';

  @override
  String get defaultModelUrl => envValue('NOBODYWHO_MODEL') ?? _defaultModel;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  bool get isGenerating => _isGenerating;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await nobodywho.NobodyWho.init();
    _isInitialized = true;
  }

  @override
  Future<bool> isModelInstalled() async => false;

  @override
  Future<void> installModel({
    required String modelUrl,
    void Function(int progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Call initialize() first.');
    }
    _chat = await _loader(
      modelUrl,
      contextSize: _contextSize,
      onDownloadProgress: (downloaded, total) {
        if (total > 0) onProgress?.call(downloaded * 100 ~/ total);
      },
    );
    _isModelLoaded = true;
  }

  /// The chat is created by [installModel]; this only (re)loads from cache if
  /// the service was disposed. [maxTokens] maps to nobodywho's context size.
  @override
  Future<void> loadChat({int maxTokens = 1024}) async {
    if (!_isInitialized) {
      throw StateError('Call initialize() first.');
    }
    _contextSize = maxTokens < 4096 ? 4096 : maxTokens;
    if (_chat != null) return;
    await installModel(modelUrl: defaultModelUrl);
  }

  @override
  Stream<String> sendMessageStream(String userMessage) {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Call loadChat() first.');
    }
    if (_isGenerating) {
      throw StateError('A generation is already in progress.');
    }

    final controller = StreamController<String>();
    _isGenerating = true;
    _stopRequested = false;
    final done = Completer<void>();
    _generationFuture = done.future;
    final timer = GenerationTimer('NobodyWhoService');

    () async {
      try {
        await for (final chunk in chat.ask(userMessage)) {
          if (_stopRequested || controller.isClosed) {
            // Drain without forwarding so the native stream can finish.
            if (!_stopRequested) {
              _stopRequested = true;
              chat.stopGeneration();
            }
            continue;
          }
          timer.onChunk();

          var token = chunk;
          var hitStop = false;
          for (final stop in _stopTokens) {
            if (token.contains(stop)) {
              debugPrint('NobodyWhoService: literal stop token "$stop" seen.');
              token = token.replaceAll(stop, '');
              hitStop = true;
              break;
            }
          }
          if (token.isNotEmpty) controller.add(token);
          if (hitStop) {
            _stopRequested = true;
            chat.stopGeneration();
          }
        }
      } catch (e) {
        if (!_stopRequested && !controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        timer.finish();
        _isGenerating = false;
        if (!controller.isClosed) {
          await controller.close();
        }
        if (!done.isCompleted) done.complete();
      }
    }();

    return controller.stream;
  }

  @override
  Future<void> stopGeneration() async {
    if (!_isGenerating) return;
    _stopRequested = true;
    final generationFuture = _generationFuture;
    try {
      _chat?.stopGeneration();
    } catch (e) {
      debugPrint('NobodyWhoService: stopGeneration failed: $e');
    }
    // Don't expose the next prompt until the native stream has unwound.
    if (generationFuture != null) {
      await generationFuture;
    }
  }

  @override
  Future<void> clearChat() async {
    await _chat?.resetHistory();
  }

  @override
  Future<void> dispose() async {
    await stopGeneration();
    _chat = null;
    _isModelLoaded = false;
  }
}
