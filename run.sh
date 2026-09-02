#!/bin/bash
# Read .env and pass HF_TOKEN as a compile-time define to Flutter.
# Usage:
#   ./run.sh run          — run the app
#   ./run.sh build apk    — build APK
#   ./run.sh build ios    — build iOS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found at $ENV_FILE"
  echo "Create one with: echo 'HF_TOKEN=your_token_here' > .env"
  exit 1
fi

# Source the .env file
set -a
source "$ENV_FILE"
set +a

if [ -z "${HF_TOKEN:-}" ] || [ "$HF_TOKEN" = "your_hf_token_here" ]; then
  echo "Warning: HF_TOKEN is empty or placeholder in .env"
  echo "Set it to your HuggingFace token: https://huggingface.co/settings/tokens"
fi

# Pass HF_TOKEN as a Dart define
DART_DEFINES="--dart-define=HF_TOKEN=${HF_TOKEN:-}"

# Run the flutter command
if [ $# -eq 0 ]; then
  echo "Usage: ./run.sh <flutter-command> [args...]"
  echo "Examples:"
  echo "  ./run.sh run"
  echo "  ./run.sh run --dart-define=OTHER=value"
  echo "  ./run.sh build apk --release"
  exit 1
fi

exec flutter "$@" $DART_DEFINES
