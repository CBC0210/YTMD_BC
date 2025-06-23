@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 設定工作目錄到專案根目錄
cd /d "%~dp0..\.."

:: 信號處理 - Windows 版本相對簡單
:: 設置清理標記
set "cleanup_needed=false"

echo 🎶 正在啟動 YTMD + 點歌系統...

:: 檢查是否在正確目錄
if not exist "web-server\server.py" (
    echo ❌ 錯誤：找不到 web-server\server.py
    echo 請確認在 YTMD_BC 專案根目錄執行此腳本
    pause
    exit /b 1
)

:: 檢查 Python 環境
echo 🐍 檢查 Python 環境...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python 3 是點歌功能的必要環境
    echo 請安裝 Python 3.7+ 後重試
    echo 下載地址：https://www.python.org/downloads/
    pause
    exit /b 1
)

:: 檢查並設置虛擬環境
echo 📦 設置 Python 虛擬環境...
cd web-server

if not exist ".venv" (
    echo 建立虛擬環境...
    python -m venv .venv
    if %errorlevel% neq 0 (
        echo ❌ 虛擬環境建立失敗
        cd ..
        pause
        exit /b 1
    )
)

:: 啟動虛擬環境並安裝依賴
call .venv\Scripts\activate.bat

echo 檢查 Python 套件...
python -m pip install --upgrade pip >nul
pip install -r requirements.txt >nul
pip install qrcode[pil] >nul

:: 檢測 IP 地址
echo 🌐 檢測網路配置...
for /f %%i in ('python ..\launchers\utils\ip-detector.py') do set LOCAL_IP=%%i
set "WEB_URL=http://!LOCAL_IP!:8080"

echo 📱 點歌系統網址：!WEB_URL!

:: 生成 QR Code
echo 📱 生成 QR Code...
python ..\launchers\utils\qr-generator.py "!WEB_URL!" >nul

:: 啟動 Web Server (背景執行)
echo 🚀 啟動 Web 服務器...
start /b python server.py
set "cleanup_needed=true"

:: 等待 Web Server 啟動
echo ⏳ 等待服務啟動...
timeout /t 3 /nobreak >nul

:: 檢查服務狀態
python ..\launchers\utils\web-status.py web >nul
if %errorlevel% equ 0 (
    echo ✅ Web 服務器啟動成功
) else (
    echo ❌ Web 服務器啟動失敗
    goto cleanup
)

:: 檢查 YTMD 可執行檔
echo 🎵 檢查 YTMD...
cd ..

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
        echo 請確認 YTMD 已正確編譯，或執行以下命令：
        echo   npm run build:win
        goto cleanup
    )
)

:: 啟動 YTMD Desktop App
echo ▶️  啟動 YTMD Desktop App...
echo.
echo 📋 使用說明：
echo   💻 電腦訪問：http://localhost:8080
echo   📱 手機掃描：QR Code 已保存為 ytmd-web-qr.png
echo   🛑 停止服務：關閉此視窗或執行 stop-all.bat
echo.
echo ⚠️  請關閉此視窗來正確停止所有服務
echo.

:: 啟動 YTMD (前台執行)
"!YTMD_EXEC!"

:: 當 YTMD 關閉時，清理
goto cleanup

:cleanup
if "%cleanup_needed%"=="true" (
    echo.
    echo 🛑 正在停止所有服務...
    
    :: 停止 Python Flask 程序
    taskkill /f /im python.exe >nul 2>&1
    if %errorlevel% equ 0 echo ✅ Web 服務器已停止
    
    echo 🏁 所有服務已停止
)
pause
exit /b 0
