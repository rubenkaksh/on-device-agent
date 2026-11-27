import 'package:flutter_gemma_poc/config/env_config.dart';
import 'package:flutter_gemma_poc/speech/native_speech_input.dart';
import 'package:flutter_gemma_poc/speech/speech_input.dart';

/// Speech backend selected by `SPEECH_INPUT` in `.env`.
///
/// To plug in a new STT engine: implement [SpeechInput], add an enum value
/// and a branch in [createSpeechInput].
enum SpeechInputKind {
  native;

  static SpeechInputKind fromEnv() => switch (envValue('SPEECH_INPUT')?.trim()) {
    _ => SpeechInputKind.native,
  };
}

SpeechInput createSpeechInput([SpeechInputKind? kind]) =>
    switch (kind ?? SpeechInputKind.fromEnv()) {
      SpeechInputKind.native => NativeSpeechInput(),
    };
