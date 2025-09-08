#!/usr/bin/env bash
# YTMD Public Mode Launcher (Production Style)
# 功能: build 檢查, 後端 + Electron, ngrok, public_links.json, 自動復原, 旋轉隧道
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CUSTOM_DIR="$ROOT_DIR/custom"
WS_DIR="$CUSTOM_DIR/web-server"
APP_SERVER="$WS_DIR/server.py"
PORT=${WEB_SERVER_PORT:-8080}
API_URL=${YTMD_API:-http://localhost:26538/api/v1}
ENABLE_NGROK=${ENABLE_NGROK:-1}
NGROK_BIN=${NGROK_BIN:-ngrok}
NGROK_REGION=${NGROK_REGION:-ap}
ROTATE_INTERVAL_MIN=${ROTATE_INTERVAL_MIN:-}
FORCE_NEW_TUNNEL=${FORCE_NEW_TUNNEL:-0}
FORCE_REBUILD=${FORCE_REBUILD:-0}
SKIP_BUILD=${SKIP_BUILD:-0}
DEV_MODE=${DEV_MODE:-0}
BACKEND_ONLY=${BACKEND_ONLY:-0}
PUBLIC_LINKS_PATH=${PUBLIC_LINKS_PATH:-"$WS_DIR/app/public_links.json"}
QR=${QR:-1}
# 當啟用 ngrok 時只為 public URL 產生 QR (可用 QR_PUBLIC_ONLY=0 覆寫)
QR_PUBLIC_ONLY=${QR_PUBLIC_ONLY:-}
if [[ -z "$QR_PUBLIC_ONLY" ]]; then
	if [[ $ENABLE_NGROK = 1 ]]; then QR_PUBLIC_ONLY=1; else QR_PUBLIC_ONLY=0; fi
fi
# 等待 public URL 最長秒數 (僅在 QR_PUBLIC_ONLY=1 且 ENABLE_NGROK=1 時用)
QR_TIMEOUT_SEC=${QR_TIMEOUT_SEC:-30}
# 強制使用 python 版 QR（忽略 qrencode），ngrok 模式預設啟用，可用 QR_PYTHON_ONLY=0 關閉
QR_PYTHON_ONLY=${QR_PYTHON_ONLY:-}
if [[ -z "$QR_PYTHON_ONLY" ]]; then
	if [[ $ENABLE_NGROK = 1 ]]; then QR_PYTHON_ONLY=1; else QR_PYTHON_ONLY=0; fi
fi
LOG_MAX_KB=${LOG_MAX_KB:-0}
QUIET=${QUIET:-0}
NGROK_LABEL=${NGROK_LABEL:-}

RUNTIME_DIR="/tmp/ytmd-public"
mkdir -p "$RUNTIME_DIR"
WEB_LOG="$RUNTIME_DIR/web.log"
NGROK_LOG="$RUNTIME_DIR/ngrok.log"
SUPERVISOR_LOG="$RUNTIME_DIR/supervisor.log"
PID_WEB="$RUNTIME_DIR/web.pid"
PID_NGROK="$RUNTIME_DIR/ngrok.pid"
PID_APP="$RUNTIME_DIR/app.pid"

color() { local c=$1; shift; [[ $QUIET = 1 ]] && { echo "$*"; return; }; printf "\033[%sm%s\033[0m\n" "$c" "$*"; }
info() { color 36 "[public] $*"; }
warn() { color 33 "[public][WARN] $*"; }
err()  { color 31 "[public][ERR] $*" >&2; }
bold() { color 1  "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { err "缺少指令: $1"; exit 2; }; }
commit_hash() { git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown; }
local_ip() { hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.' | grep -v '^127\.' | head -n1 || echo 127.0.0.1; }

atomic_write_json() { local tmp; tmp=$(mktemp "${PUBLIC_LINKS_PATH}.tmp.XXXX"); cat > "$tmp" && mv "$tmp" "$PUBLIC_LINKS_PATH"; }
rotate_if_big() { local f=$1 m=$2; [[ $m -gt 0 ]] || return 0; [[ -f $f ]] || return 0; local s=$(( $(stat -c%s "$f") /1024 )); [[ $s -ge $m ]] && { mv "$f" "$f.$(date +%Y%m%d%H%M%S)"; :>"$f"; info "rotate $f"; }; }

qr_print() {
	local u=$1
	[[ $QR = 1 ]] || return 0
	echo ""
	info "QR for: $u"
	# 若強制 python 或未找到 qrencode 則使用 python 版 (可存 PNG)
	if { [[ $QR_PYTHON_ONLY = 1 ]] || ! command -v qrencode >/dev/null 2>&1; } && [[ -f "$CUSTOM_DIR/launchers/utils/qr-generator.py" ]]; then
		PYTHONPATH="$CUSTOM_DIR/launchers/utils" python3 "$CUSTOM_DIR/launchers/utils/qr-generator.py" "$u" || echo "$u"
	else
		# 優先 qrencode 彩色模式
		if command -v qrencode >/dev/null 2>&1; then
			qrencode -t ANSIUTF8 "$u" || true
		elif [[ -f "$CUSTOM_DIR/launchers/utils/qr-generator.py" ]]; then
			PYTHONPATH="$CUSTOM_DIR/launchers/utils" python3 "$CUSTOM_DIR/launchers/utils/qr-generator.py" "$u" || echo "$u"
		else
			echo "$u"
		fi
	fi
	echo ""
}

need node; need pnpm; need python3; need curl
[[ $ENABLE_NGROK = 1 ]] && need "$NGROK_BIN" || true
[[ -f "$APP_SERVER" ]] || { err "找不到 $APP_SERVER"; exit 3; }

# 若尚未安裝依賴，自動執行 pnpm install (可用 SKIP_INSTALL=1 跳過)
if [[ ! -d "$ROOT_DIR/node_modules" && ${SKIP_INSTALL:-0} != 1 ]]; then
	info "偵測到缺少 node_modules，執行 pnpm install ..."
	(cd "$ROOT_DIR" && pnpm install)
fi

if [[ $SKIP_BUILD != 1 ]]; then
	NEED_BUILD=0
	if [[ $FORCE_REBUILD = 1 ]]; then NEED_BUILD=1; fi
	[[ -f "$ROOT_DIR/dist/main/index.js" && -f "$ROOT_DIR/dist/renderer/index.html" ]] || NEED_BUILD=1
	if [[ $NEED_BUILD = 1 ]]; then info "build..."; (cd "$ROOT_DIR" && pnpm build); else info "使用 dist/"; fi
else
	info "跳過 build"
fi

if [[ -f "$WS_DIR/requirements.txt" && ! -d "$WS_DIR/.venv" ]]; then
	info "建立 venv"; python3 -m venv "$WS_DIR/.venv"; "$WS_DIR/.venv/bin/pip" install -q --upgrade pip; "$WS_DIR/.venv/bin/pip" install -q -r "$WS_DIR/requirements.txt";
fi
PYTHON_BIN="$WS_DIR/.venv/bin/python"; [[ -x "$PYTHON_BIN" ]] || PYTHON_BIN=$(command -v python3)

start_web() {
	pgrep -f "python.*$APP_SERVER" >/dev/null 2>&1 && { warn "後端已執行"; return; }
	info "啟動後端 port=$PORT"; WEB_SERVER_PORT="$PORT" YTMD_API="$API_URL" nohup "$PYTHON_BIN" "$APP_SERVER" >>"$WEB_LOG" 2>&1 & echo $! > "$PID_WEB"
	for i in {1..25}; do curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && { info "後端健康"; return; }; sleep 0.6; done; warn "健康檢查未通過";
}

start_app() {
	[[ $BACKEND_ONLY = 1 ]] && return 0
	pgrep -f "electron-vite" >/dev/null 2>&1 && { warn "Electron 已執行"; return; }
	if [[ $DEV_MODE = 1 ]]; then info "啟動 DEV"; (cd "$ROOT_DIR" && pnpm dev >>"$SUPERVISOR_LOG" 2>&1 &); else info "啟動 preview"; (cd "$ROOT_DIR" && pnpm start >>"$SUPERVISOR_LOG" 2>&1 &); fi
	echo $! > "$PID_APP"
}

start_ngrok() {
	[[ $ENABLE_NGROK = 1 ]] || return 0
	pgrep -f "$NGROK_BIN .*http $PORT" >/dev/null 2>&1 && [[ $FORCE_NEW_TUNNEL = 1 ]] && { pkill -f "$NGROK_BIN .*http $PORT" || true; sleep 1; }
	pgrep -f "$NGROK_BIN .*http $PORT" >/dev/null 2>&1 && { warn "ngrok 已存在"; return; }
	info "啟動 ngrok"; "$NGROK_BIN" http --region="$NGROK_REGION" "$PORT" >>"$NGROK_LOG" 2>&1 & echo $! > "$PID_NGROK"
}

get_ngrok_url() { grep -Eo 'https://[-a-zA-Z0-9]+\.ngrok-[a-z]+\.app' "$NGROK_LOG" | tail -n1 | tr -d '\r' || true; }
rotate_ngrok_if_due() { [[ -n "$ROTATE_INTERVAL_MIN" && $ENABLE_NGROK = 1 ]] || return 0; local f="$RUNTIME_DIR/ngrok_started.ts"; local now=$(date +%s); local int=$((ROTATE_INTERVAL_MIN*60)); local st=0; [[ -f $f ]] && st=$(cat $f); (( now-st >= int )) || return 0; info "rotate ngrok"; pkill -f "$NGROK_BIN .*http $PORT" || true; sleep 2; start_ngrok; echo $now > $f; }

update_links() {
	local lip=$(local_ip); local lurl="http://$lip:$PORT"; local purl=$1; local ts=$(date +%s); local commit=$(commit_hash); local host=$(hostname); local label="$NGROK_LABEL"; local pid_web=$(cat "$PID_WEB" 2>/dev/null || echo -)
	if command -v jq >/dev/null 2>&1; then
		jq -n --arg local "$lurl" --arg public "$purl" --arg commit "$commit" --arg host "$host" --arg label "$label" --arg pid_web "$pid_web" --argjson ts $ts '{local:$local,public:$public,updated:$ts,commit:$commit,host:$host,pid_web:$pid_web,label:($label|select(.!=""))}' | atomic_write_json
	else
		printf '{\n"local":"%s","public":"%s","updated":%s,"commit":"%s","host":"%s"}\n' "$lurl" "$purl" "$ts" "$commit" "$host" | atomic_write_json
	fi
	[[ $QUIET = 1 ]] || info "更新 public_links.json (public=${purl:-none})"
}

cleanup() { [[ $QUIET = 1 ]] || info "清理中"; pkill -f "$NGROK_BIN .*http $PORT" 2>/dev/null || true; pkill -f "python.*$APP_SERVER" 2>/dev/null || true; if [[ -f $PID_APP ]]; then kill $(cat $PID_APP 2>/dev/null) 2>/dev/null || true; fi; exit 0; }
trap cleanup INT TERM

bold "== YTMD Public Mode =="
info "PORT=$PORT ENABLE_NGROK=$ENABLE_NGROK DEV_MODE=$DEV_MODE BACKEND_ONLY=$BACKEND_ONLY"
start_web; start_ngrok; start_app

current_public=""
if [[ $ENABLE_NGROK = 1 ]]; then
	# 若只想顯示 public URL 的 QR，則等待；否則若 QR_PUBLIC_ONLY=0 可先顯示本地
	for ((i=1;i<=QR_TIMEOUT_SEC;i++)); do
		rotate_if_big "$NGROK_LOG" "$LOG_MAX_KB"
		u=$(get_ngrok_url)
		if [[ -n $u ]]; then current_public=$u; break; fi
		sleep 1
	done
	if [[ -z $current_public ]]; then
		if [[ $QR_PUBLIC_ONLY = 1 ]]; then
			warn "在 ${QR_TIMEOUT_SEC}s 內未取得 ngrok URL，將不顯示暫時 QR (稍後偵測到會再顯示)"
		else
			info "暫無 ngrok URL，先使用本地網址 QR"
			qr_print "http://$(local_ip):$PORT"
		fi
	fi
fi
update_links "$current_public"
# 僅在得到 public URL 或未要求 public-only 時輸出 QR
if [[ -n $current_public ]]; then
	qr_print "$current_public"
fi

loop=0; backoff=2
while true; do
	sleep 5; loop=$((loop+1))
	rotate_if_big "$WEB_LOG" "$LOG_MAX_KB"; rotate_if_big "$NGROK_LOG" "$LOG_MAX_KB"; rotate_if_big "$SUPERVISOR_LOG" "$LOG_MAX_KB"
	if ! pgrep -f "python.*$APP_SERVER" >/dev/null 2>&1; then warn "後端掛掉 重啟(backoff=${backoff}s)"; sleep $backoff; start_web; backoff=$(( backoff<30 ? backoff*2 : 30 )); else backoff=2; fi
	curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 || { warn "健康失敗 重啟"; pkill -f "python.*$APP_SERVER" || true; start_web; }
	if [[ $ENABLE_NGROK = 1 ]]; then rotate_ngrok_if_due; new=$(get_ngrok_url); if [[ $new != $current_public ]]; then info "新 public URL: $new"; current_public=$new; update_links "$current_public"; qr_print "$current_public"; fi; fi
	(( loop % 12 == 0 )) && update_links "$current_public"
done

