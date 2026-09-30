# needle_flutter: your role, and what we did (human guide)

Written 2026-09-30 for Ruben. Plain language, no agent jargon. Read this first, then
`needle_flutter_handoff.md`, then `needle_flutter_two_day_schedule.md`.

## 1. The goal in one paragraph

Cactus's **Needle 3** is a tiny model (about 35 MB) that turns a sentence like "remember to buy
milk" into a structured call like `add_note(text: "buy milk")`. It runs on the phone, with no
network. Cactus ships the engine as prebuilt binaries for Android and iOS, and a Python package, but
**nothing for Flutter**. You are going to write a Dart package, `needle_flutter`, that loads that
binary and exposes it to Flutter apps. That package is your open-source contribution and your
proof of on-device-AI skill.

## 2. What we did so far (the history)

| Date | What | Outcome |
|---|---|---|
| 2026-09-24 | Spiked Needle 2 in the `server_base` todo app with hand-written FFI | It works: 70-120 ms per query, 22-28 MB RAM. Accuracy is mediocre (12/15, later 16/23). `confidence` is not reliable |
| 2026-09-26 | Decided "if Needle 3 exists, use it"; compared it with Needle 2 | Needle 3 base scored 13/23, no better. Fine-tuning is the lever, not the model swap |
| 2026-09-26 | Researched the Cactus/Needle repos; wrote the guide, issue draft and app plan (branch `docs/needle3-plan`) | Route chosen: issue, then own package, then offer upstream |
| 2026-09-29 | A first attempt at "a contribution guide" misread the goal (it pointed at Needle bug issues) | Wrong; discarded |
| 2026-09-30 | Reconciled everything, folded the schedule into this branch, dispatched the first exploration run to a free junior agent | This folder |

Why a **separate package** instead of a PR to Cactus: the old `cactus-flutter` repo was archived on
2026-07-24; the current Flutter binding (`cactus/bindings/flutter/cactus.dart`) doesn't know about
Needle; and Needle's engine is a small C API you can wrap yourself. You can offer it upstream later.

## 3. Your role

**You are the author.** Concretely:

| You do | Agents do |
|---|---|
| Write the Dart FFI bindings, the isolate that owns the engine, the native library loading, and the public `Needle` API | Explain any of those, on request, until you understand them |
| Decide the API shape and the trade-offs | Review your diffs and look for memory and lifetime bugs |
| Run everything on your Mac, an Android phone and an iPhone | Run the mechanical commands (exploration, benchmarks) and write down the facts |
| Post the issue on `cactus-compute/needle` and answer maintainers | Draft test scaffolding, CI YAML, README skeletons, example-app boilerplate **on your request**, marked as assisted |
| Sign the commits (`git commit -s`, the DCO) | Never sign for you |

Why this split: Cactus's `CONTRIBUTING.md` says "Do not blindly PR AI slop, this codebase is very
complex, they miss details." That is a warning about unreviewed output, not a ban. You chose the
stricter rule because this should be *your* work. Being able to explain every line is also the
point of doing it for your career.

## 4. What you need to understand (ordered, with time)

1. **What Needle exposes: 5 C functions** (30 min). `needle_load` (give it the weights), `needle_init`
   (tools + facts), `needle_complete` (one query), `needle_embed`, `needle_reset`. Plus
   `needle_last_error` in the Needle 3 header. There is **one global engine per process**; it cannot
   unload weights, so a new model needs an app restart.
2. **`dart:ffi`** (half a day). You already know C. The new part: `DynamicLibrary`, typedefs for
   native and Dart function types, `Pointer<Utf8>`, allocating and freeing with `package:ffi`. Your
   `server_base` files `needle_bindings.dart` and `needle_engine_ffi.dart` are a working example you
   wrote earlier: re-read them with the header open.
3. **Isolates** (half a day). FFI calls block their thread. Inference must not run on the UI isolate.
   You will run one long-lived worker isolate that owns the engine and answers messages one at a time.
4. **Packaging** (half a day each). Android: `.so` per ABI in `jniLibs`, and 16 KB page alignment.
   iOS: the engine was a static `libneedle.a` in your spike, so you link it in and look symbols up
   with `DynamicLibrary.process()`. Learn what `-force_load` is and why it is needed.
5. **The response** (30 min). The engine returns a JSON envelope: `function_calls`, `confidence`,
   `reasoning`, and more. Empty `function_calls` means "not understood", which is a normal result.
6. **Publishing** (1 h, later). pub.dev, semver, the `pana` score, licences.

## 5. The path, milestone by milestone

Numbers match the handoff.

- **M0 Explore.** A junior agent (hunter) runs the exploration commands and writes `results.md` in
  `~/projects/needle-explore`. **Your job:** read it, check it against the raw output, copy the facts
  into `docs/sessions/2026-09-30.md`, and answer these questions: what shape does the iOS engine
  have, is the Android `.so` 16 KB aligned, what does the header say, what licence covers the
  binaries.
- **M1 Issue.** Fill `needle_issue_draft.md` with those facts and post it yourself. Ask about the AI
  policy (Q8). This is also the moment maintainers see your name.
- **M2 macOS binding.** In a **new repo** (not `on-device-agent`), run
  `flutter create --template=plugin_ffi`, generate bindings with `ffigen`, write `load`, `init`,
  `complete`, `reset`, then `embed`. Prove it with a Dart test on macOS against the real engine.
  Compare its output with the Python package on the same input.
- **M3 Isolate + API.** Wrap the engine in one worker isolate; expose `Needle.create`, `complete`,
  `embed`, `setTools`, `reset`, `dispose`. Test with a fake engine.
- **M4 Android, M5 iOS.** Run the example app on real devices and measure latency and RAM.
- **M6 Wrapper parity.** Port the small pieces of logic that live in Python, not in the engine: the
  auto date fact, stateless mode, the grounding check, `confidence` being null when the weights have
  no confidence head.
- **M7 Publish.** README, example, licence and credit, telemetry off by default, pub.dev.
- **M8 Adopt.** Use it in `on-device-agent`. **M9 Upstream.** Offer it, per the maintainers' answer.

## 6. How to work with the agents

- **Ask for explanations by name:** "Explain how `Pointer<Utf8>` is freed in this function." You
  get a walkthrough of your own code; you keep writing.
- **Ask for review after you write:** paste or point at your diff and say "hunt lifetime and
  double-free bugs". Read each finding, decide, fix it yourself.
- **Delegated files:** the assignments table in the schedule lists what junior agents do (test
  stub, `ffigen.yaml`, CI YAML, example shell, benchmark, README skeleton). They work one file per
  run; a review agent checks each batch; the commit message says "assisted by hunter". You decide
  what stays.
- **Never accept code you can't explain.** If a helper file confuses you, ask until it doesn't, or
  rewrite it.

## 7. How to check that things are true

| Claim | Check |
|---|---|
| "The exploration facts are right" | Re-run one command from `results.md` yourself, e.g. `file engines/android-arm64/*` |
| "The binding works" | A Dart test that loads the real engine and gets a tool call back for "remember to buy milk" |
| "It matches the reference" | Same query and tools through Python `needle` and Dart; diff the JSON |
| "No memory leak" | Call `complete` 1,000 times and watch RSS stay flat |
| "Telemetry is off" | Run the example behind mitmproxy and confirm no traffic |
| "Works on device" | You ran it on an Android phone and an iPhone, and you say so in the PR |

## 8. Pitfalls to expect

- Two threads calling the engine at once. Serialise everything in the worker isolate.
- Freeing native memory twice, or freeing the weights buffer while the engine still uses it (keep it
  alive until you learn from the issue whether `needle_load` copies it).
- Trusting `confidence`. On Needle 2 correct answers scored 0.002-0.009. Don't build a gate on it.
- Bundling the 35 MB weights in the package. Take a path or bytes instead.
- Forgetting that changing the tool list means calling `needle_init` again.

## 9. Glossary

- **FFI:** calling C functions from Dart. **Isolate:** Dart's unit of concurrency; does not share
  memory. **`.cact`:** Needle's weights file. **xcframework / `jniLibs`:** how iOS / Android carry
  prebuilt native libraries. **DCO:** the sign-off (`Signed-off-by`) certifying you have the right to
  contribute the code. **hunter / flash:** the free and the paid opencode agents that do delegated,
  mechanical work in this setup.

## 10. Your next three actions

1. Read `results.md` from the exploration run and verify it (see section 7).
2. Post the issue.
3. Create the package repo and write the first FFI call yourself.
