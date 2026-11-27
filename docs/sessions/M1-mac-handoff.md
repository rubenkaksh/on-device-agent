# M1 handoff: build, fix and device-test the voice reminder agent on a Mac

Audience: a local Claude Code session (or you) on a Mac with an iPhone. The cloud session that wrote M1 could not reach pub.dev, so **nothing here has been compiled**. `flutter pub get`, `flutter analyze` and `flutter test` have never run on this code. The flutter_gemma API was checked against the package source at tags v1.6.5 and v1.8.2 (the lockfile pins 1.7.0, which has no tag), and speech_to_text against its master branch. Your job: make it compile, make the tests pass, run it on an iPhone, and record what you see.

Background: `docs/sessions/m1-voice-agent.md` (architecture, plug-and-play seams). Card: M1 in `docs/tasklog.md`. PR: #5 (draft, head `feat/m1-voice-reminder-agent`, base `feature/g6-gemma-poc`).

Follow `AGENTS.md` and `loop-constraints.md`: no `!` and no `as T`, never edit `.env*`, max 3 fix attempts per item before escalating, `flutter analyze` must be clean before you call anything done. Don't push to the base branch.

## 0. Prerequisites

- Flutter stable, Dart `^3.8`. Xcode + CocoaPods.
- A **physical iPhone** (iOS 17+ preferred). The simulator has no on-device speech model and no realistic inference speed.
- Internet on the Mac for `pub get`, `pod install` and the first model download (~284 MB).

## 1. Get the code and make it compile

```bash
git fetch origin
git checkout feat/m1-voice-reminder-agent
./run.sh pub get
flutter analyze
flutter test        # agent_test, natural_date_parser_test, widget_test + the existing D4 tests
```

Known risks, most likely first:

| Risk | What to check |
|---|---|
| `speech_to_text: ^7.0.0` doesn't resolve against Dart 3.8 | Pick the newest 7.x that resolves (`flutter pub add speech_to_text`). The code uses `SpeechListenOptions`, `SpeechToText.doneStatus`, `stop()`, `cancel()`, all present in 7.x. |
| flutter_gemma 1.7.0 API drift | `lib/agent/models/function_gemma_agent_model.dart` uses `ModelType.functionGemma`, `createChat(tools:, supportsFunctionCalls:, modelType:)`, `generateChatResponse()`, `FunctionCallResponse`, `ParallelFunctionCallResponse`, `FlutterGemma.isModelInstalled(id)`. If any differ in 1.7.0, adapt *only that file*. |
| Lints | `firstOrNull` (dart:core, Dart 3), `if (x case final y?)` in collections, `||` enum patterns: all Dart 3.0+. A few lines exceed 80 chars, so run `dart format lib test`. |
| `test/widget_test.dart` | Pumps `GemmaPocApp` with fakes and taps the mic. If it hangs in `pumpAndSettle`, the spinner in the "thinking" state is the likely cause. Use bounded `pump`s. |

## 2. iOS setup

```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace   # set your signing team
```

- **Deployment target (same as D4):** `IPHONEOS_DEPLOYMENT_TARGET = 12.0` and the Podfile `platform` line is commented out, but flutter_gemma_mediapipe needs 16.0. If `pod install` complains, uncomment `platform :ios, '16.0'` and set 16.0 in Xcode. Put that in its own commit.
- The EventKit bridge is in `ios/Runner/AppDelegate.swift` (`RemindersChannel`, channel `on_device_agent/reminders`). It sits in AppDelegate on purpose, so no pbxproj edit is needed. If Swift fails on `requestFullAccessToReminders`, you're building with an Xcode older than 15.
- Info.plist already has the microphone, speech recognition and reminders (incl. iOS 17 full-access) usage strings.

```bash
./run.sh run -d <iphone-id> --profile
```

## 3. Device test checklist

Mark each pass/fail with a one-line note in `docs/sessions/m1-voice-agent.md` (replace the checklist there).

1. First launch shows "Downloading model… N%", then the empty-state hint.
2. Kill and relaunch: **no re-download**. If it re-downloads, `FlutterGemma.isModelInstalled(_modelId)` is using the wrong id. Log `FlutterGemma.listInstalledModels()` and match it.
3. Tap the mic and accept the mic + speech prompts. Partial transcript appears live.
4. "Remind me to call mom tomorrow at 5pm" → Reminders permission prompt → reply "Reminder set: "call mom" tomorrow at 5:00 PM." → present in Apple Reminders with the alert time.
5. "What are my reminders?" → lists it.
6. "Mark call mom as done" → completed in Apple Reminders.
7. "Remind me to buy milk in 20 minutes" → alert fires ~20 min later.
8. Typed input works the same as voice.
9. Airplane mode: 3 to 7 still work. If speech fails offline, the device lacks an on-device model for its locale. Try passing `localeId: 'en_US'` to `NativeSpeechInput` and note it.
10. Deny Reminders permission → reply asks to enable it in Settings, no crash.
11. Say something unrelated ("tell me a joke") → a text reply or "can't do that yet", no crash.
12. App bar chat icon → Gemma chat POC still works (it should show its install card, since FunctionGemma is now the active model; Download re-activates Gemma 3n). Come back and confirm the agent still answers.

## 4. Accuracy log

FunctionGemma base is ~58% on Google's Mobile Actions eval, so expect misses. Try ~20 varied phrasings ("set a reminder…", "don't let me forget…", "remind me at 9 to…", Nepali-English mixes). Record each `Agent: ToolCallDecision(...)` debug line and whether it was right, as a table in `docs/sessions/m1-voice-agent.md`. Those rows are the dataset for a future fine-tune. Don't tune prompts or tool descriptions inside this card beyond obvious one-line fixes.

## 5. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Model always returns text, never a tool call | `supportsFunctionCalls`/`modelType` not reaching the chat, or 1.7.0 needs `ModelType.functionGemma` at install. Check the `installModel(modelType:)` call. |
| `MissingPluginException` on `on_device_agent/reminders` | AppDelegate change not built. Clean build folder, rebuild. |
| Reminder saved but no alert | Check `EKAlarm` added; the Reminders app notification setting. |
| Speech errors `error_listen_failed` | Audio session conflict or simulator. Use a real device. |
| Wrong due time | Add the phrase as a case in `test/natural_date_parser_test.dart`, then fix `NaturalDateParser`. |

## 6. Report back

- Commit fixes to `feat/m1-voice-reminder-agent` and push. Keep the PR as a draft.
- Update `docs/sessions/m1-voice-agent.md` (checklist results + accuracy table) and the M1 row in `docs/tasklog.md`.
- Summarize to the human: what compiled-fixed, checklist pass/fail, accuracy %, and anything that needs a decision.
