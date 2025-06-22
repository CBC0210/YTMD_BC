@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                                                                ║
echo ║               🎶 YTMD CBC Edition 安裝程式                    ║
echo ║                                                                ║
echo ║     YouTube Music Desktop + Web Request System               ║
echo ║                                                                ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

:: 檢查是否在正確的目錄
if not exist "package.json" (
    echo ❌ 錯誤：請在 YTMD_BC 專案根目錄執行此腳本
    pause
    exit /b 1
)

if not exist "web-server" (
    echo ❌ 錯誤：請在 YTMD_BC 專案根目錄執行此腳本
    pause
    exit /b 1
)

echo 📋 安裝內容：
echo • 🎵 YouTube Music Desktop App
echo • 🌐 Web 點歌系統
echo • 📱 QR Code 生成器
echo • 🔧 自動化啟動腳本
echo • 📝 自訂說明文字功能
echo.

:: 系統需求檢查
echo 🔍 檢查系統需求...

:: 檢查 Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 缺少必要程式：Python
    echo.
    echo 請先安裝 Python 3.7+：
    echo   下載地址：https://www.python.org/downloads/
    echo   安裝時請勾選 "Add Python to PATH"
    echo.
    pause
    exit /b 1
)

:: 檢查 Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 缺少必要程式：Node.js
    echo.
    echo 請先安裝 Node.js 16+：
    echo   下載地址：https://nodejs.org/
    echo.
    pause
    exit /b 1
)

:: 檢查 npm
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 缺少必要程式：npm
    echo npm 應該隨 Node.js 一起安裝
    pause
    exit /b 1
)

echo ✅ 系統需求檢查通過

:: 開始安裝
echo.
echo 🚀 開始安裝...
echo.

:: 1. 執行點歌系統設置
echo 🔧 設置點歌系統...
call launchers\windows\setup-web.bat
if %errorlevel% neq 0 (
    echo ❌ 點歌系統設置失敗
    pause
    exit /b 1
)

echo.
echo 🎉 安裝完成！
echo ==================================================
echo.
echo 🎵 使用方式：
echo.
echo ▶️  啟動完整功能 ^(推薦^)：
echo    launchers\windows\start-ytmd-with-web.bat
echo.
echo ▶️  僅啟動 YTMD：
echo    launchers\windows\start-ytmd.bat
echo.
echo 🛑 停止所有服務：
echo    launchers\windows\stop-all.bat
echo.
echo 🗑️  卸載點歌系統：
echo    launchers\windows\uninstall.bat
echo.
echo 🌐 點歌系統功能：
echo • 網址：http://localhost:8080
echo • 手機掃描 QR Code 點歌
echo • 即時佇列顯示
echo • 當前播放狀態指示
echo • 自訂點歌說明文字
echo.
echo 📝 自訂設定：
echo • 編輯 config\instructions.txt 來自訂點歌說明
echo • 重啟 YTMD 後生效
echo.
echo 享受您的音樂時光！🎶
pause
