#!/bin/bash
# YTMD CBC Edition 主安裝腳本

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 顯示標題
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║           🎶 YTMD CBC Edition 安裝程式            ║"
echo "║                                                  ║"
echo "║     YouTube Music Desktop + Web Request System   ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# 檢查是否在正確的目錄
if [ ! -f "./package.json" ] || [ ! -d "./web-server" ]; then
    echo -e "${RED}❌ 錯誤：請在 YTMD_BC 專案根目錄執行此腳本${NC}"
    exit 1
fi

echo -e "${BLUE}📋 安裝內容：${NC}"
echo "• 🎵 YouTube Music Desktop App"
echo "• 🌐 Web 點歌系統"
echo "• 📱 QR Code 生成器"
echo "• 🔧 自動化啟動腳本"
echo "• 📝 自訂說明文字功能"
echo ""

# 系統需求檢查
echo -e "${BLUE}🔍 檢查系統需求...${NC}"

# 檢查作業系統
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${YELLOW}⚠️  此腳本主要為 Linux 設計，其他系統可能需要手動調整${NC}"
fi

# 檢查必要程式
MISSING_DEPS=()

if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
fi

if ! command -v node &> /dev/null; then
    MISSING_DEPS+=("nodejs")
fi

if ! command -v npm &> /dev/null; then
    MISSING_DEPS+=("npm")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}❌ 缺少必要程式：${MISSING_DEPS[*]}${NC}"
    echo ""
    echo "請先安裝缺少的程式："
    echo ""
    echo -e "${YELLOW}Ubuntu/Debian:${NC}"
    echo "  sudo apt update"
    echo "  sudo apt install python3 python3-venv python3-pip nodejs npm"
    echo ""
    echo -e "${YELLOW}CentOS/RHEL:${NC}"
    echo "  sudo yum install python3 python3-pip nodejs npm"
    echo ""
    echo -e "${YELLOW}Arch Linux:${NC}"
    echo "  sudo pacman -S python python-pip nodejs npm"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ 系統需求檢查通過${NC}"

# 開始安裝
echo ""
echo -e "${BLUE}🚀 開始安裝...${NC}"
echo ""

# 1. 設置腳本權限（Linux 專用）
echo -e "${BLUE}📁 設置腳本權限...${NC}"
chmod +x launchers/*.sh 2>/dev/null || true
chmod +x launchers/utils/*.py 2>/dev/null || true
chmod +x install.sh 2>/dev/null || true

# Windows 腳本不需要設置執行權限，但提供使用說明
if [ -d "launchers/windows" ]; then
    echo -e "${GREEN}✅ 跨平台腳本已就緒${NC}"
    echo "  • Linux 腳本: launchers/*.sh"
    echo "  • Windows 腳本: launchers/windows/*.bat"
else
    echo -e "${GREEN}✅ Linux 腳本權限設置完成${NC}"
fi

# 2. 執行點歌系統設置
echo -e "${BLUE}🔧 設置點歌系統...${NC}"
./launchers/setup-web.sh

echo ""
echo -e "${GREEN}🎉 安裝完成！${NC}"
echo "=================================================="
echo ""
echo -e "${PURPLE}🎵 使用方式：${NC}"
echo ""
echo -e "${YELLOW}▶️  啟動完整功能 (推薦)：${NC}"
echo "   ./launchers/start-ytmd-with-web.sh"
echo ""
echo -e "${YELLOW}▶️  僅啟動 YTMD：${NC}"
echo "   ./launchers/start-ytmd.sh"
echo ""
echo -e "${YELLOW}🛑 停止所有服務：${NC}"
echo "   ./launchers/stop-all.sh"
echo ""
echo -e "${YELLOW}🗑️  卸載點歌系統：${NC}"
echo "   ./launchers/uninstall.sh"
echo ""

# 如果在 Windows 環境（WSL 或類似），提供 Windows 腳本說明
if [ -d "launchers/windows" ]; then
    echo -e "${PURPLE}🪟 Windows 系統使用：${NC}"
    echo "   launchers\\windows\\start-ytmd-with-web.bat"
    echo "   launchers\\windows\\stop-all.bat"
    echo ""
fi

echo -e "${PURPLE}🌐 點歌系統功能：${NC}"
echo "• 網址：http://localhost:8080"
echo "• 手機掃描 QR Code 點歌"
echo "• 即時佇列顯示"
echo "• 當前播放狀態指示"
echo "• 自訂點歌說明文字"
echo ""
echo -e "${PURPLE}📝 自訂設定：${NC}"
echo "• 編輯 config/instructions.txt 來自訂點歌說明"
echo "• 重啟 YTMD 後生效"
echo ""
echo -e "${BLUE}享受您的音樂時光！🎶${NC}"
echo ""

# 檢查是否在正確的目錄
if [ ! -f "./package.json" ] || [ ! -d "./web-server" ]; then
    echo -e "${RED}❌ 錯誤：請在 YTMD_BC 專案根目錄執行此腳本${NC}"
    exit 1
fi

echo -e "${BLUE}📋 安裝內容：${NC}"
echo "• 🎵 YouTube Music Desktop App"
echo "• 🌐 Web 點歌系統"
echo "• 📱 QR Code 生成器"
echo "• 🔧 自動化啟動腳本"
echo "• 📝 自訂說明文字功能"
echo ""

# 系統需求檢查
echo -e "${BLUE}🔍 檢查系統需求...${NC}"

# 檢查作業系統
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${YELLOW}⚠️  此腳本主要為 Linux 設計，其他系統可能需要手動調整${NC}"
fi

# 檢查必要程式
MISSING_DEPS=()

if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
fi

if ! command -v node &> /dev/null; then
    MISSING_DEPS+=("nodejs")
fi

if ! command -v npm &> /dev/null; then
    MISSING_DEPS+=("npm")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}❌ 缺少必要程式：${MISSING_DEPS[*]}${NC}"
    echo ""
    echo "請先安裝缺少的程式："
    echo ""
    echo -e "${YELLOW}Ubuntu/Debian:${NC}"
    echo "  sudo apt update"
    echo "  sudo apt install python3 python3-venv python3-pip nodejs npm"
    echo ""
    echo -e "${YELLOW}CentOS/RHEL:${NC}"
    echo "  sudo yum install python3 python3-pip nodejs npm"
    echo ""
    echo -e "${YELLOW}Arch Linux:${NC}"
    echo "  sudo pacman -S python python-pip nodejs npm"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ 系統需求檢查通過${NC}"

# 開始安裝
echo ""
echo -e "${BLUE}🚀 開始安裝...${NC}"
echo ""

# 1. 設置腳本權限
echo -e "${BLUE}📁 設置腳本權限...${NC}"
chmod +x launchers/*.sh
chmod +x launchers/utils/*.py
chmod +x install.sh
echo -e "${GREEN}✅ 權限設置完成${NC}"

# 2. 執行點歌系統設置
echo -e "${BLUE}🔧 設置點歌系統...${NC}"
./launchers/setup-web.sh

echo ""
echo -e "${GREEN}🎉 安裝完成！${NC}"
echo "=================================================="
echo ""
echo -e "${PURPLE}🎵 使用方式：${NC}"
echo ""
echo -e "${YELLOW}▶️  啟動完整功能 (推薦)：${NC}"
echo "   ./launchers/start-ytmd-with-web.sh"
echo ""
echo -e "${YELLOW}▶️  僅啟動 YTMD：${NC}"
echo "   ./launchers/start-ytmd.sh"
echo ""
echo -e "${YELLOW}🛑 停止所有服務：${NC}"
echo "   ./launchers/stop-all.sh"
echo ""
echo -e "${YELLOW}🗑️  卸載點歌系統：${NC}"
echo "   ./launchers/uninstall.sh"
echo ""

# 如果在 Windows 環境（WSL 或類似），提供 Windows 腳本說明
if [ -d "launchers/windows" ]; then
    echo -e "${PURPLE}🪟 Windows 系統使用：${NC}"
    echo "   launchers\\windows\\start-ytmd-with-web.bat"
    echo "   launchers\\windows\\stop-all.bat"
    echo ""
fi
echo -e "${PURPLE}🌐 點歌系統功能：${NC}"
echo "• 網址：http://localhost:8080"
echo "• 手機掃描 QR Code 點歌"
echo "• 即時佇列顯示"
echo "• 當前播放狀態指示"
echo "• 自訂點歌說明文字"
echo ""
echo -e "${PURPLE}📝 自訂設定：${NC}"
echo "• 編輯 config/instructions.txt 來自訂點歌說明"
echo "• 重啟 YTMD 後生效"
echo ""
echo -e "${BLUE}享受您的音樂時光！🎶${NC}"
