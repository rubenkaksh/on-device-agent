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

Source: `Documents/agent_log.txt` pulled from the iPhone (2026-11-24). "Heard" is
what speech-to-text produced. Tool = did the model pick the right tool; args =
were its arguments usable as given.

| Heard | Model call | Tool | Args |
|---|---|---|---|
| Remind me to buy milk Friday morning | create_reminder {title: buy milk Friday morning, due: 2024-05-22T12:00:00} | right | due invented (past ISO) |
| Mark call mom as Jan (STT miss) | create_reminder {title: Mom not coming, due: 2024-05-24...} | wrong | n/a |
| Mark call mom has done (STT miss) | complete_reminder {title: Mom has done} | right | paraphrased |
| Mark call mom as done | complete_reminder {title: Mom not done} | right | paraphrased |
| Call mom as done | complete_reminder {title: Mom} | right | truncated |
| Complete all reminders call mom as done | complete_reminder {title: Mom} | right | truncated |
| All | complete_reminder {title: All} | n/a | n/a |
| Call mom | create_reminder {title: Mom's Reminder, due: 2024-05-14...} | right | due invented |

Findings: tool choice was right 5 of 6 clear cases; arguments were unreliable.
The model invents past ISO `due` values and paraphrases titles. Mitigation
(commit "resolve dates from the utterance"): tools receive the raw utterance;
dates are parsed from it and past model dates are ignored; `complete_reminder`
falls back to a title that appears in the utterance. After the fix on device:
"buy milk Friday morning" -> Nov 27 9:00 AM; "Mark call mom as done" -> marked
"call mom" done. Two speech-to-text misses ("as Jan", "has done") are not the
agent's fault. Remaining device checklist items stay not verified.

## Next (M2 candidates)

- Spoken replies (TTS), Android `ReminderStore`, timers/alarms/calendar tools,
  fine-tuned FunctionGemma on this tool set.
