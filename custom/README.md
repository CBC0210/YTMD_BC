# Custom Layer

此目錄包含 fork 專案中不屬於 upstream 的客製化內容。

## 結構
- `web-server/` Python Flask 服務（提供自訂 API / 控制）
- `launchers/` 啟動與整合腳本
- `scripts/` 發佈或其他客製腳本（不與 upstream 重複者）

## 開發啟動建議
使用 `custom/start-dev.sh` 來一次啟動 web server 與 Electron 開發模式。

## Public Mode 啟動 (start-public.sh)
腳本位置: `custom/scripts/start-public.sh`

預設會：
- 檢查/建置 dist (若缺或 FORCE_REBUILD=1)
- 啟動 Flask 後端 (PORT 預設 8080)
- 啟動 Electron 預覽 (非 dev watch)
- 啟動 ngrok 並生成 public URL + QR Code (預設啟用)
- 寫入 `public_links.json` (包含 local/public/commit/time)
- 監控並自動重啟後端 / 更新 ngrok URL

常用環境變數：
- WEB_SERVER_PORT=8080  指定後端埠
- ENABLE_NGROK=0        關閉 ngrok（預設 1）
- ROTATE_INTERVAL_MIN=30 每 30 分鐘輪換隧道
- FORCE_NEW_TUNNEL=1     啟動時先強制新隧道
- YTMD_API=URL           覆寫後端使用的 YTMD 核心 API
- FORCE_REBUILD=1        強制重新 build
- SKIP_BUILD=1           跳過 build 檢查
- DEV_MODE=1             Electron 改用 dev (watch) 模式
- BACKEND_ONLY=1         只啟動後端 (仍可搭配 ngrok)
- PUBLIC_LINKS_PATH=path 自訂 public_links.json 位置
- QR=0                   關閉 QR 輸出 (預設顯示)
- QR_PUBLIC_ONLY=0       若啟用 ngrok 也先顯示本地 QR
- QR_TIMEOUT_SEC=30      等待 public URL 秒數 (Public only 模式)
- QR_PYTHON_ONLY=0       允許使用 qrencode (預設 ngrok=1 -> python)
- LOG_MAX_KB=512         超出大小自動輪替內部日誌
- NGROK_LABEL=label      寫入 public_links.json 內的 label 欄位
- SKIP_INSTALL=1         不自動執行 pnpm install

範例：
```bash
# 標準 (ngrok + QR)
bash custom/scripts/start-public.sh

# 僅後端 + 公網
BACKEND_ONLY=1 bash custom/scripts/start-public.sh

# 強制重建 + 30 分鐘輪換 + 強制新隧道
FORCE_REBUILD=1 ROTATE_INTERVAL_MIN=30 FORCE_NEW_TUNNEL=1 bash custom/scripts/start-public.sh

# 使用 dev 模式 + 不啟用 ngrok + 關閉 QR
DEV_MODE=1 ENABLE_NGROK=0 QR=0 bash custom/scripts/start-public.sh
```

## 更新 upstream 流程（摘要）
1. git fetch upstream
2. 建立備份分支： `git branch backup/pre-upgrade-$(date +%Y%m%d)`
3. 切回主線並重置： `git reset --hard upstream/master`
4. 合併或 cherry-pick 本層抽離 commit

## 覆蓋或 Patch
若需修改 upstream 核心檔案，建議放入 `custom/overlays/`（尚未建立）以利日後套用。

