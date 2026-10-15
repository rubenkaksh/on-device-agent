# flutter_gemma_poc

Flutter proof of concept that runs Gemma 3n E2B (`.litertlm`) fully on device
via [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) and chats with it
using streamed responses.

## Setup

Requirements: Flutter SDK (Dart `^3.8.0`) and an Android or iOS device/emulator.

```sh
./run.sh run
```

Use `./run.sh` instead of calling `flutter` directly. It forwards every
argument to `flutter`, but first creates `.env` from `.env.example` if `.env`
is missing (`.env` is a bundled asset, so the build fails without it). It never
overwrites an existing `.env`.

Other examples:

```sh
./run.sh build apk --release
./run.sh build ios --release
```

## Hugging Face token (`HF_TOKEN`, optional)

`HF_TOKEN` is read from `.env` at runtime and sent when downloading the model.

- The default model, `google/gemma-3n-E2B-it-litert-lm`, is gated on Hugging
  Face. Accept its licence on the model page, create a read-scope token at
  <https://huggingface.co/settings/tokens>, and set `HF_TOKEN=<token>` in `.env`.
- Leave it empty only if you point the app at a public model URL.
- `.env` is git-ignored. Don't commit tokens; commit changes to
  `.env.example` only.

## Model download and reinstall

On first launch the app downloads the model (a large file; use Wi-Fi) and
reuses it afterwards. The model URL is set in `lib/screens/chat_screen.dart`.

The installed model's metadata (file type) is stored on the device and is not
rewritten when the code changes. If you change the model URL or file type
(a `.litertlm` URL must be installed as `ModelFileType.litertlm`), reinstall:
uninstall the app, or clear its data, then run again so the model is downloaded
and registered afresh.

## Project docs

- `lib/learning-records/` and `lib/lessons/`: notes on generation lifecycle bugs.
- `docs/`: session notes and plans.
