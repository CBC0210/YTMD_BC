# 🚀 YTMD CBC Edition 啟動腳本說明

這個目錄包含了 YTMD CBC Edition 的所有啟動、設置和管理腳本。

## 📁 目錄結構

```
launchers/
├── README.md                    # 本檔案
├── install.sh                  # Linux 主安裝腳本
├── setup-web.sh               # Linux Web 系統設置
├── start-ytmd.sh              # Linux 僅啟動 YTMD
├── start-ytmd-with-web.sh     # Linux 啟動完整功能
├── stop-all.sh                # Linux 停止所有服務
├── uninstall.sh               # Linux 卸載腳本
├── windows/                   # Windows 腳本目錄
│   ├── install.bat            # Windows 主安裝腳本
│   ├── setup-web.bat          # Windows Web 系統設置
│   ├── start-ytmd.bat         # Windows 僅啟動 YTMD
│   ├── start-ytmd-with-web.bat # Windows 啟動完整功能
│   ├── stop-all.bat           # Windows 停止所有服務
│   └── uninstall.bat          # Windows 卸載腳本
└── utils/                     # 工具腳本
    ├── ip-detector.py         # IP 地址檢測
    ├── qr-generator.py        # QR Code 生成器
    └── web-status.py          # 服務狀態檢查
```

## 🔧 主要腳本說明

### 🐧 Linux 腳本

#### 安裝與設置

**`install.sh`** - 主安裝腳本
- 檢查系統需求（Python, Node.js）
- 自動設置 Python 虛擬環境
- 安裝所有必要依賴
- 設置腳本執行權限

**`setup-web.sh`** - Web 點歌系統設置
- 建立 Python 虛擬環境
- 安裝 Flask 和相關套件
- 可選編譯 YTMD
- 測試服務連接

#### 啟動服務

**`start-ytmd.sh`** - 僅啟動 YTMD
```bash
./launchers/start-ytmd.sh
```
- 只啟動 YouTube Music Desktop App
- 不包含 Web 點歌功能
- 適合純音樂播放使用

**`start-ytmd-with-web.sh`** - 啟動完整功能（推薦）
```bash
./launchers/start-ytmd-with-web.sh
```
- 啟動 YTMD + Web 點歌系統
- 自動檢測 IP 並生成 QR Code
- 支援手機和電腦同時操作
- 包含完整錯誤處理和清理

#### 管理服務

**`stop-all.sh`** - 停止所有服務
```bash
./launchers/stop-all.sh
```
- 停止所有相關程序
- 清理臨時檔案
- 安全退出機制

**`uninstall.sh`** - 卸載點歌系統
```bash
./launchers/uninstall.sh
```
- 移除虛擬環境
- 清理設置檔案
- 保留 YTMD 主程式

### 🪟 Windows 腳本

#### 安裝與設置

**`windows/install.bat`** - Windows 主安裝腳本
- UTF-8 編碼支援中文
- 檢查 Python 和 Node.js
- 自動建立虛擬環境
- 友善的錯誤提示

**`windows/setup-web.bat`** - Windows Web 系統設置
- 建立 Python 虛擬環境
- 安裝必要套件
- 可選編譯 YTMD for Windows
- 服務連接測試

#### 啟動服務

**`windows/start-ytmd.bat`** - Windows 僅啟動 YTMD
```batch
launchers\windows\start-ytmd.bat
```

**`windows/start-ytmd-with-web.bat`** - Windows 啟動完整功能
```batch
launchers\windows\start-ytmd-with-web.bat
```

#### 管理服務

**`windows/stop-all.bat`** - Windows 停止所有服務
**`windows/uninstall.bat`** - Windows 卸載腳本

### 🛠️ 工具腳本

**`utils/ip-detector.py`** - IP 地址檢測
- 自動獲取本機 IP 地址
- 支援多網卡環境
- 用於生成正確的訪問網址

**`utils/qr-generator.py`** - QR Code 生成器
- 生成 Web 點歌系統的 QR Code
- 支援自訂 URL
- 輸出 PNG 格式圖片

**`utils/web-status.py`** - 服務狀態檢查
- 檢查 Web 服務器是否正常運行
- 檢查 YTMD API 連接狀態
- 用於啟動腳本的健康檢查

## 📋 使用流程

### 初次安裝

1. **Linux 系統**：
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

2. **Windows 系統**：
   ```batch
   launchers\windows\install.bat
   ```

### 日常使用

1. **啟動完整功能**：
   - Linux: `./launchers/start-ytmd-with-web.sh`
   - Windows: `launchers\windows\start-ytmd-with-web.bat`

2. **停止服務**：
   - Linux: `./launchers/stop-all.sh`
   - Windows: `launchers\windows\stop-all.bat`

3. **僅使用 YTMD**：
   - Linux: `./launchers/start-ytmd.sh`
   - Windows: `launchers\windows\start-ytmd.bat`

## ⚙️ 設置檔案

### 環境變數

腳本會自動設置以下內容：
- Python 虛擬環境路徑
- Web 服務器端口（預設 8080）
- IP 地址檢測和 QR Code 生成

### 自訂設定

**點歌說明文字**：
- 檔案：`config/instructions.txt`
- 修改後重啟 YTMD 生效

**Web 服務器設定**：
- 檔案：`config/web-config.json`
- 可調整端口、主題等設定

## 🔍 故障排除

### 常見問題

**1. 權限錯誤（Linux）**
```bash
chmod +x launchers/*.sh
chmod +x launchers/utils/*.py
```

**2. Python 環境問題**
```bash
# 重新設置虛擬環境
./launchers/setup-web.sh
```

**3. 端口被占用**
```bash
# 檢查端口使用
netstat -tuln | grep 8080  # Linux
netstat -an | findstr 8080  # Windows

# 停止相關程序
./launchers/stop-all.sh  # Linux
launchers\windows\stop-all.bat  # Windows
```

**4. YTMD 找不到**
```bash
# 編譯 YTMD
npm install
npm run build:linux    # Linux
npm run build:win      # Windows
```

### 日誌檢查

**Linux**：
- 終端直接顯示錯誤訊息
- Web 服務器日誌：`web-server/logs/`

**Windows**：
- 命令提示字元顯示錯誤
- 腳本會暫停等待用戶確認

## 📝 開發者說明

### 腳本設計原則

1. **跨平台一致性**：Linux 和 Windows 功能對等
2. **錯誤處理**：完整的錯誤檢查和用戶提示
3. **清理機制**：程序退出時自動清理資源
4. **用戶友善**：清楚的進度提示和說明

### 新增功能

如需新增功能，請遵循：
1. 同時更新 Linux 和 Windows 版本
2. 更新本 README 說明
3. 測試所有相關腳本
4. 確保向後兼容性

### 腳本依賴

- **Linux**: bash, python3, node/npm
- **Windows**: cmd/batch, python, node/npm
- **共同**: Flask, ytmusicapi, qrcode

---

**享受您的音樂時光！** 🎶

如有問題或建議，歡迎提交 Issue 或 Pull Request。
