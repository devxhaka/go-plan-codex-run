#!/usr/bin/env bash
# Go-Plan bridge: jalankan MCP server + Cloudflare Quick Tunnel (Linux)
# Pakai: scripts/start-linux.sh /path/repo1 [/path/repo2 ...]
#   atau: scripts/start-linux.sh "alias1=/path/a:alias2=/path/b"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$ROOT_DIR/mcp_server"
PID_FILE="$ROOT_DIR/.bridge.pids"
TUNNEL_LOG="$ROOT_DIR/.tunnel.log"
SERVER_LOG="$ROOT_DIR/.server.log"

build_roots() {
  local roots="" entry p
  for entry in "$@"; do
    # dukung format alias=/path
    p="$entry"
    [[ "$p" == *"="* ]] && p="${p#*=}"
    if [ ! -d "$p" ]; then
      echo "ERROR: bukan folder: $entry"; exit 1
    fi
    case "$p" in
      "/"|"/root"|"$HOME")
        echo "ERROR: terlalu luas — pilih folder project, bukan root/home: $p"; exit 1;;
    esac
    if [ -z "$roots" ]; then roots="$entry"; else roots="$roots:$entry"; fi
  done
  echo "$roots"
}

if [ $# -gt 0 ]; then
  PROJECT_ROOTS="$(build_roots "$@")"
else
  PROJECT_ROOTS="${PROJECT_ROOTS:-${PROJECT_ROOT:-}}"
fi
if [ -z "$PROJECT_ROOTS" ]; then
  echo "Pakai: $0 /path/repo1 [/path/repo2 ...]"
  echo '   atau: $0 "fe=/path/frontend:be=/path/backend"'
  echo "   atau set env PROJECT_ROOTS dulu."
  exit 1
fi

PORT="${BRIDGE_PORT:-8765}"

command -v python3 >/dev/null || { echo "ERROR: python3 tidak ketemu."; exit 1; }
command -v cloudflared >/dev/null || {
  echo "ERROR: cloudflared tidak ketemu."
  echo "Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
  exit 1
}

if [ ! -x "$SERVER_DIR/.venv/bin/python" ]; then
  echo "[bridge] bikin venv + install requirements..."
  python3 -m venv "$SERVER_DIR/.venv"
  "$SERVER_DIR/.venv/bin/pip" install -q -r "$SERVER_DIR/requirements.txt"
fi

# hentikan sesi lama kalau ada
"$SCRIPT_DIR/stop-linux.sh" >/dev/null 2>&1 || true

echo "[bridge] start MCP server (roots: $PROJECT_ROOTS, port: $PORT)..."
PROJECT_ROOTS="$PROJECT_ROOTS" BRIDGE_PORT="$PORT" \
  nohup "$SERVER_DIR/.venv/bin/python" "$SERVER_DIR/server.py" > "$SERVER_LOG" 2>&1 &
echo $! > "$PID_FILE"

echo "[bridge] start cloudflared Quick Tunnel..."
nohup cloudflared tunnel --url "http://127.0.0.1:$PORT" > "$TUNNEL_LOG" 2>&1 &
echo $! >> "$PID_FILE"

echo "[bridge] nunggu URL tunnel..."
URL=""
for _ in $(seq 1 30); do
  URL=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1 || true)
  [ -n "$URL" ] && break
  sleep 2
done

if [ -z "$URL" ]; then
  echo "ERROR: URL tunnel tidak ketemu. Cek: $TUNNEL_LOG"
  exit 1
fi

cat <<EOF

==============================================
 Bridge AKTIF
 Tempel URL ini ke ChatGPT web (akun Go)
 sebagai custom MCP connector:

   $URL/mcp/sse

 Untuk berhenti: scripts/stop-linux.sh
==============================================
EOF
