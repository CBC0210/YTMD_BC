#!/bin/bash
# YTMD + 點歌系統完整啟動腳本

set -e  # 發生錯誤時退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 信號處理函數
cleanup() {
    echo ""
    echo -e "${YELLOW}🛑 正在停止所有服務...${NC}"
    
    # 停止 Web Server
    if [ -f "/tmp/ytmd-web.pid" ]; then
        WEB_PID=$(cat /tmp/ytmd-web.pid)
        if kill $WEB_PID 2>/dev/null; then
            echo -e "${GREEN}✅ Web 服務器已停止${NC}"
        fi
        rm -f /tmp/ytmd-web.pid
    fi
    
    # 停止 YTMD Desktop App
    if pkill -f "youtube-music" 2>/dev/null; then
        echo -e "${GREEN}✅ YTMD 已停止${NC}"
    fi
    
    echo -e "${GREEN}🏁 所有服務已停止${NC}"
    exit 0
}

# 註冊信號處理
trap cleanup SIGINT SIGTERM EXIT

echo -e "${BLUE}🎶 正在啟動 YTMD + 點歌系統...${NC}"

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

# 檢查 Python 環境
echo -e "${BLUE}🐍 檢查 Python 環境...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 是點歌功能的必要環境${NC}"
    echo "請安裝 Python 3.7+ 後重試"
    exit 1
fi

# 檢查並創建虛擬環境
echo -e "${BLUE}📦 設置 Python 虛擬環境...${NC}"
cd "$PROJECT_ROOT/custom/web-server"

if [ ! -d ".venv" ]; then
    echo "建立虛擬環境..."
    python3 -m venv .venv
fi

# 啟動虛擬環境並安裝依賴
source .venv/bin/activate

echo "檢查 Python 套件..."
pip install -q --upgrade pip
pip install -q -r requirements.txt
pip install -q qrcode[pil]  # QR Code 生成器

# 檢測 IP 地址
echo -e "${BLUE}🌐 檢測網路配置...${NC}"
LOCAL_IP=$(python3 "$PROJECT_ROOT/custom/launchers/utils/ip-detector.py")
WEB_URL="http://${LOCAL_IP}:8080"

echo -e "${GREEN}📱 點歌系統網址：${WEB_URL}${NC}"

# 生成 QR Code
echo -e "${BLUE}📱 生成 QR Code...${NC}"
python3 "$PROJECT_ROOT/custom/launchers/utils/qr-generator.py" "$WEB_URL"

# 啟動 Web Server (背景執行)
echo -e "${BLUE}🚀 啟動 Web 服務器...${NC}"
python3 server.py &
WEB_PID=$!
echo $WEB_PID > /tmp/ytmd-web.pid

# 等待 Web Server 啟動
echo -e "${BLUE}⏳ 等待服務啟動...${NC}"
sleep 3

# 檢查服務狀態
if python3 "$PROJECT_ROOT/custom/launchers/utils/web-status.py" web; then
    echo -e "${GREEN}✅ Web 服務器啟動成功${NC}"
else
    echo -e "${RED}❌ Web 服務器啟動失敗${NC}"
    kill $WEB_PID 2>/dev/null
    exit 1
fi

# 檢查 YTMD 可執行檔
echo -e "${BLUE}🎵 檢查 YTMD...${NC}"
cd "$PROJECT_ROOT"

YTMD_EXEC=""
if [ -f "$PROJECT_ROOT/dist/linux-unpacked/youtube-music" ]; then
    YTMD_EXEC="$PROJECT_ROOT/dist/linux-unpacked/youtube-music"
elif [ -f "$PROJECT_ROOT/out/YouTube Music-linux-x64/youtube-music" ]; then
    YTMD_EXEC="$PROJECT_ROOT/out/YouTube Music-linux-x64/youtube-music"
elif command -v youtube-music &> /dev/null; then
    YTMD_EXEC="youtube-music"
else
    echo -e "${RED}❌ 找不到 YTMD 執行檔！${NC}"
    echo "請確認 YTMD 已正確編譯，或執行以下命令："
    echo "  pnpm dist:linux (或 pnpm build 用於開發模式)"
    exit 1
fi

# 啟動 YTMD Desktop App
echo -e "${GREEN}▶️  啟動 YTMD Desktop App...${NC}"
echo ""
echo -e "${YELLOW}📋 使用說明：${NC}"
echo -e "  💻 電腦訪問：http://localhost:8080"
echo -e "  📱 手機掃描：上方 QR Code"
echo -e "  🛑 停止服務：按 Ctrl+C"
echo ""
echo -e "${BLUE}⚠️  請使用 Ctrl+C 來正確停止所有服務${NC}"
echo ""

# 啟動 YTMD (前台執行)
"$YTMD_EXEC"
