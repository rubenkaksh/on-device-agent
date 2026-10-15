# D4 handoff: build and test the nobodywho spike on a Mac

Audience: a local Claude Code session (or you) on a Mac. The cloud session that wrote the spike had no device, no display and no Hugging Face access, so **nothing here has run against the real nobodywho engine**. Only `flutter analyze` and 16 fake-backed unit tests ran. Your job is to build it, run it, and fill in the evidence.

Background: `docs/sessions/nobodywho-spike.md` (findings, TODO table). Card: D4 in `docs/tasklog.md`.

## 0. Prerequisites

- Flutter stable, Dart `^3.8` (pubspec constraint). The spike was analyzed with Flutter 3.47.7 / Dart 3.13.5.
- Xcode with command line tools and CocoaPods (`pod --version`).
- For Android: Android Studio or the SDK, `adb`, and a **physical arm64 device**. nobodywho ships only arm64-v8a and x86_64 libraries. The x86_64 emulator needs `minSdk` 31+, and this app's `minSdk` is 24, so don't use it.
- Internet access on the Mac: `pod install` (nobodywho's podspec runs a `dart run` script that fetches prebuilt Rust frameworks) and the model download both need it.

## 1. Get the code

```bash
git fetch origin
git checkout feature/g6-gemma-poc   # D4 commits are on this branch (3f9c199 and later)
./run.sh pub get                    # creates .env from .env.example if missing
flutter analyze                     # expect: No issues found
flutter test                        # expect: All tests passed (16)
```

`.env` is gitignored. `run.sh` creates it, then runs `flutter` with your arguments.

## 2. Select the backend

Edit `.env`:

```
LLM_BACKEND=nobodywho
# Optional. Default is unverified: huggingface:unsloth/gemma-3n-E2B-it-GGUF/gemma-3n-E2B-it-Q4_K_M.gguf
# NOBODYWHO_MODEL=huggingface:owner/repo/file.gguf
```

Remove the line, or set `LLM_BACKEND=gemma`, for the flutter_gemma baseline. The backend is read at app start, so restart the app after changing it.

**If the default model 404s:** the repo/file name was never verified. Find a public Gemma GGUF on Hugging Face (llama.cpp-style `owner/repo-GGUF:QUANT` also works, repo name must end in `-GGUF`) and set `NOBODYWHO_MODEL`. Prefer a small quant (Q4_K_M) and check the file size against the device's free RAM (needs roughly 2x the file size).

## 3. Pick a target

### A. macOS desktop (easiest first smoke test)

```bash
./run.sh run -d macos
```

- Uses Metal. Use this to confirm the integration works before involving a phone.
- Run **debug or profile**. `macos/Runner/Release.entitlements` has the sandbox but **no `com.apple.security.network.client`**, so model downloads fail in a release build. DebugProfile has it. Add the key to Release.entitlements if you need a release build.
- macOS numbers don't represent phone performance. Don't put them in the comparison table without labeling them.

### B. Android (the target that matters)

```bash
adb devices
./run.sh run -d <device-id> --profile   # profile is closer to release speed than debug
```

- Main manifest now declares `INTERNET`, so release builds can download too.
- To compare GPU vs CPU, change `useGpu` in `_loadRealChat` (`lib/services/nobodywho_service.dart`). It defaults to true and is not wired to a switch.

### C. iOS device

```bash
open ios/Runner.xcworkspace   # set a signing team under Runner > Signing & Capabilities
./run.sh run -d <ios-device-id> --profile
```

- **Known risk, untested:** `ios/Runner.xcodeproj` has `IPHONEOS_DEPLOYMENT_TARGET = 12.0` and the Podfile's `platform` line is commented out, but the pods need more: nobodywho 13.0, flutter_gemma 15.0, flutter_gemma_mediapipe 16.0. If `pod install` complains about the deployment target, uncomment `platform :ios, '16.0'` in `ios/Podfile` and set the deployment target to 16.0 in Xcode. That is a project-wide change, so keep it in its own commit.
- iPhone 11 or newer with 4 GB+ RAM is recommended by the package.

## 4. Test checklist (nobodywho backend)

Mark each as pass/fail with a one-line note.

1. App launches, shows the install card titled "NobodyWho On-Device".
2. Tap Download. Progress advances, then the chat input appears.
3. Send a prompt. Tokens stream. No literal `<end_of_turn>`, `<eos>` or `<start_of_turn>` text in the reply.
4. Send a long prompt and tap Stop mid-stream. Generation halts promptly and the input re-enables.
5. Right after Stop, send a second prompt. It must work (the "second prompt lifecycle" bug from `lib/learning-records/0001`).
6. Long-press an assistant reply to copy it (D2 regression check).
7. Clear chat, then send another prompt. The model should not remember the previous turn.
8. Kill and relaunch. The install card should be **skipped** (`isModelInstalled()` matches the cached file name). If the card shows again, record what `getCachedModels()` returned.
9. Fill the context (long conversation). Confirm nothing crashes when nobodywho shifts context.
10. Search logs for `NobodyWhoService: literal stop token`. If it never appears across the runs, the defensive stripping in `NobodyWhoService` can be deleted.
11. Switch to `LLM_BACKEND=gemma`, restart, and repeat 2 to 7 to confirm no regression in the existing backend.

## 5. Measurements

Logs (`flutter logs`, or the `run` console) contain, per generation:

```
NobodyWhoService: ttft=…ms chunks=… rate=…/s
GemmaService: ttft=…ms chunks=… rate=…/s
```

Use the same device, same prompt, a profile or release build, and three runs per configuration. Record peak RAM from Xcode Instruments or `adb shell dumpsys meminfo <package>` and Stop-button latency by eye or screen recording. Put results in the TODO table in `docs/sessions/nobodywho-spike.md`, labeling the device and OS.

## 6. Troubleshooting

| Symptom | Likely cause |
|---|---|
| `NobodyWho.init()` error about a second call | init must run once per process. Services share a once-guard, so this means another call site exists. Search for `NobodyWho.init`. |
| Calling any nobodywho API throws before init | `initialize()` wasn't awaited before `installModel` or `loadChat`. |
| Download works in debug, fails in release (Android) | Manifest `INTERNET` missing. It is now in the main manifest. |
| Download fails on macOS release | Missing `network.client` entitlement (see 3A). |
| `pod install` deployment-target error (iOS) | See 3C. |
| Crash or "model failed to load" | Some GGUFs fail on formatting (README warns). Try another quant or model. |
| Out-of-memory kill | Model file too large for free RAM (needs about 2x). Use a smaller quant or model. |
| Download 404 | Default model name unverified (see 2). |

Enable nobodywho debug logs by adding a `package:logging` `onRecord` listener before `NobodyWho.init()` (see `docs/docs-flutter/logging-and-troubleshooting.md` in the nobodywho repo). It isn't wired up in this app.

## 7. Report back

Update `docs/sessions/nobodywho-spike.md`:

- Replace the "Unverified" answers (cancel, stop tokens, Android GPU) with what you observed.
- Fill the comparison table.
- Update the recommendation.

Commit to `feature/g6-gemma-poc`. Any PR needs a separate head branch, since this branch is also the PR base (see PR #4's setup).
