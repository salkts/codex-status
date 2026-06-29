# Codex Status

Codex Status is a small native macOS menu bar app for keeping an eye on local
Codex activity without switching back to the Codex app.

It watches the local Codex state stored under `~/.codex`, shows whether Codex is
idle or active, and displays elapsed timers for active Codex conversations in
the menu bar.

## What It Does

Codex Status runs as a menu bar utility. It does not create Codex sessions or
talk to the OpenAI API directly. Instead, it reads local Codex app state and
turn logs, then presents a compact status view:

- active Codex conversations with elapsed timers
- recently completed Codex conversations for a short retention window
- running/idle Codex app state
- one-click opening of Codex or a specific Codex thread URL
- an optional timer strip next to the status icon

## Features

- **Native macOS menu bar app** built with Swift, Cocoa, and `NSStatusBar`.
- **Animated status icon** while Codex is actively working.
- **Conversation timers** for active Codex turns.
- **Multiple active chats** with a configurable visible timer limit and `+N`
  overflow indicator.
- **Completed-turn flash** for qualifying completed conversations.
- **Thread opening** through `codex://threads/<id>` links when available.
- **Settings window** for launch behavior, timer visibility, icon style, timer
  count, and shimmer cadence.
- **Local activity stats** for completed turns, active time, average duration,
  and longest turn.
- **Bounded recent stats backfill** that scans recently modified rollout logs
  to correct missed or undercounted completed turns.
- **Update indicator groundwork** with a GitHub commit check, blue menu bar
  badge, and Sparkle-ready update handoff for signed releases.
- **File watching plus polling** for responsive updates when Codex state files
  change.
- **Optional local diagnostics** written to
  `~/.codex/statusbar/codex-status-debug.json` and
  `/tmp/codex-status-debug.json` when debug logging is enabled.

## Requirements

- macOS 12.0 or later.
- Xcode Command Line Tools, including `swiftc`.
- Codex installed at `/Applications/Codex.app` for open-app behavior.
- Local Codex state under `~/.codex`.
- Apple Silicon for the current local build artifact. Universal builds are not
  wired up yet.

The app is currently built directly with `swiftc`; there is no Xcode project,
Swift Package Manager manifest, Homebrew formula, or notarized installer in this
repository.

## Install, Build, and Run

Clone the repository, then build the app bundle:

```bash
./build.sh
```

The build script creates:

```text
build/Codex Status.app
```

Run it with:

```bash
open "build/Codex Status.app"
```

To install it manually, copy `build/Codex Status.app` to `/Applications` after
building.

For local development, build and relaunch the menu bar app with:

```bash
./scripts/run-app.sh
```

To create a local DMG:

```bash
./scripts/package-dmg.sh
```

The package script creates:

```text
dist/Codex-Status.dmg
```

Local builds are ad-hoc signed by default. For a Developer ID signed and
notarized release, provide:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notarytool-profile-name" \
./scripts/package-dmg.sh
```

## How Status Is Detected

Codex Status reads these local files and locations:

- `~/.codex/process_manager/chat_processes.json` for live command/process
  records.
- `~/.codex/session_index.jsonl` for recent thread titles and session metadata.
- `~/.codex/state_5.sqlite` and `~/.codex/state_5.sqlite-wal` for indexed thread
  records and rollout paths.
- `~/.codex/sessions` for rollout JSONL files when the SQLite thread index is
  unavailable or incomplete.
- macOS process/application metadata to detect whether Codex is running.

It also checks that recorded process IDs are still alive before treating command
records as live.

Activity stats are stored locally at:

```text
~/Library/Application Support/Codex Status/usage-store.json
```

The app keeps detailed completed-session rows for the most recent 60 days and
keeps compact daily rollups indefinitely so the `All` filter remains cheap. It
does not store prompts, responses, file paths, or conversation titles in the
activity store.

On launch, Codex Status also performs a capped 24-hour backfill over recently
modified rollout JSONL files. The backfill streams each file line by line,
extracts only turn start/completion metadata, and is capped by file count and
total bytes so it does not scan the full `~/.codex/sessions` history.

## Menu and Settings

Click the Codex Status icon to open the app menu:

- **Open Codex** opens the installed Codex app.
- **Settings...** opens the Codex Status settings window.
- **Quit Codex Status** exits the menu bar app.

Click the timer strip to open a conversation when only one active conversation
is shown. When multiple conversations are active, the timer strip opens a list
of active conversations.

Settings are stored in macOS `UserDefaults` for this app:

- **Launch at login**: open Codex Status when you sign in. On macOS 13+, this
  uses `SMAppService`.
- **Show timer strip**: show or hide elapsed timers next to the icon.
- **Max visible timers**: choose how many active timers appear before extra
  conversations collapse into `+N` (1 to 12).
- **Icon style**: choose Outline, Solid, or Codex artwork.
- **Shimmer cadence**: choose how frequently the active icon sweep repeats.

The Activity section includes:

- **Turns completed**: completed local Codex turns recorded since this version
  started tracking.
- **Active time**: summed active timer duration. Concurrent main/subagent work
  is summed as Codex work time, not de-overlapped wall-clock time.
- **Average duration**: active time divided by recorded turns.
- **Longest turn**: longest recorded completed turn.
- **Date filters**: `7D`, `30D`, `60D`, and `All`.
- **Work filters**: `All work`, `Main`, and `Subagents`.
- **Reset stats**: deletes local Codex Status activity stats.

## Development

Main source files:

- `Sources/main.swift`: the macOS app, status detection, rendering, settings,
  and menu actions.
- `Info.plist`: app bundle metadata. The current bundle version is `0.1.0`.
- `build.sh`: direct `swiftc` build script.
- `Assets/`: local menu bar artwork used by the build.
- `scripts/probe-state.sh`: diagnostic helper for inspecting local Codex state.
- `scripts/run-app.sh`: build and relaunch helper for development.
- `scripts/package-dmg.sh`: local DMG packaging helper.
- `scripts/verify-release.sh`: plist, code-signing, and DMG verification helper.

Build command used by `build.sh`:

```bash
swiftc -O -framework Cocoa Sources/main.swift -o "build/Codex Status.app/Contents/MacOS/CodexStatus"
```

Disable ad-hoc signing during development with:

```bash
CODESIGN=0 ./build.sh
```

Sparkle is optional in local builds. To compile and embed a downloaded
`Sparkle.framework`, pass:

```bash
SPARKLE_FRAMEWORK="/path/to/Sparkle.framework" ./build.sh
```

The menu bar can show an update badge from the public GitHub commit check. The
Sparkle install handoff requires a signed appcast release feed before it can
replace and relaunch the app automatically.

## Troubleshooting

If the icon only shows idle or "No active chats":

1. Confirm Codex is installed and running:

   ```bash
   open /Applications/Codex.app
   ```

2. Check whether Codex local state exists:

   ```bash
   ls ~/.codex/session_index.jsonl ~/.codex/process_manager/chat_processes.json
   ```

3. Run the included diagnostic script:

   ```bash
   ./scripts/probe-state.sh
   ```

4. Enable debug logging and inspect the latest Codex Status debug snapshot:

   ```bash
   defaults write com.sal.codex-status debugLogging -bool true
   ./scripts/run-app.sh
   ```

   ```bash
   cat ~/.codex/statusbar/codex-status-debug.json
   cat /tmp/codex-status-debug.json
   ```

If build fails with `swiftc: command not found`, install the Xcode Command Line
Tools:

```bash
xcode-select --install
```

If launch-at-login does not stick, check macOS System Settings > General >
Login Items and confirm Codex Status is allowed.

## Limitations

- macOS only.
- Local-state only; it does not query OpenAI services or remote Codex servers.
- Status accuracy depends on Codex's current local file formats under
  `~/.codex`.
- Activity stats start from the version that introduced tracking; there is no
  historical backfill.
- Current build scripts produce a native binary for the build machine
  architecture. The DMG generated on Apple Silicon is arm64-only.
- Public releases should be Developer ID signed and notarized. Local builds are
  ad-hoc signed unless `CODESIGN=0` is set.
- Completed conversations are shown only briefly and only when the recorded turn
  duration meets the app's completion threshold.
- Subagent completions are not shown in the completed-conversation flash.
- Launch-at-login support is best on macOS 13+.

## Trademark Notice

Codex Status is an independent project and is not affiliated with, endorsed by,
or sponsored by OpenAI. Codex, OpenAI, and related marks are trademarks or
registered trademarks of OpenAI. See `NOTICE`.

## Release Notes

### 0.1.0

- Initial public README for the native macOS menu bar utility.
- Tracks local Codex running, active, completed, and idle states.
- Shows active conversation timers and multi-chat overflow.
- Adds settings for launch at login, timer strip visibility, visible timer
  count, icon style, and shimmer cadence.
- Includes optional local debug snapshots and a state probing script for
  troubleshooting.
