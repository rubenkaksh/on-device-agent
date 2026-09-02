#!/bin/bash
# Run Flutter commands. HF_TOKEN is read from .env at runtime (bundled asset).
# Usage:
#   ./run.sh run          — run the app
#   ./run.sh build apk    — build APK
#   ./run.sh build ios    — build iOS

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: ./run.sh <flutter-command> [args...]"
  echo "Examples:"
  echo "  ./run.sh run"
  echo "  ./run.sh build apk --release"
  echo "  ./run.sh build ios --release"
  exit 1
fi

exec flutter "$@"
