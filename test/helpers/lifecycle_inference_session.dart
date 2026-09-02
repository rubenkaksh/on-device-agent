import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

/// Fake session that rejects a new query until the previous native turn is
/// stopped, matching the MediaPipe PredictDone/AddQueryChunk contract.
class LifecycleInferenceSession extends InferenceModelSession {
  StreamController<String>? _firstResponse;
  bool _nativeGenerationActive = false;
  int _generationCount = 0;
  int stopCalls = 0;

  @override
  Future<void> addQueryChunk(Message message) async {
    if (_nativeGenerationActive) {
      throw StateError(
        'PredictDone() AddQueryChunk should not be called before PredictDone',
      );
    }
  }

  @override
  Stream<String> getResponseAsync() {
    _generationCount += 1;
    if (_generationCount == 1) {
      final controller = StreamController<String>();
      _firstResponse = controller;
      _nativeGenerationActive = true;
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add('hello<end_of_turn>');
        }
      });
      return controller.stream;
    }

    if (_nativeGenerationActive) {
      throw StateError(
        'PredictDone() AddQueryChunk should not be called before PredictDone',
      );
    }

    _nativeGenerationActive = true;
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add('second');
        _nativeGenerationActive = false;
        controller.close();
      }
    });
    return controller.stream;
  }

  @override
  Future<String> getResponse() async => '';

  @override
  Future<int> sizeInTokens(String text) async => text.length;

  @override
  Future<void> stopGeneration() async {
    stopCalls += 1;
    _nativeGenerationActive = false;
    final response = _firstResponse;
    if (response != null && !response.isClosed) {
      unawaited(response.close());
    }
  }

  @override
  SessionMetrics getSessionMetrics() => SessionMetrics();

  @override
  Future<void> close() async {
    _nativeGenerationActive = false;
    final response = _firstResponse;
    if (response != null && !response.isClosed) {
      unawaited(response.close());
    }
  }
}
