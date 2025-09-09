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

# -------------------- optional config file --------------------
# Allow loading a config file so users don't need to retype env vars each run.
# Search order (first hit wins):
#   1) $START_PUBLIC_CONFIG (explicit)
#   2) $ROOT_DIR/.start-public.conf
#   3) $CUSTOM_DIR/scripts/start-public.conf
#   4) $HOME/.config/ytmd-start-public.conf
{
  cfg_candidates=()
  [ -n "${START_PUBLIC_CONFIG:-}" ] && cfg_candidates+=("$START_PUBLIC_CONFIG")
  cfg_candidates+=("$ROOT_DIR/.start-public.conf" "$CUSTOM_DIR/scripts/start-public.conf" "$HOME/.config/ytmd-start-public.conf")
  for cfg in "${cfg_candidates[@]}"; do
    if [ -f "$cfg" ]; then
      echo "[public] 載入設定檔: $cfg"
      set -a
      # shellcheck disable=SC1090
      . "$cfg"
      set +a
      break
    fi
  done
}

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
QR_PREFER_LAN=${QR_PREFER_LAN:-0}          # 1=QR 使用區域網 IP，即使有 public URL

# Public URL provider (default: ngrok; Cloudflare only when Named Tunnel is configured)
ENABLE_CLOUDFLARE=${ENABLE_CLOUDFLARE:-0}
CLOUDFLARED_BIN=${CLOUDFLARED_BIN:-cloudflared}
# Named Tunnel is optional and disabled by default; Quick Tunnel is default.
ENABLE_NAMED_TUNNEL=${ENABLE_NAMED_TUNNEL:-0}
CF_TUNNEL_TOKEN=${CF_TUNNEL_TOKEN:-}
# If using a Named Tunnel, you can specify the tunnel name and hostnames.
# Example:
#   ENABLE_NAMED_TUNNEL=1 CF_TUNNEL_NAME=song-server \
#   CF_HOSTNAME_FRONTEND=vite.bc-verse.com CF_HOSTNAME_BACKEND=api.bc-verse.com
CF_TUNNEL_NAME=${CF_TUNNEL_NAME:-}
CF_HOSTNAME_FRONTEND=${CF_HOSTNAME_FRONTEND:-}
CF_HOSTNAME_BACKEND=${CF_HOSTNAME_BACKEND:-}
# Optional cloudflared config file (contains ingress rules) if not managed in Zero Trust UI
CF_TUNNEL_CONFIG=${CF_TUNNEL_CONFIG:-}
PUBLIC_PROVIDER=""
# Cloudflare metrics ports (local API) for Quick Tunnel URL discovery
CLOUDFLARE_METRICS_PORT_FE=${CLOUDFLARE_METRICS_PORT_FE:-52711}
CLOUDFLARE_METRICS_PORT_BE=${CLOUDFLARE_METRICS_PORT_BE:-52712}

# API Server (YTMD plugin) connectivity config; align with plugin menu (hostname/port)
YTMD_HOSTNAME=${YTMD_HOSTNAME:-${YTMD_HOST:-localhost}}
YTMD_PORT=${YTMD_PORT:-26538}
# Compose YTMD_API if not provided
export YTMD_API=${YTMD_API:-http://$YTMD_HOSTNAME:$YTMD_PORT/api/v1}

# make Vite/electron-vite more permissive when in dev
export VITE_ALLOW_ALL_HOSTS=1
export NGROK_HOST="${NGROK_HOST:-}"
export ELECTRON_RENDERER_PORT=${ELECTRON_RENDERER_PORT:-5600}
export RENDERER_LOCAL_ONLY=1

# -------------------- helpers --------------------
log(){ echo "[public] $*"; }

# parse flags (simple)
for arg in "$@"; do
  case "$arg" in
    --qr-lan|--qr-local|--qr-use-lan)
      QR_PREFER_LAN=1
      ;;
  esac
done

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
  # stop cloudflared tunnels
  pkill -f "$CLOUDFLARED_BIN .*--url .*:${FRONTEND_PORT}" 2>/dev/null || true
  pkill -f "$CLOUDFLARED_BIN .*--url .*:${BACKEND_PORT}" 2>/dev/null || true
  pkill -f "$CLOUDFLARED_BIN tunnel" 2>/dev/null || true
  # named tunnel explicit kill (token/name based)
  pkill -f "$CLOUDFLARED_BIN tunnel --no-autoupdate .* run" 2>/dev/null || true
  # stop frontend vite/http.server
  if [ -f "/tmp/ytreq-frontend.pid" ]; then
    FRONT_PID=$(cat /tmp/ytreq-frontend.pid || true)
    [ -n "$FRONT_PID" ] && kill "$FRONT_PID" 2>/dev/null || true
    rm -f /tmp/ytreq-frontend.pid
  fi
  # kill any vite processes regardless of auto-selected port
  pkill -f "vite" 2>/dev/null || true
  pkill -f "node .*vite" 2>/dev/null || true
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
  # stop song-server supervisor and process
  if [ -f "/tmp/cloudflared-song-server-supervisor.pid" ]; then
    CF_SUP_PID=$(cat /tmp/cloudflared-song-server-supervisor.pid 2>/dev/null || true)
    [ -n "$CF_SUP_PID" ] && kill "$CF_SUP_PID" 2>/dev/null || true
    rm -f /tmp/cloudflared-song-server-supervisor.pid
  fi
  if [ -f "/tmp/cloudflared-song-server.pid" ]; then
    CF_SONG_PID=$(cat /tmp/cloudflared-song-server.pid 2>/dev/null || true)
    [ -n "$CF_SONG_PID" ] && kill "$CF_SONG_PID" 2>/dev/null || true
    rm -f /tmp/cloudflared-song-server.pid
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

# 取得 cloudflared 安裝建議
pkg_hint_cloudflared(){
  if [ -f /etc/os-release ]; then . /etc/os-release; fi
  case "${ID:-}" in
    ubuntu|debian) echo "curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null && echo \"deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflare-main $(. /etc/os-release && echo $VERSION_CODENAME) main\" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null && sudo apt-get update && sudo apt-get install -y cloudflared" ;;
    fedora) echo "sudo dnf install -y cloudflared" ;;
    arch|manjaro) echo "sudo pacman -S --noconfirm cloudflared" ;;
    *) echo "See: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" ;;
  esac
}

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
  # Force Vite to bind the configured port and fail if occupied
  pnpm vite --host 0.0.0.0 --port $FRONTEND_PORT --strictPort >>"$FRONTEND_LOG" 2>&1 & echo $! > "$PID_FILE"
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
if ! need_bin jq; then log "⚠️ 未找到 jq（解析 JSON）。安裝建議：$(pkg_hint jq)"; fi
if [ "$ENABLE_CLOUDFLARE" = "1" ]; then
  if need_bin "$CLOUDFLARED_BIN"; then
    # 啟用 Cloudflare Named Tunnel 模式（不預設名稱）
    ENABLE_NAMED_TUNNEL=1
    PUBLIC_PROVIDER="cloudflare"
    ENABLE_NGROK=0
  if [ -n "$CF_TUNNEL_TOKEN" ]; then
      log "Public provider: Cloudflare (Named Tunnel via token)"
    else
      log "Public provider: Cloudflare (Named Tunnel)"
    fi
  # 注意：實際啟動 song-server 會在預清理之後執行
  else
    log "⚠️ Cloudflare 隧道未安裝，建議安裝：$(pkg_hint_cloudflared)"
  fi
fi
if [ -z "$PUBLIC_PROVIDER" ] && [ "$ENABLE_NGROK" = "1" ]; then
  if need_bin "$NGROK_BIN"; then
    PUBLIC_PROVIDER="ngrok"
    log "Public provider: ngrok"
  else
    log "⚠️ 未找到 ngrok。請先安裝並設定 authtoken。建議參考：https://ngrok.com/download"
  fi
fi
if [ -z "$PUBLIC_PROVIDER" ]; then
  log "ℹ️ 無可用的公開隧道提供者（使用 LAN 連結 / 本機埠）"
fi

# backend
# pre-start purge lingering processes on configured ports
log "預清理既有進程（若有）..."
pkill -f "$NGROK_BIN http .*:${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "$NGROK_BIN http .*:${BACKEND_PORT}" 2>/dev/null || true
# stop lingering cloudflared
pkill -f "$CLOUDFLARED_BIN .*--url .*:${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "$CLOUDFLARED_BIN .*--url .*:${BACKEND_PORT}" 2>/dev/null || true
pkill -f "$CLOUDFLARED_BIN tunnel" 2>/dev/null || true
# Be aggressive to avoid stray vite instances from previous runs
pkill -f "vite" 2>/dev/null || true
pkill -f "node .*vite" 2>/dev/null || true
pkill -f "http.server ${FRONTEND_PORT}" 2>/dev/null || true
pkill -f "server.py" 2>/dev/null || true
kill_port "$FRONTEND_PORT"; kill_port "$BACKEND_PORT"; kill_port "$ELECTRON_RENDERER_PORT"

# ensure song-server sidecar is running (if Cloudflare chosen)
if [ "$PUBLIC_PROVIDER" = "cloudflare" ]; then
  # 若 Named Tunnel 不是使用同名 song-server，才啟動 sidecar，避免重複跑同一個 tunnel
  if [ "${CF_TUNNEL_NAME:-}" != "song-server" ] && [ -z "${CF_TUNNEL_TOKEN:-}" ]; then
    start_cloudflared_song_server >/dev/null 2>&1 || true
    start_song_server_supervisor >/dev/null 2>&1 || true
  fi
fi

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

# -------------------- public tunnels --------------------
# Cloudflare helpers
start_cloudflared(){
  local name="$1"; shift
  local target="$1"; shift
  local metrics_port="$1"; shift
  local log_file="/tmp/cloudflared-${name}.log"
  log "啟動 Cloudflare 隧道(${name}) -> ${target} (metrics=127.0.0.1:${metrics_port})";
  if [ "$ENABLE_NAMED_TUNNEL" = "1" ] && [ -n "$CF_TUNNEL_TOKEN" ]; then
    # Named tunnel (requires pre-config). Public hostname is managed via Cloudflare DNS.
    ("$CLOUDFLARED_BIN" tunnel --no-autoupdate --loglevel warn --metrics 127.0.0.1:${metrics_port} run --token "$CF_TUNNEL_TOKEN" &> "$log_file" &)
  else
    # Quick tunnel (trycloudflare.com)
    ("$CLOUDFLARED_BIN" tunnel --no-autoupdate --loglevel info --metrics 127.0.0.1:${metrics_port} --url "$target" &> "$log_file" &)
  fi
  echo "$log_file"
}

# Named tunnel launcher (single process). Requires CF_TUNNEL_NAME or CF_TUNNEL_TOKEN
start_cloudflared_named(){
  local log_file="/tmp/cloudflared-named.log"
  if [ -n "$CF_TUNNEL_TOKEN" ]; then
    log "啟動 Cloudflare Named Tunnel (token)"
    ("$CLOUDFLARED_BIN" tunnel --no-autoupdate --loglevel warn ${CF_TUNNEL_CONFIG:+--config "$CF_TUNNEL_CONFIG"} run --token "$CF_TUNNEL_TOKEN" &> "$log_file" &)
  elif [ -n "$CF_TUNNEL_NAME" ]; then
  log "啟動 Cloudflare Named Tunnel: $CF_TUNNEL_NAME${CF_TUNNEL_CONFIG:+ (config=$CF_TUNNEL_CONFIG)}"
  ("$CLOUDFLARED_BIN" tunnel --no-autoupdate --loglevel warn ${CF_TUNNEL_CONFIG:+--config "$CF_TUNNEL_CONFIG"} run "$CF_TUNNEL_NAME" &> "$log_file" &)
  else
    log "❌ ENABLE_NAMED_TUNNEL=1 但未提供 CF_TUNNEL_NAME 或 CF_TUNNEL_TOKEN"
  fi
  echo "$log_file"
}

# Sidecar: run a fixed tunnel service name to ensure Cloudflare connectivity
start_cloudflared_song_server(){
  local log_file="/tmp/cloudflared-song-server.log"
  log "啟動 Cloudflared 服務 (song-server) 以確保連線"
  ("$CLOUDFLARED_BIN" tunnel --no-autoupdate --loglevel warn ${CF_TUNNEL_CONFIG:+--config "$CF_TUNNEL_CONFIG"} run song-server >> "$log_file" 2>&1 & echo $! > /tmp/cloudflared-song-server.pid)
  echo "$log_file"
}

# Supervisor to keep song-server running persistently
start_song_server_supervisor(){
  local sup_pid_file="/tmp/cloudflared-song-server-supervisor.pid"
  # stop previous
  if [ -f "$sup_pid_file" ]; then
    local old
    old=$(cat "$sup_pid_file" 2>/dev/null || true)
    [ -n "$old" ] && kill "$old" 2>/dev/null || true
    rm -f "$sup_pid_file"
  fi
  (
    while :; do
      sleep 10
      if ! pgrep -f "${CLOUDFLARED_BIN} .*tunnel .*run .*song-server" >/dev/null 2>&1; then
        log "⚠️ song-server 進程不在，嘗試重啟"
        start_cloudflared_song_server >/dev/null 2>&1 || true
      fi
    done
  ) & echo $! > "$sup_pid_file"
}

# Attempt to infer hostnames from a cloudflared YAML config by matching service ports
cf_hostname_for_port(){
  local cfg="$1"; local port="$2"
  [ -f "$cfg" ] || { echo ""; return 0; }
  awk -v tgt=":""$port" -v h="" '
    /^[[:space:]]*-?[[:space:]]*hostname:[[:space:]]*/ { sub(/^[[:space:]]*-?[[:space:]]*hostname:[[:space:]]*/, ""); h=$0; gsub(/["\047]/, "", h) }
    /^[[:space:]]*service:[[:space:]]*/ {
      s=$0; gsub(/["\047]/, "", s);
      if (index(s, tgt)>0) { print h; exit }
    }
  ' "$cfg" | head -n1
}

# Auto-detect cloudflared config file if not provided
resolve_cf_config(){
  if [ -n "$CF_TUNNEL_CONFIG" ] && [ -f "$CF_TUNNEL_CONFIG" ]; then echo "$CF_TUNNEL_CONFIG"; return; fi
  local home_cfg1="$HOME/.cloudflared/config.yml"
  local home_cfg2="$HOME/.cloudflared/config.yaml"
  local etc_cfg1="/etc/cloudflared/config.yml"
  local etc_cfg2="/etc/cloudflared/config.yaml"
  if [ -f "$home_cfg1" ]; then echo "$home_cfg1"; return; fi
  if [ -f "$home_cfg2" ]; then echo "$home_cfg2"; return; fi
  if [ -f "$etc_cfg1" ]; then echo "$etc_cfg1"; return; fi
  if [ -f "$etc_cfg2" ]; then echo "$etc_cfg2"; return; fi
  echo ""
}

# Prefer metrics API for Quick Tunnel (recommended)
fetch_cloudflared_url_metrics(){
  local port="$1"
  local url="" raw
  raw=$(curl -sf "http://127.0.0.1:${port}/quicktunnel" 2>/dev/null || true)
  if [ -n "$raw" ]; then
    if need_bin jq; then
      # Try common JSON shapes
      url=$(echo "$raw" | jq -r '.hostname // .result.hostname // .tunnel // empty' 2>/dev/null || true)
    fi
    if [ -z "$url" ]; then
      url=$(echo "$raw" | grep -Eo 'https?://[A-Za-z0-9.-]+trycloudflare\.com[^"[:space:]]*' | head -n1 || true)
    fi
  fi
  echo "$url"
}

# Fallback: parse log file for trycloudflare hostname
fetch_cloudflared_url_from_log(){
  local log_file="$1"
  local url=""
  if [ -f "$log_file" ]; then
    url=$(grep -Eo 'https?://[A-Za-z0-9.-]+trycloudflare\.com[^"[:space:]]*' "$log_file" | tail -n1 || true)
  fi
  echo "$url"
}

# ngrok helpers (kept as fallback)
start_ngrok(){
  local name="$1"; shift
  local target="$1"; shift
  local log_file="/tmp/ngrok-${name}.log"
  log "啟動 ngrok 隧道(${name}) -> ${target} (region=$NGROK_REGION)";
  ("$NGROK_BIN" http "$target" \
     --host-header=rewrite \
     --region=$NGROK_REGION \
     --log=stdout --log-level=warn &> "$log_file" &)
  echo "$log_file"
}

fetch_ngrok_url(){
  local port="$1"
  local url="" raw=""
  raw=$(curl -sf $NGROK_API || true)
  if [ -n "$raw" ]; then
    if need_bin jq; then
      url=$(echo "$raw" | jq -r --arg p ":$port" '.tunnels[] | select(.config.addr | test($p)) | .public_url' | head -n1)
    else
      url=$(echo "$raw" | grep -Eo 'https://[^" ]+ngrok[^" ]+' | head -n1 || true)
    fi
  fi
  echo "$url"
}

frontend_url=""
backend_url=""

if [ "$PUBLIC_PROVIDER" = "cloudflare" ]; then
  if [ "$ENABLE_NAMED_TUNNEL" = "1" ]; then
    # Start one named tunnel and use provided hostnames as public URLs
    CF_NAMED_LOG=$(start_cloudflared_named)
    # Quick readiness hint
    sleep 2
    if ! pgrep -f "${CLOUDFLARED_BIN} .*tunnel .*run( |$)" >/dev/null 2>&1; then
      log "⚠️ Named Tunnel 似乎未啟動，請檢查：$CF_NAMED_LOG"
    fi
  # Try to auto-detect config if not provided
  if [ -z "$CF_TUNNEL_CONFIG" ]; then CF_TUNNEL_CONFIG=$(resolve_cf_config); fi
  if [ -z "$CF_HOSTNAME_FRONTEND" ] && [ -n "$CF_TUNNEL_CONFIG" ]; then
      CF_HOSTNAME_FRONTEND=$(cf_hostname_for_port "$CF_TUNNEL_CONFIG" "$FRONTEND_PORT" || true)
    fi
    if [ -n "$CF_HOSTNAME_FRONTEND" ]; then
      frontend_url="https://$CF_HOSTNAME_FRONTEND"
      log "使用 Named Tunnel FE hostname: $frontend_url"
    else
      log "⚠️ 未設定 CF_HOSTNAME_FRONTEND，public_links 將只包含本地連結"
    fi
    if [ -z "$CF_HOSTNAME_BACKEND" ] && [ -n "$CF_TUNNEL_CONFIG" ]; then
      CF_HOSTNAME_BACKEND=$(cf_hostname_for_port "$CF_TUNNEL_CONFIG" "$BACKEND_PORT" || true)
    fi
    if [ -n "$CF_HOSTNAME_BACKEND" ]; then
      backend_url="https://$CF_HOSTNAME_BACKEND"
      log "使用 Named Tunnel BE hostname: $backend_url"
    else
      log "⚠️ 未設定 CF_HOSTNAME_BACKEND，public_links 將只包含本地連結（backend）"
    fi
  else
    # Quick Tunnel mode: start per-port tunnels and discover URLs
    CF_FE_LOG=$(start_cloudflared frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}" "$CLOUDFLARE_METRICS_PORT_FE")
    # wait for FE URL with backoff on 429
    for i in {1..60}; do 
      frontend_url=$(fetch_cloudflared_url_metrics "$CLOUDFLARE_METRICS_PORT_FE")
      [ -z "$frontend_url" ] && frontend_url=$(fetch_cloudflared_url_from_log "$CF_FE_LOG")
      if [ -n "$frontend_url" ]; then break; fi
      if grep -q "429 Too Many Requests" "$CF_FE_LOG" 2>/dev/null; then
        log "Cloudflare Quick Tunnel (frontend) 遭到 429，30 秒後重試"
        pkill -f "$CLOUDFLARED_BIN .*--url .*:$FRONTEND_PORT" 2>/dev/null || true
        sleep 30
        CF_FE_LOG=$(start_cloudflared frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}" "$CLOUDFLARE_METRICS_PORT_FE")
      else
        sleep 1
      fi
  done
    [ -z "$frontend_url" ] && log "⚠️ 尚未取得 Cloudflare URL (frontend)" || log "取得 Cloudflare URL (frontend): $frontend_url"
    # slight delay before starting backend to reduce rate limit likelihood
    sleep 2
  CF_BE_LOG=$(start_cloudflared backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}" "$CLOUDFLARE_METRICS_PORT_BE")
    for i in {1..60}; do 
      backend_url=$(fetch_cloudflared_url_metrics "$CLOUDFLARE_METRICS_PORT_BE")
      [ -z "$backend_url" ] && backend_url=$(fetch_cloudflared_url_from_log "$CF_BE_LOG")
      if [ -n "$backend_url" ]; then break; fi
      if grep -q "429 Too Many Requests" "$CF_BE_LOG" 2>/dev/null; then
        log "Cloudflare Quick Tunnel (backend) 遭到 429，30 秒後重試"
        pkill -f "$CLOUDFLARED_BIN .*--url .*:$BACKEND_PORT" 2>/dev/null || true
        sleep 30
        CF_BE_LOG=$(start_cloudflared backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}" "$CLOUDFLARE_METRICS_PORT_BE")
      else
        sleep 1
      fi
    done
    [ -z "$backend_url" ] && log "⚠️ 尚未取得 Cloudflare URL (backend)" || log "取得 Cloudflare URL (backend): $backend_url"
  fi
elif [ "$PUBLIC_PROVIDER" = "ngrok" ]; then
  # ensure running
  NG_FE_LOG=$(start_ngrok frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}")
  NG_BE_LOG=$(start_ngrok backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}")
  # fetch from API
  for i in {1..15}; do frontend_url=$(fetch_ngrok_url "$FRONTEND_PORT"); [ -n "$frontend_url" ] && break; sleep 1; done
  [ -z "$frontend_url" ] && log "⚠️ 尚未取得 ngrok URL，將背景持續嘗試刷新" || log "取得 ngrok URL: $frontend_url"
  for i in {1..15}; do backend_url=$(fetch_ngrok_url "$BACKEND_PORT"); [ -n "$backend_url" ] && break; sleep 1; done
  [ -z "$backend_url" ] && log "⚠️ 尚未取得 backend ngrok URL" || log "取得 backend ngrok URL: $backend_url"
else
  log "ℹ️ 不使用公開隧道，將只寫入本地連結"
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

monitor_public_links(){
  prev_lan="$LAN_IP"
  while :; do
    sleep 15
  local new_url="" new_b=""
    current_lan=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
    if [ -z "$current_lan" ]; then
      current_lan="$prev_lan"
    fi
    if [ "$current_lan" != "$prev_lan" ]; then
      prev_lan="$current_lan"
      LAN_IP="$current_lan"
      log "偵測到 LAN IP 變更 -> $current_lan 重新寫入 public_links"
      write_public_links "$frontend_url" "$backend_url"
    fi

    fe_pub=$(grep '"frontend"' -A2 "$LINKS_FILE" 2>/dev/null | grep '"public"' | head -n1 | sed -E 's/.*"public": "([^"]*)".*/\1/')
    be_pub=$(grep '"backend"' -A2 "$LINKS_FILE" 2>/dev/null | grep '"public"' | head -n1 | sed -E 's/.*"public": "([^"]*)".*/\1/')

    if [ -z "$fe_pub" ] || [ "$fe_pub" = "null" ]; then
      if [ "$PUBLIC_PROVIDER" = "cloudflare" ] && [ "$ENABLE_NAMED_TUNNEL" != "1" ]; then
        # First, try metrics endpoint again in case it's delayed
        new_url=$(fetch_cloudflared_url_metrics "$CLOUDFLARE_METRICS_PORT_FE")
        if [ -z "$new_url" ]; then
          pkill -f "$CLOUDFLARED_BIN .*--url .*:$FRONTEND_PORT" 2>/dev/null || true
          sleep 1
          CF_FE_LOG=$(start_cloudflared frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}" "$CLOUDFLARE_METRICS_PORT_FE")
          sleep 2
          new_url=$(fetch_cloudflared_url_metrics "$CLOUDFLARE_METRICS_PORT_FE")
          [ -z "$new_url" ] && new_url=$(fetch_cloudflared_url_from_log "$CF_FE_LOG")
        fi
      elif [ "$PUBLIC_PROVIDER" = "ngrok" ]; then
        new_url=$(fetch_ngrok_url "$FRONTEND_PORT")
      else
        new_url=""
      fi
      if [ -n "$new_url" ]; then
        frontend_url="$new_url"
        write_public_links "$new_url" "$backend_url"
        continue
      fi
    else
      code=$(curl -sk -o /dev/null -w '%{http_code}' "$fe_pub" || echo 000)
    case "$code" in
        000|502|503|504)
          log "⚠️ frontend public URL ($fe_pub) HTTP=$code，嘗試重建隧道 ($PUBLIC_PROVIDER)"
      if [ "$PUBLIC_PROVIDER" = "cloudflare" ] && [ "$ENABLE_NAMED_TUNNEL" != "1" ]; then
            pkill -f "$CLOUDFLARED_BIN .*--url .*:$FRONTEND_PORT" 2>/dev/null || true
            sleep 1
            CF_FE_LOG=$(start_cloudflared frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}" "$CLOUDFLARE_METRICS_PORT_FE")
            sleep 2
            new_url=$(fetch_cloudflared_url_metrics "$CLOUDFLARE_METRICS_PORT_FE")
            [ -z "$new_url" ] && new_url=$(fetch_cloudflared_url_from_log "$CF_FE_LOG")
          elif [ "$PUBLIC_PROVIDER" = "cloudflare" ] && [ "$ENABLE_NAMED_TUNNEL" = "1" ]; then
            pkill -f "$CLOUDFLARED_BIN tunnel --no-autoupdate .* run" 2>/dev/null || true
            sleep 1
            CF_NAMED_LOG=$(start_cloudflared_named)
          elif [ "$PUBLIC_PROVIDER" = "ngrok" ]; then
            pkill -f "$NGROK_BIN http .*:$FRONTEND_PORT" 2>/dev/null || true
            sleep 1
            start_ngrok frontend "http://${UPSTREAM_HOST}:${FRONTEND_PORT}"
            sleep 2
            new_url=$(fetch_ngrok_url "$FRONTEND_PORT")
          fi
          if [ -n "$new_url" ]; then
            frontend_url="$new_url"
            write_public_links "$new_url" "$backend_url"
          fi
          ;;
      esac
    fi

  if [ -n "$be_pub" ] && [ "$be_pub" != "null" ]; then
      code=$(curl -sk -o /dev/null -w '%{http_code}' "$be_pub/health" || echo 000)
    case "$code" in
        000|502|503|504)
          log "⚠️ backend public URL ($be_pub) HTTP=$code，嘗試重建隧道 ($PUBLIC_PROVIDER)"
      if [ "$PUBLIC_PROVIDER" = "cloudflare" ] && [ "$ENABLE_NAMED_TUNNEL" != "1" ]; then
            pkill -f "$CLOUDFLARED_BIN .*--url .*:$BACKEND_PORT" 2>/dev/null || true
            sleep 1
            CF_BE_LOG=$(start_cloudflared backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}" "$CLOUDFLARE_METRICS_PORT_BE")
            sleep 2
            new_b=$(fetch_cloudflared_url_metrics "$CLOUDFLARE_METRICS_PORT_BE")
            [ -z "$new_b" ] && new_b=$(fetch_cloudflared_url_from_log "$CF_BE_LOG")
          elif [ "$PUBLIC_PROVIDER" = "cloudflare" ] && [ "$ENABLE_NAMED_TUNNEL" = "1" ]; then
            pkill -f "$CLOUDFLARED_BIN tunnel --no-autoupdate .* run" 2>/dev/null || true
            sleep 1
            CF_NAMED_LOG=$(start_cloudflared_named)
          elif [ "$PUBLIC_PROVIDER" = "ngrok" ]; then
            pkill -f "$NGROK_BIN http .*:$BACKEND_PORT" 2>/dev/null || true
            sleep 1
            start_ngrok backend "http://${UPSTREAM_HOST}:${BACKEND_PORT}"
            sleep 2
            new_b=$(fetch_ngrok_url "$BACKEND_PORT")
          fi
          if [ -n "$new_b" ]; then
            backend_url="$new_b"
            write_public_links "$frontend_url" "$new_b"
          fi
          ;;
      esac
    fi
  done
}

monitor_public_links &

# -------------------- QR code --------------------
QR_SCRIPT="$CUSTOM_DIR/launchers/utils/qr-generator.py"
# 選擇 QR 目標：優先 public URL；若加上 --qr-lan 或 QR_PREFER_LAN=1，則強制使用區域網 IP
if [ "$QR_PREFER_LAN" = "1" ]; then
  TARGET_URL="http://$LAN_IP:${FRONTEND_PORT}"
  log "QR 模式：使用區域網 IP ($TARGET_URL)"
else
  TARGET_URL="${frontend_url:-http://$LAN_IP:${FRONTEND_PORT}}"
fi
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
