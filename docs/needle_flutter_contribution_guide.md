# needle_flutter — Contribution Prep Guide

> Route: **① open an issue on `cactus-compute/needle` → ② build and publish your own
> `needle_flutter` package → ③ offer it upstream once the maintainers agree.**
> You write the code. This guide covers what to know, set up, decide and verify.

Research date: 2026-09-26, against `cactus-compute/needle` `main` (engine 3.0.2).

---

## 0. What the research changed

| Earlier assumption | What the source actually says | Source |
|---|---|---|
| No Android/iOS engine | **Prebuilt engines are published** for `android-arm64`, `android-armv7`, `ios-arm64`, `ios-sim-arm64` (plus tvOS and watchOS) | `needle/agent/fetch.py` → `PLATFORMS` |
| We would cross-compile the C engine | **The engine source is not in the repo.** It ships as binaries on Hugging Face (`Cactus-Compute/needle3/<platform>/`). You **wrap** a binary; you don't build it | repo tree, `fetch.download_platform` |
| No system prompt | `system` exists, but it is for **facts, not instructions** (`date`, `locale`, `device`, `battery`, `network`, `location`, `user`, `assistant`) | `llms.txt` → *System facts* |
| Guidance only via descriptions | Tools also take **`triggers`**: regexes that force a call for a matching request | `llms.txt` line 26 |
| Local LoRA keeps confidence | **Local `needle finetune` + `build --lora` drop the confidence head, so `confidence` becomes `null`.** Only platform fine-tunes keep it. Local builds are 4-bit | `llms.txt` → *Confidence gating*, *Playground* |
| Swap models at runtime | **The engine cannot unload weights.** Once a tuned `.cact` is loaded, the process is stuck with it | `llms.txt` → *Common mistakes* |
| Tools can change per call | **One toolset per session.** Changing tools means calling `needle_init` again | `llms.txt` → *Behaviour contract* |

> **M0 correction (2026-10-02):** `needle build --platform android-arm64` yields a static `libneedle.a`, a `needle` executable and `needle.h`, with **no `.so`**. Android is a static link like iOS: build your own shared library (CMake + NDK) and set `-Wl,-z,max-page-size=16384` yourself. The header has a sixth function, `needle_last_error`. See `needle_m0_results.md` and `needle_flutter_two_day_schedule.md`.

The two Needle-3 rows in `needle3_implementation_plan.md` have been corrected to match.

---

## 1. The whole engine surface: 5 C functions

These signatures come from the Python `ctypes` binding (`needle/__init__.py`) and the stub engine in `tests/test_worker.py`. Confirm them against the real header that `needle build --platform` downloads.

```c
int  needle_load(const unsigned char* data, unsigned long long size); // <0 = error
int  needle_init(const char* system, const char* tools_json,
                 const char* tool_index_path /* nullable */);        // returns prefix tokens, <0 = error
int  needle_complete(const char* input, int max_new_tokens,
                     char* output, int capacity);                     // writes JSON envelope; <0 = error (msg in output)
int  needle_embed(const char* text, float* out /* nullable */, int dim); // out=NULL → returns dim; then fill
void needle_reset(void);                                              // clear history, keep tools
```

**Call order:** `needle_load(weights)` once → `needle_init(system, tools)` → `needle_complete(...)` repeatedly. Call `needle_reset()` between independent queries. The engine behaves as **one global instance per process**; the Python wrapper tracks a single `_active` agent.

**Response envelope** (from `llms.txt`):

```json
{"type":"call","success":true,"error":null,"error_code":null,
 "function_calls":[{"name":"set_lights","arguments":{"room":"living room","on":true}}],
 "suppressed_calls":[...], "reasoning":"...", "confidence":0.94,
 "validation":{"ungrounded":["tool.field"]}, "prefill_tps":4300.0, "decode_tps":850.0}
```

**Logic that lives in the Python wrapper, not the engine.** Port it to Dart, because it is part of the value you add:

| Python behaviour | Where |
|---|---|
| Prefix a `date: YYYY-MM-DD Ddd HH:MM` fact to `system` unless one is already there | `_with_date_fact` |
| Warn after 4 turns without `reset()`; `stateless` mode resets before every call | `UNRESET_TURNS`, `complete()` |
| Grounding check (`validation.ungrounded`, year check) and `strict` refusal in `run()` | `_annotate_ungrounded`, `run()` |
| Report `confidence` as null when the weights have no confidence head | `_confidence_head_present` |
| Tool loop: execute calls, feed the JSON result back through `complete()` | `run()` |
| Build a schema from a function (Dart: from a builder or class) | `agent/tools.py` |

---

## 2. Skills gap: what to learn before coding

You know C/C++ and Flutter. These are new, in priority order:

| # | Topic | What you need from it | Time |
|---|---|---|---|
| 1 | **`dart:ffi` basics** | `DynamicLibrary`, `NativeFunction` typedefs, `Pointer<Utf8>`, `calloc`/`free` from `package:ffi`, `toNativeUtf8()`, `Pointer<Float>.asTypedList` | ½ day |
| 2 | **`package:ffigen`** | Generate bindings from the downloaded header instead of writing them by hand | 1 h |
| 3 | **Isolates for blocking FFI** | A long-lived worker isolate with a `SendPort`/`ReceivePort` protocol. FFI calls block their thread, so they must not run on the UI isolate | ½ day |
| 4 | **Flutter FFI plugin template** | `flutter create --template=plugin_ffi`: how Android `jniLibs` and iOS `vendored_frameworks` ship a **prebuilt** binary | ½ day |
| 5 | **Android native packaging** | `jniLibs/<abi>/`, ABI filters, **16 KB page-size alignment** (Play requires it for Android 15+ targets), `readelf -l` to check `LOAD` alignment | 2 h |
| 6 | **iOS native packaging** | `.xcframework` with `ios-arm64` + `ios-arm64-simulator` slices; dynamic framework vs static `.a` (`DynamicLibrary.process()` + `-force_load`); code signing; CocoaPods podspec **and** Swift Package Manager support for Flutter plugins | ½ day |
| 7 | **pub.dev publishing** | Verified publisher, `pana` score, `example/`, `CHANGELOG.md`, semver, `dart pub publish --dry-run` | 1 h |

Reading list:
- dart.dev → *C interop using dart:ffi*
- docs.flutter.dev → *Binding to native code using dart:ffi* (Android and iOS sections)
- `package:ffigen` README
- developer.android.com → *Support 16 KB page sizes*
- Apple → *Creating a multiplatform binary framework bundle* (xcframework)
- The Needle repo itself: `llms.txt`, `needle/__init__.py`, `needle/_worker.py`, `tests/test_worker.py`

---

## 3. Toolchain setup (Mac)

```bash
# Flutter / Dart (you have these)
flutter --version                  # 3.35+ recommended; Dart 3.8+ (matches on-device-agent)

# iOS
xcode-select --install; sudo xcodebuild -license accept
sudo gem install cocoapods         # or rely on SPM-enabled Flutter

# Android: Android Studio → SDK Manager → NDK (Side by side) + CMake
export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/<version>

# ffigen needs libclang
brew install llvm

# Needle tooling (fetch engines, reference outputs, fine-tuning later)
python3.12 -m venv ~/.venvs/needle && source ~/.venvs/needle/bin/activate
pip install cactus-needle "cactus-needle[train]"
export NEEDLE_TELEMETRY=0          # see §8
```

Devices: one physical flagship **Android (arm64)** and one **iPhone**. Also the iOS simulator on Apple Silicon, since `ios-sim-arm64` exists. There is no x86_64 Android emulator engine, so use an arm64 emulator image or a real device.

---

## 4. Step 1: Explore the engine on your Mac (first session, ~2 h)

Goal: resolve the unknowns in §10 before writing any Dart code.

```bash
mkdir needle-explore && cd needle-explore

# 1. Reference behaviour in Python
python - <<'EOF'
import needle, json
tools=[{"name":"add_note","description":"Save a note. Use when the user says note, write down, remember.",
        "parameters":{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}}]
a=needle.Needle(tools=tools, system="locale: en-US; device: phone")
print(json.dumps(a.complete("remember to buy milk"), indent=2))
print(len(a.embed("buy milk")))           # embedding dimension
EOF

# 2. Pull mobile engines + header + weights
needle build --platform android-arm64 --out ./engines
needle build --platform ios-arm64     --out ./engines
needle build --platform ios-sim-arm64 --out ./engines
ls -la engines/*/

# 3. Inspect what you got
file engines/*/*
llvm-nm -D --defined-only engines/android-arm64/*.so | grep needle_
llvm-readelf -l engines/android-arm64/*.so | grep -A1 LOAD   # alignment: want 0x4000 (16 KB)
cat engines/*/*.h
```

Record in `docs/sessions/<date>.md`:
- the file list per platform
- the exact header
- whether iOS ships as a dylib, framework, or static `.a`
- ELF alignment
- embedding dimension
- the size of `needle3.cact`

---

## 5. Step 2: Open the issue (before or right after Step 1)

Use the draft in `docs/needle_issue_draft.md`. Fill in the Step 1 results so the issue is concrete. The `needle` repo has **no CONTRIBUTING.md**. The main `cactus` repo's CONTRIBUTING says *"Do not blindly PR AI slop, this codebase is very complex, they miss details"* (a warning against unreviewed AI code, not a ban), and requires a **DCO sign-off** and **focused PRs tied to an issue**. Assume the same norms apply to `needle`, and ask in the issue. Full policy notes: `docs/needle_flutter_handoff.md` §4.

---

## 6. Step 3: Package skeleton

```bash
flutter create --template=plugin_ffi --platforms=android,ios,macos --org dev.<you> needle_flutter
```

Check that `needle_flutter` is still free on pub.dev before you pick the name.

Target layout:

```
needle_flutter/
├── lib/
│   ├── needle_flutter.dart          # public exports
│   └── src/
│       ├── bindings.g.dart          # ffigen output (committed)
│       ├── native_library.dart      # per-platform DynamicLibrary loading
│       ├── needle_isolate.dart      # worker isolate + message protocol
│       ├── needle.dart              # public Needle class
│       ├── tool.dart                # NeedleTool / NeedleParam / triggers → JSON
│       ├── response.dart            # NeedleResponse, NeedleCall
│       ├── system_facts.dart        # date fact etc.
│       └── grounding.dart           # port of ungrounded check (v0.2)
├── src/needle.h                     # header from the platform download
├── ffigen.yaml
├── android/src/main/jniLibs/arm64-v8a/libneedle.so
├── ios/Frameworks/needle.xcframework
├── macos/…                          # macos-arm64 dylib → easy desktop testing
├── example/                         # demo app with 3–5 tools
├── test/                            # fake-engine unit tests
├── LICENSE  NOTICE  CHANGELOG.md  README.md
```

**Binary distribution decision (make it early):**

| Option | Pros | Cons |
|---|---|---|
| **Vendor binaries in the package** | Simple, works offline, reproducible | Package size grows by a few MB; must redistribute under Needle's licence |
| Fetch at build time (Gradle task / podspec `prepare_command` / Dart build hook) | Small package | Network during build; fragile CI |

Start with **vendoring** (engines are < 1 MB each). **Don't** bundle `needle3.cact` (~35 MB). Take a file path or bytes, and let the app download or bundle it.

---

## 7. Step 4: Dart API design (mirror Python; stay idiomatic)

```dart
final needle = await Needle.create(
  weights: File(path),                         // .cact
  tools: [NeedleTool(name: 'add_note', description: '...', params: {...}, triggers: [r'\bnote\b'])],
  system: SystemFacts(locale: 'en-US', device: 'phone'), // date auto-added
  toolIndexPath: '${dir.path}/tools.idx',
  stateless: true,
);
final r = await needle.complete('remember to buy milk');   // NeedleResponse
final v = await needle.embed('buy milk');                  // Float32List
await needle.setTools([...]);                              // re-runs needle_init
await needle.reset();
await needle.dispose();
```

Rules to encode in the design:
1. **One worker isolate owns the engine.** Every call is a message and all calls are serialised. It's a process-wide singleton, so make `Needle.create` throw if an instance is already live.
2. **Weights are locked for the process** because the engine can't unload. Loading different weights requires an app restart. Document this, and design model updates as *download now, use from next launch*.
3. **Buffer handling:** allocate the output buffer once (64 KB, as Python does) and grow it if you see truncation. For `needle_load`, keep the byte buffer alive for the whole session until §10-Q2 is answered.
4. **Errors:** a negative return code becomes a `NeedleException(code, message)`, where the message is read from the output buffer.
5. **Typed response:** `NeedleResponse` has `type`, `calls`, `suppressedCalls`, `confidence` (nullable), `reasoning`, `ungrounded`, `decodeTps`. Parse defensively; no `!` or `as T`.

---

## 8. Compliance items (don't skip)

- **Telemetry:** the README says *"telemetry is turned on in the binary"*, with opt-out via `NEEDLE_TELEMETRY=0` / `DO_NOT_TRACK=1`. On mobile, env vars must be set **inside the process before the library loads**, e.g. by calling libc `setenv` through `DynamicLibrary.process()`. Verify with a network proxy (Charles or mitmproxy) that nothing is sent.
  - Expose `telemetry: false` as the **default** in your package, and ask about mobile behaviour in the issue.
  - iOS: this affects `PrivacyInfo.xcprivacy` and App Store privacy labels. Android: the Data safety form.
- **Licence:** the code repo is **Apache-2.0**. Check the licence on the HF model card for `Cactus-Compute/needle3` (engine binaries and weights). Keep `LICENSE` + `NOTICE` and credit Cactus in the README.
- **Naming:** say "unofficial" in the package description until Cactus endorses it.
- **Android 16 KB alignment:** if the prebuilt `.so` isn't 16 KB aligned, you can't fix it yourself because you don't have the source. Report it in the issue.

---

## 9. Testing & verification

| Layer | How |
|---|---|
| Unit (no engine) | Compile the `tests/test_worker.py` C stub for macOS as `libstub.dylib` and load it in `dart test`. This mirrors Cactus's own approach and keeps tests off the real model |
| Parity | Run the same query + tools set through Python `needle` and `needle_flutter` on macOS, and diff the JSON envelopes. Commit them as goldens |
| Device integration | Use `integration_test` in `example/` on a real Android and iPhone: load, complete, embed, reset, setTools |
| Performance | Measure cold load time, p50/p95 `complete` latency, `decode_tps`, and peak RSS on flagship devices. Put the table in the README |
| CI | GitHub Actions runs `dart analyze`, `dart test` (stub) on macOS, and `flutter build apk` / `flutter build ios --no-codesign` for the example |

---

## 10. Open questions to resolve (Step 1 or the issue)

| # | Question | How to answer |
|---|---|---|
| Q1 | iOS artefact format: dylib, framework, or static `.a`? | Step 1 `file` output |
| Q2 | Does `needle_load` copy the buffer, or must the caller keep it alive? | Ask in the issue; keep it alive meanwhile |
| Q3 | Is the engine thread-safe? Can it be called from a non-main thread? | Ask; assume a single thread |
| Q4 | What happens when the output overflows `capacity`: truncation or an error code? | Test with a tiny buffer |
| Q5 | Is telemetry active in mobile builds, and how is it disabled there? | Ask, then verify with a proxy |
| Q6 | Is the `.so` 16 KB aligned? | `readelf -l` |
| Q7 | Licence of the binaries and weights | HF model card |
| Q8 | Would they accept a Dart binding upstream, and under what process (DCO, AI policy)? | The issue |

---

## 11. Milestones & definition of done

| Milestone | Done when |
|---|---|
| **M0 Explore** | §4 recorded; Q1, Q4, Q6, Q7 answered |
| **M1 Issue** | Issue opened on `cactus-compute/needle` with Step 1 facts |
| **M2 macOS binding** | `complete`/`embed`/`reset` work from a Dart test on macOS against the real engine; parity goldens pass |
| **M3 Isolate + API** | Public `Needle` API over a worker isolate; stub-engine unit tests green |
| **M4 Android** | Example runs on a real arm64 device; latency and RAM measured |
| **M5 iOS** | Example runs on an iPhone and the arm64 simulator |
| **M6 Wrapper parity** | Date fact, stateless mode, grounding check, null confidence handled |
| **M7 Publish v0.1.0** | README, example, CHANGELOG, licence and credit; telemetry off by default; `pana` ≥ 130; published |
| **M8 Adopt** | on-device-agent uses `needle_flutter` via `ActionModel` (plan Phase 1/3) |
| **M9 Upstream** | PR or link per the maintainers' answer on the issue |

## 12. How I can help without writing the upstream code

- Explain any piece of FFI, isolate, or packaging behaviour.
- Review your diffs (`/code-review`) and hunt for FFI memory bugs.
- Write test scaffolding, CI YAML, and README prose if you want. Mark it clearly; it's your call whether that counts toward your contribution.
- Update the on-device-agent plan and cards as the milestones land.
