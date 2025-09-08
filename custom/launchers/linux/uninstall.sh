#!/bin/bash
# YTMD 點歌系統卸載腳本

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🗑️  YTMD 點歌系統卸載程式${NC}"
echo "=========================================="

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 確認卸載
echo -e "${YELLOW}這將移除點歌系統的所有設置，但保留 YTMD 主程式${NC}"
echo -e "${YELLOW}確定要繼續嗎？[y/N]${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "取消卸載"
    exit 0
fi

echo -e "${BLUE}🛑 停止所有服務...${NC}"
cd "$PROJECT_ROOT"

# 停止所有服務
"$PROJECT_ROOT/launchers/linux/stop-all.sh"

echo -e "${BLUE}🧹 清理設置...${NC}"

# 移除 Python 虛擬環境
if [ -d "$PROJECT_ROOT/web-server/.venv" ]; then
    echo "移除 Python 虛擬環境..."
    rm -rf "$PROJECT_ROOT/web-server/.venv"
    echo -e "${GREEN}✅ 虛擬環境已移除${NC}"
fi

# 清理臨時檔案
echo "清理臨時檔案..."
rm -f /tmp/ytmd-web.pid
rm -f /tmp/ytmd-*.pid
rm -f ytmd-web-qr.png
rm -f web-server/ytmd-web-qr.png

# 移除日誌檔案 (如果有)
rm -f web-server/*.log
rm -f launchers/*.log

echo -e "${GREEN}✅ 臨時檔案已清理${NC}"

# 詢問是否移除自訂配置
echo ""
echo -e "${YELLOW}是否移除自訂配置檔案？${NC}"
echo "這將刪除："
echo "  • config/instructions.txt (自訂點歌說明)"
echo "  • config/web-config.json (網頁設置)"
echo "  • config/README-instructions.md (說明文檔)"
echo ""
echo -e "${YELLOW}移除配置檔案？[y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    if [ -f "$PROJECT_ROOT/config/instructions.txt" ]; then
        rm -f "$PROJECT_ROOT/config/instructions.txt"
        echo "✅ 自訂點歌說明已移除"
    fi
    
    if [ -f "$PROJECT_ROOT/config/web-config.json" ]; then
        rm -f "$PROJECT_ROOT/config/web-config.json"
        echo "✅ 網頁設置已移除"
    fi
    
    if [ -f "$PROJECT_ROOT/config/README-instructions.md" ]; then
        rm -f "$PROJECT_ROOT/config/README-instructions.md"
        echo "✅ 說明文檔已移除"
    fi
    
    # 如果 config 目錄為空，也移除它
    if [ -d "$PROJECT_ROOT/config" ] && [ -z "$(ls -A "$PROJECT_ROOT/config")" ]; then
        rmdir "$PROJECT_ROOT/config"
        echo "✅ 空的 config 目錄已移除"
    fi
else
    echo "ℹ️  保留配置檔案"
fi

# 詢問是否移除整個啟動器目錄
echo ""
echo -e "${YELLOW}是否移除整個啟動器目錄？${NC}"
echo "這將刪除所有啟動腳本和工具"
echo ""
echo -e "${YELLOW}移除啟動器目錄？[y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -rf "$PROJECT_ROOT/launchers"
    echo -e "${GREEN}✅ 啟動器目錄已移除${NC}"
else
    echo "ℹ️  保留啟動器目錄"
fi

echo ""
echo -e "${GREEN}🎉 卸載完成！${NC}"
echo "=========================================="
echo -e "${BLUE}已保留：${NC}"
echo "• YTMD 主程式和所有原始功能"
echo "• web-server/ 目錄 (點歌系統原始碼)"
echo "• package.json 和其他 YTMD 檔案"
echo ""
echo -e "${BLUE}如需完全移除點歌系統：${NC}"
echo "• 手動刪除 web-server/ 目錄"
echo "• 從 package.json 中移除相關依賴"
echo "• 移除 src/plugins/side-info/ 插件"
