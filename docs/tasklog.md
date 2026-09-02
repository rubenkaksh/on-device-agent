# Task Log — on-device-agent (live task board)

> Trello-style status board for the on-device-agent workspace.
> Statuses: 🔴 Active / 🟡 Backlog / 🟠 Parked / ⚪ Descoped / ⚠️ User actions / 📋 Closed.
> The `🤖 Autonomous queue` section is executor-owned — the orchestrator picks up `✅ Approved` cards.

_Last updated: 2026-09-02 (D3 added)_

## 🤖 Autonomous queue (executor-owned)
> Routing tag controls cap multiplier: scr=tight (est×1.5+5), bld=standard (est×2+10), orc=generous (est×2+15).
| Card | Scope | Estimate (min) | Depends on | Done when | Status | Routing |
|---|---|---|---|---|---|---|
| D1 | on-device-agent | 45 | | Stop-token guardrails + generation cancellation: (1) configure stop tokens `<end_of_turn>`, `<eos>`, `<start_of_turn>` at engine level + temperature 0.2, (2) stream token interception — break on stop tokens, strip literal occurrences from output, (3) StreamSubscription lifecycle management with isGenerating state, (4) stopGeneration() cancel function bound to dispose/onDone/onError, (5) UI toggle — Send button becomes Stop while generating, input disabled during generation. flutter analyze clean. Commit + push to feature branch. | ✅ Done | bld |
| D2 | on-device-agent | 5 | | Make LLM response text selectable/copyable — long-press assistant message bubbles to copy full response to clipboard. | ✅ Done | scr |
| D3 | on-device-agent | 3 | | Trim trailing whitespace/newlines from finalized assistant responses. | ✅ Done | scr |

## 📋 Closed / superseded
- None yet.
