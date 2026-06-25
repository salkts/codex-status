#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SESSION_INDEX="$CODEX_HOME/session_index.jsonl"
CHAT_PROCESSES="$CODEX_HOME/process_manager/chat_processes.json"

echo "Codex app processes:"
pgrep -fl "/Applications/Codex.app|codex app-server" || true

echo
echo "Active Codex kernels:"
ps axo pid=,command= | grep "/Applications/Codex.app/Contents/Resources/cua_node/bin/node" | grep -- "--session-id" | grep -- "--working-dir" | grep -v grep || true

echo
echo "Live chat commands:"
if [[ -f "$CHAT_PROCESSES" ]]; then
  /usr/bin/python3 - "$CHAT_PROCESSES" <<'PY'
import json
import os
import signal
import sys
from datetime import datetime

with open(sys.argv[1], "r", encoding="utf-8") as f:
    rows = json.load(f)

for row in rows:
    pid = row.get("osPid")
    alive = False
    if isinstance(pid, int) and pid > 0:
        try:
            os.kill(pid, 0)
            alive = True
        except OSError:
            alive = False
    if alive:
        started = datetime.fromtimestamp(row.get("startedAtMs", 0) / 1000).isoformat(timespec="seconds")
        print(f"- pid={pid} started={started} cwd={row.get('cwd') or ''} command={row.get('command') or ''}")
PY
else
  echo "missing: $CHAT_PROCESSES"
fi

echo
echo "Latest indexed sessions:"
if [[ -f "$SESSION_INDEX" ]]; then
  tail -5 "$SESSION_INDEX"
else
  echo "missing: $SESSION_INDEX"
fi
