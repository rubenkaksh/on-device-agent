# Issue draft — cactus-compute/needle

> Fill the `<…>` fields from Step 1 of the guide before posting. Post it yourself.

**Title:** Flutter/Dart binding for Needle 3 on Android & iOS: interest + a few engine questions

---

Hi Cactus team 👋

I'm building an on-device app-action assistant in Flutter and want to run Needle 3 on Android and iOS. The published `android-arm64` / `ios-arm64` / `ios-sim-arm64` engine folders make this possible. I plan to write a Dart FFI binding (`needle_flutter`) that mirrors the Python `Needle` API (`complete`, `embed`, `reset`, tools, system facts), including the wrapper-side logic (date fact, stateless mode, grounding check).

**What I've verified so far** (engine `<3.0.2>`, `needle3.cact` `<size>`):
- Android: `<file list>`, exports `needle_load/init/complete/embed/reset`, ELF LOAD alignment `<0x…>`
- iOS: `<dylib | framework | static .a>`
- Embedding dimension: `<n>`

**Questions**
1. Does `needle_load` copy the weights buffer, or must the caller keep it alive for the session?
2. Is the engine safe to call from a non-main thread (I'll use one dedicated worker isolate/thread)? Any re-entrancy constraints?
3. When `needle_complete` output exceeds `capacity`, is it truncated or does it return an error code?
4. Is telemetry active in the mobile engine builds? If so, what's the supported opt-out on Android/iOS, where env vars aren't set by the user?
5. Android: are the `.so` files built with 16 KB page alignment (Play requirement for Android 15+)?
6. What licence covers the engine binaries and `needle3.cact` for redistribution inside a pub.dev package?
7. Would you be open to an official Dart/Flutter binding, either in this repo or in `cactus/bindings/flutter`? If so, what's your preferred process (DCO, issue-first, policy on AI-assisted code)?

Until then I'll publish it as an unofficial package, with credit, and link it here. Happy to adapt it to whatever structure you'd prefer.

Thanks for Needle!
