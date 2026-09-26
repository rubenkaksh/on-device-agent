# Needle 3 On-Device Action Mapping — Implementation Plan (Flutter)

> Replaces `flutter_gemma` in the on-device-agent POC with Cactus **Needle 3**
> for mapping natural-language prompts to app actions, with two learning
> loops: **(B)** on-device correction memory and **(A)** periodic LoRA
> fine-tuning on a Mac (local JAX).

## Context & known facts (Sept 2026)

| Item | Status |
|---|---|
| Model | Needle 3 — tool-calling / extraction model, 2-bit `.cact`, ~35 MB full depth (29–121M params), depths 2–20 layers via `needle build --layers N` |
| Output | JSON: `function_calls`, `reasoning`, calibrated `confidence` [0–1]; calls < 0.1 go to `suppressed_calls`; off-topic → empty list |
| Tools | JSON schema `{name, description, parameters}`. With **> 5 tools**, the engine retrieves and renders only the **top 5 per turn** (index persisted via `tool_index_path`) |
| System prompt | Not a documented input. Guidance goes into tool names, descriptions, and schema constraints |
| Fine-tuning | LoRA on attention projections, merged at export: `needle finetune` → `needle build --lora` |
| **Mobile runtime** | ⚠️ Prebuilt engines listed only for macOS-arm64, linux-x86_64, WASM. C API mentioned. **No official Android/iOS build, and the `cactus` Flutter plugin does not list Needle.** Phase 0 resolves this. |

Target: flagship Android and iOS devices.

---

## Phase 0 — Runtime spike (decision gate)

**Goal:** Find out how Needle 3 will run inside Flutter on a phone before building anything else.

1. **S1 — Native engine build:** Cross-compile the Needle C engine for
   - Android `arm64-v8a` (NDK, CMake) → `libneedle.so`
   - iOS `arm64` + simulator → `Needle.xcframework`

   Load `needle3.cact` and run one tool call from a tiny C harness on a real device.
2. **S2 — Plugin check:** Check the latest `cactus` (pub.dev) / `cactus-flutter` release for Needle support.
3. **S3 — Embeddings check:** Confirm whether the C API exposes sentence embeddings. Phase 5 needs them.
4. **Measure on a flagship device:** load time, p50/p95 latency per call, peak RAM.

**Decision:**

| Result | Path |
|---|---|
| S1 works | **Path A:** own FFI plugin (`packages/needle_ffi`) using `dart:ffi` and `ffigen` |
| S1 fails, S2 has Needle | **Path B:** use the `cactus` plugin |
| Both fail | **Path C:** use the `cactus` plugin with `gemma3-270m` tool calling, behind the same Dart interface; switch to Needle when mobile support lands |

**Exit:** a decision recorded in `docs/sessions/`, plus the measured numbers.

---

## Phase 1 — Backend abstraction

Keep the rest of the app independent of whichever path Phase 0 picks.

```dart
abstract interface class ActionModel {
  Future<void> load(ModelSource source);
  Future<ActionResolution> resolve(String query, List<ActionTool> tools);
  Future<List<double>?> embed(String text); // null if backend lacks it
  Future<void> dispose();
}

final class ActionResolution {
  final List<ActionCall> calls;       // empty = off-topic / not understood
  final List<ActionCall> suppressed;
  final double confidence;
  final String? reasoning;
}
```

- `NeedleActionModel` (Path A/B) and `CactusGemmaActionModel` (Path C).
- `FakeActionModel` in `test/helpers/`. Tests never touch platform channels or FFI.
- Retire `GemmaService` once the new flow reaches parity.

---

## Phase 2 — Action registry (fixed + runtime)

```dart
final class ActionTool {
  final String name;              // snake_case verb the user would say
  final String description;       // what + WHEN (trigger phrases) + formats
  final Map<String, ActionParam> params; // type, enum, format, required
  final ActionHandler handler;
  final ActionOrigin origin;      // fixed | runtime
}
```

- **Fixed registry:** declared at build time; eligible for LoRA training (Phase 6).
- **Runtime registry:** `register()` / `unregister()` while the app runs; declared to Needle in each call's context.
- **Context filter:** send only the tools valid for the current screen or state. This keeps Needle's top-5 retrieval accurate.
- **Serialiser:** `ActionTool` → Needle tool JSON.

### Tool-design rules (these replace a system prompt)

1. One tool per action. No `mode` switches inside a single tool.
2. Name tools with words users say: `add_note`, not `note_op_create`.
3. The description states the trigger: *"Use when the user says add, write down, remember, note…"*
4. Put formats in the description (*"date as YYYY-MM-DD"*) and constraints in the schema (`enum`, `required`).
5. Avoid near-duplicate tools. Merge them or make the triggers clearly different.

### POC demo actions (replace with your real set)

| Tool | Params | Origin |
|---|---|---|
| `add_note` | `text` (req) | fixed |
| `set_reminder` | `text` (req), `time` (HH:mm), `date` (YYYY-MM-DD) | fixed |
| `open_screen` | `screen` enum [notes, reminders, settings] | fixed |
| `toggle_theme` | `mode` enum [light, dark, system] | fixed |
| `clear_notes` | — | fixed (requires confirmation) |
| `run_shortcut` | `name` (req) | runtime (user-defined shortcuts) |

---

## Phase 3 — Engine integration

1. **Model manager:** download `needle3.cact` (and later the tuned `.cact`) to the Application Support directory. Check its SHA-256 against a small `manifest.json` (`version`, `url`, `sha256`, `layers`). Keep the previous model for rollback.
2. **Depth:** use the full 20 layers on flagship devices. Revisit only if Phase 0 latency exceeds budget.
3. **Isolate:** run all FFI calls in a long-lived background isolate so the UI thread never blocks. Serialise requests; this reuses the lesson from D1 about generation lifecycles.
4. **Lifecycle:** `load` once at startup; `dispose` on app detach. Persist the tool index at `tool_index_path`.
5. **Parsing:** map the engine JSON to `ActionResolution`. Any parse failure becomes an empty result, never a crash.

---

## Phase 4 — Resolution pipeline

```
query
  → (1) Memory lookup (Phase 5)
        hit ≥ τ_mem → resolve(query, [thatToolOnly])   // extract args only
  → (2) Needle resolve(query, contextFilteredTools)
  → (3) Dart validator (schema: required, enum, format)
  → (4) Confidence gate
        ≥ τ_high           → execute
        τ_low … τ_high     → confirm card ("Add note 'milk'?")
        < τ_low / empty    → "Didn't get that" + top suggestions
  → (5) Execute handler → log outcome
```

- Starting thresholds: `τ_high = 0.8`, `τ_low = 0.4`, `τ_mem = 0.9` cosine. Tune them with the eval harness (Phase 7).
- Destructive actions (`clear_notes`) always need confirmation, whatever the confidence.
- If an argument is missing or invalid, show an inline form for that one field instead of failing the whole action.

---

## Phase 5 — Learning B: correction memory (on-device, immediate)

1. **Capture:** the result card offers ✓ and ✎. ✎ opens a picker for the correct action and editable arguments.
2. **Store** in `sqflite`: `query`, `embedding`, `tool`, `args_json`, `source` (confirmed | corrected), `model_version`, `created_at`.
3. **Lookup:** cosine similarity over stored embeddings. A few hundred rows fits a brute-force scan in Dart.
   - If Needle doesn't expose embeddings (Phase 0 S3), fall back to normalised-text match plus user aliases.
4. **Aliases:** users can teach phrases, e.g. "groceries" → `open_screen(notes)`. These are checked before the embedding lookup.
5. **Hygiene:** cap rows per tool, drop rows for unregistered runtime tools, and add a settings entry to clear memory.

---

## Phase 6 — Learning A: LoRA fine-tuning (Mac, local JAX)

1. **Export:** the settings screen offers "Export training data", which shares a JSONL file of corrections. This is opt-in and nothing is uploaded automatically.
2. **Dataset build** (script in `tool/needle/`):
   - Merge the exported corrections with synthetic paraphrases for each fixed tool (target ≥ 50 per tool).
   - Add **off-topic negatives** with `"answers": []` (~15% of rows).
   - Format each row as `{"query": "...", "tools": [...], "answers": [{"name": "...", "arguments": {...}}]}`.
   - Split 80/10/10 by paraphrase group so the same wording never appears in both train and test.
3. **Train and build:**
   ```bash
   pip install "cactus-needle[train]"
   needle finetune data/train.jsonl --epochs 10 --out adapter.safetensors
   needle build --lora adapter.safetensors --layers 20 --out needle3-app-vN.cact
   ```
4. **Gate:** run the Phase 7 eval. Ship only if action accuracy and off-topic rejection both improve on the current model.
5. **Ship:** upload the `.cact`, bump `manifest.json`, and let the app download it and keep the previous model for rollback.
6. **Runtime tools are never trained.** They stay context-declared, and memory (B) covers them.

---

## Phase 7 — Eval harness

- **Golden set** `tool/needle/eval.jsonl`: ≥ 20 queries per action (paraphrases, missing arguments, typos, mixed intents) plus ≥ 50 off-topic queries.
- **Metrics:** action accuracy, argument exact-match, off-topic false-positive rate, confidence calibration (reliability buckets), p50/p95 latency, peak RAM.
- **Runs:** on the Mac via the Python `needle` package (fast iteration and the gate for Phase 6), and on device via an integration test.

---

## Phase 8 — UI

- Replace the chat screen with a **command bar** and an action result card showing tool, arguments, confidence, and ✓ / ✎.
- Add simple Notes, Reminders, and Settings screens as action targets.
- Model states: `Downloading` → `Loading` → `Ready` → `Resolving` → `Executing` / `NeedsConfirmation`.

---

## Acceptance checklist

- [ ] Phase 0 decision recorded with on-device numbers
- [ ] p95 resolve latency < 300 ms on flagship (tune after spike)
- [ ] Peak added RAM < 100 MB
- [ ] Action accuracy ≥ 90% and off-topic false-positive rate ≤ 5% on the golden set (base model)
- [ ] LoRA model beats base on held-out test before shipping
- [ ] A corrected query resolves correctly on its next use (memory B)
- [ ] Runtime-registered tool callable without retraining
- [ ] `flutter analyze` clean; no `!` or `as T`; unit tests use `FakeActionModel`

## Risks

| Risk | Mitigation |
|---|---|
| No mobile engine build | Path C fallback behind `ActionModel` |
| Top-5 tool retrieval misses the right tool | Context filtering; tool descriptions with clear triggers |
| No embeddings in the C API | Text and alias memory fallback |
| LoRA overfits to a small correction set | Synthetic paraphrases, negatives, held-out gate |
| Model file corruption or bad update | SHA-256 check and kept rollback copy |
