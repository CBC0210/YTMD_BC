#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${CUSTOM_DIR}/.." && pwd)"

FRONTEND_PORT=${FRONTEND_PORT:-5173}
BACKEND_PORT=${WEB_SERVER_PORT:-${BACKEND_PORT:-8080}}
NGROK_BIN=${NGROK_BIN:-ngrok}
ELECTRON_RENDERER_PORT=${ELECTRON_RENDERER_PORT:-5600}

log(){ echo "[stop-public] $*"; }

log "Stopping ngrok tunnels..."
pkill -f "$NGROK_BIN http .*:${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "$NGROK_BIN http .*:${BACKEND_PORT}" 2>/dev/null || true

log "Stopping frontend (vite/http.server)..."
pkill -f "vite" 2>/dev/null || true
pkill -f "node .*vite" 2>/dev/null || true
pkill -f "http.server ${FRONTEND_PORT}" 2>/dev/null || true
[ -f /tmp/ytreq-frontend.pid ] && kill $(cat /tmp/ytreq-frontend.pid) 2>/dev/null || true
rm -f /tmp/ytreq-frontend.pid /tmp/ytreq-frontend-supervisor.pid /tmp/ytmd-public.pid

log "Stopping backend (Flask server.py)..."
pkill -f "server.py" 2>/dev/null || true

log "Stopping electron dev (if any)..."
pkill -f "electron" 2>/dev/null || true
fuser -k -n tcp $ELECTRON_RENDERER_PORT 2>/dev/null || true

log "Done."
