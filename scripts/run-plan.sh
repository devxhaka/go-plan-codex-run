#!/usr/bin/env bash
# Go-Plan/Codex-Run: jalankan plan (markdown dari ChatGPT Go) dengan Codex (akun Plus)
# Pakai: scripts/run-plan.sh plan.md [opsi-codex-tambahan...]
# Contoh: scripts/run-plan.sh plan.md --full-auto
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Pakai: $0 plan.md [opsi-codex-tambahan...]"
  exit 1
fi
PLAN="$1"; shift
[ -f "$PLAN" ] || { echo "ERROR: file tidak ada: $PLAN"; exit 1; }
command -v codex >/dev/null || {
  echo "ERROR: 'codex' tidak ketemu."
  echo "Install Codex CLI (npm i -g @openai/codex) lalu login dengan akun Plus: codex login"
  exit 1
}

PROJECT_DIR="${PROJECT_ROOT:-$(pwd)}"
echo "[codex-run] project : $PROJECT_DIR"
echo "[codex-run] plan    : $PLAN"
[ $# -gt 0 ] && echo "[codex-run] opsi    : $*"
echo "[codex-run] jalanin codex..."
cd "$PROJECT_DIR"
codex exec "$@" "$(cat "$PLAN")"
