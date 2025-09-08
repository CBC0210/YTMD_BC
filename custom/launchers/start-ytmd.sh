#!/bin/bash
# YTMD 基本啟動腳本 (無點歌功能)

echo "🎵 正在啟動 YTMD..."

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 檢查 Node.js 依賴
if [ ! -d "node_modules" ]; then
    echo "❌ 未找到 node_modules！請先安裝依賴："
    echo "  npm install"
    exit 1
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

if [ "$BUILD_COMPLETE" = false ]; then
    echo "❌ 構建檔案不完整！請先構建專案："
    echo "  npm run build"
    echo ""
    echo "💡 或使用完整啟動腳本（會自動構建）："
    echo "  ./launchers/start-ytmd-with-web.sh"
    exit 1
fi

echo "✅ 檢查通過，使用生產模式啟動"
echo "💡 如需重新構建，請執行：npm run build"
echo "▶️  啟動 YTMD Desktop App..."

# 使用 npm start 啟動 (electron-vite preview - 生產模式)
exec npm start
