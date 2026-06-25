#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Codex Status.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

swiftc \
  -O \
  -framework Cocoa \
  "$ROOT/Sources/main.swift" \
  -o "$MACOS/CodexStatus"

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT/Assets/codexTemplate.png" "$RESOURCES/codexTemplate.png"
cp "$ROOT/Assets/codexStartupLogo.png" "$RESOURCES/codexStartupLogo.png"
if [[ -f "$ROOT/Assets/codexOutlineLogo.svg" ]]; then
  cp "$ROOT/Assets/codexOutlineLogo.svg" "$RESOURCES/codexOutlineLogo.svg"
fi
if compgen -G "$ROOT/Assets/StatusFrames/codex-active-*.png" > /dev/null; then
  cp "$ROOT"/Assets/StatusFrames/codex-active-*.png "$RESOURCES/"
fi

if [[ "${CODESIGN:-1}" != "0" ]]; then
  if [[ -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP" >/dev/null
  else
    codesign --force --deep --sign - "$APP" >/dev/null
  fi
fi

echo "Built: $APP"
