# 📦 YTMD_BC 專案打包與發布指南

這份指南說明如何將你對 YTMD 專案的修改打包並發布。

## 🎯 目前的專案狀態

你目前的專案結構：
```
YTMD_BC/ (你的 fork)
├── 原始 YTMD 專案檔案...
├── web-server/ (你新增的功能)
│   ├── server.py
│   ├── templates/
│   ├── static/
│   ├── requirements.txt
│   └── README.md
├── src/plugins/side-info/ (你新增的插件)
└── 其他修改的檔案...
```

## 🔄 Git 分支管理策略

### 建議的分支結構
```bash
# 主分支 - 穩定版本
master (或 main)

# 功能分支
├── feature/web-server     # 網頁點歌系統
├── feature/side-info      # 側邊資訊插件
└── develop               # 開發分支
```

## 📋 打包步驟

### 1. 整理並提交你的修改

```bash
cd /home/cbc/Documents/Projects/YTMD/YTMD_BC

# 檢查目前狀態
git status

# 建立功能分支 (建議)
git checkout -b feature/web-server-system

# 新增所有 web-server 相關檔案
git add web-server/

# 新增其他修改的檔案
git add src/plugins/side-info/
git add debug-sideinfo.js
git add qr-test.html

# 檢查修改的檔案
git add package.json pnpm-lock.yaml

# 提交修改
git commit -m "✨ Add web-server music request system

- 🎵 Real-time queue display with auto-refresh
- 🔍 YouTube Music search integration  
- ➕ One-click song request functionality
- 🎨 YouTube-style dark theme interface
- 📱 Responsive design for mobile and desktop
- 🛠️ Complete setup documentation

Features:
- Flask web server with REST API
- ytmusicapi integration for search
- YTMD API integration for queue management
- Auto-updating queue every 4 seconds
- Comprehensive error handling
- Detailed usage documentation"
```

### 2. 建立發布版本

```bash
# 切換到主分支
git checkout master

# 合併功能分支
git merge feature/web-server-system

# 建立版本標籤
git tag -a v1.0.0-cbc -m "🎶 YTMD CBC Edition v1.0.0

Major Features:
- Web-based music request system
- Real-time queue management  
- YouTube Music search integration
- Mobile-friendly interface

Added Components:
- web-server/ - Complete Flask application
- Enhanced YTMD integration
- Comprehensive documentation"

# 推送到你的 GitHub
git push origin master
git push origin --tags
```

### 3. 建立 Release 包

有幾種方式可以分發你的修改：

#### 方法 A: GitHub Release (推薦)
1. 到你的 GitHub 倉庫: `https://github.com/CBC0210/YTMD_BC`
2. 點擊 "Releases" → "Create a new release"
3. 選擇標籤: `v1.0.0-cbc`
4. 填寫發布說明：

```markdown
# 🎶 YTMD CBC Edition v1.0.0

## ✨ 新功能
- **🌐 網頁點歌系統**: 完整的 Flask 網頁應用
- **🎵 即時佇列顯示**: 自動更新播放佇列 
- **🔍 智慧搜尋**: 整合 YouTube Music API
- **📱 響應式設計**: 支援手機和桌面
- **🎨 YouTube 風格**: 深色主題界面

## 📦 安裝方式
1. Clone 或下載此專案
2. 進入 `web-server/` 目錄
3. 安裝 Python 依賴: `pip install -r requirements.txt`
4. 啟動服務: `python server.py`
5. 開啟瀏覽器: `http://localhost:8080`

## 📚 完整文檔
詳見 `web-server/README.md`

## 🔧 系統需求
- YouTube Music Desktop App (YTMD)
- Python 3.7+
- 現代網頁瀏覽器
```

#### 方法 B: 建立安裝包
```bash
# 建立發布目錄
mkdir -p releases/ytmd-cbc-v1.0.0

# 複製必要檔案 (選擇性打包)
cp -r web-server/ releases/ytmd-cbc-v1.0.0/
cp -r src/ releases/ytmd-cbc-v1.0.0/
cp package.json releases/ytmd-cbc-v1.0.0/
cp README.md releases/ytmd-cbc-v1.0.0/

# 建立安裝腳本
cat > releases/ytmd-cbc-v1.0.0/install.sh << 'EOF'
#!/bin/bash
echo "🎶 Installing YTMD CBC Edition..."

# 安裝 Node.js 依賴
echo "📦 Installing Node.js dependencies..."
npm install

# 設置 Python 環境
echo "🐍 Setting up Python environment..."
cd web-server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

echo "✅ Installation complete!"
echo "📖 Read web-server/README.md for usage instructions"
EOF

chmod +x releases/ytmd-cbc-v1.0.0/install.sh

# 建立壓縮包
tar -czf releases/ytmd-cbc-v1.0.0.tar.gz -C releases ytmd-cbc-v1.0.0
zip -r releases/ytmd-cbc-v1.0.0.zip releases/ytmd-cbc-v1.0.0/
```

## 🚀 發布選項

### 選項 1: 獨立發布 (推薦新手)
- 在你的 GitHub 建立獨立的 Repository
- 完全掌控版本和發布節奏
- 適合大幅修改或新功能

### 選項 2: 貢獻回原專案
```bash
# 建立 Pull Request 到原專案
git remote add upstream https://github.com/th-ch/youtube-music.git
git fetch upstream
git checkout -b feature/web-server-contribution
# 整理 commits 並建立 PR
```

### 選項 3: Fork 持續開發
- 保持與原專案同步
- 定期 merge upstream 更新
- 適合長期維護分支

## 📄 建議的檔案結構

如果要建立完整安裝包，建議包含：

```
ytmd-cbc-edition/
├── README.md                 # 主要說明文件
├── CHANGELOG.md             # 更新日誌
├── LICENSE                  # 授權條款  
├── install.sh              # Linux/Mac 安裝腳本
├── install.bat             # Windows 安裝腳本
├── web-server/             # 你的網頁系統
│   ├── README.md           # 詳細使用說明
│   ├── requirements.txt    # Python 依賴
│   ├── server.py          # Flask 應用
│   ├── templates/         # HTML 模板
│   └── static/            # 靜態檔案
├── src/                   # YTMD 主程式修改
└── docs/                  # 額外文檔
    ├── setup-guide.md     # 設置指南
    ├── troubleshooting.md # 故障排除
    └── api-reference.md   # API 參考
```

## 🔄 維護更新流程

```bash
# 定期同步原專案更新
git fetch upstream
git checkout master
git merge upstream/master

# 解決衝突 (如果有)
# 測試功能正常
# 更新版本號並發布
```

## 📝 版本命名建議

- `v1.0.0-cbc` - 主要版本
- `v1.1.0-cbc` - 新功能更新  
- `v1.0.1-cbc` - 錯誤修正
- `v1.0.0-beta-cbc` - 測試版本

---

**選擇最適合你的發布方式，開始分享你的創作！** 🚀
