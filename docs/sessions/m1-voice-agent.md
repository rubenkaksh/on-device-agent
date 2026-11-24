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

Run 2026-11-24 on a Mac (Flutter 3.47.5, Xcode, CocoaPods 1.16.2).

Build gates (verified):

- [x] `flutter pub get`: resolved, speech_to_text 7.5.0, no changes needed
- [x] `flutter analyze`: no issues, first run
- [x] `flutter test`: all passed (agent, natural_date_parser, widget + D4 tests)
- [x] `pod install`: needed `platform :ios, '16.0'` and
      `use_frameworks! :linkage => :static` (MediaPipe static xcframeworks)
- [x] `flutter build ios --profile`: compiles, incl. Swift EventKit bridge
- [x] Signed with the local Apple Development identity, install started on
      iPhone 13 Pro over wireless debugging (iOS 27.2.1)

Device checklist (items 1-12 of M1-mac-handoff.md): **not verified.** They need
a person at the phone (mic, speech, Reminders prompts, airplane mode). The
install/launch step had not confirmed the app opened when this was written.

| # | Item | Result |
|---|---|---|
| 1-12 | all device items | not verified |

## Accuracy log

Not run: needs the app running on the device. Table to fill (utterance |
`ToolCallDecision` | correct?).

## Next (M2 candidates)

- Spoken replies (TTS), Android `ReminderStore`, timers/alarms/calendar tools,
  fine-tuned FunctionGemma on this tool set.
