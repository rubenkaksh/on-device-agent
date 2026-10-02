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

## Assignments: who does what

Rule of thumb from the handoff: **you write** the FFI bindings, isolate protocol, native loading and
public API. Everything else can go to a junior, run from the repo's directory, one file per run,
reviewed by Sonnet before you keep it. Juniors never branch, commit, push or sign off.

| ID | Task | Engine | When | Notes |
|---|---|---|---|---|
| H1 | M0 exploration run: `needle build` for 4 platforms, `file`, header, ELF alignment, symbols, Python reference call, write `results.md` | hunter | **Dispatched 2026-09-30**, in `~/projects/needle-explore` | Facts only, no code. You copy the results into `docs/sessions/` and answer Q1, Q4, Q6, Q7 |
| H2 | C stub engine for `dart test` (mirrors `tests/test_worker.py`) | hunter | After M0 (needs the real header) | Test scaffolding; one file |
| H3 | `ffigen.yaml` | hunter | After M0 | One file; you run `ffigen` and read the output |
| H4 | GitHub Actions workflow: `dart analyze`, `dart test` on macOS, `flutter build apk`, `flutter build ios --no-codesign` for the example | hunter | After the package repo exists | One file |
| H5 | Example app shell (pubspec, `main.dart`, a screen with 3-5 tools) calling **your** API | hunter, several runs | After M3 (API exists) | One file per run |
| H6 | Latency and RAM benchmark script for M4/M5 | hunter | After M3 | Measures only; you interpret |
| H7 | README, CHANGELOG, NOTICE skeletons | hunter | M7 | You supply the measured numbers and edit for accuracy |
| N1 | `ActionModel` + `ActionResolution` + `FakeActionModel` + tests (app-side, in `on-device-agent`) | hunter, one file per run | Any time; does not need the package | Tasklog card N1 |
| N2 | Action registry + tool JSON serialiser | hunter, one file per run | After N1 | Tasklog card N2 |
| N6 | Eval harness: golden set + Python eval script | hunter | Any time | Tasklog card N6 |
| N3-N5 | Engine integration, resolution pipeline, correction memory (multi-file app phase) | **flash** | After M8 starts | Long-spanning, several files at once; costs money, so only once the package API is stable |

**flash is not used yet.** Nothing in M0-M7 spans enough files to justify it; most of that work is
yours by rule. cursor is suspended until 2026-10-29.

Review: one batched Sonnet seat per unit (H2+H3 together, H5 together, and so on) rates each junior
into `~/.claude/junior-ratings.md`. Marking: put "assisted by hunter" in the commit message of any
junior-written file.
