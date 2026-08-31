# AGENTS.md — on-device-agent

Inherits the global software-engineer instructions at `~/.config/opencode/AGENTS.md`. This is a Flutter workspace for on-device LLM POCs.

## Purpose

Flutter projects running LLMs entirely on-device — no API calls, no cloud dependency.

## Current Projects

- **flutter_gemma_poc** — Gemma 2B on-device inference via `flutter_gemma` (MediaPipe backend)

## Flutter Conventions

- Feature-based structure under `lib/`
- `flutter analyze` must pass clean before any commit
- No null force operators (`!`) or force casts (`as T`) — per global Hard Rule
- Use `?.` / `??` / pattern matching for null safety
- Shared test fakes in `test/helpers/` — never hit real platform channels

## Autonomous Executor

This workspace is a consumer of the autonomous executor. Cards go in `docs/tasklog.md`.

### Card Types

| Type | Scope field | Behavior |
|---|---|---|
| `general` | Task description | Execute standalone work |
| `project` | Repo path | Dispatch to target repo |
| `new-project` | Plan path | Create from implementation plan |

## Layout
```
on-device-agent/
├── AGENTS.md
├── lib/
│   ├── main.dart
│   ├── screens/
│   └── services/
├── test/
├── android/
├── ios/
├── docs/
│   ├── tasklog.md
│   └── sessions/
├── loop-constraints.md
├── loop-budget.md
└── README.md
```
