#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUSTOM_DIR="$ROOT_DIR/custom"
WS_DIR="$CUSTOM_DIR/web-server"
LOG_FILE="/tmp/ytmd-web.log"
PORT=${WEB_SERVER_PORT:-8080}
TOKEN=${CUSTOM_API_TOKEN:-dev-token}

echo "[custom] 使用 PORT=$PORT TOKEN=$TOKEN"

# Node 版本檢查 (需要 >=22)
NODE_MAJOR=$(node -v 2>/dev/null | sed -E 's/v([0-9]+).*/\1/' || echo 0)
if [ "${NODE_MAJOR}" -lt 22 ]; then
  echo "[custom] ❌ Node.js 版本過低 (目前 v${NODE_MAJOR}). 需要 >=22"
  echo "[custom] 請執行："
  echo "       nvm install 22 && nvm use 22   (若已安裝 nvm)"
  echo "       或使用系統套件管理器升級 Node 版本"
  exit 1
fi

# Python venv 檢查
if [ -f "$WS_DIR/requirements.txt" ]; then
  if [ ! -d "$WS_DIR/.venv" ]; then
    echo "[custom] 建立虛擬環境..."
    python3 -m venv "$WS_DIR/.venv"
    "$WS_DIR/.venv/bin/pip" install -r "$WS_DIR/requirements.txt"
  fi
  # 啟動 web server（若尚未啟動）
  RESTART=${RESTART_WEB:-0}
  if pgrep -f "python.*$WS_DIR/server.py" >/dev/null 2>&1; then
    if [ "$RESTART" = "1" ]; then
      echo "[custom] 停止既有 web server (RESTART_WEB=1)"
      pkill -f "python.*$WS_DIR/server.py" || true
      sleep 1
    else
      echo "[custom] web server 已在執行中，略過 (設定 RESTART_WEB=1 可重啟)"
    fi
  fi
  if ! pgrep -f "python.*$WS_DIR/server.py" >/dev/null 2>&1; then
    echo "[custom] 啟動 web server (port=$PORT)..."
  WEB_SERVER_PORT="$PORT" CUSTOM_API_TOKEN="$TOKEN" nohup "$WS_DIR/.venv/bin/python" "$WS_DIR/server.py" >"$LOG_FILE" 2>&1 &
    # 等待健康檢查
    for i in {1..15}; do
      if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        echo "[custom] web server 就緒 (http://127.0.0.1:$PORT)"
        break
      fi
      sleep 1
      if [ $i -eq 15 ]; then
        echo "[custom] ⚠️ web server 尚未就緒，請檢查日誌: $LOG_FILE"
      fi
    done
  fi
else
  echo "[custom] 無 requirements.txt，跳過 web server 啟動"
fi

cd "$ROOT_DIR"
if [ "${SERVER_ONLY:-0}" = "1" ]; then
  echo "[custom] SERVER_ONLY=1 不啟動 Electron/Vite，只保留 web server (log: $LOG_FILE)"
  tail -f "$LOG_FILE"
  exit 0
fi

if command -v pnpm >/dev/null 2>&1; then
  echo "[custom] 啟動 pnpm dev (可用 CTRL+C 結束，web server 會繼續運行)"
  pnpm dev
else
  echo "[custom] 未找到 pnpm，請先安裝"
  exit 1
fi
