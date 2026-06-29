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

SWIFTC_ARGS=(
  -O
  -framework Cocoa
)

if [[ -n "${SPARKLE_FRAMEWORK:-}" && -d "$SPARKLE_FRAMEWORK" ]]; then
  SWIFTC_ARGS+=(
    -F "$(dirname "$SPARKLE_FRAMEWORK")"
    -framework Sparkle
    -Xlinker -rpath
    -Xlinker "@executable_path/../Frameworks"
  )
fi

swiftc \
  "${SWIFTC_ARGS[@]}" \
  "$ROOT/Sources/main.swift" \
  -o "$MACOS/CodexStatus"

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
GIT_COMMIT="$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || true)"
if [[ -n "$GIT_COMMIT" ]]; then
  /usr/libexec/PlistBuddy -c "Delete :CodexStatusGitCommit" "$CONTENTS/Info.plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CodexStatusGitCommit string $GIT_COMMIT" "$CONTENTS/Info.plist"
fi
cp "$ROOT/Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT/Assets/codexTemplate.png" "$RESOURCES/codexTemplate.png"
cp "$ROOT/Assets/codexStartupLogo.png" "$RESOURCES/codexStartupLogo.png"
if [[ -f "$ROOT/Assets/codexOutlineLogo.svg" ]]; then
  cp "$ROOT/Assets/codexOutlineLogo.svg" "$RESOURCES/codexOutlineLogo.svg"
fi
if compgen -G "$ROOT/Assets/StatusFrames/codex-active-*.png" > /dev/null; then
  cp "$ROOT"/Assets/StatusFrames/codex-active-*.png "$RESOURCES/"
fi

if [[ -n "${SPARKLE_FRAMEWORK:-}" && -d "$SPARKLE_FRAMEWORK" ]]; then
  mkdir -p "$CONTENTS/Frameworks"
  cp -R "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/Sparkle.framework"
fi

if [[ "${CODESIGN:-1}" != "0" ]]; then
  if [[ -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP" >/dev/null
  else
    codesign --force --deep --sign - "$APP" >/dev/null
  fi
fi

echo "Built: $APP"
