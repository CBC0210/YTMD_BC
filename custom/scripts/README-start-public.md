# start-public.sh 使用說明

啟動完整點歌系統（後端 Flask、前端 Vite/靜態、選用 ngrok、公用連結 JSON、終端 QR Code、可選 Electron dev）。

- 腳本：`custom/scripts/start-public.sh`
- 後端：`custom/web-server`
- 前端：`custom/web-server/frontend`
- 公開連結 JSON：`custom/web-server/app/public_links.json`（由後端 `/public-links` 提供）

## 需求
- 必要：bash、curl、lsof
- 建議：
  - python3（啟動後端/靜態前端、產生 QR）
  - node + pnpm（若要啟動 Vite 前端）
  - jq（解析 ngrok API）
  - ngrok（若要公開 URL）

## 快速開始
- 預設啟動（後端 + 前端 + ngrok + Electron dev）
```bash
bash custom/scripts/start-public.sh
```

- 只用區域網 IP 產生 QR（不使用 ngrok 公開 URL 作為 QR）
```bash
bash custom/scripts/start-public.sh --qr-lan
# 或
QR_PREFER_LAN=1 bash custom/scripts/start-public.sh
```

- 不使用 ngrok（僅本機/區域網）
```bash
ENABLE_NGROK=0 bash custom/scripts/start-public.sh
```

## 旗標（命令列參數）
- `--qr-lan`（同義：`--qr-local`, `--qr-use-lan`）
  - 生成 QR 時強制使用區域網 IP，例如 `http://192.168.x.x:5173`

## 環境變數
- 連線與埠
  - `FRONTEND_PORT`（預設 5173）
  - `WEB_SERVER_PORT` 或 `BACKEND_PORT`（預設 8080）
  - `UPSTREAM_HOST`（預設 localhost）
- ngrok
  - `ENABLE_NGROK=1|0`（預設 1）
  - `NGROK_BIN`（預設 `ngrok`）、`NGROK_REGION`（預設 `jp`）
  - `NGROK_ALWAYS_NEW=1` 強制重建隧道
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
- 僅區域網（無 ngrok）+ 靜態前端：
```bash
ENABLE_NGROK=0 FRONTEND_MODE=static bash custom/scripts/start-public.sh --qr-lan
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
- ngrok 未安裝或無 authtoken：
  - 設 `ENABLE_NGROK=0` 改走區域網，或先安裝/設定 ngrok。
- 前端顯示 404：
  - 腳本會自動嘗試修復並重啟；如仍異常，檢查 `FRONTEND_LOG` 或到前端目錄手動啟動：
```bash
(cd custom/web-server/frontend && pnpm dev)
```

---

小提示：若要在螢幕/投影上展示 QR，建議加上 `--qr-lan`，手機同網段掃描更穩定；QR 下方會同時印出可點擊的連結，方便快速分享。
