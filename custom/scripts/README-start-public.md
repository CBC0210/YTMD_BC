# start-public.sh 使用說明

啟動完整點歌系統（後端 Flask、前端 Vite/靜態、公開隧道：預設 ngrok；可選 Cloudflare「命名隧道」；公用連結 JSON、終端 QR Code、可選 Electron dev）。

- 腳本：`custom/scripts/start-public.sh`
- 後端：`custom/web-server`
- 前端：`custom/web-server/frontend`
- 公開連結 JSON：`custom/web-server/app/public_links.json`（由後端 `/public-links` 提供）

## 需求
- 必要：bash、curl、lsof
- 建議：
  - python3（啟動後端/靜態前端、產生 QR）
  - node + pnpm（若要啟動 Vite 前端）
  - jq（解析 JSON）
  - ngrok（預設）或 cloudflared（Cloudflare 命名隧道，選用）

## 快速開始
- 預設啟動（後端 + 前端 + ngrok 隧道 + Electron dev）
```bash
bash custom/scripts/start-public.sh
```

- 設定檔（免每次輸入環境變數）
  - 新增一個設定檔，會在啟動時自動載入（以下其一即可）：
    1) 設定環境變數 `START_PUBLIC_CONFIG` 指向你的檔案
    2) 專案根目錄：`.start-public.conf`
    3) 此目錄：`custom/scripts/start-public.conf`
    4) 使用者：`$HOME/.config/ytmd-start-public.conf`
  - 範例：`custom/scripts/start-public.conf.sample`
  - 檔案內容為 `VAR=value` 形式，等同於每次下 `VAR=value bash ...`

- 只用區域網 IP 產生 QR（不使用 ngrok 公開 URL 作為 QR）
```bash
bash custom/scripts/start-public.sh --qr-lan
# 或
QR_PREFER_LAN=1 bash custom/scripts/start-public.sh
```

- 不使用公開隧道（僅本機/區域網）
```bash
ENABLE_NGROK=0 ENABLE_CLOUDFLARE=0 bash custom/scripts/start-public.sh
```

## 旗標（命令列參數）
- `--qr-lan`（同義：`--qr-local`, `--qr-use-lan`）
  - 生成 QR 時強制使用區域網 IP，例如 `http://192.168.x.x:5173`

## 環境變數
（也可放入設定檔，上述搜尋路徑優先順序適用）
- 連線與埠
  - `FRONTEND_PORT`（預設 5173）
  - `WEB_SERVER_PORT` 或 `BACKEND_PORT`（預設 8080）
  - `UPSTREAM_HOST`（預設 localhost）
- ngrok（預設）
  - `ENABLE_NGROK=1|0`（預設 1）
  - `NGROK_BIN`（預設 `ngrok`）、`NGROK_REGION`（預設 `jp`）
  - `NGROK_ALWAYS_NEW=1` 強制重建隧道

- Cloudflare（僅命名隧道；不自動使用 trycloudflare Quick Tunnel）
  - `ENABLE_CLOUDFLARE=1` 與以下其一：
    - `CF_TUNNEL_TOKEN`（推薦）或
    - `CF_TUNNEL_NAME`（事先在 Zero Trust 建立）
  - `ENABLE_NAMED_TUNNEL=1`（若提供 `CF_TUNNEL_TOKEN/NAME` 會自動啟用）
  - `CLOUDFLARED_BIN`（預設 `cloudflared`）
  - `CF_TUNNEL_CONFIG`（選填）用於自動從 ingress 推斷 hostname，否則請提供：
    - `CF_HOSTNAME_FRONTEND`（例如：vite.bc-verse.com）
    - `CF_HOSTNAME_BACKEND`（例如：api.bc-verse.com）
- 前端
  - `FRONTEND_MODE=auto|vite|static`（預設 auto）
  - `FRONTEND_LOG`（預設 `/tmp/ytreq-frontend.log`）
  - `ENABLE_FRONTEND_SUPERVISOR=1|0`（預設 1，自動監控重啟前端）
- 後端
  - `FORCE_BACKEND_RESTART=1|0`（預設 0）
- QR
  - `QR_PREFER_LAN=1|0`（預設 0）同 `--qr-lan`
  - `AUTO_INSTALL_QRCODE=1|0`（預設 1，自動安裝 `qrcode[pil]`）
- 其他
  - `ELECTRON_DEV=1|0`（預設 1，啟動 Electron 開發）

## 輸出與檔案
- `public_links.json`（由後端 `/public-links` 回傳）
  - `frontend.local` / `frontend.public`
  - `backend.local` / `backend.public`
- 終端會顯示 QR Code 與可點擊連結（支援 ANSI 超連結的終端可直接點）
- 前端 log：`/tmp/ytreq-frontend.log`
- 啟動後會定期輸出埠狀態與 public URL 健康檢查摘要

## 常用範例
- 僅區域網（無公開隧道）+ 靜態前端：
```bash
ENABLE_CLOUDFLARE=0 ENABLE_NGROK=0 FRONTEND_MODE=static bash custom/scripts/start-public.sh --qr-lan
```

- 指定不同埠：
```bash
FRONTEND_PORT=8081 WEB_SERVER_PORT=9090 bash custom/scripts/start-public.sh
```

- 關閉 Electron（只跑 API 與前端）：
```bash
ELECTRON_DEV=0 bash custom/scripts/start-public.sh
```

## 常見問題
- 缺少 qrcode：腳本會嘗試自動安裝（`AUTO_INSTALL_QRCODE=1`）；若仍失敗，手動安裝：
```bash
python3 -m pip install qrcode[pil]
```
- Cloudflare/ngrok 未安裝：
  - 預設使用 ngrok；若未安裝，請先安裝並設定 authtoken。
  - ngrok 安裝指南：https://ngrok.com/download
  - 若欲使用 Cloudflare 命名隧道，請安裝 cloudflared 並於 Zero Trust 建立 Tunnel，準備 token 或名稱與 hostname。
  - cloudflared 安裝指南：https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
- 前端顯示 404：
  - 腳本會自動嘗試修復並重啟；如仍異常，檢查 `FRONTEND_LOG` 或到前端目錄手動啟動：
```bash
(cd custom/web-server/frontend && pnpm dev)
```

---

小提示：若要在螢幕/投影上展示 QR，建議加上 `--qr-lan`，手機同網段掃描更穩定；QR 下方會同時印出可點擊的連結，方便快速分享。
