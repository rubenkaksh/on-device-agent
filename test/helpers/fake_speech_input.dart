import 'dart:async';

import 'package:flutter_gemma_poc/speech/speech_input.dart';

/// [SpeechInput] that "hears" [nextUtterance] when [listen] is called.
class FakeSpeechInput implements SpeechInput {
  FakeSpeechInput({this.available = true, this.nextUtterance = ''});

  bool available;
  String nextUtterance;
  StreamController<SpeechTranscript>? _controller;

  @override
  String get displayName => 'Fake speech';

  @override
  bool get isListening => _controller != null;

  @override
  Future<bool> initialize() async => available;

  @override
  Stream<SpeechTranscript> listen() {
    final controller = StreamController<SpeechTranscript>();
    _controller = controller;
    scheduleMicrotask(() async {
      controller.add(SpeechTranscript(nextUtterance, isFinal: true));
      _controller = null;
      await controller.close();
    });
    return controller.stream;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {
    final controller = _controller;
    _controller = null;
    await controller?.close();
  }
}
