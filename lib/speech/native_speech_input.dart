import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma_poc/speech/speech_input.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// [SpeechInput] using the platform recognizer via `speech_to_text`.
///
/// `onDevice: true` keeps audio on the phone (iOS SFSpeechRecognizer
/// on-device mode). If the device has no on-device model for the locale,
/// recognition fails rather than silently going to the cloud.
class NativeSpeechInput implements SpeechInput {
  NativeSpeechInput({SpeechToText? speech, this.localeId})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final String? localeId;

  StreamController<SpeechTranscript>? _controller;
  String _lastText = '';

  @override
  String get displayName => 'On-device speech';

  @override
  bool get isListening => _controller != null;

  @override
  Future<bool> initialize() =>
      _speech.initialize(onError: _onError, onStatus: _onStatus);

  @override
  Stream<SpeechTranscript> listen() {
    if (_controller != null) {
      throw StateError('Already listening.');
    }
    final controller = StreamController<SpeechTranscript>();
    _controller = controller;
    _lastText = '';

    unawaited(
      _speech
          .listen(
            onResult: _onResult,
            listenOptions: SpeechListenOptions(
              onDevice: true,
              partialResults: true,
              cancelOnError: true,
              listenMode: ListenMode.confirmation,
              pauseFor: const Duration(seconds: 3),
              listenFor: const Duration(seconds: 30),
              localeId: localeId,
            ),
          )
          .catchError((Object e) {
            controller.addError(e);
            _finish();
          }),
    );
    return controller.stream;
  }

  void _onResult(SpeechRecognitionResult result) {
    final controller = _controller;
    if (controller == null) return;
    _lastText = result.recognizedWords;
    controller.add(
      SpeechTranscript(result.recognizedWords, isFinal: result.finalResult),
    );
    if (result.finalResult) _finish();
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('NativeSpeechInput error: ${error.errorMsg}');
    final controller = _controller;
    if (controller == null) return;
    // "No match" just means silence — finish with whatever we heard.
    if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      controller.add(SpeechTranscript(_lastText, isFinal: true));
    } else {
      controller.addError(StateError(error.errorMsg));
    }
    _finish();
  }

  void _onStatus(String status) {
    // Recognizer stopped without a final result (e.g. user tapped stop).
    if (status == SpeechToText.doneStatus && _controller != null) {
      _controller?.add(SpeechTranscript(_lastText, isFinal: true));
      _finish();
    }
  }

  void _finish() {
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    _finish();
    await _speech.cancel();
  }
}
