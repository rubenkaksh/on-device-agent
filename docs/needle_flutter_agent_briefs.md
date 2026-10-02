# needle_flutter: agent briefs (hunter / flash)

_2026-10-02. Companion to `needle_flutter_two_day_schedule.md` (the table says who and when; this file says what to paste)._

## Rules that apply to every brief

- **Scope:** create exactly the files listed. Don't touch anything else.
- **Git:** never branch, commit, push, tag or sign off. The owner commits (`git commit -s`) and marks
  the message "assisted by hunter" or "assisted by flash".
- **No core code:** don't write FFI bindings, the isolate protocol, native library loading, the
  Android CMake/NDK glue, iOS linking or the public API. Those belong to the owner.
- **Facts:** use only `docs/needle_m0_results.md` and the files named in the brief. If something isn't
  there, write `UNKNOWN: <what>` instead of guessing.
- **Run location:** the directory named under "Run in".
- **Report:** end with a short list: files written, commands run, anything not verified.
- **Review:** each unit is checked by a Sonnet seat before the owner keeps it.

Repo-wide Dart rules (for N-briefs): `flutter analyze` clean, no `!` and no `as T`, use `?.`, `??`
and pattern matching, shared fakes in `test/helpers/`, tests never hit platform channels.

---

## hunter briefs

### H8: Parity golden generator

- **Run in:** `~/projects/needle-explore` (has the Python venv with `cactus-needle`).
- **Write:** `tool/goldens/gen_goldens.py`, then run it to produce `goldens/*.json`.
- **Do:** define 3 tool sets (notes: `add_note`; reminders: `set_reminder` with date/time; a 5-tool
  mixed set) and 6 queries each (3 clear, 1 missing argument, 1 off-topic, 1 relative date).
  Create one `Needle(tools=..., system="date: 2026-10-02 Fri 10:00; locale: en-US", stateless=True)`
  per tool set and write one JSON file per (tool set, query) holding `tools`, `system`, `query` and
  the full response envelope. Set `NEEDLE_TELEMETRY=0`. Print a table of query -> function call.
- **Done when:** 36 JSON files exist, the script re-runs without errors, and the table is in the report.
- **Note:** the engine isn't deterministic in `prefill_tps`/`decode_tps`/`peak_ram_mb`; the script
  must store them but mark them as "ignore in diff".

### H3: `ffigen.yaml`

- **Run in:** the package repo root (or a scratch folder with a copy of `needle.h`).
- **Write:** `ffigen.yaml` only.
- **Do:** configure `package:ffigen` to read `src/needle.h` and write `lib/src/bindings.g.dart`.
  Expose the 6 `needle_*` functions only, with `ffi-native` off (use `DynamicLibrary`), a class name
  `NeedleBindings`, and the `NEEDLE_API` macro handled. Run `dart run ffigen` and report the
  generated signatures next to the header, flagging any mismatch (e.g. `unsigned long long`).
- **Done when:** `dart run ffigen` succeeds and the 6 signatures match the header.

### H2: C stub engine

- **Run in:** the package repo root.
- **Write:** `test/stub/needle_stub.c`, `test/stub/build.sh`.
- **Do:** implement all 6 functions of `needle.h` as a fake: `needle_load` checks `size >= 6` and
  `data[4] != 0` (as in Needle's `tests/test_worker.py`); `needle_init` returns 7 and stores the tools
  JSON; `needle_complete` writes a canned response envelope (`type`, `function_calls`, `confidence`)
  that echoes the input, and returns `-1` with a message when the input is `"__fail__"` or when
  `capacity` is too small; `needle_last_error` returns that message; `needle_embed(NULL,...)` returns 8
  and otherwise fills 8 floats; `needle_reset` counts resets. `build.sh` builds
  `libneedle_stub.dylib` for macOS arm64.
- **Done when:** `build.sh` succeeds and `nm -gU` lists the 6 symbols.

### H9: Fetch script

- **Run in:** the package repo root.
- **Write:** `tool/fetch_needle.sh`.
- **Do:** adapt `server_base/tool/fetch_needle.sh` (pins HF `Cactus-Compute/needle3`, sha256-checked)
  to four platform folders (`android-arm64`, `ios-arm64`, `ios-sim-arm64`, `macos-arm64`). Output
  each `libneedle.a` and `needle.h` into `third_party/needle/<platform>/`. `needle3.cact` is fetched
  once into a cache folder and is **never** copied into the package. Verify sha256 for every file;
  fail loudly on mismatch; support `HF_HUB_OFFLINE=1`. Take the hashes from running the script once.
- **Done when:** a fresh run downloads and verifies all files, and a tampered file fails.

### H10: pub.dev name check

- **Run in:** anywhere with network.
- **Write:** one results block (append to `needle_m0_results.md` under `## pub.dev names`).
- **Do:** query `https://pub.dev/api/packages/<name>` for `needle_flutter`, `flutter_needle`,
  `needle_ffi`, `cactus_needle`. Report HTTP status (404 = free), latest version, publisher, and last
  published date for any that exist.

### H11: Telemetry check harness

- **Run in:** `~/projects/needle-explore`.
- **Write:** `tool/telemetry/addon.py` (mitmproxy addon logging every request host + path, nothing else)
  and `tool/telemetry/check.md` (steps).
- **Do:** steps to (a) run the Python reference with `NEEDLE_TELEMETRY=1` behind mitmproxy and record
  which host is called, (b) repeat with `NEEDLE_TELEMETRY=0` and `DO_NOT_TRACK=1`, (c) a checklist for
  later running the example app on a phone through a proxy. Execute (a) and (b) and report the hosts.
- **Done when:** the report lists the call with telemetry on, and no calls with it off.

### N1: `ActionModel` types

- **Run in:** `on-device-agent`. **One file per run, three runs.**
- **Run 1:** `lib/services/action_model.dart`: `ActionModel` (abstract interface class with `load`,
  `resolve`, `embed`, `dispose`), as in `docs/needle3_implementation_plan.md` Phase 1.
- **Run 2:** `lib/services/action_resolution.dart`: `ActionCall`, `ActionResolution` (calls, suppressed,
  nullable confidence, reasoning). Parsing helper `ActionResolution.fromEnvelope(Map)` that never throws:
  malformed input returns an empty resolution.
- **Run 3:** `test/helpers/fake_action_model.dart` + `test/action_resolution_test.dart` (empty calls,
  suppressed calls, null confidence, malformed JSON).
- **Done when:** `flutter analyze` clean and the new tests pass.

### N6a: Eval set and scorer

- **Run in:** `on-device-agent` (Python parts in `tool/needle/`).
- **Write:** `tool/needle/eval.jsonl`, `tool/needle/score.py`.
- **Do:** from the six demo actions in the plan, write >= 20 queries per action (paraphrases, missing
  arguments, typos, mixed intents) and >= 50 off-topic queries, one JSON object per line (`query`,
  `tools`, `answers`; off-topic has `"answers": []`). `score.py` reads a file of responses and reports
  action accuracy, argument exact match, off-topic false-positive rate, and confidence buckets.
- **Done when:** the file counts match and `score.py` runs on a hand-made 5-line responses file.

### H4: CI workflow (after the repo exists)

- **Write:** `.github/workflows/ci.yaml`: `dart analyze`, `dart test` on macOS using the H2 stub,
  `flutter build apk --debug` and `flutter build ios --no-codesign` for `example/`. Cache pub.

### N2: Action registry (after N1)

- **Run in:** `on-device-agent`. **One file per run:** `lib/actions/action_tool.dart` (`ActionTool`,
  `ActionParam`, origin enum), `lib/actions/action_registry.dart` (fixed + runtime `register`/
  `unregister`, context filter), `lib/actions/needle_tool_json.dart` (serialiser to Needle's
  `{name, description, parameters}` shape), then one test file per source file.

### H5-H7, N7 (later)

- **H5 example shell** (one file per run, calling the owner's API); **H6 benchmark script** (cold
  load, p50/p95 `complete`, `decode_tps`, RSS); **H7 README/CHANGELOG/NOTICE skeletons** (owner
  supplies measured numbers); **N7 dataset-build script** (merge corrections + paraphrases + off-topic
  negatives into `train/val/test.jsonl`, split by paraphrase group). Write these briefs when the
  inputs exist.

---

## flash briefs (not before the gating work is stable)

### N3-N5: App integration

- **Gate:** the `needle_flutter` API is stable (M3 done) and N1/N2 are merged.
- **Run in:** `on-device-agent`. **One brief per task**, multi-file.
- **N3:** model manager (download + sha256 + manifest + rollback copy), `NeedleActionModel`
  implementing `ActionModel`, response parsing; model switch takes effect on next launch.
- **N4:** resolution pipeline: memory lookup hook, validator (required/enum/format), confidence gate
  (do not gate on `confidence` for Needle 2 or locally tuned weights, where it can be null or
  uncalibrated; use confirmation instead), destructive-action confirmation, missing-argument flow.
- **N5:** `sqflite` correction memory: schema, `Float32List` embedding blobs (3072 floats), cosine
  lookup, aliases, row caps, clear-memory.
- **Each task ends** with `flutter analyze` clean and tests using `FakeActionModel`.

### N8: UI

- **Gate:** N4 merged.
- Command bar, result card (tool, arguments, confidence, confirm and correct buttons), Notes,
  Reminders and Settings screens, model-state machine; retire `GemmaService` only if the owner
  agrees in the task text.
