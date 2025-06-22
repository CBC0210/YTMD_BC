@echo off
chcp 65001 >nul

echo 🛑 正在停止所有 YTMD 服務...

:: 停止 Web Server
tasklist | findstr "python.exe" >nul
if %errorlevel% equ 0 (
    echo 🔍 發現運行中的 Python 程序
    taskkill /f /im python.exe >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ Web 服務器已停止
    ) else (
        echo ⚠️  停止 Web 服務器時發生錯誤
    )
) else (
    echo ℹ️  未發現運行中的 Python 程序
)

:: 停止 YTMD Desktop App
tasklist | findstr "YouTube Music.exe" >nul
if %errorlevel% equ 0 (
    echo 🔍 發現運行中的 YTMD 程序
    taskkill /f /im "YouTube Music.exe" >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ YTMD 已停止
    ) else (
        echo ⚠️  停止 YTMD 時發生錯誤
    )
) else (
    echo ℹ️  未發現運行中的 YTMD 程序
)

:: 清理臨時檔案
if exist "ytmd-web-qr.png" del /q "ytmd-web-qr.png"

echo 🏁 所有服務已停止，臨時檔案已清理

:: 檢查是否還有相關程序運行
timeout /t 1 /nobreak >nul
tasklist | findstr /i "python.*server\|youtube.*music" >nul
if %errorlevel% equ 0 (
    echo.
    echo ⚠️  警告：仍有相關程序在運行
    echo 運行中的程序：
    tasklist | findstr /i "python\|youtube"
    echo.
    echo 如果需要，可以手動結束這些程序
) else (
    echo ✅ 確認所有相關程序已停止
)

echo.
pause
