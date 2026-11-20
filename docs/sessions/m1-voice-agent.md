# M1 — Voice reminder agent

Speak (or type) → on-device STT → FunctionGemma 270M picks a tool → tool runs
against Apple Reminders. No network after the one-time model download.

## Flow

```
SpeechInput ──text──▶ Agent ──utterance──▶ AgentModel ──ToolCallDecision──▶ AgentTool ──▶ ReminderStore
(native STT)          (orchestrator)       (FunctionGemma)                   (create/list/complete)  (EventKit)
```

## Plug-and-play seams

| Seam | Interface | Default | Swap by |
|---|---|---|---|
| Agent model | `lib/agent/agent_model.dart` → `AgentModel` | `FunctionGemmaAgentModel` | New class + branch in `agent_model_factory.dart`; select with `AGENT_MODEL` |
| Speech-to-text | `lib/speech/speech_input.dart` → `SpeechInput` | `NativeSpeechInput` (speech_to_text, `onDevice: true`) | New class + branch in `speech_input_factory.dart`; select with `SPEECH_INPUT` |
| Reminder storage | `lib/reminders/reminder.dart` → `ReminderStore` | `EventKitReminderStore` (iOS), `InMemoryReminderStore` elsewhere | Return it from `reminder_store_factory.dart` |
| Skills | `lib/agent/agent_tool.dart` → `AgentTool` | `reminderTools(...)` | Implement `AgentTool`, add to the `ToolRegistry` in `main.dart` |
| Date resolution | `NaturalDateParser` | rule-based | Pass a different parser to `reminderTools` |

Optional `.env` keys (add them yourself; `.env*` files are off-limits to the
executor): `AGENT_MODEL=functionGemma`, `AGENT_MODEL_URL=<custom .litertlm>`,
`SPEECH_INPUT=native`.

All of them can also be injected through `GemmaPocApp(...)` (used by tests).

## Design notes

- **The model never does date maths.** `create_reminder.due` is the user's own
  words ("tomorrow at 5pm"); `NaturalDateParser` resolves it in Dart. If the
  model leaves the time in the title, the tool recovers it.
- FunctionGemma is single-turn in flutter_gemma (history cleared each call),
  so each utterance is independent. The tool result text is the reply — no
  second generation, which keeps latency at one model call.
- `GemmaService.isModelInstalled` now also checks `modelType == gemmaIt`, so
  the chat POC does not accidentally load FunctionGemma (both are `.litertlm`).
- iOS EventKit bridge lives in `ios/Runner/AppDelegate.swift`
  (`on_device_agent/reminders`); due reminders get an `EKAlarm` so iOS fires
  the alert natively.

## Mac test checklist

- [ ] `flutter pub get` (adds `speech_to_text`), `cd ios && pod install`
- [ ] `flutter analyze` clean, `flutter test` green (not runnable in the cloud
      session that wrote this — pub.dev was unreachable there)
- [ ] Run on a physical iPhone; first launch downloads FunctionGemma (~284 MB)
- [ ] Allow Microphone, Speech Recognition and Reminders prompts
- [ ] "Remind me to call mom tomorrow at 5pm" → appears in Apple Reminders
- [ ] "What are my reminders?" → lists it
- [ ] "Mark call mom as done" → completed in Apple Reminders
- [ ] Airplane mode: all three still work
- [ ] Record accuracy misses here → candidates for a FunctionGemma fine-tune

## Next (M2 candidates)

- Spoken replies (TTS), Android `ReminderStore`, timers/alarms/calendar tools,
  fine-tuned FunctionGemma on this tool set.
