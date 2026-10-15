# nobodywho spike (card D4)

Side-by-side of `nobodywho` 5.1.0 (llama.cpp, GGUF) against the existing `flutter_gemma` (MediaPipe / LiteRT-LM) backend. flutter_gemma stays the default; nothing was replaced.

**Evidence level:** the answers below come from reading the nobodywho 5.1.0 package source and changelog and from fake-backed unit tests. Nothing ran on a device or emulator, and Hugging Face was unreachable from the build container. "Unverified" marks what needs a real run.

## What changed

- `lib/services/llm_service.dart`: `LlmService` interface plus `GenerationTimer` (logs time-to-first-token and chunks/sec per generation).
- `GemmaService` now `implements LlmService`. Behaviour is unchanged.
- `lib/services/nobodywho_service.dart`: `NobodyWhoService` over `Chat.fromPath`, with a small `NobodyWhoChat` seam so tests never touch native code.
- `lib/services/llm_service_factory.dart`: backend switch, `LLM_BACKEND=gemma|nobodywho` in `.env` (default `gemma`).
- `ChatScreen` and `GemmaPocApp` take an `LlmService`. UI text uses the backend's `displayName`.
- Tests: `test/nobodywho_service_test.dart`, `test/helpers/fake_nobodywho_chat.dart`. 13 tests pass, `flutter analyze` is clean apart from the pre-existing missing `.env` asset warning on a fresh clone (`run.sh` creates it).
- `pubspec.yaml`: `nobodywho: ^5.1.0`. Plugin registrants regenerated for linux, macos and windows.

## How to try it

1. In `.env` set `LLM_BACKEND=nobodywho`. Optionally set `NOBODYWHO_MODEL=huggingface:owner/repo/file.gguf`.
2. `./run.sh run` on an Android or iOS device.
3. Tap Download. nobodywho downloads and caches inside `Chat.fromPath`, so it is a fast cache hit on later launches. `isModelInstalled()` is always false for this backend, so the install card shows on each launch.
4. Read `GemmaService:` / `NobodyWhoService:` lines from `flutter logs` for the throughput numbers.

Default model: `huggingface:unsloth/gemma-3n-E2B-it-GGUF/gemma-3n-E2B-it-Q4_K_M.gguf`. **Unverified.** I could not confirm the repo or file name, so override it if the download 404s.

## Findings

| Question | Answer |
|---|---|
| How to cancel mid-stream | `Chat.stopGeneration()` is synchronous and returns void. The `TokenStream` has no cancel of its own and ends after the stop. `NobodyWhoService.stopGeneration()` calls it, drains the stream, and waits for it to unwind before allowing the next prompt, the same lifecycle rule as `GemmaService` (see `lib/learning-records/0001`). Covered by a fake-backed test. Unverified against the real engine. |
| Stop tokens / chat template | The chat applies the model's template inside the Rust core, and the 5.1.0 changelog lists a fix for stray tokens after the end-of-turn token "seen with Gemma 3". So manual `<end_of_turn>` handling should be unnecessary. The service still strips them defensively and logs `literal stop token ... seen` if one ever reaches Dart. If that line never appears in device logs, the stripping can be deleted. Temperature 0.2 is set through `SamplerPresets.temperature`. Unverified at runtime. |
| Android GPU | 5.1.0 adds OpenCL and Vulkan backends on Android, and `Chat.fromPath(useGpu: true)` is the default. Which backend actually gets picked on a given device, and whether it beats CPU, is unverified. (An earlier desk-research note said the Android backend was undocumented. The changelog documents it.) |
| Web | Unsupported. Platforms are Android, iOS, macOS, Linux and Windows, and the repo has a `web/` folder this backend can't serve. |
| Device requirements | Package guidance: Android Snapdragon 855 / 6 GB RAM or better, iPhone 11 or newer with 4 GB, and free RAM of at least about 2x the model file. Android `minSdk` is 24. |
| Licence | EUPL-1.2: free for commercial use, no API key, but it is a copyleft licence. Get a legal read before distributing a build that includes it. |
| Context size | `Chat.fromPath(contextSize:)` defaults to 4096. The service uses `max(maxTokens, 4096)`, so `loadChat(maxTokens: 1024)` does not shrink it. |

## Spike limitations

- No streaming metadata beyond chunks. nobodywho does not report token counts per reply, so the rate is chunks/sec (accurate per token for nobodywho, approximate for flutter_gemma).
- `isModelInstalled()` is always false (see above), so the first screen is the install card.
- Download size for the Gemma 3n E2B Q4_K_M file is unchecked. Verify it fits the target device before testing.

## Device comparison (TODO, manual)

Fill in on the same physical Android device, same prompt, release or profile build, three runs each.

| Metric | flutter_gemma (litertlm, CPU) | nobodywho (`useGpu: true`) | nobodywho (`useGpu: false`) |
|---|---|---|---|
| Device / OS | TODO | TODO | TODO |
| Model file + size | TODO | TODO | TODO |
| Time to first token (ms) | TODO | TODO | TODO |
| Decode rate (chunks/s) | TODO | TODO | TODO |
| Peak RAM (MB) | TODO | TODO | TODO |
| Stop-button latency (ms) | TODO | TODO | TODO |
| Literal stop token seen in Dart? | TODO | TODO | TODO |

`useGpu: false` needs a one-line change in `_loadRealChat`, which isn't wired to a switch yet.

## Recommendation

Keep flutter_gemma as the default. Fill in the table above and decide on data. The interface and tests mean either backend can be removed later without touching the UI.
