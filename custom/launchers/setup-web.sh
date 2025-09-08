#!/bin/bash
# YTMD 點歌系統初次設置腳本

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 YTMD 點歌系統設置程式${NC}"
echo "=========================================="

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 檢查 Python 環境
echo -e "${BLUE}🐍 檢查 Python 環境...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ 未找到 Python 3${NC}"
    echo "請先安裝 Python 3.7+ 後重新執行此腳本"
    echo ""
    echo "Ubuntu/Debian: sudo apt install python3 python3-venv python3-pip"
    echo "CentOS/RHEL:   sudo yum install python3 python3-pip"
    echo "Arch Linux:    sudo pacman -S python python-pip"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | grep -oE '[0-9]+\.[0-9]+')
echo -e "${GREEN}✅ Python 版本：$PYTHON_VERSION${NC}"

# 檢查 Node.js 和 npm (YTMD 需要)
echo -e "${BLUE}📦 檢查 Node.js 環境...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠️  未找到 Node.js${NC}"
    echo "YTMD 需要 Node.js 來編譯，請安裝後重新執行"
    exit 1
fi

NODE_VERSION=$(node --version)
echo -e "${GREEN}✅ Node.js 版本：$NODE_VERSION${NC}"

# 建立 Python 虛擬環境
echo -e "${BLUE}🏗️  建立 Python 虛擬環境...${NC}"
cd web-server

if [ -d ".venv" ]; then
    echo -e "${YELLOW}⚠️  虛擬環境已存在，正在重新建立...${NC}"
    rm -rf .venv
fi

python3 -m venv .venv
echo -e "${GREEN}✅ 虛擬環境建立完成${NC}"

# 啟動虛擬環境並安裝依賴
echo -e "${BLUE}📥 安裝 Python 套件...${NC}"
source .venv/bin/activate

# 升級 pip
pip install --upgrade pip

# 安裝基本依賴
echo "正在安裝 Flask 和相關套件..."
pip install -r requirements.txt

# 安裝額外依賴
echo "正在安裝 QR Code 生成器..."
pip install qrcode[pil]

echo -e "${GREEN}✅ Python 套件安裝完成${NC}"

# 設置腳本執行權限
echo -e "${BLUE}🔑 設置腳本執行權限...${NC}"
cd "$PROJECT_ROOT/launchers"
chmod +x *.sh
chmod +x utils/*.py
echo -e "${GREEN}✅ 執行權限設置完成${NC}"

# 檢查 YTMD 是否已編譯
echo -e "${BLUE}🎵 檢查 YTMD 編譯狀態...${NC}"
cd "$PROJECT_ROOT"

if [ -f "./dist/linux-unpacked/youtube-music" ]; then
    echo -e "${GREEN}✅ YTMD 已編譯完成${NC}"
elif [ -f "./package.json" ]; then
    echo -e "${YELLOW}⚠️  YTMD 尚未編譯${NC}"
    echo "是否要現在編譯 YTMD？(這可能需要幾分鐘) [y/N]"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "正在安裝 Node.js 依賴..."
        npm install
        echo "正在編譯 YTMD..."
        npm run build:linux
        echo -e "${GREEN}✅ YTMD 編譯完成${NC}"
    else
        echo -e "${YELLOW}⚠️  您可以稍後手動編譯：npm run build:linux${NC}"
    fi
else
    echo -e "${RED}❌ 這似乎不是有效的 YTMD 專案目錄${NC}"
fi

# 測試服務
echo -e "${BLUE}🧪 測試服務連接...${NC}"
cd web-server

# 簡單測試 Flask 能否啟動
echo "測試 Flask 服務器..."
source .venv/bin/activate

# 啟動測試
timeout 5 python3 server.py &
TEST_PID=$!
sleep 2

if kill -0 $TEST_PID 2>/dev/null; then
    echo -e "${GREEN}✅ Web 服務器測試通過${NC}"
    kill $TEST_PID 2>/dev/null
    wait $TEST_PID 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  Web 服務器測試未通過，但設置已完成${NC}"
fi

# 完成設置
echo ""
echo -e "${GREEN}🎉 設置完成！${NC}"
echo "=========================================="
echo -e "${BLUE}使用方式：${NC}"
echo ""
echo -e "${YELLOW}基本 YTMD (無點歌功能)：${NC}"
echo "  ./launchers/start-ytmd.sh"
echo ""
echo -e "${YELLOW}完整功能 (YTMD + 點歌系統)：${NC}"
echo "  ./launchers/start-ytmd-with-web.sh"
echo ""
echo -e "${YELLOW}停止所有服務：${NC}"
echo "  ./launchers/stop-all.sh"
echo ""
echo -e "${BLUE}📝 注意事項：${NC}"
echo "• 完整功能需要 YTMD 已啟動並運行"
echo "• 點歌系統會在 http://localhost:8080 啟動"
echo "• 使用 Ctrl+C 來正確停止服務"
echo "• 可編輯 config/instructions.txt 自訂點歌說明"
