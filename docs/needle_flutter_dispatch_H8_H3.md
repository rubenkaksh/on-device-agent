# Dispatch: H8 and H3 to hunter

_2026-10-03. Run these on your Mac; the full briefs are in `needle_flutter_agent_briefs.md`._
_Not dispatched by Claude: the cloud session has no opencode or Needle environment._

Both tasks are independent, so open **two separate hunter runs** (one file per run, one folder each).
Paste the shared rules first in each run, then the task block.

## Shared rules (paste first)

```
You are doing one delegated, mechanical task. Rules:
- Create exactly the files named below. Do not touch anything else.
- Never branch, commit, push, tag or sign off. The owner commits.
- Do not write FFI bindings, isolate code, native loading or any public API.
- Use only the files named below and docs/needle_m0_results.md as facts. If something is
  missing, write "UNKNOWN: <what>" instead of guessing.
- End with a short report: files written, commands run, anything you did not verify.
```

## H8: parity golden generator

- **Run in:** `~/projects/needle-explore` (the venv with `cactus-needle` 3.0.6 active, `NEEDLE_TELEMETRY=0`)
- **Needs:** nothing else.

```
Task H8. Write tool/goldens/gen_goldens.py, then run it to produce goldens/*.json.

Define 3 tool sets: (1) notes: add_note(text, required); (2) reminders: set_reminder(text required,
time HH:mm, date YYYY-MM-DD); (3) a mixed set of 5 tools (add_note, set_reminder, open_screen with an
enum of notes/reminders/settings, toggle_theme with an enum of light/dark/system, clear_notes).
Each tool needs a description that says when to use it. For each set write 6 queries: 3 clear,
1 with a missing argument, 1 off-topic, 1 with a relative date ("tomorrow at 7").

For each tool set create needle.Needle(tools=..., system="date: 2026-10-02 Fri 10:00; locale: en-US",
stateless=True) and call .complete(query) for each query. Write one JSON file per (tool set, query)
named goldens/<set>_<nn>.json holding: tools, system, query, and the full response envelope.
The fields prefill_tps, decode_tps and peak_ram_mb vary between runs: store them but also list their
names under a top-level "ignore_in_diff" key.
Print a table of query -> function_calls at the end.

Done when: 18 JSON files exist (3 sets x 6 queries), the script re-runs without errors, and the
table is in your report.
```

> Note: 3 sets x 6 queries = **18** files. (The earlier brief said 36; that was a miscount.)

## H3: `ffigen.yaml`

- **Run in:** a scratch folder, e.g. `~/projects/needle-ffigen`, containing `src/needle.h` copied from
  `~/projects/needle-explore/engines/macos-arm64/needle.h`, and a Dart SDK with `ffigen` available.
  The package repo does not exist yet, so do not wait for it.

```
Task H3. Write ffigen.yaml only.

Configure package:ffigen to read src/needle.h and write lib/src/bindings.g.dart. Expose the six
needle_* functions only (needle_init, needle_last_error, needle_complete, needle_embed, needle_reset,
needle_load). Use DynamicLibrary lookup (no @Native / ffi-native). Class name: NeedleBindings.
Handle the NEEDLE_API visibility macro if it affects parsing.
Then run "dart run ffigen" and paste the generated function signatures next to the header's, and
flag any mismatch (for example how "unsigned long long" and "const unsigned char*" were mapped).

Done when: dart run ffigen succeeds and the six generated signatures match the header.
```

## After the runs

1. Read the reports; re-run one thing yourself (e.g. `python tool/goldens/gen_goldens.py`, `dart run ffigen`).
2. A Sonnet seat reviews H8 + H3 together and rates both into `~/.claude/junior-ratings.md`.
3. You copy the files into the right repo and commit with `git commit -s`, message ending
   "assisted by hunter".
