# 🚀 GitHub 發布指南

這份指南說明如何將 YTMD CBC Edition 發布到 GitHub。

## 📋 發布前準備

### 1. 確認所有更改已提交
```bash
git status
git add .
git commit -m "準備發布 v1.0.0"
```

### 2. 推送到 GitHub
```bash
git push origin main
```

## 📦 自動化打包與發布

### 使用打包腳本
```bash
# 執行自動打包腳本，指定版本號
./scripts/package-release.sh 1.0.0

# 或者測試版本
./scripts/package-release.sh 1.0.0-beta
```

腳本會自動：
1. ✅ 檢查 Git 狀態和遠端倉庫
2. 📦 建立發布檔案和壓縮包
3. 📄 生成發布說明文件
4. 🏷️ 建立並推送 Git 標籤（可選）
5. 🔗 提供 GitHub Release 連結

### 產生的檔案
```
releases/
├── ytmd-cbc-v1.0.0/           # 發布目錄
├── ytmd-cbc-v1.0.0.zip        # Windows 友好格式
├── ytmd-cbc-v1.0.0.tar.gz     # Linux 友好格式
└── ytmd-cbc-v1.0.0-RELEASE-NOTES.md  # 發布說明
```

## 🌐 GitHub Release 發布

### 1. 前往 GitHub Releases
訪問：`https://github.com/你的用戶名/YTMD_BC/releases/new`

### 2. 設置 Release 資訊
- **Tag**: `v1.0.0` (如果未自動建立標籤)
- **Release title**: `🎶 YTMD CBC Edition v1.0.0`
- **Description**: 複製 `RELEASE-NOTES.md` 的內容

### 3. 上傳檔案
拖拽以下檔案到 GitHub：
- `ytmd-cbc-v1.0.0.zip`
- `ytmd-cbc-v1.0.0.tar.gz`

### 4. 發布設定
- ✅ **Set as the latest release** (如果是穩定版)
- ⚠️ **Set as a pre-release** (如果是測試版)

### 5. 點擊 "Publish release"

## 📝 發布說明模板

```markdown
# 🎶 YTMD CBC Edition v1.0.0

## ✨ 主要功能

### 🌐 Web 點歌系統
- 即時搜尋 YouTube Music 歌曲
- 一鍵加入播放佇列
- 響應式設計，支援手機和桌面
- 自動更新佇列狀態
- QR Code 快速訪問

### 🎵 YTMD 整合
- 完整保留原 YTMD 功能
- 增強的佇列管理
- 當前播放狀態顯示
- 自訂點歌說明文字

### 🔧 便利工具
- 一鍵安裝腳本
- 自動化啟動/停止腳本
- 跨平台支援 (Linux/Windows)
- 完整的錯誤處理和日誌

## 🚀 快速開始

### Linux 系統
1. 下載並解壓縮 `ytmd-cbc-v1.0.0.tar.gz`
2. 執行安裝：`./install.sh`
3. 啟動服務：`./launchers/start-ytmd-with-web.sh`

### Windows 系統
1. 下載並解壓縮 `ytmd-cbc-v1.0.0.zip`
2. 執行安裝：`launchers\windows\install.bat`
3. 啟動服務：`launchers\windows\start-ytmd-with-web.bat`

## 📋 系統需求
- Python 3.7+
- Node.js 16+
- 現代瀏覽器

## 🔗 相關連結
- 🏠 [專案首頁](https://github.com/你的用戶名/YTMD_BC)
- 📖 [詳細文檔](https://github.com/你的用戶名/YTMD_BC/blob/main/README.md)
- 🐛 [問題回報](https://github.com/你的用戶名/YTMD_BC/issues)
- 💬 [討論區](https://github.com/你的用戶名/YTMD_BC/discussions)

---
**享受您的音樂時光！** 🎶
```

## 🔄 版本管理建議

### 版本號格式
- `x.y.z` - 穩定版本
- `x.y.z-beta` - 測試版本
- `x.y.z-alpha` - 開發版本

### 版本升級規則
- **Major (x)**: 重大功能變更或不兼容更新
- **Minor (y)**: 新功能或功能改進
- **Patch (z)**: 錯誤修正或小幅改進

### 範例
- `1.0.0` - 首次穩定發布
- `1.1.0` - 新增功能
- `1.1.1` - 錯誤修正
- `2.0.0` - 重大更新

## 🛠️ 維護與更新

### 定期更新
1. 同步原專案更新
2. 測試功能相容性
3. 更新文檔和說明
4. 發布新版本

### 社群互動
- 及時回應 Issues
- 接受 Pull Requests
- 維護 Discussions
- 更新 README 和文檔

---

**持續改進，分享創意！** 🚀
