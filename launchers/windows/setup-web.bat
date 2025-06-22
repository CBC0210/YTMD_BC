@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 設定工作目錄到專案根目錄
cd /d "%~dp0..\.."

echo 🔧 YTMD 點歌系統設置程式
echo ==========================================

:: 檢查 Python 環境
echo 🐍 檢查 Python 環境...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 未找到 Python 3
    echo 請先安裝 Python 3.7+ 後重新執行此腳本
    echo.
    echo 下載地址：https://www.python.org/downloads/
    echo 安裝時請勾選 "Add Python to PATH"
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo ✅ Python 版本：!PYTHON_VERSION!

:: 檢查 Node.js
echo 📦 檢查 Node.js 環境...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  未找到 Node.js
    echo YTMD 需要 Node.js 來編譯，請安裝後重新執行
    echo 下載地址：https://nodejs.org/
    pause
    exit /b 1
)

for /f %%i in ('node --version') do set NODE_VERSION=%%i
echo ✅ Node.js 版本：!NODE_VERSION!

:: 建立 Python 虛擬環境
echo 🏗️  建立 Python 虛擬環境...
cd web-server

if exist ".venv" (
    echo ⚠️  虛擬環境已存在，正在重新建立...
    rmdir /s /q .venv
)

python -m venv .venv
if %errorlevel% neq 0 (
    echo ❌ 虛擬環境建立失敗
    cd ..
    pause
    exit /b 1
)
echo ✅ 虛擬環境建立完成

:: 啟動虛擬環境並安裝依賴
echo 📥 安裝 Python 套件...
call .venv\Scripts\activate.bat

:: 升級 pip
python -m pip install --upgrade pip

:: 安裝基本依賴
echo 正在安裝 Flask 和相關套件...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ❌ Python 套件安裝失敗
    cd ..
    pause
    exit /b 1
)

:: 安裝額外依賴
echo 正在安裝 QR Code 生成器...
pip install qrcode[pil]

echo ✅ Python 套件安裝完成

:: 檢查 YTMD 是否已編譯
echo 🎵 檢查 YTMD 編譯狀態...
cd ..

if exist "dist\win-unpacked\YouTube Music.exe" (
    echo ✅ YTMD 已編譯完成
) else if exist "package.json" (
    echo ⚠️  YTMD 尚未編譯
    set /p "response=是否要現在編譯 YTMD？(這可能需要幾分鐘) [y/N]: "
    if /i "!response!"=="y" (
        echo 正在安裝 Node.js 依賴...
        npm install
        echo 正在編譯 YTMD...
        npm run build:win
        if %errorlevel% equ 0 (
            echo ✅ YTMD 編譯完成
        ) else (
            echo ❌ YTMD 編譯失敗
        )
    ) else (
        echo ⚠️  您可以稍後手動編譯：npm run build:win
    )
) else (
    echo ❌ 這似乎不是有效的 YTMD 專案目錄
)

:: 測試服務
echo 🧪 測試服務連接...
cd web-server
call .venv\Scripts\activate.bat

:: 簡單測試 Flask 能否啟動
echo 測試 Flask 服務器...
start /b python server.py
timeout /t 2 /nobreak >nul

:: 檢查進程
tasklist | findstr python >nul
if %errorlevel% equ 0 (
    echo ✅ Web 服務器測試通過
    :: 停止測試進程
    taskkill /f /im python.exe >nul 2>&1
) else (
    echo ⚠️  Web 服務器測試未通過，但設置已完成
)

cd ..

:: 完成設置
echo.
echo 🎉 設置完成！
echo ==========================================
echo 使用方式：
echo.
echo 基本 YTMD ^(無點歌功能^)：
echo   launchers\windows\start-ytmd.bat
echo.
echo 完整功能 ^(YTMD + 點歌系統^)：
echo   launchers\windows\start-ytmd-with-web.bat
echo.
echo 停止所有服務：
echo   launchers\windows\stop-all.bat
echo.
echo 📝 注意事項：
echo • 完整功能需要 YTMD 已啟動並運行
echo • 點歌系統會在 http://localhost:8080 啟動
echo • 關閉視窗來停止服務
echo • 可編輯 config\instructions.txt 自訂點歌說明
echo.
pause
