# 0002 — Two bugs, one cause: separate lifecycles

## Date

2026-09-02

## Context

Two distinct bugs appeared during the D1 stop-token and generation-cancellation
work on consecutive days. Both were rooted in the same misunderstanding: treating
the Dart stream and native generation as a single lifecycle.

## Bug 1: Infinite `<end_of_turn>` tags (D1)

### Symptom

The model emitted repeated `<end_of_turn>` tokens that leaked into the displayed
response. The UI showed a wall of `<end_of_turn>` tags after each answer.

### Cause

Gemma models emit `<end_of_turn>` to signal end of a turn. Without interception,
these literal tokens pass through to the Dart stream as visible text. The native
engine continues sampling and may emit several before settling, creating a loop of
visible stop-token text.

### Fix (D1 — `4100bd3`)

Stream token interception in `GemmaService.sendMessageStream`:

```dart
for (final stop in _stopTokens) {
  if (token.contains(stop)) {
    token = token.replaceAll(stop, '');
    hitStop = true;
    break;
  }
}
```

Each token is checked against `_stopTokens` before being emitted. On a hit, the
literal stop-token text is stripped and generation halts via `break`.

### Takeaway

A Dart-side safety net is necessary even when the native engine handles stop
tokens, because different backends (MediaPipe `.task` vs LiteRT-LM `.litertlm`)
handle stop conditions differently. The safety net must still respect the native
lifecycle — see Bug 2.

## Bug 2: Breaking after one message response (D2)

### Symptom

The first prompt worked fine. The second prompt crashed with:

```
PredictDone() AddQueryChunk should not be called before PredictDone
```

### Cause

D1's fix used `break` to exit the `await for` loop on stop-token detection.
This ended the Dart-side stream immediately, making the UI appear idle. But the
native prediction was still unwinding. The user could then send a second prompt,
which called `addQueryChunk` before the native engine reached `PredictDone`.

The root: **the Dart stream ending is not proof that native inference has
completed**.

### Fix (`9dba3e5`)

1. On stop-token detection, request native cancellation instead of `break`.
2. Continue draining the native stream until it ends naturally.
3. Track completion via a `Completer<void>` (`_generationFuture`).
4. `stopGeneration()` awaits `_generationFuture` before returning, ensuring
   the next prompt cannot be staged until native is done.

```dart
// On stop token:
_stopRequested = true;
await _requestNativeStop();   // signal native
continue;                     // drain, don't break

// On Stop button:
await _requestNativeStop();
await _generationFuture;      // wait for native completion
```

### Takeaway

A Dart `StreamSubscription` is an observation channel, not a lifecycle
controller. The native session owns the prediction state. Any time the app
cancels or detects a stop, it must wait for the native session to reach a
terminal state before staging a new query.

## Related: stale model metadata

The app also had `ModelFileType.task` registered for a `.litertlm` artifact.
This routed the model through MediaPipe instead of LiteRT-LM, which uses
different prompt formatting. The log showed `fileType=task` while the URL
ended in `.litertlm`. Fix: install with `ModelFileType.litertlm` and reinstall
once after the code change.

## Pattern

Both bugs share one pattern: **the Dart stream and native generation are
separate lifecycles that can diverge**. The app must treat the native session
as the source of truth for "is inference done?", not the Dart stream.

| Bug | What looked done | What was actually still running |
|---|---|---|
| Infinite `<end_of_turn>` | Nothing — tokens leaked visibly | Native engine sampling repeatedly |
| Breaking after one message | Dart stream closed | Native `Predict` still unwinding |

## Next stretch

Design a small diagnostic overlay that shows native lifecycle state in
real-time (streaming / native-done / idle) to catch similar divergences
earlier.
