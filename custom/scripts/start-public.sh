#!/usr/bin/env bash
set -euo pipefail
# Launch dev stack with frontend (static or Vite), backend (Flask), optional Electron, and ngrok for the frontend.
# Auto-attempt installs when possible; otherwise print actionable hints.

# -------------------- paths --------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"           # custom/
ROOT_DIR="$(cd "${CUSTOM_DIR}/.." && pwd)"              # repo root
WS_DIR="$CUSTOM_DIR/web-server"                         # Flask web server
FRONTEND_DIR_DEFAULT="$CUSTOM_DIR/web-server/frontend"  # empty frontend by default
FRONTEND_DIR_ALT="$CUSTOM_DIR/ytreqpod/frontend"        # alt location if exists
FRONTEND_DIR="${FRONTEND_DIR:-}"                        # allow override via env
if [ -z "$FRONTEND_DIR" ]; then
  if [ -d "$FRONTEND_DIR_DEFAULT" ]; then FRONTEND_DIR="$FRONTEND_DIR_DEFAULT";
  elif [ -d "$FRONTEND_DIR_ALT" ]; then FRONTEND_DIR="$FRONTEND_DIR_ALT";
  else FRONTEND_DIR="$FRONTEND_DIR_DEFAULT"; fi
fi
APP_DIR="$WS_DIR/app"
LINKS_FILE="${PUBLIC_LINKS_PATH:-$APP_DIR/public_links.json}"
NGROK_API="http://127.0.0.1:4040/api/tunnels"

# -------------------- config --------------------
FRONTEND_PORT=${FRONTEND_PORT:-5173}
BACKEND_PORT=${WEB_SERVER_PORT:-${BACKEND_PORT:-8080}}
UPSTREAM_HOST=${UPSTREAM_HOST:-localhost}  # avoid 127.0.0.1 edge cases on some setups
ELECTRON_DEV=${ELECTRON_DEV:-1}            # run pnpm dev for Electron
ENABLE_NGROK=${ENABLE_NGROK:-1}
NGROK_BIN=${NGROK_BIN:-ngrok}
NGROK_REGION=${NGROK_REGION:-jp}
NGROK_ALWAYS_NEW=${NGROK_ALWAYS_NEW:-0}
ENABLE_FRONTEND_SUPERVISOR=${ENABLE_FRONTEND_SUPERVISOR:-1}
FRONTEND_MODE=${FRONTEND_MODE:-auto}       # auto|vite|static
FRONTEND_LOG=${FRONTEND_LOG:-/tmp/ytreq-frontend.log}
AUTO_INSTALL_QRCODE=${AUTO_INSTALL_QRCODE:-1}
FORCE_BACKEND_RESTART=${FORCE_BACKEND_RESTART:-0}
FRONTEND_FORCE_RESTART_ON_404=${FRONTEND_FORCE_RESTART_ON_404:-1}

# make Vite/electron-vite more permissive when in dev
export VITE_ALLOW_ALL_HOSTS=1
export NGROK_HOST="${NGROK_HOST:-}"
export ELECTRON_RENDERER_PORT=${ELECTRON_RENDERER_PORT:-5600}
export RENDERER_LOCAL_ONLY=1

# -------------------- helpers --------------------
log(){ echo "[public] $*"; }

# Single-instance (PID file) to avoid multiple supervisors thrashing
PID_FILE_MAIN="/tmp/ytmd-public.pid"
if [ -f "$PID_FILE_MAIN" ]; then
  OLD=$(( $(cat "$PID_FILE_MAIN" 2>/dev/null || echo 0) ))
  if [ "$OLD" -gt 1 ] && kill -0 "$OLD" 2>/dev/null; then
    log "已有一個 start-public 實例在執行 (pid=$OLD)；若需強制中止可執行 custom/scripts/stop-public.sh"
    exit 0
  fi
fi
echo $$ > "$PID_FILE_MAIN"

# Port killer helper (global)
kill_port(){
  local p="$1"
  lsof -ti :"$p" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
  if command -v fuser >/dev/null 2>&1; then fuser -k -n tcp "$p" 2>/dev/null || true; fi
}

cleanup(){
  local why="${1:-signal/exit}"
  log "🧹 清理程序觸發（$why）..."
  # stop ngrok tunnels
  pkill -f "$NGROK_BIN http .*:${FRONTEND_PORT}" 2>/dev/null || true
  pkill -f "$NGROK_BIN http .*:${BACKEND_PORT}" 2>/dev/null || true
  # stop frontend vite/http.server
  if [ -f "/tmp/ytreq-frontend.pid" ]; then
    FRONT_PID=$(cat /tmp/ytreq-frontend.pid || true)
    [ -n "$FRONT_PID" ] && kill "$FRONT_PID" 2>/dev/null || true
    rm -f /tmp/ytreq-frontend.pid
  fi
  pkill -f "vite.*:${FRONTEND_PORT}" 2>/dev/null || true
  pkill -f "http.server ${FRONTEND_PORT}" 2>/dev/null || true
  kill_port "$FRONTEND_PORT"
  # stop backend flask
  pkill -f "server.py" 2>/dev/null || true
  kill_port "$BACKEND_PORT"
  # stop supervisor loop if tracked
  if [ -f "/tmp/ytreq-frontend-supervisor.pid" ]; then
    SUP_PID=$(cat /tmp/ytreq-frontend-supervisor.pid 2>/dev/null || true)
    [ -n "$SUP_PID" ] && kill "$SUP_PID" 2>/dev/null || true
    rm -f /tmp/ytreq-frontend-supervisor.pid
  fi
  # optional: stop electron dev
  pkill -f "electron" 2>/dev/null || true
  rm -f "$PID_FILE_MAIN"
  log "✅ 清理完成"
}

trap 'cleanup INT' INT TERM
trap 'cleanup EXIT' EXIT

pkg_hint() {
  local pkg="$1"
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian) echo "sudo apt-get install -y $pkg" ;;
      fedora) echo "sudo dnf install -y $pkg" ;;
      centos|rhel) echo "sudo yum install -y $pkg" ;;
      arch|manjaro) echo "sudo pacman -S --noconfirm $pkg" ;;
      opensuse*|sles) echo "sudo zypper install -y $pkg" ;;
      *) echo "Use your package manager to install $pkg" ;;
    esac
  else
    echo "Use your package manager to install $pkg"
  fi
}

need_bin(){ command -v "$1" >/dev/null 2>&1; }
need_or_hint(){ if ! need_bin "$1"; then log "❌ 缺少指令: $1"; log "👉 安裝建議：$(pkg_hint "$2")"; return 1; fi }

ensure_python() {
  if need_bin python3; then return 0; fi
  log "⚠️ 未找到 python3。安裝建議：$(pkg_hint python3)"; return 1
}

ensure_node_pnpm() {
  if ! need_bin node; then
    log "⚠️ 未找到 node。請安裝 Node.js（建議 >= 22）。例如：$(pkg_hint nodejs)"
    return 1
  fi
  if need_bin pnpm; then return 0; fi
  if need_bin corepack; then
    if corepack enable >/dev/null 2>&1 && corepack prepare pnpm@10 --activate >/dev/null 2>&1; then
      log "✅ 已透過 corepack 啟用 pnpm"; return 0
    fi
  fi
  if need_bin npm; then
    if npm i -g pnpm >/dev/null 2>&1; then log "✅ 已透過 npm 全域安裝 pnpm"; return 0; fi
  fi
  log "⚠️ 自動安裝 pnpm 失敗。手動安裝建議：corepack enable && corepack prepare pnpm@10 --activate 或 npm i -g pnpm"; return 1
}

ensure_frontend_scaffold() {
  mkdir -p "$FRONTEND_DIR"
  if [ ! -f "$FRONTEND_DIR/index.html" ] && [ ! -f "$FRONTEND_DIR/package.json" ]; then
    cat > "$FRONTEND_DIR/index.html" <<HTML
<!doctype html>
<html lang="zh-TW">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>YTMD 前端占位頁</title>
    <style>body{font-family:sans-serif;margin:2rem}code{background:#eee;padding:.2rem .4rem;border-radius:4px}</style>
  </head>
  <body>
    <h1>YTMD 前端占位頁</h1>
    <p>目前尚未實作 UI。此頁由 <code>start-public.sh</code> 建立的靜態伺服器提供。</p>
    <p>可稍後以 Vite 專案取代本目錄內容（放置 package.json 等）。</p>
  </body>
</html>
HTML
  fi
}

start_backend() {
  if [ "$FORCE_BACKEND_RESTART" = "1" ] && lsof -i :${BACKEND_PORT} >/dev/null 2>&1; then
    log "FORCE_BACKEND_RESTART=1 -> 終止既有後端 ${BACKEND_PORT}"; pkill -f "server.py" 2>/dev/null || true; sleep 1
  fi
  if lsof -i :${BACKEND_PORT} >/dev/null 2>&1; then return 0; fi
  log "啟動 Flask 後端 (port $BACKEND_PORT)";
  if [ -x "$CUSTOM_DIR/start-dev.sh" ]; then
    (SERVER_ONLY=1 WEB_SERVER_PORT=$BACKEND_PORT bash "$CUSTOM_DIR/start-dev.sh" >/dev/null 2>&1 &)
  else
    ensure_python || true
    if need_bin python3; then
      if [ ! -d "$WS_DIR/.venv" ]; then
        python3 -m venv "$WS_DIR/.venv" || true
        "$WS_DIR/.venv/bin/python" -m pip install -U pip >/dev/null 2>&1 || true
        if [ -f "$WS_DIR/requirements.txt" ]; then
          "$WS_DIR/.venv/bin/python" -m pip install -r "$WS_DIR/requirements.txt" >/dev/null 2>&1 || true
        fi
      fi
      (WEB_SERVER_PORT=$BACKEND_PORT "$WS_DIR/.venv/bin/python" "$WS_DIR/server.py" >/dev/null 2>&1 &)
    else
      log "❌ 無法啟動後端：缺少 python3。建議：$(pkg_hint python3)"
    fi
  fi
  for i in {1..30}; do curl -sf http://127.0.0.1:${BACKEND_PORT}/health >/dev/null 2>&1 && break; sleep 0.5; done
}

start_frontend() {
  local PID_FILE="/tmp/ytreq-frontend.pid"
  # If we started it before and it's still alive, skip
  if [ -f "$PID_FILE" ]; then
    local oldpid
    oldpid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
      log "前端已在執行 (pid=$oldpid)，略過重啟"
      return 0
    fi
  fi
  # prefer vite if requested/available
  if { [ "$FRONTEND_MODE" = "vite" ] || [ "$FRONTEND_MODE" = "auto" ]; } \
     && [ -f "$FRONTEND_DIR/package.json" ] \
     && need_bin pnpm; then
    log "啟動前端 Vite (port $FRONTEND_PORT) log: $FRONTEND_LOG"
    (
      cd "$FRONTEND_DIR"
      pnpm install >>"$FRONTEND_LOG" 2>&1 || true
      pnpm dev --host 0.0.0.0 --port $FRONTEND_PORT >>"$FRONTEND_LOG" 2>&1 & echo $! > "$PID_FILE"
    )
    return 0
  fi
  # static server fallback
  ensure_python || return 1
  log "啟動前端靜態伺服器 (python http.server) 於 $FRONTEND_DIR port $FRONTEND_PORT"
  (
    cd "$FRONTEND_DIR"
    python3 -m http.server "$FRONTEND_PORT" --bind 0.0.0.0 >>"$FRONTEND_LOG" 2>&1 & echo $! > "$PID_FILE"
  )
}

# -------------------- bootstrap --------------------
need_or_hint curl curl >/dev/null || true
if ! need_bin jq; then log "⚠️ 未找到 jq（解析 ngrok API）。安裝建議：$(pkg_hint jq)"; fi
if [ "$ENABLE_NGROK" = "1" ] && ! need_bin "$NGROK_BIN"; then
  log "⚠️ 未找到 ngrok。請先安裝並設定 authtoken。建議參考：https://ngrok.com/download"
fi

# backend
# pre-start purge lingering processes on configured ports
log "預清理既有進程（若有）..."
pkill -f "$NGROK_BIN http .*:${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "$NGROK_BIN http .*:${BACKEND_PORT}" 2>/dev/null || true
pkill -f "vite.*:${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "http.server ${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "server.py" 2>/dev/null || true
kill_port "$FRONTEND_PORT"; kill_port "$BACKEND_PORT"

start_backend

# frontend
ensure_frontend_scaffold
if ! lsof -i :${FRONTEND_PORT} >/dev/null 2>&1; then
  if [ "$FRONTEND_MODE" != "static" ]; then ensure_node_pnpm || true; fi
  start_frontend || log "⚠️ 前端啟動失敗，請檢查 $FRONTEND_LOG"
fi

# supervisor for frontend
start_supervisor(){
  log "啟動前端監控循環 (ENABLE_FRONTEND_SUPERVISOR=1)"
  while true; do
    sleep 5
    if ! lsof -i :${FRONTEND_PORT} >/dev/null 2>&1; then
      log "⚠️ 偵測到前端 port ${FRONTEND_PORT} 不在，嘗試自動重啟"
      [ "$FRONTEND_MODE" != "static" ] && ensure_node_pnpm || true
      start_frontend || log "❌ 無法重啟前端，請檢查 $FRONTEND_LOG 或手動啟動"
      for i in {1..20}; do lsof -i :${FRONTEND_PORT} >/dev/null 2>&1 && { log "✅ 前端已自動重啟"; break; }; sleep 0.5; done
    fi
  done
}
if [ "$ENABLE_FRONTEND_SUPERVISOR" = "1" ]; then
  # stop any previous supervisor
  if [ -f "/tmp/ytreq-frontend-supervisor.pid" ]; then
    SUP_PID=$(cat /tmp/ytreq-frontend-supervisor.pid 2>/dev/null || true)
    [ -n "$SUP_PID" ] && kill "$SUP_PID" 2>/dev/null || true
    rm -f /tmp/ytreq-frontend-supervisor.pid
  fi
  start_supervisor & echo $! > /tmp/ytreq-frontend-supervisor.pid
fi

# wait briefly for frontend and try 404 remediation (vite only)
if ! curl -sf http://$UPSTREAM_HOST:${FRONTEND_PORT} >/dev/null 2>&1; then
  for i in {1..30}; do curl -sf http://$UPSTREAM_HOST:${FRONTEND_PORT} >/dev/null 2>&1 && break; sleep 0.5; [ $i -eq 10 ] && log "等待前端啟動中..."; done
fi
if ! curl -sf http://$UPSTREAM_HOST:${FRONTEND_PORT} >/dev/null 2>&1; then
  log "⚠️ 前端仍未在 ${FRONTEND_PORT} 啟動 (host=$UPSTREAM_HOST)，ngrok 可能報 ERR_NGROK_8012";
fi
if [ "$FRONTEND_FORCE_RESTART_ON_404" = "1" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://$UPSTREAM_HOST:${FRONTEND_PORT}/ || echo 000)
  if [ "$HTTP_CODE" = "404" ]; then
    log "⚠️ 前端埠已開但 GET / 為 404，嘗試 --root 修復"
    if [ -f "/tmp/ytreq-frontend.pid" ]; then
      OLD_PID=$(cat /tmp/ytreq-frontend.pid 2>/dev/null || true)
      [ -n "$OLD_PID" ] && { log "終止既有 Vite 進程: $OLD_PID"; kill "$OLD_PID" 2>/dev/null || true; sleep 1; }
      rm -f /tmp/ytreq-frontend.pid
    else
      OLD_PIDS=$(lsof -ti :${FRONTEND_PORT} -c node 2>/dev/null || true)
      [ -n "$OLD_PIDS" ] && { log "終止既有 Vite 進程: $OLD_PIDS"; kill $OLD_PIDS 2>/dev/null || true; sleep 1; }
    fi
    if need_bin pnpm && [ -f "$FRONTEND_DIR/package.json" ]; then
      (cd "$FRONTEND_DIR" && pnpm vite --host 0.0.0.0 --port $FRONTEND_PORT --strictPort --root "$FRONTEND_DIR" >>"$FRONTEND_LOG" 2>&1 & echo $! > /tmp/ytreq-frontend.pid)
    else
      start_frontend || true
    fi
    for i in {1..20}; do HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://$UPSTREAM_HOST:${FRONTEND_PORT}/ || echo 000); [ "$HTTP_CODE" = "200" ] && { log "✅ 修復成功：GET / = 200"; break; }; sleep 0.5; done
    [ "$HTTP_CODE" != "200" ] && log "❌ 修復後仍非 200 (目前 $HTTP_CODE)。檢查 $FRONTEND_LOG 或手動：cd $FRONTEND_DIR && pnpm dev"
  fi
else
  log "跳過 404 自動修復 (FRONTEND_FORCE_RESTART_ON_404=0)"
fi

# -------------------- ngrok --------------------
start_ngrok(){
  local name="$1"; shift
  local target="$1"; shift
  local log_file="/tmp/ngrok-${name}.log"
  log "啟動 ngrok 隧道(${name}) -> ${target} (region=$NGROK_REGION)";
  ("$NGROK_BIN" http "$target" \
     --host-header=rewrite \
     --region=$NGROK_REGION \
     --log=stdout --log-level=warn &> "$log_file" &)
  sleep 2
}

if [ "$ENABLE_NGROK" = "1" ]; then
  if need_bin "$NGROK_BIN"; then
    if [ "$NGROK_ALWAYS_NEW" = "1" ]; then
      old_ngrok=$(pgrep -f "$NGROK_BIN http .*:${FRONTEND_PORT}" || true)
      [ -n "$old_ngrok" ] && { log "NGROK_ALWAYS_NEW=1 -> 終止既有 ngrok(frontend): $old_ngrok"; kill $old_ngrok 2>/dev/null || true; sleep 1; }
    fi
    pgrep -f "$NGROK_BIN http .*:${FRONTEND_PORT}" >/dev/null 2>&1 || start_ngrok frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}"

    # backend tunnel
    if [ "$NGROK_ALWAYS_NEW" = "1" ]; then
      old_ngrok=$(pgrep -f "$NGROK_BIN http .*:${BACKEND_PORT}" || true)
      [ -n "$old_ngrok" ] && { log "NGROK_ALWAYS_NEW=1 -> 終止既有 ngrok(backend): $old_ngrok"; kill $old_ngrok 2>/dev/null || true; sleep 1; }
    fi
    pgrep -f "$NGROK_BIN http .*:${BACKEND_PORT}" >/dev/null 2>&1 || start_ngrok backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}"
  else
    log "⚠️ 略過 ngrok（未安裝）"
  fi
else
  log "ℹ️ 已禁用 ngrok (ENABLE_NGROK=0)"
fi

fetch_ngrok_url(){
  local url="" raw="";
  raw=$(curl -sf $NGROK_API || true)
  if [ -n "$raw" ]; then
    if need_bin jq; then
  url=$(echo "$raw" | jq -r --arg p ":$1" '.tunnels[] | select(.config.addr | test($p)) | .public_url' | head -n1)
    else
      url=$(echo "$raw" | grep -Eo 'https://[^" ]+ngrok[^" ]+' | head -n1 || true)
    fi
  fi
  echo "$url"
}

frontend_url=""
backend_url=""
if [ "$ENABLE_NGROK" = "1" ] && need_bin "$NGROK_BIN"; then
  for i in {1..15}; do frontend_url=$(fetch_ngrok_url "$FRONTEND_PORT"); [ -n "$frontend_url" ] && break; sleep 1; done
  [ -z "$frontend_url" ] && log "⚠️ 尚未取得 ngrok URL，將背景持續嘗試刷新" || log "取得 ngrok URL: $frontend_url"
  for i in {1..15}; do backend_url=$(fetch_ngrok_url "$BACKEND_PORT"); [ -n "$backend_url" ] && break; sleep 1; done
  [ -z "$backend_url" ] && log "⚠️ 尚未取得 backend ngrok URL" || log "取得 backend ngrok URL: $backend_url"
else
  log "ℹ️ 不使用 ngrok，將只寫入本地連結"
fi

# -------------------- public_links.json --------------------
detect_lan_ip(){
  local ip
  ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
  if [ -z "$ip" ]; then ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\.' | head -n1); fi
  echo "$ip"
}
LAN_IP=$(detect_lan_ip); [ -z "$LAN_IP" ] && LAN_IP="127.0.0.1"

write_public_links(){
  mkdir -p "$(dirname "$LINKS_FILE")"
  local tmp="${LINKS_FILE}.tmp$$"
  cat > "$tmp" <<JSON
{
  "generatedAt": "$(date -Iseconds)",
  "frontend": {
    "local": "http://$LAN_IP:${FRONTEND_PORT}",
      "public": "${1:-$frontend_url}"
    },
    "backend": {
      "local": "http://$LAN_IP:${BACKEND_PORT}",
      "public": "${2:-$backend_url}"
  }
}
JSON
  mv "$tmp" "$LINKS_FILE" 2>/dev/null || { cp "$tmp" "$LINKS_FILE"; rm -f "$tmp"; }
  log "更新 public_links.json (public=${1:-$frontend_url}) size=$(stat -c%s "$LINKS_FILE" 2>/dev/null || echo ?)"
}

write_public_links "$frontend_url" "$backend_url"
log "GET /public-links 可取得 JSON（由 Flask 服務）"

(
  prev_lan="$LAN_IP"
  while true; do
    sleep 15
    current_lan=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
    [ -z "$current_lan" ] && current_lan="$prev_lan"
  if [ "$current_lan" != "$prev_lan" ]; then prev_lan="$current_lan"; LAN_IP="$current_lan"; log "偵測到 LAN IP 變更 -> $current_lan 重新寫入 public_links"; write_public_links "$frontend_url" "$backend_url"; fi
    fe_pub=$(grep '"frontend"' -A2 "$LINKS_FILE" 2>/dev/null | grep '"public"' | head -n1 | sed -E 's/.*"public": "([^"]*)".*/\1/')
    be_pub=$(grep '"backend"' -A2 "$LINKS_FILE" 2>/dev/null | grep '"public"' | head -n1 | sed -E 's/.*"public": "([^"]*)".*/\1/')
    if [ -z "$fe_pub" ] || [ "$fe_pub" = "null" ]; then
      new_url=$(fetch_ngrok_url "$FRONTEND_PORT")
      [ -n "$new_url" ] && { frontend_url="$new_url"; write_public_links "$new_url" "$backend_url"; continue; }
    else
      code=$(curl -sk -o /dev/null -w '%{http_code}' "$fe_pub" || echo 000)
      case "$code" in
        000|502|503|504)
          log "⚠️ frontend public URL ($fe_pub) HTTP=$code，嘗試重建 ngrok"
          pkill -f "$NGROK_BIN http .*:$FRONTEND_PORT" 2>/dev/null || true; sleep 1
          start_ngrok frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}"; sleep 2
          new_url=$(fetch_ngrok_url "$FRONTEND_PORT")
          [ -n "$new_url" ] && { frontend_url="$new_url"; write_public_links "$new_url" "$backend_url"; }
          ;;
      esac
    fi
    if [ -n "$be_pub" ] && [ "$be_pub" != "null" ]; then
      code=$(curl -sk -o /dev/null -w '%{http_code}' "$be_pub/health" || echo 000)
      case "$code" in
        000|502|503|504)
          log "⚠️ backend public URL ($be_pub) HTTP=$code，嘗試重建 ngrok"
          pkill -f "$NGROK_BIN http .*:$BACKEND_PORT" 2>/dev/null || true; sleep 1
          start_ngrok backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}"; sleep 2
          new_b=$(fetch_ngrok_url "$BACKEND_PORT")
          [ -n "$new_b" ] && { backend_url="$new_b"; write_public_links "$frontend_url" "$new_b"; }
          ;;
      esac
    fi
  done
) &

# -------------------- QR code --------------------
QR_SCRIPT="$CUSTOM_DIR/launchers/utils/qr-generator.py"
TARGET_URL="${frontend_url:-http://$LAN_IP:${FRONTEND_PORT}}"
PYTHON_CANDIDATE="$WS_DIR/.venv/bin/python"
if [ -x "$PYTHON_CANDIDATE" ]; then PYTHON_BIN="$PYTHON_CANDIDATE"; else PYTHON_BIN="$(command -v python3 || true)"; fi
if [ -n "$PYTHON_BIN" ] && [ -f "$QR_SCRIPT" ]; then
  if ! "$PYTHON_BIN" -c "import qrcode" >/dev/null 2>&1; then
    if [ "$AUTO_INSTALL_QRCODE" = "1" ]; then
      log "缺少 qrcode 套件，嘗試安裝 (AUTO_INSTALL_QRCODE=1 可關閉設 0)";
      "$PYTHON_BIN" -m pip install -q --upgrade pip >/dev/null 2>&1 || true
      "$PYTHON_BIN" -m pip install -q qrcode[pil] || log "⚠️ 自動安裝 qrcode 失敗，請手動：$PYTHON_BIN -m pip install qrcode[pil]"
    else
      log "⚠️ 缺少 qrcode 套件，略過（設定 AUTO_INSTALL_QRCODE=1 可自動安裝)"
    fi
  fi
  if "$PYTHON_BIN" -c "import qrcode" >/dev/null 2>&1; then
    log "產生並顯示 QR Code (URL: $TARGET_URL)"; "$PYTHON_BIN" "$QR_SCRIPT" "$TARGET_URL" --no-save || true
  else
    log "⚠️ 仍缺少 qrcode 套件，無法顯示 QR"
  fi
else
  log "⚠️ 無法顯示 QR：缺少 python 或腳本 $QR_SCRIPT"
fi

# -------------------- Electron dev --------------------
if [ "$ELECTRON_DEV" = "1" ]; then
  if ensure_node_pnpm; then
    log "啟動 Electron（pnpm dev）"; (cd "$ROOT_DIR" && pnpm dev)
  else
    log "⚠️ 略過 Electron：未安裝 node/pnpm"; log "👉 範例安裝：$(pkg_hint nodejs) 然後 corepack enable && corepack prepare pnpm@10 --activate"
    log "前景保持，CTRL+C 結束"; while true; do sleep 3600; done
  fi
else
  log "前景保持（不啟動 Electron），CTRL+C 結束"; while true; do sleep 3600; done
fi

# -------------------- health (non-blocking) --------------------
(
  sleep 2
  echo "[public][health] ---- runtime ports ----"
  for p in $FRONTEND_PORT $BACKEND_PORT 26538 4040; do
    if lsof -i :$p >/dev/null 2>&1; then echo "[public][health] port $p: UP"; else echo "[public][health] port $p: DOWN"; fi
  done
  if curl -sf http://localhost:${BACKEND_PORT}/public-links >/dev/null 2>&1; then echo "[public][health] public-links: OK"; else echo "[public][health] public-links: UNREACHABLE"; fi
  if [ -f "$LINKS_FILE" ]; then
    PUB=$(grep '"public"' "$LINKS_FILE" | head -n1 | sed -E 's/.*"public": "([^"]*)".*/\1/')
    if [ -n "$PUB" ] && [[ "$PUB" == http* ]]; then CODE=$(curl -sk -o /dev/null -w '%{http_code}' "$PUB" || echo 000); echo "[public][health] public-url HTTP=$CODE ($PUB)"; fi
  fi
) &
