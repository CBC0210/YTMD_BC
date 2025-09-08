#!/bin/bash
# 停止所有 YTMD 相關服務

echo "🛑 正在停止所有 YTMD 服務..."

# 停止 Web Server
if [ -f "/tmp/ytmd-web.pid" ]; then
    WEB_PID=$(cat /tmp/ytmd-web.pid)
    if kill $WEB_PID 2>/dev/null; then
        echo "✅ Web 服務器已停止 (PID: $WEB_PID)"
    else
        echo "⚠️  Web 服務器 PID 檔案存在但程序未運行"
    fi
    rm -f /tmp/ytmd-web.pid
else
    echo "ℹ️  未找到 Web 服務器 PID 檔案"
fi

# 停止所有 Python Flask 程序 (備用方法)
FLASK_PIDS=$(pgrep -f "python.*server.py")
if [ ! -z "$FLASK_PIDS" ]; then
    echo "🔍 發現運行中的 Flask 程序：$FLASK_PIDS"
    kill $FLASK_PIDS 2>/dev/null
    echo "✅ Flask 程序已停止"
fi

# 停止 YTMD Desktop App
YTMD_PIDS=$(pgrep -f "youtube-music")
if [ ! -z "$YTMD_PIDS" ]; then
    echo "🔍 發現運行中的 YTMD 程序：$YTMD_PIDS"
    kill $YTMD_PIDS 2>/dev/null
    echo "✅ YTMD 已停止"
else
    echo "ℹ️  未發現運行中的 YTMD 程序"
fi

# 清理臨時檔案
rm -f ytmd-web-qr.png
rm -f /tmp/ytmd-*.pid

echo "🏁 所有服務已停止，臨時檔案已清理"

# 檢查是否還有相關程序運行
sleep 1
if pgrep -f "youtube-music\|server.py" > /dev/null; then
    echo "⚠️  警告：仍有相關程序在運行，您可能需要手動停止"
    echo "運行中的程序："
    pgrep -f "youtube-music\|server.py" | while read pid; do
        echo "  PID $pid: $(ps -p $pid -o comm=)"
    done
else
    echo "✅ 確認所有相關程序已完全停止"
fi
