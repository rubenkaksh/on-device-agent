# Resources

## Primary references

1. [flutter_gemma on pub.dev](https://pub.dev/packages/flutter_gemma) — the
   package API, supported model file types, streaming, and cancellation
   contracts. The installed version used for this lesson is 1.7.0.
2. [flutter_gemma source repository](https://github.com/DenisovAV/flutter_gemma)
   — implementation and issue history for the Dart/native session boundary.
3. [Google AI Edge LLM Inference](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference)
   — official MediaPipe lifecycle and on-device generation concepts.
4. [Gemma 3n E2B LiteRT-LM model card](https://huggingface.co/google/gemma-3n-E2B-it-litert-lm)
   — the model artifact and its `.litertlm` format.
5. [Hugging Face tokenizer summary](https://huggingface.co/docs/transformers/tokenizer_summary)
   — why model tokens are not the same as characters or words.
6. [Google generation parameters](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/content-generation-parameters)
   — temperature and sampling parameter definitions. The API surface differs
   from `flutter_gemma`, but the sampling concepts are the same.

## Local source inspected

- `lib/services/gemma_service.dart`
- `lib/screens/chat_screen.dart`
- `test/gemma_service_test.dart`
- Installed `flutter_gemma` 1.7.0 `InferenceChat` and session implementations.

## How to use these

Start with today's lesson. Use the [reference cheat sheet](reference/gemma-generation-cheat-sheet.html) while reading code, then consult the primary references when changing model or engine configuration.
