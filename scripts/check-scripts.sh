#!/bin/bash
# 腳本語法檢查工具

echo "🔍 檢查所有腳本語法..."

# 檢查 Linux shell 腳本
echo "📋 Linux Shell 腳本："
for script in launchers/*.sh scripts/*.sh install.sh; do
    if [ -f "$script" ]; then
        echo -n "  $(basename "$script"): "
        if bash -n "$script" 2>/dev/null; then
            echo "✅"
        else
            echo "❌"
            echo "    錯誤詳情："
            bash -n "$script"
        fi
    fi
done

# 檢查 Python 腳本
echo ""
echo "🐍 Python 腳本："
for script in launchers/utils/*.py; do
    if [ -f "$script" ]; then
        echo -n "  $(basename "$script"): "
        if python3 -m py_compile "$script" 2>/dev/null; then
            echo "✅"
            rm -f "${script}c" 2>/dev/null  # 清理編譯檔案
        else
            echo "❌"
            echo "    錯誤詳情："
            python3 -m py_compile "$script"
        fi
    fi
done

# 檢查 Windows 批次檔語法（基本檢查）
echo ""
echo "🪟 Windows 批次檔："
for script in launchers/windows/*.bat; do
    if [ -f "$script" ]; then
        echo -n "  $(basename "$script"): "
        # 基本語法檢查：尋找常見錯誤
        if grep -q "^[[:space:]]*@echo off" "$script" && \
           ! grep -q "goto :eof" "$script" && \
           ! grep -q "%~[0-9]" "$script"; then
            echo "✅"
        else
            echo "⚠️ (需在 Windows 環境測試)"
        fi
    fi
done

# 檢查檔案權限
echo ""
echo "🔑 檔案權限："
for script in launchers/*.sh scripts/*.sh install.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "  $(basename "$script"): ✅ 可執行"
        else
            echo "  $(basename "$script"): ⚠️ 不可執行"
        fi
    fi
done

echo ""
echo "🎉 語法檢查完成！"
