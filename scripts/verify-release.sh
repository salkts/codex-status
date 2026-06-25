#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Codex Status.app"
DMG="$ROOT/dist/Codex-Status.dmg"

if [[ ! -d "$APP" ]]; then
  echo "missing app: $APP" >&2
  exit 1
fi

plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"

if [[ -f "$DMG" ]]; then
  hdiutil verify "$DMG"
  codesign --verify --verbose=2 "$DMG" || true
fi

echo "Release verification completed."
