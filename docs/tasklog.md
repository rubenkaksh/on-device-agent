# Task Log — on-device-agent (live task board)

> Trello-style status board for the on-device-agent workspace.
> Statuses: 🔴 Active / 🟡 Backlog / 🟠 Parked / ⚪ Descoped / ⚠️ User actions / 📋 Closed.
> The `🤖 Autonomous queue` section is executor-owned — the orchestrator picks up `✅ Approved` cards.

_Last updated: 2026-09-26 (N0–N8 Needle 3 cards added)_

## 🤖 Autonomous queue (executor-owned)
> Routing tag controls cap multiplier: scr=tight (est×1.5+5), bld=standard (est×2+10), orc=generous (est×2+15).
| Card | Scope | Estimate (min) | Depends on | Done when | Status | Routing |
|---|---|---|---|---|---|---|
| D1 | on-device-agent | 45 | | Stop-token guardrails + generation cancellation: (1) configure stop tokens `<end_of_turn>`, `<eos>`, `<start_of_turn>` at engine level + temperature 0.2, (2) stream token interception — break on stop tokens, strip literal occurrences from output, (3) StreamSubscription lifecycle management with isGenerating state, (4) stopGeneration() cancel function bound to dispose/onDone/onError, (5) UI toggle — Send button becomes Stop while generating, input disabled during generation. flutter analyze clean. Commit + push to feature branch. | ✅ Done | bld |
| D2 | on-device-agent | 5 | | Make LLM response text selectable/copyable — long-press assistant message bubbles to copy full response to clipboard. | ✅ Done | scr |
| D3 | on-device-agent | 3 | | Trim trailing whitespace/newlines from finalized assistant responses. | ✅ Done | scr |
| N0 | on-device-agent | 120 | | Needle 3 runtime spike per docs/needle3_implementation_plan.md Phase 0: try NDK/iOS build of Needle C engine, check cactus plugin for Needle, check embeddings in C API, measure latency/RAM on flagship. Record Path A/B/C decision in docs/sessions/. | 🟡 Backlog | orc |
| N1 | on-device-agent | 45 | N0 | `ActionModel` interface + `ActionResolution` types + `FakeActionModel` in test/helpers (Phase 1). flutter analyze clean. | 🟡 Backlog | bld |
| N2 | on-device-agent | 60 | N1 | Action registry: `ActionTool`, fixed + runtime registries, context filter, Needle tool-JSON serializer, demo actions (Phase 2). Unit tests. | 🟡 Backlog | bld |
| N3 | on-device-agent | 120 | N0, N1 | Engine integration per chosen path: model manager (manifest, SHA-256, rollback), background isolate, lifecycle, response parsing (Phase 3). | 🟡 Backlog | orc |
| N4 | on-device-agent | 60 | N2, N3 | Resolution pipeline: validator, confidence gate, confirm/missing-arg flow, destructive-action confirmation (Phase 4). Unit tests with fake. | 🟡 Backlog | bld |
| N5 | on-device-agent | 60 | N4 | Learning B: sqflite correction memory, embedding/alias lookup, single-tool arg extraction on hit, clear-memory setting (Phase 5). | 🟡 Backlog | bld |
| N6 | on-device-agent | 45 | N2 | Eval harness: golden set + Python eval script on Mac + on-device integration test (Phase 7). | 🟡 Backlog | bld |
| N7 | on-device-agent | 60 | N5, N6 | Learning A: JSONL export, dataset build script, LoRA finetune/build commands, eval gate, manifest-based model update (Phase 6). | 🟡 Backlog | bld |
| N8 | on-device-agent | 60 | N4 | UI: command bar, action result card (✓/✎), Notes/Reminders/Settings target screens, model state machine; retire GemmaService (Phase 8). | 🟡 Backlog | bld |

## 📋 Closed / superseded
- None yet.
