#!/bin/bash
# YTMD 基本啟動腳本 (無點歌功能)

echo "🎵 正在啟動 YTMD..."

# 設置工作目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 檢查 YTMD 可執行檔
YTMD_EXEC=""

if [ -f "./dist/linux-unpacked/youtube-music" ]; then
    YTMD_EXEC="./dist/linux-unpacked/youtube-music"
elif [ -f "./out/YouTube Music-linux-x64/youtube-music" ]; then
    YTMD_EXEC="./out/YouTube Music-linux-x64/youtube-music"
elif command -v youtube-music &> /dev/null; then
    YTMD_EXEC="youtube-music"
else
    echo "❌ 找不到 YTMD 執行檔！"
    echo "請確認 YTMD 已正確編譯，或執行以下命令："
    echo "  npm run build:linux"
    exit 1
fi

echo "✅ 找到 YTMD：$YTMD_EXEC"
echo "▶️  啟動 YTMD Desktop App..."

# 啟動 YTMD
exec "$YTMD_EXEC"
