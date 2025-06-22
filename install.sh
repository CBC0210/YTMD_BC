#!/bin/bash
# YTMD CBC Edition 主安裝腳本 - 跨平台入口

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 顯示使用說明
show_usage() {
    echo "使用方式: $0 [選項]"
    echo ""
    echo "選項："
    echo "  install     安裝 YTMD CBC Edition（預設）"
    echo "  update      更新已安裝的系統"
    echo "  uninstall   完全移除 YTMD CBC Edition"
    echo "  status      檢查安裝狀態"
    echo "  help        顯示此說明"
    echo ""
    echo "範例："
    echo "  $0              # 安裝系統"
    echo "  $0 install      # 安裝系統"
    echo "  $0 update       # 更新系統"
    echo "  $0 uninstall    # 移除系統"
    echo "  $0 status       # 檢查狀態"
}

# 檢查安裝狀態
check_status() {
    echo -e "${BLUE}🔍 檢查 YTMD CBC Edition 安裝狀態...${NC}"
    echo ""
    
    local status_ok=true
    
    # 檢查必要檔案
    echo "📁 核心檔案："
    if [ -f "./package.json" ]; then
        echo "  ✅ package.json"
    else
        echo "  ❌ package.json"
        status_ok=false
    fi
    
    if [ -d "./web-server" ]; then
        echo "  ✅ web-server/"
    else
        echo "  ❌ web-server/"
        status_ok=false
    fi
    
    if [ -d "./src/plugins/side-info" ]; then
        echo "  ✅ side-info plugin"
    else
        echo "  ❌ side-info plugin"
        status_ok=false
    fi
    
    # 檢查啟動腳本
    echo ""
    echo "🚀 啟動腳本："
    if [ -d "./launchers/linux" ]; then
        echo "  ✅ Linux 腳本"
    else
        echo "  ❌ Linux 腳本"
        status_ok=false
    fi
    
    if [ -d "./launchers/windows" ]; then
        echo "  ✅ Windows 腳本"
    else
        echo "  ❌ Windows 腳本"
        status_ok=false
    fi
    
    # 檢查 Python 環境
    echo ""
    echo "🐍 Python 環境："
    if [ -d "./web-server/.venv" ]; then
        echo "  ✅ 虛擬環境已建立"
    else
        echo "  ⚠️  虛擬環境未建立"
    fi
    
    # 檢查系統需求
    echo ""
    echo "💻 系統需求："
    if command -v python3 &> /dev/null; then
        echo "  ✅ Python 3: $(python3 --version)"
    else
        echo "  ❌ Python 3 未安裝"
        status_ok=false
    fi
    
    if command -v node &> /dev/null; then
        echo "  ✅ Node.js: $(node --version)"
    else
        echo "  ❌ Node.js 未安裝"
        status_ok=false
    fi
    
    echo ""
    if [ "$status_ok" = true ]; then
        echo -e "${GREEN}🎉 YTMD CBC Edition 安裝完整！${NC}"
        return 0
    else
        echo -e "${RED}❌ 發現問題，建議重新安裝${NC}"
        return 1
    fi
}

# 完全移除系統
uninstall_system() {
    echo -e "${RED}🗑️  YTMD CBC Edition 完全移除程式${NC}"
    echo "=================================================="
    echo ""
    echo -e "${YELLOW}⚠️  此操作將移除：${NC}"
    echo "• Web 點歌系統和虛擬環境"
    echo "• 所有啟動腳本"
    echo "• 自訂設定檔案"
    echo "• Side-info 插件"
    echo ""
    echo -e "${YELLOW}不會移除：${NC}"
    echo "• YTMD 主程式"
    echo "• Node.js 相關檔案"
    echo "• package.json (原專案檔案)"
    echo ""
    
    read -p "確定要繼續嗎？[y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消移除"
        exit 0
    fi
    
    echo ""
    echo -e "${BLUE}🛑 停止所有相關服務...${NC}"
    
    # 停止服務
    if [ -f "./launchers/linux/stop-all.sh" ]; then
        ./launchers/linux/stop-all.sh 2>/dev/null || true
    fi
    
    echo -e "${BLUE}🗑️  移除檔案...${NC}"
    
    # 移除 Web 系統
    if [ -d "./web-server" ]; then
        rm -rf ./web-server
        echo "  ✅ Web 點歌系統已移除"
    fi
    
    # 移除啟動腳本
    if [ -d "./launchers" ]; then
        rm -rf ./launchers
        echo "  ✅ 啟動腳本已移除"
    fi
    
    # 移除 side-info 插件
    if [ -d "./src/plugins/side-info" ]; then
        rm -rf ./src/plugins/side-info
        echo "  ✅ Side-info 插件已移除"
    fi
    
    # 移除設定檔案
    if [ -d "./config" ]; then
        rm -rf ./config
        echo "  ✅ 設定檔案已移除"
    fi
    
    # 移除文檔
    if [ -f "./PACKAGING.md" ]; then
        rm -f ./PACKAGING.md
        echo "  ✅ 打包文檔已移除"
    fi
    
    # 移除腳本目錄
    if [ -d "./scripts" ]; then
        rm -rf ./scripts
        echo "  ✅ 管理腳本已移除"
    fi
    
    # 移除文檔目錄
    if [ -d "./docs" ]; then
        rm -rf ./docs
        echo "  ✅ 額外文檔已移除"
    fi
    
    # 清理臨時檔案
    rm -f ytmd-web-qr.png 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}🎉 移除完成！${NC}"
    echo ""
    echo "現在您的目錄只剩下原始的 YTMD 專案檔案。"
    echo "如需重新安裝，請重新 clone 或下載 YTMD CBC Edition。"
    
    # 刪除自己
    rm -f "$0"
}

# 更新系統
update_system() {
    echo -e "${CYAN}🔄 YTMD CBC Edition 更新程式${NC}"
    echo "=================================================="
    echo ""
    
    # 檢查 Git 狀態
    if [ -d ".git" ]; then
        echo -e "${BLUE}📡 檢查更新...${NC}"
        git fetch origin
        
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
        
        if [ "$LOCAL" = "$REMOTE" ]; then
            echo -e "${GREEN}✅ 已是最新版本${NC}"
        else
            echo -e "${YELLOW}📥 發現新版本，正在更新...${NC}"
            git pull origin $(git branch --show-current)
            echo -e "${GREEN}✅ 代碼更新完成${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  這不是 Git 倉庫，跳過代碼更新${NC}"
    fi
    
    # 更新 Python 依賴
    echo -e "${BLUE}🐍 更新 Python 依賴...${NC}"
    if [ -d "./web-server/.venv" ]; then
        cd web-server
        source .venv/bin/activate
        pip install --upgrade -r requirements.txt
        pip install --upgrade qrcode[pil]
        cd ..
        echo -e "${GREEN}✅ Python 依賴更新完成${NC}"
    else
        echo -e "${YELLOW}⚠️  虛擬環境不存在，執行完整安裝...${NC}"
        install_system
        return
    fi
    
    # 更新 Node.js 依賴
    echo -e "${BLUE}📦 更新 Node.js 依賴...${NC}"
    if [ -f "./package.json" ]; then
        npm install
        echo -e "${GREEN}✅ Node.js 依賴更新完成${NC}"
    fi
    
    # 重新設置權限
    echo -e "${BLUE}🔑 更新腳本權限...${NC}"
    chmod +x launchers/linux/*.sh 2>/dev/null || true
    chmod +x launchers/utils/*.py 2>/dev/null || true
    chmod +x install.sh 2>/dev/null || true
    echo -e "${GREEN}✅ 權限更新完成${NC}"
    
    echo ""
    echo -e "${GREEN}🎉 更新完成！${NC}"
    echo ""
    echo "您可以重新啟動 YTMD CBC Edition 來使用最新功能。"
}

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

# 主安裝功能
install_system() {
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

    # 檢測作業系統
    OS_TYPE=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="linux"  # macOS 使用 Linux 腳本
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS_TYPE="windows"
    else
        echo -e "${YELLOW}⚠️  無法自動檢測作業系統類型${NC}"
        echo "請手動選擇："
        echo "1) Linux/macOS"
        echo "2) Windows"
        read -p "請選擇 (1/2): " choice
        case $choice in
            1) OS_TYPE="linux" ;;
            2) OS_TYPE="windows" ;;
            *) echo -e "${RED}❌ 無效選擇${NC}"; exit 1 ;;
        esac
    fi

    echo -e "${BLUE}🖥️  檢測到作業系統: ${OS_TYPE}${NC}"
    echo ""

    echo -e "${BLUE}📋 安裝內容：${NC}"
    echo "• 🎵 YouTube Music Desktop App"
    echo "• 🌐 Web 點歌系統"
    echo "• 📱 QR Code 生成器"
    echo "• 🔧 自動化啟動腳本"
    echo "• 📝 自訂說明文字功能"
    echo ""

    # 根據作業系統執行對應的安裝流程
    if [ "$OS_TYPE" = "linux" ]; then
        # Linux/macOS 安裝流程
        echo -e "${BLUE}🔍 檢查系統需求...${NC}"
        
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
        
        # 設置腳本權限
        echo -e "${BLUE}📁 設置腳本權限...${NC}"
        chmod +x launchers/linux/*.sh 2>/dev/null || true
        chmod +x launchers/utils/*.py 2>/dev/null || true
        chmod +x install.sh 2>/dev/null || true
        echo -e "${GREEN}✅ 腳本權限設置完成${NC}"
        
        # 執行點歌系統設置
        echo -e "${BLUE}🔧 設置點歌系統...${NC}"
        if [ -f "./launchers/linux/setup-web.sh" ]; then
            ./launchers/linux/setup-web.sh
        else
            echo -e "${RED}❌ 找不到 Linux 設置腳本${NC}"
            exit 1
        fi
        
        echo ""
        echo -e "${GREEN}🎉 安裝完成！${NC}"
        echo "=================================================="
        echo ""
        echo -e "${PURPLE}🎵 使用方式：${NC}"
        echo ""
        echo -e "${YELLOW}▶️  啟動完整功能 (推薦)：${NC}"
        echo "   ./launchers/linux/start-ytmd-with-web.sh"
        echo ""
        echo -e "${YELLOW}▶️  僅啟動 YTMD：${NC}"
        echo "   ./launchers/linux/start-ytmd.sh"
        echo ""
        echo -e "${YELLOW}🛑 停止所有服務：${NC}"
        echo "   ./launchers/linux/stop-all.sh"
        echo ""
        echo -e "${YELLOW}🗑️  卸載點歌系統：${NC}"
        echo "   ./launchers/linux/uninstall.sh"
        
    elif [ "$OS_TYPE" = "windows" ]; then
        # Windows 安裝流程
        echo -e "${YELLOW}Windows 系統檢測到！${NC}"
        echo ""
        echo -e "${BLUE}請執行 Windows 安裝腳本：${NC}"
        echo "  launchers\\windows\\install.bat"
        echo ""
        echo -e "${YELLOW}或者雙擊檔案：${NC}"
        echo "  launchers/windows/install.bat"
        echo ""
        exit 0
    fi

    echo ""
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
    echo -e "${PURPLE}📋 管理指令：${NC}"
    echo "• 更新系統：./install.sh update"
    echo "• 檢查狀態：./install.sh status"
    echo "• 完全移除：./install.sh uninstall"
    echo ""
    echo -e "${BLUE}享受您的音樂時光！🎶${NC}"
}

# 主程式入口
main() {
    case "${1:-install}" in
        "install")
            install_system
            ;;
        "update")
            update_system
            ;;
        "uninstall")
            uninstall_system
            ;;
        "status")
            check_status
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo -e "${RED}❌ 未知選項: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# 執行主程式
main "$@"
