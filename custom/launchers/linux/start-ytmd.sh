#!/bin/bash
# YTMD 基本啟動腳本 (無點歌功能)

echo "🎵 正在啟動 YTMD..."

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

# 檢查 YTMD 可執行檔
YTMD_EXEC=""

if command -v node >/dev/null 2>&1; then
    NODE_MAJOR=$(node -v | sed -E 's/v([0-9]+).*/\1/')
    if [ "$NODE_MAJOR" -lt 22 ]; then
        echo "❌ Node.js 版本過低 $(node -v) (需要 >=22)"; exit 1; fi
else
    echo "❌ 未找到 Node.js"; exit 1; fi

if [ -f "$PROJECT_ROOT/dist/linux-unpacked/youtube-music" ]; then
    YTMD_EXEC="$PROJECT_ROOT/dist/linux-unpacked/youtube-music"
elif [ -f "$PROJECT_ROOT/out/YouTube Music-linux-x64/youtube-music" ]; then
    YTMD_EXEC="$PROJECT_ROOT/out/YouTube Music-linux-x64/youtube-music"
elif command -v youtube-music &> /dev/null; then
    YTMD_EXEC="youtube-music"
else
    echo "❌ 找不到 YTMD 執行檔！"
    echo "請執行：pnpm build  (開發) 或 pnpm dist:linux (打包)"
    exit 1
fi

echo "✅ 找到 YTMD：$YTMD_EXEC"
echo "▶️  啟動 YTMD Desktop App..."

# 啟動 YTMD
exec "$YTMD_EXEC"
