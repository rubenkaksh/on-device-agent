/// Plug-and-play contract for speech-to-text.
///
/// Implemented by [NativeSpeechInput] (speech_to_text, on-device recognition).
/// Swap in Whisper, Gemma audio, Vosk, etc. by implementing this and changing
/// `speech_input_factory.dart` (or `SPEECH_INPUT` in `.env`).
abstract interface class SpeechInput {
  String get displayName;

  bool get isListening;

  /// Request permissions and set up the recognizer. Returns `false` when
  /// speech is unavailable or permission was denied.
  Future<bool> initialize();

  /// Start listening. Emits partial transcripts, then one [SpeechTranscript]
  /// with `isFinal: true`, then closes. Errors are emitted as stream errors.
  Stream<SpeechTranscript> listen();

  /// Stop listening early; the stream still emits its final transcript.
  Future<void> stop();

  /// Abort without a final transcript.
  Future<void> cancel();
}

class SpeechTranscript {
  const SpeechTranscript(this.text, {required this.isFinal});

  final String text;
  final bool isFinal;
}
