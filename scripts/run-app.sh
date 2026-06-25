#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Codex Status.app"

"$ROOT/build.sh"
pkill -x CodexStatus 2>/dev/null || true
open "$APP"
echo "Launched: $APP"
