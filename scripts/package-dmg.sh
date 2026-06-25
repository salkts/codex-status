#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Codex Status.app"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-root"
DMG="$DIST/Codex-Status.dmg"
VOLNAME="Codex Status"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" "$ROOT/build.sh"
else
  "$ROOT/build.sh"
fi

rm -rf "$DIST"
mkdir -p "$DIST"
rm -f "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG"
elif [[ "${CODESIGN:-1}" != "0" ]]; then
  codesign --force --sign - "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "Packaged: $DMG"
