# Needle 3 for Flutter on the Cactus package: 2-day guide (v2, 2026-09-30)

Supersedes v1, which wrongly framed this as "contribute to Needle issues". The goal is to
**integrate Needle 3 into the Cactus Flutter binding**, building on the FFI work already done in
`server_base`.

## Rule zero: Cactus's AI policy

`cactus-compute/cactus` `CONTRIBUTING.md` says: *"Do not blindly PR AI slop, this codebase is very
complex, they miss details."* It also says a PR that fails to build is "the biggest red flag, means
it was not tested" and requires DCO sign-off (`git commit -s`), which certifies you wrote it or have
the right to submit it.

(Fetched 2026-09-30 through a summarising tool. Read the file yourself before day 1 and copy the
exact wording. No note of this policy exists in memory; the memory dirs only hold the on-device-AI
goal. Save a note once you have read it.)

How to work under it:
- **You write every line of the PR.** Claude explains code, traces the FFI, reviews your diff and
  answers questions; it does not author diff hunks you paste in.
- Understand every line you submit well enough to defend it in review.
- Run everything yourself on a real device. "Builds, and I ran it on iPhone/macOS" goes in the PR.
- Ask upstream first (issue or Discord) whether Needle 3 in the Flutter binding is wanted and how
  they want it shaped. A surprise large PR is the worst case under this policy.

## Intel (verified 2026-09-30 unless marked)

| Fact | Source |
|---|---|
| `cactus-compute/cactus-flutter` was **archived 2026-07-24**, read-only. | GitHub page |
| The `cactus` pub.dev package is v1.3.0, ~9 months old, predates Needle 2. | server_base `learn/slm-decisions.md` (Round 4) |
| The main repo `cactus-compute/cactus` has `bindings/flutter/` with just `README.md` + `cactus.dart`, raw Dart FFI over `cactus_engine.h` (`cactusInit`, `cactusComplete`, streaming transcribe). **No Needle mention.** | GitHub page |
| Native libs are prebuilt: `cactus build --apple` / `--android` -> `cactus-ios.xcframework`, `cactus-macos.xcframework`, `libcactus_engine.so`. | bindings/flutter README |
| Needle 3 (HF `Cactus-Compute/needle3` @ `b274efcb`, 2026-09-19) is a separate `needle3.cact` weights file loaded via `needle_load`. C header is a superset of Needle 2: `needle_load`, `needle_init`, `needle_complete`, `needle_reset` + `needle_last_error`, `needle_embed`. | server_base `learn/slm-decisions.md` |
| Needle ships its own prebuilt engines: `needle build --platform <folder> [--layers N]`, artifacts `libneedle.a` for `macos-arm64`, `ios-arm64`. Porting guide: `cactuscompute.com/blog/porting-needle`. | needle README, porting guide |
| A hand-rolled `NeedleBindings` + FFI engine already works against `libneedle`: `server_base/server_base_flutter/lib/features/assistant/needle/{needle_bindings,needle_engine,needle_engine_ffi}.dart`, plus `tool/fetch_needle.sh` (pins needle3 @ b274efcb, sha256-checked). | local files |
| Measured: base Needle 3 = 13/23 (14/23 with placeholder schema) on the 23-phrase todo eval, no better than Needle 2. | slm-decisions.md |

## Open questions to settle before writing code (day 1 morning)

1. **What exactly is the contribution?** Assumed here: add Needle 3 support to Cactus's Flutter
   binding (`bindings/flutter` in the main repo, or a revived pub package). Alternatives: PR a new
   `needle` Dart binding beside `cactus.dart`; or publish your own package. Confirm with upstream.
2. Does `cactus_engine.h` (the Cactus engine) load `.cact` Needle weights, or is Needle a separate
   engine (`libneedle`, different header)? The server_base spike used `libneedle`, and Cactus's
   Flutter binding wraps `cactus_engine.h`. They may be two different C APIs. **Read both headers
   first**; this decides the whole design.
3. Which platforms? server_base targets iOS device + macOS arm64 only. Android needs `.so`
   artifacts; check whether Needle publishes them (needle issue #17 asks about Android).
4. Does upstream want streaming, embeddings (`needle_embed`), and layer selection (2-20) exposed
   in v1, or only `load/init/complete/reset`? Start with the four core calls.

## Day 1: understand and design (no PR code yet)

1. Read `CONTRIBUTING.md` and `DCO.md` in `cactus-compute/cactus`. Note the exact AI wording.
2. Fork and clone `cactus-compute/cactus`. Run `cactus test` on unmodified `main` first, so you know
   the baseline (per CONTRIBUTING). Note the exact command and which platform flags you need.
3. Read `bindings/flutter/cactus.dart` end to end. Write down how it loads the library per platform
   and how it maps C strings and errors.
4. Read your own working code: `needle_bindings.dart` (typedefs, `lookupFunction`), `needle_engine_ffi.dart`
   (lifecycle, buffer sizes, `needle_last_error`). This is your reference implementation; your PR
   should be a cleaned-up, tested version of ideas you already understand.
5. Read `needle.h` from the needle3 artifacts (`fetch_needle.sh` downloads it). List every function
   and its ownership rules (who allocates `out`, meaning of negative returns).
6. Answer the four open questions above. Post one short issue or Discord message describing the
   plan and asking whether they want it. Wait for signal before day 2 code.
7. Write a one-page design in your own words: file layout, public Dart API, error type, how the
   native artifact is bundled, test plan. Keep it in `docs/`, not in the PR.

## Day 2: implement, test on device, PR

1. Branch from `main` in your fork: `git switch -c feat/needle3-flutter-binding`.
2. Write the Dart binding yourself, smallest slice first: `needle_load` -> `needle_init` ->
   `needle_complete` -> `needle_reset`, with `needle_last_error` mapped to an exception.
3. Wire the native artifact for **one platform first** (macOS arm64, since it is the easiest to
   iterate on). Prove a tool call comes back for one phrase ("add buy milk").
4. Add tests next to the existing ones in the repo (mirror their style; check `cactus test`).
   Include: load failure, empty `function_calls` (correct refusal), and a multi-call output.
5. Add iOS: `ios-arm64/libneedle.a`, run on a real device. Record what you ran.
6. Update the docs for the new API (`bindings/flutter/README.md`). CONTRIBUTING requires it for
   user-facing changes.
7. Run `cactus test` plus your device runs. Commit with `git commit -s` (DCO).
8. Open the PR: focused scope, link the issue, state what you ran on which device, and the tradeoffs
   you chose. Do not submit anything you cannot explain.

## Pitfalls

- `confidence` is uncalibrated (correct answers at 0.002-0.009). Never expose it as a gate.
- Needle keeps **one process-global conversation**; document `needle_reset` and make the Dart API
  non-reentrant or serialised.
- Multi-call outputs occur ("cross off call mom" -> complete + add). The API must return a list.
- Descriptions are part of the product, and the Needle README says system-prompt facts "do not steer
  the model". Do not promise accuracy in the PR text; quote the measured 13/23.
- Weights (`needle3.cact`, 13.5 MB libs) do not go into git. Fetch with a pinned, hashed script like
  `fetch_needle.sh`.
- Upstream moves fast (Needle 3 announced 2026-09-17): re-check `main` at the start of each day.
- The needle repo itself (`cactus-compute/needle`) is Python; issues #31/#33 are not relevant to
  this goal. v1 of this guide suggested them by mistake.
