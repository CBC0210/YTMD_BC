#!/bin/bash
# YTMD CBC Edition 自動打包發布腳本 - GitHub 版本

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 版本資訊
VERSION="${1}"
if [ -z "$VERSION" ]; then
    echo -e "${RED}❌ 請提供版本號${NC}"
    echo "使用方式: $0 <版本號>"
    echo "範例: $0 1.0.0"
    echo "      $0 1.1.0-beta"
    exit 1
fi

# 檢查版本格式
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${YELLOW}⚠️  版本號格式建議: x.y.z 或 x.y.z-suffix${NC}"
    echo "繼續使用: $VERSION"
fi

RELEASE_NAME="ytmd-cbc-v${VERSION}"

echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║               🎶 YTMD CBC Edition 打包工具                    ║"
echo "║                                                                ║"
echo "║                  版本: ${VERSION}                         ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 檢查 Git 狀態和遠端
echo -e "${BLUE}📋 檢查專案狀態...${NC}"

if [ ! -d ".git" ]; then
    echo -e "${RED}❌ 這不是一個 Git 倉庫${NC}"
    echo "請確認在 Git 專案根目錄執行此腳本"
    exit 1
fi

# 檢查是否有遠端倉庫
if ! git remote get-url origin &>/dev/null; then
    echo -e "${RED}❌ 未設置 Git 遠端倉庫${NC}"
    echo "請先設置 GitHub 遠端倉庫："
    echo "  git remote add origin https://github.com/你的用戶名/YTMD_BC.git"
    exit 1
fi

REMOTE_URL=$(git remote get-url origin)
echo -e "${GREEN}✅ Git 遠端倉庫: ${REMOTE_URL}${NC}"

# 檢查當前分支
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${YELLOW}⚠️  當前分支: ${CURRENT_BRANCH}${NC}"
    echo "建議在 main/master 分支進行發布"
    read -p "是否要繼續？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 檢查未提交的更改
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  發現未提交的更改${NC}"
    git status --porcelain
    echo
    echo "建議先提交所有更改再進行發布"
    read -p "是否要繼續？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "請先提交更改：git add . && git commit -m \"準備發布 v${VERSION}\""
        exit 1
    fi
fi

# 檢查標籤是否已存在
if git tag | grep -q "^v${VERSION}$"; then
    echo -e "${RED}❌ 標籤 v${VERSION} 已存在${NC}"
    echo "請使用不同的版本號或刪除現有標籤：git tag -d v${VERSION}"
    exit 1
fi

# 獲取當前提交資訊
CURRENT_COMMIT=$(git rev-parse --short HEAD)
COMMIT_MESSAGE=$(git log -1 --pretty=format:"%s")
echo -e "${GREEN}✅ Git 分支: ${CURRENT_BRANCH} (${CURRENT_COMMIT})${NC}"
echo -e "${GREEN}✅ 最新提交: ${COMMIT_MESSAGE}${NC}"

# 建立發布目錄
RELEASE_DIR="releases/${RELEASE_NAME}"
echo -e "${BLUE}📁 建立發布目錄: ${RELEASE_DIR}${NC}"

rm -rf "releases/${RELEASE_NAME}"
mkdir -p "releases/${RELEASE_NAME}"

# 複製核心檔案
echo -e "${BLUE}📦 複製專案檔案...${NC}"

# YTMD 核心檔案
echo "  • YTMD 核心檔案"
cp package.json "${RELEASE_DIR}/"
cp -r src/ "${RELEASE_DIR}/"
cp -r assets/ "${RELEASE_DIR}/" 2>/dev/null || true
cp electron.vite.config.mts "${RELEASE_DIR}/"
cp tsconfig.json "${RELEASE_DIR}/"
cp .npmrc "${RELEASE_DIR}/" 2>/dev/null || true

# Web 點歌系統
echo "  • Web 點歌系統"
cp -r web-server/ "${RELEASE_DIR}/"

# 設定檔案
echo "  • 設定檔案"
cp -r config/ "${RELEASE_DIR}/"

# 啟動腳本
echo "  • 啟動腳本"
cp -r launchers/ "${RELEASE_DIR}/"

# 文檔
echo "  • 文檔檔案"
cp README.md "${RELEASE_DIR}/"
cp PACKAGING.md "${RELEASE_DIR}/"
cp license "${RELEASE_DIR}/"
cp changelog.md "${RELEASE_DIR}/" 2>/dev/null || true

# 複製安裝腳本
cp install.sh "${RELEASE_DIR}/"

# 建立版本資訊檔案
echo -e "${BLUE}📄 生成版本資訊...${NC}"
cat > "${RELEASE_DIR}/VERSION.txt" << EOF
YTMD CBC Edition
版本: v${VERSION}
打包時間: $(date '+%Y-%m-%d %H:%M:%S')
Git 分支: ${CURRENT_BRANCH}
Git 提交: ${CURRENT_COMMIT}
Git 遠端: ${REMOTE_URL}
EOF

# 建立 Windows 啟動腳本
echo -e "${BLUE}🪟 生成 Windows 腳本...${NC}"
mkdir -p "${RELEASE_DIR}/launchers/windows"

# Windows 主安裝腳本
cat > "${RELEASE_DIR}/launchers/windows/install.bat" << 'EOF'
@echo off
chcp 65001 >nul
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                                                                ║
echo ║               🎶 YTMD CBC Edition 安裝程式                    ║
echo ║                                                                ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

cd /d "%~dp0..\.."

echo 📋 檢查系統需求...

:: 檢查 Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 未找到 Python，請先安裝 Python 3.7+
    echo 下載地址: https://www.python.org/downloads/
    pause
    exit /b 1
)

:: 檢查 Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 未找到 Node.js，請先安裝 Node.js
    echo 下載地址: https://nodejs.org/
    pause
    exit /b 1
)

echo ✅ 系統需求檢查通過

echo.
echo 🔧 設置 Web 點歌系統...

cd web-server

:: 建立虛擬環境
echo 建立 Python 虛擬環境...
python -m venv .venv

:: 啟動虛擬環境並安裝依賴
call .venv\Scripts\activate.bat
echo 安裝 Python 套件...
pip install --upgrade pip
pip install -r requirements.txt
pip install qrcode[pil]

cd ..

echo.
echo ✅ 安裝完成！
echo.
echo 📖 使用方式：
echo   啟動完整功能: launchers\windows\start-ytmd-with-web.bat
echo   僅啟動 YTMD:  launchers\windows\start-ytmd.bat
echo   停止所有服務: launchers\windows\stop-all.bat
echo.
pause
EOF

# Windows 啟動腳本
cat > "${RELEASE_DIR}/launchers/windows/start-ytmd-with-web.bat" << 'EOF'
@echo off
chcp 65001 >nul
echo.
echo 🎶 正在啟動 YTMD + 點歌系統...

cd /d "%~dp0..\.."

:: 啟動 Web 服務器
echo 🚀 啟動 Web 服務器...
cd web-server
call .venv\Scripts\activate.bat
start /b python server.py

:: 等待服務啟動
timeout /t 3 /nobreak >nul

:: 檢查 YTMD 執行檔
cd ..
if exist "dist\win-unpacked\YouTube Music.exe" (
    set "YTMD_EXEC=dist\win-unpacked\YouTube Music.exe"
) else if exist "out\YouTube Music-win32-x64\YouTube Music.exe" (
    set "YTMD_EXEC=out\YouTube Music-win32-x64\YouTube Music.exe"
) else (
    echo ❌ 找不到 YTMD 執行檔！
    echo 請確認 YTMD 已正確編譯
    pause
    exit /b 1
)

echo.
echo ▶️  啟動 YTMD Desktop App...
echo.
echo 📋 使用說明：
echo   💻 電腦訪問：http://localhost:8080
echo   📱 手機訪問：請查看終端顯示的 QR Code
echo   🛑 停止服務：關閉此視窗或執行 stop-all.bat
echo.

"%YTMD_EXEC%"
EOF

# Windows 停止腳本
cat > "${RELEASE_DIR}/launchers/windows/stop-all.bat" << 'EOF'
@echo off
chcp 65001 >nul
echo 🛑 正在停止所有 YTMD 服務...

:: 停止 Python Flask 程序
taskkill /f /im python.exe >nul 2>&1
if %errorlevel% equ 0 echo ✅ Web 服務器已停止

:: 停止 YTMD 程序
taskkill /f /im "YouTube Music.exe" >nul 2>&1
if %errorlevel% equ 0 echo ✅ YTMD 已停止

echo 🏁 所有服務已停止
pause
EOF

# 建立完整的 README 文件
echo -e "${BLUE}📚 生成使用說明...${NC}"
cat > "${RELEASE_DIR}/README-INSTALLATION.md" << EOF
# 🎶 YTMD CBC Edition 安裝與使用指南

## 📋 系統需求

### 必要軟體
- **Python 3.7+**: Web 點歌系統需要
- **Node.js 16+**: YTMD 編譯需要
- **現代瀏覽器**: Chrome, Firefox, Safari, Edge

### 系統支援
- ✅ Linux (Ubuntu, Debian, CentOS, Arch 等)
- ✅ Windows 10/11
- ✅ macOS (理論支援，未完整測試)

## 🚀 快速開始

### Linux 系統

\`\`\`bash
# 1. 執行一鍵安裝
./install.sh

# 2. 啟動完整功能 (推薦)
./launchers/start-ytmd-with-web.sh

# 3. 在瀏覽器開啟 http://localhost:8080
\`\`\`

### Windows 系統

\`\`\`batch
# 1. 執行安裝程式
launchers\\windows\\install.bat

# 2. 啟動完整功能
launchers\\windows\\start-ytmd-with-web.bat

# 3. 在瀏覽器開啟 http://localhost:8080
\`\`\`

## 🔧 詳細安裝步驟

### 手動安裝依賴

**Linux:**
\`\`\`bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-venv python3-pip nodejs npm

# CentOS/RHEL
sudo yum install python3 python3-pip nodejs npm

# Arch Linux
sudo pacman -S python python-pip nodejs npm
\`\`\`

**Windows:**
1. 下載並安裝 [Python](https://www.python.org/downloads/)
2. 下載並安裝 [Node.js](https://nodejs.org/)

### 編譯 YTMD (如果需要)

\`\`\`bash
# 安裝 Node.js 依賴
npm install

# Linux 編譯
npm run build:linux

# Windows 編譯  
npm run build:win

# macOS 編譯
npm run build:mac
\`\`\`

## 📖 使用說明

### 啟動方式

**完整功能** (YTMD + Web 點歌系統):
- Linux: \`./launchers/start-ytmd-with-web.sh\`
- Windows: \`launchers\\windows\\start-ytmd-with-web.bat\`

**僅 YTMD**:
- Linux: \`./launchers/start-ytmd.sh\`
- Windows: \`launchers\\windows\\start-ytmd.bat\`

### 停止服務

- Linux: \`./launchers/stop-all.sh\`
- Windows: \`launchers\\windows\\stop-all.bat\`
- 或直接按 Ctrl+C (Linux) / 關閉視窗 (Windows)

### Web 點歌功能

1. 啟動完整功能後，訪問 http://localhost:8080
2. 使用手機掃描 QR Code 或直接訪問網址
3. 搜尋想聽的歌曲並點擊加入佇列
4. 歌曲會自動添加到 YTMD 播放佇列

### 自訂設定

**點歌說明文字:**
- 編輯 \`config/instructions.txt\`
- 重啟 YTMD 後生效

## 🛠️ 故障排除

### 常見問題

**Q: 無法啟動 Web 服務器**
A: 檢查 Python 環境是否正確安裝，確認 8080 端口未被占用

**Q: 找不到 YTMD 執行檔**
A: 確認 YTMD 已正確編譯，執行 \`npm run build:linux\` 或對應平台的編譯命令

**Q: 點歌無效果**
A: 確認 YTMD 已啟動並登錄 YouTube Music 帳號

**Q: 手機無法訪問**
A: 確認電腦和手機在同一網路，防火牆未阻擋 8080 端口

### 檢查服務狀態

\`\`\`bash
# Linux 檢查進程
ps aux | grep -E "(python.*server|youtube-music)"

# Windows 檢查進程
tasklist | findstr /i "python youtube"

# 檢查端口
netstat -tuln | grep 8080  # Linux
netstat -an | findstr 8080  # Windows
\`\`\`

## 📝 版本資訊

版本: v${VERSION}
打包時間: $(date '+%Y-%m-%d %H:%M:%S')
Git 分支: ${CURRENT_BRANCH}
Git 提交: ${CURRENT_COMMIT}

## 🤝 支援與回饋

如有問題或建議，歡迎聯絡或提交 Issue。

## 📄 授權

本專案基於原 YTMD 專案進行修改，請遵循相關授權條款。
EOF

# 清理不必要的檔案
echo -e "${BLUE}🧹 清理不必要檔案...${NC}"
rm -rf "${RELEASE_DIR}/node_modules" 2>/dev/null || true
rm -rf "${RELEASE_DIR}/.git" 2>/dev/null || true
rm -rf "${RELEASE_DIR}/dist" 2>/dev/null || true
rm -rf "${RELEASE_DIR}/out" 2>/dev/null || true
rm -rf "${RELEASE_DIR}/web-server/.venv" 2>/dev/null || true
rm -f "${RELEASE_DIR}/web-server/*.log" 2>/dev/null || true
rm -f "${RELEASE_DIR}/debug-*.js" 2>/dev/null || true
rm -f "${RELEASE_DIR}/qr-test.html" 2>/dev/null || true

# 建立壓縮檔
echo -e "${BLUE}📦 建立壓縮檔...${NC}"
cd releases

# ZIP 格式 (Windows 友好)
echo "  • 建立 ZIP 檔案..."
zip -r "${RELEASE_NAME}.zip" "${RELEASE_NAME}/" >/dev/null
ZIP_SIZE=$(du -h "${RELEASE_NAME}.zip" | cut -f1)

# TAR.GZ 格式 (Linux 友好)  
echo "  • 建立 TAR.GZ 檔案..."
tar -czf "${RELEASE_NAME}.tar.gz" "${RELEASE_NAME}/"
TGZ_SIZE=$(du -h "${RELEASE_NAME}.tar.gz" | cut -f1)

cd ..

# 生成發布摘要
echo -e "${BLUE}📄 生成發布摘要...${NC}"
cat > "releases/${RELEASE_NAME}-RELEASE-NOTES.md" << EOF
# 🎶 YTMD CBC Edition v${VERSION} 發布說明

## 📦 發布內容

- **發布版本**: v${VERSION}
- **打包時間**: $(date '+%Y-%m-%d %H:%M:%S')
- **Git 分支**: ${CURRENT_BRANCH}
- **Git 提交**: ${CURRENT_COMMIT}
- **ZIP 檔案**: ${RELEASE_NAME}.zip (${ZIP_SIZE})
- **TAR.GZ 檔案**: ${RELEASE_NAME}.tar.gz (${TGZ_SIZE})

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
1. 下載並解壓縮: \`tar -xzf ${RELEASE_NAME}.tar.gz\`
2. 進入目錄: \`cd ${RELEASE_NAME}\`
3. 執行安裝: \`./install.sh\`
4. 啟動服務: \`./launchers/start-ytmd-with-web.sh\`

### Windows 系統
1. 下載並解壓縮: \`${RELEASE_NAME}.zip\`
2. 進入目錄: \`${RELEASE_NAME}\`
3. 執行安裝: \`launchers\\windows\\install.bat\`
4. 啟動服務: \`launchers\\windows\\start-ytmd-with-web.bat\`

## 📋 系統需求

- Python 3.7+
- Node.js 16+
- 現代瀏覽器
- 2GB+ 可用磁碟空間

## 📖 詳細文檔

- 安裝指南: \`README-INSTALLATION.md\`
- 啟動腳本說明: \`launchers/README.md\`
- Web 系統說明: \`web-server/README.md\`
- 打包說明: \`PACKAGING.md\`

## 🔗 相關連結

- GitHub 倉庫: ${REMOTE_URL}
- 原專案: https://github.com/th-ch/youtube-music

---

**享受您的音樂時光！** 🎶
EOF

# 完成打包
echo ""
echo -e "${GREEN}🎉 打包完成！${NC}"
echo "========================================"
echo -e "${CYAN}📦 發布檔案：${NC}"
echo "  • releases/${RELEASE_NAME}.zip (${ZIP_SIZE})"
echo "  • releases/${RELEASE_NAME}.tar.gz (${TGZ_SIZE})"
echo "  • releases/${RELEASE_NAME}/ (資料夾)"
echo ""
echo -e "${CYAN}📄 說明檔案：${NC}"
echo "  • releases/${RELEASE_NAME}-RELEASE-NOTES.md"
echo ""

# 提供 GitHub 發布建議
echo -e "${YELLOW}📋 GitHub 發布流程：${NC}"
echo ""
echo -e "${BLUE}1. 建立並推送版本標籤：${NC}"
echo "   git tag -a v${VERSION} -m \"🎶 YTMD CBC Edition v${VERSION}\""
echo "   git push origin v${VERSION}"
echo ""
echo -e "${BLUE}2. 到 GitHub 建立 Release：${NC}"
echo "   • 訪問: ${REMOTE_URL}/releases/new"
echo "   • 選擇標籤: v${VERSION}"
echo "   • 標題: 🎶 YTMD CBC Edition v${VERSION}"
echo "   • 描述: 複製 releases/${RELEASE_NAME}-RELEASE-NOTES.md 內容"
echo "   • 上傳檔案: ${RELEASE_NAME}.zip 和 ${RELEASE_NAME}.tar.gz"
echo ""
echo -e "${BLUE}3. 發布 Release：${NC}"
echo "   • 點擊 'Publish release'"
echo ""

# 詢問是否自動建立標籤
echo -e "${YELLOW}是否要現在建立並推送版本標籤？${NC}"
read -p "(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🏷️  建立版本標籤...${NC}"
    
    # 建立標籤
    git tag -a "v${VERSION}" -m "🎶 YTMD CBC Edition v${VERSION}

主要功能:
- 🌐 Web 點歌系統
- 🎵 YTMD 整合與增強
- 🔧 跨平台啟動腳本
- 📱 QR Code 快速訪問

發布檔案:
- ${RELEASE_NAME}.zip
- ${RELEASE_NAME}.tar.gz"

    echo -e "${GREEN}✅ 標籤 v${VERSION} 已建立${NC}"
    
    # 推送標籤
    echo -e "${BLUE}📤 推送標籤到 GitHub...${NC}"
    if git push origin "v${VERSION}"; then
        echo -e "${GREEN}✅ 標籤已推送到 GitHub${NC}"
        echo ""
        echo -e "${GREEN}🚀 現在可以到 GitHub 建立 Release：${NC}"
        echo "   ${REMOTE_URL}/releases/new?tag=v${VERSION}"
    else
        echo -e "${RED}❌ 標籤推送失敗${NC}"
        echo "請檢查網路連接和 GitHub 權限"
    fi
else
    echo -e "${BLUE}標籤建立指令：${NC}"
    echo "  git tag -a v${VERSION} -m \"🎶 YTMD CBC Edition v${VERSION}\""
    echo "  git push origin v${VERSION}"
fi

echo ""
echo -e "${GREEN}打包流程完成！🚀${NC}"
