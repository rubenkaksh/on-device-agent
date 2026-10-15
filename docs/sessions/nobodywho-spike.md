# nobodywho spike (card D4)

Side-by-side of `nobodywho` 5.1.0 (llama.cpp, GGUF) against the existing `flutter_gemma` (MediaPipe / LiteRT-LM) backend. flutter_gemma stays the default; nothing was replaced.

**Evidence level:** the answers below come from the nobodywho 5.1.0 package source and changelog, the Flutter docs source (`docs/docs-flutter/` in the nobodywho repo; docs.nobodywho.ooo itself is blocked from the build container), and fake-backed unit tests. Nothing ran on a device or emulator, and Hugging Face was unreachable from the build container. "Unverified" marks what needs a real run.

## What changed

- `lib/services/llm_service.dart`: `LlmService` interface plus `GenerationTimer` (logs time-to-first-token and chunks/sec per generation).
- `GemmaService` now `implements LlmService`. Behaviour is unchanged.
- `lib/services/nobodywho_service.dart`: `NobodyWhoService` over `Chat.fromPath`, with a small `NobodyWhoChat` seam so tests never touch native code.
- `lib/services/llm_service_factory.dart`: backend switch, `LLM_BACKEND=gemma|nobodywho` in `.env` (default `gemma`).
- `ChatScreen` and `GemmaPocApp` take an `LlmService`. UI text uses the backend's `displayName`.
- Tests: `test/nobodywho_service_test.dart`, `test/helpers/fake_nobodywho_chat.dart`. 13 tests pass, `flutter analyze` is clean apart from the pre-existing missing `.env` asset warning on a fresh clone (`run.sh` creates it).
- `pubspec.yaml`: `nobodywho: ^5.1.0`. Plugin registrants regenerated for linux, macos and windows.
- `AndroidManifest.xml` (main): added `INTERNET`. Debug and profile manifests already had it, so downloads would have worked in debug and failed in release.
- `NobodyWho.init()` runs once per process through a shared guard, because the docs say a second call throws.

## How to try it

1. In `.env` set `LLM_BACKEND=nobodywho`. Optionally set `NOBODYWHO_MODEL=huggingface:owner/repo/file.gguf`.
2. `./run.sh run` on an Android or iOS device.
3. Tap Download. nobodywho downloads and caches inside `Chat.fromPath`. `isModelInstalled()` checks `getCachedModels()` for the model's file name, so later launches load straight from the cache.
4. Read `GemmaService:` / `NobodyWhoService:` lines from `flutter logs` for the throughput numbers.

Default model: `huggingface:unsloth/gemma-3n-E2B-it-GGUF/gemma-3n-E2B-it-Q4_K_M.gguf`. **Unverified.** I could not confirm the repo or file name, so override it if the download 404s.

## Findings

| Question | Answer |
|---|---|
| How to cancel mid-stream | `Chat.stopGeneration()` is synchronous and returns void. The `TokenStream` has no cancel of its own and ends after the stop. `NobodyWhoService.stopGeneration()` calls it, drains the stream, and waits for it to unwind before allowing the next prompt, the same lifecycle rule as `GemmaService` (see `lib/learning-records/0001`). Covered by a fake-backed test. Unverified against the real engine. |
| Stop tokens / chat template | The chat applies the model's template inside the Rust core, and the 5.1.0 changelog lists a fix for stray tokens after the end-of-turn token "seen with Gemma 3". So manual `<end_of_turn>` handling should be unnecessary. The service still strips them defensively and logs `literal stop token ... seen` if one ever reaches Dart. If that line never appears in device logs, the stripping can be deleted. Temperature 0.2 is set through `SamplerPresets.temperature`. Unverified at runtime. |
| Android GPU | `useGpu` defaults to true. The 5.1.0 changelog adds OpenCL and Vulkan on Android, but the chat docs page still says nobodywho "relies purely on Vulkan", so the docs lag the release. Which backend a given device picks, and whether it beats CPU, is unverified. |
| Web | Unsupported. Platforms are Android, iOS, macOS, Linux and Windows, and the repo has a `web/` folder this backend can't serve. |
| Device requirements | Android Snapdragon 855 / Adreno 640 / 6 GB RAM or better, iPhone 11 or newer with 4 GB, free RAM of at least about 2x the model file. Native libraries are arm64-v8a and x86_64 only (no 32-bit). **The x86_64 emulator needs `minSdk` 31 or higher; this app's `minSdk` is 24, so use a physical arm64 device or an arm64 emulator.** |
| Docs coverage of cancel | The Flutter docs never mention `stopGeneration`, cancelling, or stop tokens. The cancel answer above rests on the package source only. |
| Licence | EUPL-1.2: free for commercial use, no API key, but it is a copyleft licence. Get a legal read before distributing a build that includes it. |
| Context size | `Chat.fromPath(contextSize:)` defaults to 4096. The service uses `max(maxTokens, 4096)`, so `loadChat(maxTokens: 1024)` does not shrink it. |

## Other things from the docs

- `Chat.fromPath(modelPath: "auto")` picks a chat model from available memory.
- `threadCount` defaults to performance cores; the docs suggest lowering it on phones so the UI keeps CPU headroom.
- Context fills trigger automatic shifting (keeps the first turn and last two, shrinks to half). Configurable with `ContextShiftOptions`.
- Debug logs: add a `package:logging` `onRecord` listener before `NobodyWho.init()` to see template, context-shift and tool activity. Not wired up in this app.
- Gated Hugging Face repos need `downloadModel(headers: {'Authorization': 'Bearer ...'})`. The default model is a public repo (unverified), so the app's `HF_TOKEN` isn't used by this backend.
- Model paths accept `hf:`, `huggingface:`, `owner/repo:QUANT` (repo must end in `-GGUF`), HTTPS URLs and local paths.
- The chat docs mention MTP speculative decoding with a Gemma 4 E2B draft model. Not tried here.

## Spike limitations

- No streaming metadata beyond chunks. nobodywho does not report token counts per reply, so the rate is chunks/sec (accurate per token for nobodywho, approximate for flutter_gemma).
- `isModelInstalled()` matches on file name only, not size or checksum, so a partial download would count as installed (unverified how nobodywho handles an interrupted download).
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
