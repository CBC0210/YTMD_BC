from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
from ytmusicapi import YTMusic
import requests
import os
import logging
import socket
import threading
import time
import signal
import sys

# 設置日誌
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 初始化 YouTube Music API
try:
    YTM = YTMusic()
    logger.info("YouTube Music API initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize YouTube Music API: {e}")
    YTM = None

# YTMD API 端點
YTMD = os.getenv('YTMD_API', 'http://localhost:26538/api/v1')

app = Flask(__name__)

# 配置 CORS，允許來自 YouTube Music 的請求
CORS(app, origins=[
    "https://music.youtube.com",
    "https://www.youtube.com", 
    "http://localhost:*",
    "https://localhost:*"
])

def get_server_ip():
    """獲取服務器 IP 地址"""
    try:
        # 連接到外部地址來獲取本機 IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"

@app.route('/')
def home():
    """主頁面：顯示目前佇列和搜尋介面"""
    return render_template('index.html')

@app.route('/queue')
def queue():
    """獲取當前佇列"""
    try:
        response = requests.get(f'{YTMD}/queue', timeout=5)
        if response.status_code == 200:
            raw_data = response.json()
            
            # 解析 YTMD 的複雜佇列格式
            simplified_queue = []
            
            if 'items' in raw_data and isinstance(raw_data['items'], list):
                for item in raw_data['items']:
                    if 'playlistPanelVideoRenderer' in item:
                        renderer = item['playlistPanelVideoRenderer']
                        
                        # 提取歌曲標題
                        title = 'Unknown Title'
                        if 'title' in renderer and 'runs' in renderer['title']:
                            title = renderer['title']['runs'][0].get('text', 'Unknown Title')
                        
                        # 提取藝術家名稱
                        artist = 'Unknown Artist'
                        if 'longBylineText' in renderer and 'runs' in renderer['longBylineText']:
                            # 通常第一個 run 是藝術家名稱
                            for run in renderer['longBylineText']['runs']:
                                if 'text' in run and run['text'].strip() != ' • ':
                                    artist = run['text']
                                    break
                        
                        # 提取時長
                        duration = ''
                        if 'lengthText' in renderer and 'runs' in renderer['lengthText']:
                            duration = renderer['lengthText']['runs'][0].get('text', '')
                        
                        # 提取 videoId
                        video_id = ''
                        if 'videoId' in renderer:
                            video_id = renderer['videoId']
                        
                        simplified_queue.append({
                            'title': title,
                            'artist': artist,
                            'duration': duration,
                            'videoId': video_id
                        })
            
            logger.info(f"Parsed {len(simplified_queue)} songs from queue")
            return jsonify(simplified_queue)
        else:
            logger.error(f"Failed to get queue: {response.status_code}")
            # 返回空佇列而不是錯誤
            return jsonify([])
    except requests.exceptions.RequestException as e:
        logger.error(f"Request to YTMD failed: {e}")
        # 返回空佇列和狀態信息，而不是錯誤
        return jsonify({
            'queue': [],
            'status': 'YTMD_DISCONNECTED',
            'message': 'YTMD 尚未連接或啟動，請確保 YTMD 應用程式正在運行'
        })

@app.route('/search', methods=['POST'])
def search():
    """搜尋歌曲"""
    if not YTM:
        return jsonify({'error': 'YouTube Music API not available'}), 500
    
    try:
        data = request.get_json()
        query = data.get('q', '').strip()
        
        if not query:
            return jsonify({'error': 'Query is required'}), 400
        
        logger.info(f"Searching for: {query}")
        results = YTM.search(query, filter='songs', limit=15)
        
        # 簡化結果格式
        simplified_results = []
        for song in results:
            simplified_results.append({
                'videoId': song.get('videoId', ''),
                'title': song.get('title', 'Unknown Title'),
                'artists': [artist.get('name', '') for artist in song.get('artists', [])],
                'album': song.get('album', {}).get('name', '') if song.get('album') else '',
                'duration': song.get('duration', ''),
                'thumbnails': song.get('thumbnails', [])
            })
        
        logger.info(f"Found {len(simplified_results)} results")
        return jsonify(simplified_results)
        
    except Exception as e:
        logger.error(f"Search failed: {e}")
        return jsonify({'error': 'Search failed'}), 500

@app.route('/enqueue', methods=['POST'])
def enqueue():
    """加入佇列最後面（不立即播放）"""
    try:
        data = request.get_json()
        video_id = data.get('videoId', '').strip()
        
        if not video_id:
            return jsonify({'error': 'videoId is required'}), 400
        
        logger.info(f"Adding to queue: {video_id}")
        
        # 使用正確的 YTMD API 端點來加入佇列最後面
        queue_endpoint = f'{YTMD}/queue'
        
        # 根據 API 文檔，使用正確的請求格式
        payload = {
            'videoId': video_id,
            'insertPosition': 'INSERT_AT_END'  # 加入到佇列最後面
        }
        
        try:
            response = requests.post(
                queue_endpoint,
                json=payload,
                timeout=10
            )
            
            logger.info(f"YTMD API response: {response.status_code}")
            
            if response.status_code == 204:
                logger.info(f"Successfully added to queue: {video_id}")
                return jsonify({
                    'success': True, 
                    'message': f'歌曲已加入佇列: {video_id}'
                }), 200
            else:
                logger.error(f"YTMD API returned status {response.status_code}: {response.text}")
                return jsonify({
                    'error': f'YTMD API error: {response.status_code}'
                }), 500
                
        except requests.exceptions.Timeout:
            logger.error("YTMD API timeout")
            return jsonify({'error': 'YTMD API timeout'}), 500
        except requests.exceptions.ConnectionError:
            logger.error("Cannot connect to YTMD API")
            return jsonify({'error': 'Cannot connect to YTMD API'}), 500
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to YTMD failed: {e}")
            return jsonify({'error': f'YTMD connection failed: {str(e)}'}), 500
        
    except Exception as e:
        logger.error(f"Enqueue failed: {e}")
        return jsonify({'error': f'Server error: {str(e)}'}), 500

@app.route('/lyrics')
def lyrics():
    """獲取歌詞（可選功能）"""
    # 這是可選功能的骨架
    return jsonify({'lyrics': 'Lyrics feature not implemented yet'})

@app.route('/instructions')
def instructions():
    """獲取點歌說明文字"""
    try:
        # 嘗試讀取自定義說明文件
        instructions_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'config', 'instructions.txt')
        if os.path.exists(instructions_path):
            with open(instructions_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                return jsonify({'instructions': content})
        else:
            # 默認說明文字
            default_instructions = """✦ 點歌教學
1. 掃下方 QR Code
2. 搜尋並加入歌曲
3. 立即播放！
"""
            return jsonify({'instructions': default_instructions})
    except Exception as e:
        logger.error(f"Failed to get instructions: {e}")
        return jsonify({'instructions': '✦ 點歌教學\n1. 掃下方 QR Code\n2. 搜尋並加入歌曲\n3. 立即播放！'})

@app.route('/current-song')
def current_song():
    """獲取當前播放的歌曲信息"""
    try:
        response = requests.get(f'{YTMD}/song', timeout=5)
        if response.status_code == 200:
            song_data = response.json()
            # 簡化回傳格式，只包含我們需要的信息
            return jsonify({
                'videoId': song_data.get('videoId', ''),
                'title': song_data.get('title', ''),
                'artist': song_data.get('artist', ''),
                'isPaused': song_data.get('isPaused', True),
                'elapsedSeconds': song_data.get('elapsedSeconds', 0),
                'songDuration': song_data.get('songDuration', 0)
            })
        elif response.status_code == 204:
            # 沒有歌曲在播放
            return jsonify({'videoId': None})
        else:
            logger.error(f"Failed to get current song: {response.status_code}")
            return jsonify({'error': 'Failed to get current song'}), 500
    except requests.exceptions.RequestException as e:
        logger.error(f"Request to YTMD failed: {e}")
        return jsonify({'error': 'YTMD connection failed'}), 500

@app.route('/config')
def get_config():
    """提供配置信息給前端和插件"""
    server_ip = get_server_ip()
    return jsonify({
        'serverUrl': f'http://{server_ip}:8080',
        'localUrl': 'http://localhost:8080',
        'serverIp': server_ip,
        'status': 'running'
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

# 全局變量用於狀態管理
server_start_time = time.time()
ytmd_connected = False
auto_shutdown_enabled = True
shutdown_timer = None

def check_ytmd_api():
    """檢查 YTMD API 是否可用"""
    try:
        response = requests.get(f'{YTMD}/song', timeout=3)
        return response.status_code in [200, 204]
    except:
        return False

def ytmd_monitor():
    """監控 YTMD API 狀態的後台線程"""
    global ytmd_connected, shutdown_timer
    
    logger.info("YTMD 監控線程啟動")
    
    # 每 30 秒檢查一次 YTMD API
    while auto_shutdown_enabled:
        if check_ytmd_api():
            if not ytmd_connected:
                logger.info("✅ YTMD API 已連接")
                ytmd_connected = True
                # 取消自動關閉定時器
                if shutdown_timer:
                    shutdown_timer.cancel()
                    shutdown_timer = None
                    logger.info("📋 取消自動關閉定時器")
        else:
            if ytmd_connected:
                logger.warning("⚠️ YTMD API 連接丟失")
                ytmd_connected = False
        
        time.sleep(30)  # 每 30 秒檢查一次

def auto_shutdown():
    """5分鐘後自動關閉伺服器（如果 YTMD 仍未連接）"""
    global ytmd_connected
    
    logger.warning("⏰ 5 分鐘自動關閉定時器觸發")
    
    if not ytmd_connected:
        logger.error("❌ 5 分鐘後 YTMD API 仍無法連接，自動關閉服務器")
        logger.info("💡 提示：請確保 YTMD 應用程式正在運行，然後重新啟動點歌服務")
        
        # 優雅地關閉服務器
        threading.Timer(1.0, lambda: os._exit(0)).start()
    else:
        logger.info("✅ YTMD API 已連接，取消自動關閉")

def start_background_tasks():
    """啟動背景任務"""
    global shutdown_timer
    
    # 啟動 YTMD 監控線程
    monitor_thread = threading.Thread(target=ytmd_monitor, daemon=True)
    monitor_thread.start()
    
    # 設置 5 分鐘自動關閉定時器
    shutdown_timer = threading.Timer(300.0, auto_shutdown)  # 300 秒 = 5 分鐘
    shutdown_timer.start()
    logger.info("⏰ 設置 5 分鐘自動關閉定時器（如果 YTMD API 無法連接）")

def signal_handler(sig, frame):
    """處理中斷信號"""
    global auto_shutdown_enabled, shutdown_timer
    
    logger.info("🛑 收到中斷信號，正在關閉服務器...")
    auto_shutdown_enabled = False
    
    if shutdown_timer:
        shutdown_timer.cancel()
        logger.info("📋 取消自動關閉定時器")
    
    sys.exit(0)

if __name__ == '__main__':
    # 註冊信號處理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("🚀 啟動 Flask 服務器...")
    logger.info(f"🔗 YTMD API 端點: {YTMD}")
    logger.info(f"🌐 服務器 IP: {get_server_ip()}")
    
    # 啟動背景任務
    start_background_tasks()
    
    # 根據環境變數決定是否啟用調試模式
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    try:
        app.run(host='0.0.0.0', port=8080, debug=debug_mode, use_reloader=False)
    except KeyboardInterrupt:
        logger.info("🛑 收到鍵盤中斷，正在關閉...")
    except Exception as e:
        logger.error(f"❌ 服務器錯誤: {e}")
    finally:
        logger.info("👋 Flask 服務器已關閉")
