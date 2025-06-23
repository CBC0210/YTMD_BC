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
    
    # 停止 YTMD Desktop App
    if [ -f "/tmp/ytmd-app.pid" ]; then
        YTMD_PID=$(cat /tmp/ytmd-app.pid)
        if kill $YTMD_PID 2>/dev/null; then
            echo -e "${GREEN}✅ YTMD 已停止${NC}"
        fi
        rm -f /tmp/ytmd-app.pid
    else
        # 備用方法：根據進程名停止
        if pkill -f "youtube-music\|electron" 2>/dev/null; then
            echo -e "${GREEN}✅ YTMD 已停止${NC}"
        fi
    fi
    
    # 停止 Web Server
    if [ -f "/tmp/ytmd-web.pid" ]; then
        WEB_PID=$(cat /tmp/ytmd-web.pid)
        if kill $WEB_PID 2>/dev/null; then
            echo -e "${GREEN}✅ Web 服務器已停止${NC}"
        fi
        rm -f /tmp/ytmd-web.pid
    fi
    
    echo -e "${GREEN}🏁 所有服務已停止${NC}"
    exit 0
}

# 註冊信號處理
trap cleanup SIGINT SIGTERM EXIT

echo -e "${BLUE}🎶 正在啟動 YTMD + 點歌系統...${NC}"

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 檢查是否需要重新構建
REBUILD_FLAG=false
if [ "$1" = "--rebuild" ] || [ "$1" = "-r" ]; then
    REBUILD_FLAG=true
    echo -e "${BLUE}🔄 強制重新構建...${NC}"
fi

# 檢查構建完整性
BUILD_COMPLETE=true

# 檢查必要的構建文件
if [ ! -d "dist" ] || \
   [ ! -f "dist/main/index.js" ] || \
   [ ! -f "dist/preload/preload.js" ] || \
   [ ! -f "dist/renderer/youtube-music.iife.js" ] || \
   [ ! -f "dist/renderer/index.html" ]; then
    BUILD_COMPLETE=false
fi

# 如果強制重建或構建不完整，則重新構建
if [ "$REBUILD_FLAG" = true ] || [ "$BUILD_COMPLETE" = false ]; then
    if [ "$BUILD_COMPLETE" = false ]; then
        echo -e "${YELLOW}⚠️ 檢測到構建檔案不完整${NC}"
    fi
    echo -e "${BLUE}🏗️ 構建專案...${NC}"
    if npm run build; then
        echo -e "${GREEN}✅ 專案構建完成${NC}"
    else
        echo -e "${RED}❌ 專案構建失敗${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ 使用現有構建${NC}"
    echo -e "${BLUE}💡 如需重新構建，請使用：${NC}"
    echo -e "${BLUE}   ./launchers/start-ytmd-with-web.sh --rebuild${NC}"
fi

# 檢查 Python 環境
echo -e "${BLUE}🐍 檢查 Python 環境...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 是點歌功能的必要環境${NC}"
    echo "請安裝 Python 3.7+ 後重試"
    exit 1
fi

# 檢查並創建虛擬環境
echo -e "${BLUE}📦 設置 Python 虛擬環境...${NC}"
cd web-server

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
LOCAL_IP=$(python3 ../launchers/utils/ip-detector.py)
WEB_URL="http://${LOCAL_IP}:8080"

echo -e "${GREEN}📱 點歌系統網址：${WEB_URL}${NC}"

# 生成 QR Code
echo -e "${BLUE}📱 生成 QR Code...${NC}"
python3 ../launchers/utils/qr-generator.py "$WEB_URL"

# 啟動 Web Server (背景執行)
echo -e "${BLUE}🚀 啟動 Web 服務器...${NC}"
python3 server.py &
WEB_PID=$!
echo $WEB_PID > /tmp/ytmd-web.pid

# 等待 Web Server 啟動
echo -e "${BLUE}⏳ 等待 Web 服務啟動...${NC}"
sleep 3

# 檢查 Web 服務狀態（只檢查服務器本身，不檢查功能）
WEB_READY=false
for i in {1..10}; do
    if curl -s http://localhost:8080/ >/dev/null 2>&1; then
        WEB_READY=true
        echo -e "${GREEN}✅ Web 服務器啟動成功${NC}"
        break
    fi
    echo "  等待 Web 服務器... (嘗試 $i/10)"
    sleep 1
done

if [ "$WEB_READY" = false ]; then
    echo -e "${RED}❌ Web 服務器啟動失敗${NC}"
    kill $WEB_PID 2>/dev/null
    exit 1
fi

# 回到專案根目錄啟動 YTMD
cd "$PROJECT_ROOT"

# 檢查 Node.js 依賴
if [ ! -d "node_modules" ]; then
    echo -e "${RED}❌ 未找到 node_modules！請先安裝依賴：${NC}"
    echo "  npm install"
    exit 1
fi

# 啟動 YTMD Desktop App (背景執行)
echo -e "${BLUE}🎵 啟動 YTMD Desktop App...${NC}"
npm start &
YTMD_PID=$!
echo $YTMD_PID > /tmp/ytmd-app.pid
echo -e "${GREEN}✅ YTMD 已在背景啟動 (PID: $YTMD_PID)${NC}"

# 等待 YTMD 完全啟動
echo -e "${BLUE}⏳ 等待 YTMD 完全啟動...${NC}"
sleep 8

# 檢查 YTMD API 是否可用
echo -e "${BLUE}🔍 檢查 YTMD API 狀態...${NC}"
YTMD_READY=false
for i in {1..10}; do
    if curl -s http://localhost:26538/api/v1/queue >/dev/null 2>&1; then
        YTMD_READY=true
        echo -e "${GREEN}✅ YTMD API 已就緒${NC}"
        break
    fi
    echo "  等待 YTMD API... (嘗試 $i/10)"
    sleep 2
done

if [ "$YTMD_READY" = false ]; then
    echo -e "${YELLOW}⚠️  YTMD API 尚未就緒，但服務將繼續運行${NC}"
    echo -e "${YELLOW}   等 YTMD 完全啟動後點歌功能才會可用${NC}"
fi

echo ""
echo -e "${GREEN}🎉 所有服務啟動完成！${NC}"
echo ""
echo -e "${YELLOW}📋 使用說明：${NC}"
echo -e "  💻 電腦訪問：http://localhost:8080"
echo -e "  📱 手機掃描：側邊的 QR Code"
echo -e "  🛑 停止服務：按 Ctrl+C"
echo ""
echo -e "${BLUE}⚠️  請使用 Ctrl+C 來正確停止所有服務${NC}"
echo ""

# 等待用戶中斷
wait
