from flask import Flask, render_template, request, jsonify
from ytmusicapi import YTMusic
import requests
import os
import logging

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
            return jsonify({'error': 'Failed to get queue'}), 500
    except requests.exceptions.RequestException as e:
        logger.error(f"Request to YTMD failed: {e}")
        return jsonify({'error': 'YTMD connection failed'}), 500

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

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    logger.info("Starting Flask server...")
    logger.info(f"YTMD API endpoint: {YTMD}")
    app.run(host='0.0.0.0', port=8080, debug=True)
