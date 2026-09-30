# needle_flutter: 2-day schedule (v3, 2026-09-30)

This file is only the **2-day schedule**. The full guide already exists on branch
`origin/docs/needle3-plan`:

- `docs/needle_flutter_contribution_guide.md` (canonical: engine surface, skills gap, toolchain,
  package layout, API design, compliance, testing, milestones M0-M9)
- `docs/needle_issue_draft.md` (issue to post on `cactus-compute/needle`)
- `docs/needle3_implementation_plan.md` (app-side plan, Phases 0-8)

Route (from that guide): **(1) open an issue on `cactus-compute/needle` -> (2) build and publish your
own `needle_flutter` package -> (3) offer it upstream once the maintainers agree.**
v1 and v2 of this file ignored that work; they were wrong and are replaced.

## No-AI rule (applies to every step)

Cactus `CONTRIBUTING.md` (main `cactus` repo): *"Do not blindly PR AI slop, this codebase is very
complex, they miss details."* Also: `cactus test` must pass, DCO sign-off (`git commit -s`), focused
PRs tied to an issue. The `needle` repo has no CONTRIBUTING.md; the guide assumes the same norms.
(Wording fetched 2026-09-30 through a summarising tool: read the file and copy it exactly.)

- You write the package code. Claude explains, reviews diffs, hunts FFI memory bugs, and may write
  test scaffolding, CI YAML and README prose only if you ask and mark it clearly (guide section 12).
- Everything must be run by you on real devices before you claim it in the issue or PR.

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
6. Handoff file `/Users/rubenk/Downloads/needle_flutter_handoff.md` could not be read by Claude
   (EPERM, macOS privacy). Its contents are **not** reflected here. Copy it into the repo or
   grant access, then reconcile.

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
