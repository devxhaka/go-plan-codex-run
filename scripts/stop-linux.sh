#!/usr/bin/env bash
# Go-Plan bridge: hentikan MCP server + tunnel (Linux)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$(dirname "$SCRIPT_DIR")/.bridge.pids"

if [ ! -f "$PID_FILE" ]; then
  echo "[bridge] tidak ada sesi berjalan."
  exit 0
fi
while read -r pid; do
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null && echo "[bridge] stop PID $pid"
  fi
done < "$PID_FILE"
rm -f "$PID_FILE"
echo "[bridge] berhenti."
