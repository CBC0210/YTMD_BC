# 🎶 YTMD 點歌系統 by CBC

一個基於 Flask 的網頁點歌系統，配合 YouTube Music Desktop App (YTMD) 使用。

## 📋 功能特色

- 🎵 **佇列顯示**：即時顯示目前播放佇列
- 🔍 **歌曲搜尋**：使用 YouTube Music API 搜尋歌曲
- ➕ **一鍵點歌**：點擊搜尋結果即可加入佇列
- 🔄 **自動更新**：佇列每 4 秒自動刷新
- 📱 **響應式設計**：支援手機和桌面瀏覽器
- 🌙 **深色主題**：仿 YouTube 風格的深色界面

## 🛠️ 系統需求

### 必要軟體
- **YouTube Music Desktop App (YTMD)**：主要播放器
- **Python 3.7+**：運行 Flask 伺服器
- **網頁瀏覽器**：任何現代瀏覽器

### Python 套件依賴
```
Flask==2.3.3
ytmusicapi==1.7.0
requests==2.31.0
```

## 🚀 快速開始

### 1. 啟動 YTMD
確保 YouTube Music Desktop App 已經啟動並運行在預設端口 (26538)。

### 2. 設置 Python 環境
```bash
# 進入專案目錄
cd /path/to/YTMD_BC/web-server

# 建立虛擬環境 (推薦)
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# 或
.venv\Scripts\activate  # Windows

# 安裝依賴套件
pip install -r requirements.txt
```

### 3. 啟動 Flask 伺服器
```bash
python server.py
```

服務器將在 `http://localhost:8080` 啟動。

### 4. 開始使用
1. 開啟瀏覽器訪問 `http://localhost:8080`
2. 在搜尋框輸入歌手、歌名或關鍵字
3. 點擊搜尋結果中的歌曲即可加入佇列
4. 佇列會自動顯示並定期更新

## 🔧 進階配置

### 環境變數
可以透過環境變數自訂 YTMD API 端點：
```bash
export YTMD_API=http://localhost:26538/api/v1
python server.py
```

### 自訂端口
修改 `server.py` 最後一行來變更網頁服務器端口：
```python
app.run(host='0.0.0.0', port=8080, debug=True)  # 改為您要的端口
```

## 📡 API 端點

### 前端使用的 API
- `GET /` - 主頁面
- `GET /queue` - 獲取目前佇列 (JSON)
- `POST /search` - 搜尋歌曲
  ```json
  { "q": "搜尋關鍵字" }
  ```
- `POST /enqueue` - 加入歌曲到佇列
  ```json
  { "videoId": "YouTube影片ID" }
  ```

### YTMD API 整合
系統會自動連接到 YTMD 的 REST API：
- `GET /api/v1/queue` - 取得佇列資料
- `POST /api/v1/queue` - 加入歌曲到佇列

## 🎨 界面功能

### 佇列顯示區
- 顯示目前播放佇列中的所有歌曲
- 包含歌曲編號、標題、演出者和時長
- 每 4 秒自動更新
- 空佇列時顯示提示訊息

### 搜尋區
- 支援中英文搜尋
- 按 Enter 鍵或點擊搜尋按鈕執行搜尋
- 顯示歌曲標題、演出者、專輯和時長
- 點擊任一搜尋結果即可加入佇列

### 狀態訊息
- 綠色：成功訊息 (歌曲已加入、搜尋完成)
- 紅色：錯誤訊息 (連線失敗、搜尋無結果)
- 藍色：處理中訊息 (搜尋中、加入中)

## 🐛 故障排除

### 常見問題

**1. 佇列顯示「載入佇列失敗：無法連接到 YTMD」**
- 確認 YTMD 是否正在運行
- 檢查 YTMD 是否啟用了 Web API 功能
- 確認防火牆沒有阻擋 26538 端口

**2. 搜尋功能無法使用**
- 確認網路連線正常
- 檢查 YouTube Music API 配置
- 查看 Flask 服務器日誌中的錯誤訊息

**3. 點歌後歌曲沒有加入佇列**
- 確認 YTMD 處於可接受佇列操作的狀態
- 檢查歌曲的 videoId 是否有效
- 查看 Flask 服務器和 YTMD 的日誌

### 日誌查看
Flask 服務器會在控制台輸出詳細的操作日誌，包括：
- API 請求和回應
- 錯誤訊息和異常
- 搜尋和點歌操作記錄

## 🔒 安全注意事項

- 此工具僅供內網使用，不建議暴露到公網
- 如需公網部署，請配置適當的認證和授權機制
- 定期更新依賴套件以修補安全漏洞

## 🤝 技術支援

### 開發者
- **作者**：CBC
- **基於**：YTMD (YouTube Music Desktop App)

### 相關專案
- [YTMD GitHub](https://github.com/ytmdesktop/ytmdesktop)
- [ytmusicapi](https://github.com/sigma67/ytmusicapi)
- [Flask 文檔](https://flask.palletsprojects.com/)

## 📝 更新日誌

### v1.0.0 (2025-06-23)
- ✨ 初始版本發布
- 🎵 支援佇列顯示和自動更新
- 🔍 整合 YouTube Music 搜尋功能
- ➕ 實現一鍵點歌功能
- 🎨 YouTube 風格深色主題界面

---

**享受您的音樂時光！** 🎶
