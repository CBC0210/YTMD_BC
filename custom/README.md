# Custom Layer

此目錄包含 fork 專案中不屬於 upstream 的客製化內容。

## 結構
- `web-server/` Python Flask 服務（提供自訂 API / 控制）
- `launchers/` 啟動與整合腳本
- `scripts/` 發佈或其他客製腳本（不與 upstream 重複者）

## 開發啟動建議
使用 `custom/start-dev.sh` 來一次啟動 web server 與 Electron 開發模式。

## 更新 upstream 流程（摘要）
1. git fetch upstream
2. 建立備份分支： `git branch backup/pre-upgrade-$(date +%Y%m%d)`
3. 切回主線並重置： `git reset --hard upstream/master`
4. 合併或 cherry-pick 本層抽離 commit

## 覆蓋或 Patch
若需修改 upstream 核心檔案，建議放入 `custom/overlays/`（尚未建立）以利日後套用。

