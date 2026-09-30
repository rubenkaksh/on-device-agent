# Handoff — Needle 3 Flutter contribution (`needle_flutter`)

_Written 2026-09-30. Read this first, then `needle_flutter_contribution_guide.md` for the technical detail._

## 1. TL;DR

- **Goal:** get Cactus **Needle 3** (on-device tool-calling model) running in Flutter on Android and iOS, and make that a real open-source contribution under the owner's name.
- **Route:** ① open an issue on `cactus-compute/needle` → ② build and publish an own package, `needle_flutter` → ③ offer it upstream once the maintainers agree.
- **Who writes the code:** **the owner (Ruben) writes it.** The owner's stated reason is that this is meant to be *their* contribution. Agents explain, review, and unblock; they don't author the binding. See §4 and §5.
- **State:** research and planning are done, and nothing has been built. The next step is the exploration session (guide §4, about 2 hours), then the issue.

## 2. Why this route

| Fact | Consequence |
|---|---|
| The standalone `cactus-flutter` repo was **archived on 2026-07-24** | There's no Flutter repo to contribute to. Flutter support now sits in `cactus/bindings/flutter` |
| That binding is a single `cactus.dart` (`dart:ffi`) and **does not list Needle** | Needle isn't reachable through Cactus's Flutter package today |
| Needle ships **prebuilt** mobile engines: `android-arm64`, `android-armv7`, `ios-arm64`, `ios-sim-arm64` (HF `Cactus-Compute/needle3`) | Nothing to cross-compile. You **wrap** a binary with Dart FFI |
| The engine's C API has **5 functions** (`needle_load / init / complete / embed / reset`) | The binding is small. The value is the isolate, the typed API and the wrapper logic ported from Python |
| Needle is **Apache-2.0** | An independent `needle_flutter` package is allowed, and it can be offered upstream later |

## 3. The plan in one screen

| Milestone | Done when |
|---|---|
| M0 Explore | Guide §4 run on a Mac; engine files, header, alignment, embedding dim recorded in `docs/sessions/` |
| M1 Issue | Issue posted using `docs/needle_issue_draft.md`, filled with M0 facts |
| M2 macOS binding | `complete`/`embed`/`reset` work from a Dart test against the real engine |
| M3 Isolate + API | Public `Needle` class over one worker isolate; stub-engine tests green |
| M4 Android / M5 iOS | Example app runs on a real device; latency and RAM measured |
| M6 Wrapper parity | Date fact, stateless mode, grounding check, null confidence |
| M7 Publish v0.1.0 | README, example, licence and credit, telemetry off by default, on pub.dev |
| M8 Adopt | `on-device-agent` uses it through the `ActionModel` interface |
| M9 Upstream | PR or link, per the maintainers' answer on the issue |

The app-level design that will consume the package is in `needle3_implementation_plan.md`. Its Phase 0 is superseded by this work. The tasklog card **N0 is parked as user-owned**, so the autonomous executor must not pick it up.

## 4. The "no AI" policy: exactly what it says

**Source (verified verbatim on 2026-09-30):** `cactus-compute/cactus` → `CONTRIBUTING.md`, *Code Guidelines*:

> **AI-Generated Code**: Do not blindly PR AI slop, this codebase is very complex, they miss details.

Other rules in the same file that matter here:
- **Scope:** keep PRs "lean" and within "the scope of the GH issue". Don't do bloated PRs.
- **Testing:** "A PR that fails to build is the biggest red flag, means it was not tested." Run `cactus test` (including `--ios` / `--android`).
- **Benchmarks:** "Test performance impact, Cactus is performance-critical."
- **Style:** C++20, minimal comments, "make your code read like plain english."
- **DCO:** all contributions must comply with the Developer Certificate of Origin, so the contributor certifies they have the right to submit.
- **Docs:** update docs when the public API changes.

**What it is and isn't**
- It **is** a warning against unreviewed, unverified AI output in a complex C++ engine. It is **not** a written ban on any AI assistance.
- It applies to the **main `cactus` repo**. The **`needle` repo has no CONTRIBUTING file** (404). Its policy is unknown, and it's question Q8 in the issue draft.
- It doesn't govern the owner's **own** `needle_flutter` repo.

> ⚠️ **Correction:** earlier in this project I summarised this rule as "avoid AI-generated code submissions" and told the owner I shouldn't write upstream code because of it. That was a paraphrase from a summarising tool and it was stronger than the actual text. The wording above is what the file says. The *working rule below* stays conservative for a separate reason: the owner wants this to be their own contribution.

### Working rules for agents and helpers

| Situation | Rule |
|---|---|
| Code that will be **submitted upstream** (PR to `cactus` or `needle`) | **The owner writes it.** Agents may explain, review and test, but don't author the submitted diff |
| Core code of the **owner's own package** (FFI bindings, isolate protocol, native loading, public API) | **The owner writes it.** This is the contribution the owner wants to own |
| Explaining `dart:ffi`, isolates, packaging, the Needle C API | ✅ Allowed and encouraged |
| Reviewing the owner's diffs, hunting FFI memory or lifetime bugs, finding edge cases | ✅ Allowed |
| Test scaffolding, CI YAML, README prose, example-app boilerplate | Only **on request**. Mark it in the commit message; the owner decides whether to keep it |
| **Signed-off-by (DCO)** | Never add it on the owner's behalf. It's a personal certification |
| Disclosing AI help in an upstream PR | Recommended: say what was assisted. Don't hide it |
| Commit trailers on upstream-bound commits | Owner's call. Agent `Co-Authored-By` trailers aren't added by default there |

These rules are my recommendation from the policy text and the owner's intent. They are not Cactus's rules. If the maintainers answer Q8 with something clearer, update this table.

## 5. What the owner has decided

- Route: issue → own package → upstream (chosen over "upstream only" and "own package only").
- The owner has **C/C++** experience. Assume no prior `dart:ffi`, NDK, or xcframework experience.
- Output lives in `docs/` on branch `docs/needle3-plan`; no PR was requested for it.
- Learning loop A (LoRA) runs **locally on the owner's Mac with JAX**, and loop B (correction memory) runs on the device. Local LoRA builds lose the confidence score, which the plan accounts for.

## 6. Do-not-forget technical facts (details in the guide)

- **One global engine instance per process.** It can't unload weights, so a new model takes effect on the next launch. One toolset per session, and changing tools re-runs `needle_init`.
- `system` takes **facts** (`date`, `locale`, `device`, …), **not** instructions. Tools accept regex `triggers`.
- With more than 5 tools, the engine retrieves the top 5 per turn. Off-topic input returns an empty `function_calls`, which must be handled.
- **Telemetry is on by default in the engine**, with opt-out via `NEEDLE_TELEMETRY=0` / `DO_NOT_TRACK=1`. On mobile this needs `setenv` before load, so verify with a proxy and default it to off in the package. It also affects the iOS privacy manifest and the Android Data safety form.
- Check **16 KB page alignment** of the prebuilt `.so` (Android 15+ on Play).
- Don't bundle `needle3.cact` (~35 MB) in the package; take a path or bytes.

## 7. Open questions

| # | Question | Where it gets answered |
|---|---|---|
| Q1–Q7 | iOS artefact format, `needle_load` buffer ownership, thread-safety, output overflow, mobile telemetry, 16 KB alignment, binary/weights licence | Guide §10: exploration session or the issue |
| Q8 | Does `needle` accept a Dart binding, and what's its AI-assistance / DCO process? | The issue |
| Q9 | Unofficial package name: is `needle_flutter` free on pub.dev, and does Cactus object to the name? | Check pub.dev; mention in the issue |

## 8. Next actions (in order)

1. Owner: run guide §4 on a Mac and record the results in `docs/sessions/<date>.md`.
2. Owner: fill `docs/needle_issue_draft.md` and post it on `cactus-compute/needle`. Posting is the owner's action.
3. Owner: scaffold the package with `flutter create --template=plugin_ffi` and start M2 in a **separate repo**, not inside `on-device-agent`.
4. Agent (on request): explain and review as in §4. Update this file and the tasklog as milestones land.

## 9. Files and where things are

| File | Purpose |
|---|---|
| `docs/needle_flutter_handoff.md` | This file |
| `docs/needle_flutter_contribution_guide.md` | Full technical prep: C API, skills gap, toolchain, package layout, testing, compliance |
| `docs/needle_issue_draft.md` | Ready-to-fill issue text |
| `docs/needle3_implementation_plan.md` | App-side plan that will consume the package |
| `docs/tasklog.md` | Cards N0–N8 (N0 parked, user-owned) |

Branch: `docs/needle3-plan` on `rubenkaksh/on-device-agent`. No PR is open for it. The separate PR #3 (`fix/sequential-gemma-generation`) is unrelated Gemma work.

## 10. Sources

- Cactus `CONTRIBUTING.md`: <https://raw.githubusercontent.com/cactus-compute/cactus/main/CONTRIBUTING.md>
- Needle repo: <https://github.com/cactus-compute/needle> (`llms.txt`, `needle/__init__.py`, `needle/agent/fetch.py`, `tests/test_worker.py`)
- Archived Flutter plugin: <https://github.com/cactus-compute/cactus-flutter>
- Current Flutter binding: <https://github.com/cactus-compute/cactus/tree/main/bindings/flutter>
