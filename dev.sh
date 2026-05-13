#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP="$SCRIPT_DIR/build/Key30.app"

if "$SCRIPT_DIR/build.sh"; then
    osascript -e 'tell application "Key30" to quit' >/dev/null 2>&1 || true
    sleep 0.5
    open "$APP"
else
    echo "❌ Build failed."
    exit 1
fi
