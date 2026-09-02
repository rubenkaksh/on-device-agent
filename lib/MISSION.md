# Mission

## Why this matters

I already know how to download a model and call Gemma through the Flutter
package. I want to understand what actually happens between a prompt, the
native inference engine, and the streamed response so I can diagnose model
behaviour instead of treating native errors as black boxes.

## Outcome

Be able to explain, reproduce, and fix a multi-turn on-device inference
failure—especially a generation-lifecycle race—and choose sensible values for
context size, output length, temperature, top-k, and stop conditions.

## Starting point

- Comfortable with Flutter and the basic `flutter_gemma` API.
- Comfortable downloading and loading Gemma models.
- New focus: native session state, streaming cancellation, token budgets, and
  sampling controls.

## Learning style

Use short, practical lessons grounded in this app's code and logs. Prefer a
small mental model, a concrete trace, and one exercise with immediate feedback.
