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

# .env is a bundled asset, so it must exist at build time. Create it from the
# template on fresh clones; never overwrite an existing one.
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — set HF_TOKEN in .env if the model is gated."
fi

exec flutter "$@"
