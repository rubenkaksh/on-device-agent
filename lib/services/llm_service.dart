import 'package:flutter/foundation.dart';

/// Backend-agnostic contract for an on-device chat LLM.
///
/// Implemented by `GemmaService` (flutter_gemma) and `NobodyWhoService`
/// (nobodywho / llama.cpp) so the chat UI can run against either.
abstract interface class LlmService {
  /// Short backend name used in the UI (e.g. "Gemma").
  String get displayName;

  /// Default model location passed to [installModel].
  String get defaultModelUrl;

  bool get isInitialized;
  bool get isModelLoaded;
  bool get isGenerating;

  /// Initialize the backend. Call once at app startup.
  Future<void> initialize();

  /// Whether a usable model is already on the device (skips the download).
  Future<bool> isModelInstalled();

  /// Download (if needed) and install the model.
  ///
  /// [onProgress] receives 0-100.
  Future<void> installModel({
    required String modelUrl,
    void Function(int progress)? onProgress,
  });

  /// Load the installed model and create a chat session.
  Future<void> loadChat({int maxTokens = 1024});

  /// Send [userMessage] and stream the response tokens.
  ///
  /// Stop tokens are stripped from the output. Throws [StateError] when no
  /// chat is loaded or a generation is already running.
  Stream<String> sendMessageStream(String userMessage);

  /// Cancel the in-flight generation and wait for it to unwind. No-op when
  /// idle.
  Future<void> stopGeneration();

  /// Clear conversation history.
  Future<void> clearChat();

  /// Release model and chat resources.
  Future<void> dispose();
}

/// Logs time-to-first-token and chunk throughput for one generation, so the
/// two backends can be compared on a real device.
///
/// Counts stream chunks, which approximates tokens (exact for nobodywho,
/// engine-dependent for flutter_gemma).
class GenerationTimer {
  GenerationTimer(this.label) : _watch = Stopwatch()..start();

  final String label;
  final Stopwatch _watch;
  Duration? _firstChunk;
  int _chunks = 0;

  void onChunk() {
    _firstChunk ??= _watch.elapsed;
    _chunks++;
  }

  void finish() {
    _watch.stop();
    final first = _firstChunk;
    if (first == null) return;
    final decodeSeconds = (_watch.elapsed - first).inMicroseconds / 1e6;
    final rate = decodeSeconds > 0 ? (_chunks - 1) / decodeSeconds : 0;
    debugPrint(
      '$label: ttft=${first.inMilliseconds}ms chunks=$_chunks '
      'rate=${rate.toStringAsFixed(1)}/s',
    );
  }
}
