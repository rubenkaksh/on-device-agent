import 'dart:async';

import 'package:flutter_gemma_poc/services/nobodywho_service.dart';

/// Scripted [NobodyWhoChat]: each `ask` replays the next entry of [replies].
///
/// Tokens are released one per microtask turn so tests can interleave
/// `stopGeneration`. After `stopGeneration` the current reply stops emitting
/// but the stream still unwinds, like the native engine.
class FakeNobodyWhoChat implements NobodyWhoChat {
  FakeNobodyWhoChat(this.replies);

  final List<List<String>> replies;
  final List<String> prompts = [];
  int stopCalls = 0;
  int resetCalls = 0;
  Object? errorAfterFirstToken;

  bool _stopped = false;
  int _next = 0;

  @override
  Stream<String> ask(String message) async* {
    prompts.add(message);
    _stopped = false;
    final tokens = replies[_next++];
    for (var i = 0; i < tokens.length; i++) {
      await Future<void>.delayed(Duration.zero);
      if (_stopped) return;
      yield tokens[i];
      final error = errorAfterFirstToken;
      if (i == 0 && error != null) throw error;
    }
  }

  @override
  void stopGeneration() {
    stopCalls++;
    _stopped = true;
  }

  @override
  Future<void> resetHistory() async {
    resetCalls++;
  }
}
