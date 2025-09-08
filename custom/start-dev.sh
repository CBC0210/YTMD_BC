#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUSTOM_DIR="$ROOT_DIR/custom"
WS_DIR="$CUSTOM_DIR/web-server"
LOG_FILE="/tmp/ytmd-web.log"
PORT=${WEB_SERVER_PORT:-5678}
TOKEN=${CUSTOM_API_TOKEN:-dev-token}

echo "[custom] 使用 PORT=$PORT TOKEN=$TOKEN"

# Python venv 檢查
if [ -f "$WS_DIR/requirements.txt" ]; then
  if [ ! -d "$WS_DIR/.venv" ]; then
    echo "[custom] 建立虛擬環境..."
    python3 -m venv "$WS_DIR/.venv"
    "$WS_DIR/.venv/bin/pip" install -r "$WS_DIR/requirements.txt"
  fi
  # 啟動 web server（若尚未啟動）
  if ! pgrep -f "python.*$WS_DIR/server.py" >/dev/null 2>&1; then
    echo "[custom] 啟動 web server..."
    ( WEB_SERVER_PORT="$PORT" CUSTOM_API_TOKEN="$TOKEN" nohup "$WS_DIR/.venv/bin/python" "$WS_DIR/server.py" >"$LOG_FILE" 2>&1 & )
    echo "[custom] web server 已啟動 (log: $LOG_FILE)"
  else
    echo "[custom] web server 已在執行中，略過"
  fi
else
  echo "[custom] 無 requirements.txt，跳過 web server 啟動"
fi

cd "$ROOT_DIR"
if command -v pnpm >/dev/null 2>&1; then
  echo "[custom] 啟動 pnpm dev"
  pnpm dev
else
  echo "[custom] 未找到 pnpm，請先安裝"
  exit 1
fi
