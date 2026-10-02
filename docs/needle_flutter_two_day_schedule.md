# needle_flutter: 2-day schedule and assignments (2026-09-30)

This file is the **2-day schedule and the agent assignments**. Companion files in this folder:

- `needle_flutter_handoff.md` (start here: route, AI rules, milestones M0-M9)
- `needle_flutter_contribution_guide.md` (technical detail: engine surface, skills, toolchain, layout, testing)
- `needle_flutter_human_guide.md` (your role, in plain language, and what was done and why)
- `needle_issue_draft.md`, `needle3_implementation_plan.md`, `tasklog.md`

Route (from that guide): **(1) open an issue on `cactus-compute/needle` -> (2) build and publish your
own `needle_flutter` package -> (3) offer it upstream once the maintainers agree.**
v1 and v2 of this file ignored that work; they were wrong and are replaced.

## AI-assistance rules

Canonical text: `docs/needle_flutter_handoff.md` section 4 on the same branch (read it first).
Cactus `CONTRIBUTING.md` (main `cactus` repo, verified verbatim there): *"AI-Generated Code: Do not
blindly PR AI slop, this codebase is very complex, they miss details."* It is a warning, not a ban;
it does not cover the `needle` repo (no CONTRIBUTING) or your own package. The working rules are
stricter because you want this to be your contribution:

- **You write** the core code of `needle_flutter` (bindings, isolate protocol, native loading, public
  API) and anything sent upstream. Claude explains, reviews diffs, hunts FFI lifetime bugs.
- Test scaffolding, CI YAML, README prose, example boilerplate: only on request, marked in the commit message.
- Never add `Signed-off-by` (DCO) for you. Disclose AI help in upstream PRs.
- The package lives in a **separate repo**, not in `on-device-agent`. Tasklog card N0 is parked (user-owned).

## Corrections and additions to the guide (found 2026-09-30)

1. **You already have a working prototype.** `server_base` (`/Users/rubenk/projects/infra/server_base`)
   has hand-rolled FFI to `libneedle`:
   `server_base_flutter/lib/features/assistant/needle/{needle_bindings,needle_engine,needle_engine_ffi}.dart`
   and `tool/fetch_needle.sh` (pins HF `Cactus-Compute/needle3` @ `b274efcb`, sha256-checked,
   macos-arm64 + ios-arm64 `libneedle.a`). It answers M2 partly and Q1: on macOS/iOS the engine
   shipped as a **static `libneedle.a`**, so the iOS/macOS route is static linking (guide section 3
   `-force_load`, `DynamicLibrary.process()`), not a dylib. Confirm for Android in Step 1.
2. **`needle_last_error` exists** in the Needle 3 header (needle_embed too). The guide lists five
   functions; the server_base notes list `needle_last_error` as a sixth. Check the header from
   `needle build --platform`. It may replace reading the error from the output buffer (guide Q4).
3. **Measured facts to reuse** (`server_base/learn/slm-decisions.md`): `confidence` is
   uncalibrated on Needle 2 (0.002-0.009 when correct); one process-global conversation; base Needle 3
   scored 13/23 (14/23 placeholder schema) on the 23-phrase todo eval. Needle 2 spike: 70-120 ms per
   query, 22-28 MB RAM. Do not gate on confidence; if you ship it, say so in the README.
4. **`cactus-flutter` is archived** (2026-07-24), and pub.dev `cactus` is v1.3.0 (predates Needle 2).
   `cactus/bindings/flutter` is just `cactus.dart` over `cactus_engine.h`, with no Needle. So an
   upstream offer (M9) means a new binding beside it; ask in Q8.
5. **Platform naming:** the guide uses `needle build --platform android-arm64|ios-arm64|ios-sim-arm64`;
   the server_base spike used `macos-arm64`. Same command works for macOS.
6. The handoff (`docs/needle_flutter_handoff.md`) is on the same branch; its rules above and
   its milestones M0-M9 are what this schedule follows.

## Day 1: explore and open the issue (guide M0, M1)

1. Read the guide end to end, plus `llms.txt`, `needle/__init__.py`, `needle/_worker.py`,
   `tests/test_worker.py` in `cactus-compute/needle`.
2. Toolchain (guide section 3): Xcode, NDK + CMake, `brew install llvm`, Python venv with
   `cactus-needle`, `NEEDLE_TELEMETRY=0`. Devices: one Android arm64 phone, one iPhone.
3. Run guide Step 1 (section 4): Python reference, `needle build` for android-arm64, ios-arm64,
   ios-sim-arm64 (and macos-arm64), inspect `file`, `llvm-nm`, `readelf -l`, the header. Record in
   `docs/sessions/2026-09-30.md`.
4. Re-read your `server_base` bindings next to the header; note what carries over to the package.
5. Answer Q1, Q4, Q6, Q7 (guide section 10). Fill and **post yourself** the issue draft; it asks
   the AI-policy question (Q8) explicitly.
6. Check `needle_flutter` name availability on pub.dev.

Done when: section 4 results are on disk and the issue is posted.

## Day 2: macOS binding and skeleton (guide M2, part of M3)

1. `flutter create --template=plugin_ffi --platforms=android,ios,macos needle_flutter`.
2. `ffigen` from the downloaded header (`ffigen.yaml`, commit `bindings.g.dart`).
3. Write `native_library.dart` and the four core calls (`load`, `init`, `complete`, `reset`) plus
   `embed` on macOS first, then a Dart test against the real engine. Reuse understanding from
   `needle_engine_ffi.dart`, not a copy-paste: you must be able to explain every line.
4. Keep the weights byte buffer alive for the whole session until Q2 is answered.
5. Parity check: same query and tools through Python `needle` and Dart, diff the JSON envelopes.
6. Start `needle_isolate.dart` (one worker isolate owns the engine, serialised calls).

Done when: a Dart test on macOS returns a tool call from the real engine and matches the Python output.
Later milestones (M4 Android, M5 iOS, M6 wrapper parity, M7 publish) follow the guide.

## Pitfalls (see guide sections 7-8)

- One global engine per process; weights cannot be unloaded; one toolset per session
  (`setTools` re-runs `needle_init`).
- Telemetry is on in the binary; verify with a proxy that opt-out works on mobile.
- Do not bundle `needle3.cact`; fetch with a pinned, hashed script.
- Prebuilt `.so` alignment (16 KB) is not fixable by you; report it in the issue.

## M0 results: what changed (2026-10-02, from `needle_m0_results.md`)

M0 is **done** (hunter run H1). Facts that change the plan:

1. **Android has no `.so`.** The Android folder holds a static `libneedle.a`, a stripped `needle`
   executable and the header. So Android, like iOS and macOS, is a **static link**: you build your
   own small shared library (CMake + NDK) that links `libneedle.a` and exports the 6 symbols. This
   corrects guide section 0/6, which assumed a prebuilt `.so` in `jniLibs`.
2. **16 KB alignment is now yours to set.** The measured 0x4000 is on the `needle` executable, not
   on anything you ship. Build your `.so` with `-Wl,-z,max-page-size=16384` and check it with
   `readelf -l`. The "report it in the issue" pitfall no longer applies, so reword Q6.
3. **Six symbols, not five.** `needle_last_error` is in `needle.h` and in every `libneedle.a`. Use
   it for error text instead of the output buffer (guide Q4).
4. **The header says it plainly:** "One process-global, non-thread-safe model." That answers Q3:
   one worker isolate, no concurrent calls. `needle_embed(NULL, ...)` returns the dimension.
5. **Embedding dimension is 3072** floats (12 KB per vector). Phase 5 memory storage should keep
   vectors as `Float32List` blobs and cap the row count.
6. **Python reference on macOS:** `peak_ram_mb` 127.9 and `confidence` 0.1466 for a correct call.
   The plan's "added RAM under 100 MB" target needs re-baselining on a phone.
7. **Weights:** `needle3.cact` is 35,335,380 bytes (same on every platform); `libneedle.a` is
   1.1-1.7 MB. Still no `.so`, so the package's iOS side links a static archive.
8. **Still open:** Q2 (does `needle_load` copy its buffer), Q5 (telemetry on mobile) and Q7
   (licence of binaries and weights). They go in the issue.

## Assignments: who does what

Rule of thumb from the handoff: **you write** the FFI bindings, isolate protocol, native loading and
public API, and also the Android CMake/NDK glue and iOS linking (native loading). Everything else
can go to a junior, run from the repo's directory, one file per run, reviewed by Sonnet before you
keep it. Juniors never branch, commit, push or sign off. **Dispatch-ready briefs for every row are
in `needle_flutter_agent_briefs.md`.**

Engines: **hunter** = free opencode agent, one file per run. **flash** = paid opencode agent for
multi-file work; use it only when the work spans several files and the API it targets is stable.

### Ready now (no package needed)

| ID | Task | Engine | Output | Depends on |
|---|---|---|---|---|
| H1 | M0 exploration | hunter | `needle_m0_results.md` | **Done** |
| H8 | Parity golden generator: Python script that runs a fixed list of (tools, query) pairs through `needle` and writes JSON envelopes | hunter | `tool/goldens/gen_goldens.py` + `goldens/*.json` | M0 |
| H3 | `ffigen.yaml` for `needle.h` (6 functions, no helpers) | hunter | `ffigen.yaml` | M0 |
| H2 | C stub engine mirroring `needle.h` and `tests/test_worker.py`, with a build script for macOS | hunter | `test/stub/needle_stub.c`, `test/stub/build.sh` | M0 |
| H9 | Pinned, sha256-checked fetch script for engines + `needle3.cact`, adapted from `server_base/tool/fetch_needle.sh` for 4 platforms | hunter | `tool/fetch_needle.sh` | M0 |
| H10 | Name check: is `needle_flutter` free on pub.dev, plus 3 fallback names | hunter | one-line result in `results.md` | none |
| H11 | Telemetry check harness: mitmproxy addon + steps to run the macOS Python reference and later the example app behind it | hunter | `tool/telemetry/check.md`, `tool/telemetry/addon.py` | M0 |
| N1 | `ActionModel`, `ActionResolution`, `FakeActionModel` + tests (on-device-agent) | hunter, one file per run | `lib/...`, `test/helpers/` | none |
| N6a | Eval harness, Python side: golden set (>=20 queries per action, >=50 off-topic) + scorer script | hunter | `tool/needle/eval.jsonl`, `tool/needle/score.py` | none |

### After the package repo exists

| ID | Task | Engine | When |
|---|---|---|---|
| H4 | GitHub Actions: `dart analyze`, `dart test` on macOS with the stub, `flutter build apk`, `flutter build ios --no-codesign` for the example | hunter | New repo created |
| N2 | Action registry + tool JSON serialiser (on-device-agent) | hunter, one file per run | After N1 |

### After the API exists (M3)

| ID | Task | Engine | When |
|---|---|---|---|
| H5 | Example app shell calling **your** API, one file per run | hunter, several runs | M3 |
| H6 | Latency and RAM benchmark script (cold load, p50/p95, decode tps, RSS) | hunter | M3 |
| H7 | README, CHANGELOG, NOTICE skeletons | hunter | M7, with your measured numbers |
| N3-N5 | Engine integration, resolution pipeline, correction memory (several files at once) | **flash** | After M8 starts |
| N7 | Learning A: dataset-build script + LoRA commands (run on your Mac) | hunter (script), you run training | After N5 |
| N8 | UI: command bar, result card, target screens, state machine | **flash** | After N4 |

### Yours (not for agents)

M1 post the issue, M2-M3 bindings and isolate, Android CMake/NDK glue and `-z max-page-size`,
iOS static-link setup, M6 wrapper logic, signing commits (`git commit -s`), publishing, M9.

**flash is not used yet.** Nothing in M0-M7 spans enough files to justify it. cursor is suspended
until 2026-10-29.

Review: one batched Sonnet seat per unit (H2+H3 together, H8+H9 together, H5 together, and so on)
rates each junior into `~/.claude/junior-ratings.md`. Marking: put "assisted by hunter" (or
"assisted by flash") in the commit message of any junior-written file.
