@echo off
chcp 65001 >nul

:: 設定工作目錄到專案根目錄
cd /d "%~dp0..\.."

echo 🎵 正在啟動 YTMD Desktop App...

:: 檢查 YTMD 可執行檔
set "YTMD_EXEC="
if exist "dist\win-unpacked\YouTube Music.exe" (
    set "YTMD_EXEC=dist\win-unpacked\YouTube Music.exe"
) else if exist "out\YouTube Music-win32-x64\YouTube Music.exe" (
    set "YTMD_EXEC=out\YouTube Music-win32-x64\YouTube Music.exe"
) else (
    where youtube-music >nul 2>&1
    if %errorlevel% equ 0 (
        set "YTMD_EXEC=youtube-music"
    ) else (
        echo ❌ 找不到 YTMD 執行檔！
        echo.
        echo 請確認 YTMD 已正確編譯，可嘗試以下方法：
        echo.
        echo 1. 編譯 YTMD：
        echo    npm install
        echo    npm run build:win
        echo.
        echo 2. 或使用完整功能腳本：
        echo    launchers\windows\start-ytmd-with-web.bat
        echo.
        pause
        exit /b 1
    )
)

echo ✅ 找到 YTMD：!YTMD_EXEC!
echo.
echo 📋 啟動模式：僅 YTMD ^(無點歌功能^)
echo.
echo 💡 提示：如需點歌功能，請使用：
echo    launchers\windows\start-ytmd-with-web.bat
echo.
echo ▶️  啟動中...

:: 啟動 YTMD
"!YTMD_EXEC!"

echo.
echo 🏁 YTMD 已關閉
pause
