@echo off
chcp 65001 >nul

echo 🗑️  YTMD 點歌系統卸載程式
echo ========================================
echo.

echo ⚠️  此操作將移除：
echo • Python 虛擬環境
echo • 已安裝的 Python 套件
echo • 臨時檔案和 QR Code
echo.
echo 不會移除：
echo • YTMD 主程式
echo • Node.js 相關檔案
echo • 自訂設定檔案
echo.

set /p "confirm=確定要繼續嗎？ [y/N]: "
if /i not "%confirm%"=="y" (
    echo 取消卸載
    pause
    exit /b 0
)

echo.
echo 🛑 停止所有相關服務...

:: 停止服務
taskkill /f /im python.exe >nul 2>&1
taskkill /f /im "YouTube Music.exe" >nul 2>&1

echo ✅ 服務已停止

:: 移除 Python 虛擬環境
echo 🗑️  移除 Python 虛擬環境...
if exist "web-server\.venv" (
    rmdir /s /q "web-server\.venv"
    echo ✅ 虛擬環境已移除
) else (
    echo ℹ️  虛擬環境不存在
)

:: 清理臨時檔案
echo 🧹 清理臨時檔案...
if exist "ytmd-web-qr.png" del /q "ytmd-web-qr.png"
if exist "web-server\*.log" del /q "web-server\*.log"
if exist "web-server\*.pid" del /q "web-server\*.pid"

echo ✅ 臨時檔案已清理

echo.
echo 🎉 卸載完成！
echo.
echo 如需重新安裝，請執行：
echo   launchers\windows\install.bat
echo.
echo 或手動設置：
echo   launchers\windows\setup-web.bat
echo.
pause
