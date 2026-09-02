# 0001 — Native generation is separate from the Dart stream

## Date

2026-09-02

## Context

The learner already understands model downloading and basic Gemma Flutter
usage. The first real debugging target was a second-prompt failure after a
stop-token/cancellation change.

## Learned

- A streamed Dart response is an observation channel; it is not proof that the
  native prediction has reached `PredictDone`.
- Breaking an outer `await for` on a stop token can make the UI appear idle
  while native inference is still unwinding.
- A later `addQueryChunk` must wait for native cancellation/completion.
- A `.litertlm` URL must be installed with `ModelFileType.litertlm`; stale
  active metadata can route the model through the wrong engine and prompt
  formatter.
- `maxTokens` is a context-window budget, not simply output length.
- Temperature changes sampling variability; it does not repair lifecycle or
  routing errors.

## Evidence

- The app log reported `fileType=task` for a `.litertlm` artifact.
- Native reported `PredictDone() AddQueryChunk should not be called before
  PredictDone` only on the second prompt.
- The regression fake rejects a second query while its first generation is
  active and passes after native stop plus stream drain.

## Next stretch

Explain the difference between context-window exhaustion and a lifecycle race,
then choose a safe `maxOutputTokens` value for a small chat UI.
