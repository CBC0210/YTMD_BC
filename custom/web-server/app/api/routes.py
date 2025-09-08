"""
API 路由定義
包含所有 REST API 端點
"""

from flask import Blueprint, render_template, request, jsonify
import logging

from ..services.ytmd_service import YTMDService
from ..services.youtube_service import YouTubeService
from ..services.config_service import ConfigService
from ..utils.file_utils import read_instructions

logger = logging.getLogger(__name__)

# 創建藍圖
api_blueprint = Blueprint('api', __name__)

# 服務實例
ytmd_service = YTMDService()
youtube_service = YouTubeService()
config_service = ConfigService()


@api_blueprint.route('/')
def home():
    """主頁面：顯示目前佇列和搜尋介面"""
    return render_template('index.html')


@api_blueprint.route('/health')
def health():
    """健康檢查端點"""
    return jsonify({
        'status': 'ok',
        'queue_connected': ytmd_service.is_connected(),
    })


@api_blueprint.route('/queue')
def queue():
    """獲取當前佇列"""
    try:
        queue_data = ytmd_service.get_queue()
        return jsonify(queue_data)
    except Exception as e:
        logger.error(f"獲取佇列失敗: {e}")
        return jsonify({
            'queue': [],
            'status': 'YTMD_DISCONNECTED',
            'message': 'YTMD 尚未連接或啟動，請確保 YTMD 應用程式正在運行'
        })


@api_blueprint.route('/search', methods=['POST'])
def search():
    """搜尋歌曲"""
    try:
        data = request.get_json()
        query = data.get('q', '').strip()
        
        if not query:
            return jsonify({'error': 'Query is required'}), 400
        
        results = youtube_service.search_songs(query)
        return jsonify(results)
        
    except Exception as e:
        logger.error(f"搜尋失敗: {e}")
        return jsonify({'error': 'Search failed'}), 500


@api_blueprint.route('/enqueue', methods=['POST'])
def enqueue():
    """加入佇列最後面（不立即播放）"""
    try:
        data = request.get_json()
        video_id = data.get('videoId', '').strip()
        
        if not video_id:
            return jsonify({'error': 'videoId is required'}), 400
        
        success, message = ytmd_service.enqueue_song(video_id)
        
        if success:
            return jsonify({
                'success': True, 
                'message': message
            }), 200
        else:
            return jsonify({'error': message}), 500
            
    except Exception as e:
        logger.error(f"加入佇列失敗: {e}")
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@api_blueprint.route('/lyrics')
def lyrics():
    """獲取歌詞（可選功能）"""
    # 這是可選功能的骨架
    return jsonify({'lyrics': 'Lyrics feature not implemented yet'})


@api_blueprint.route('/instructions')
def instructions():
    """獲取點歌說明文字"""
    try:
        instructions_text = read_instructions()
        return jsonify({'instructions': instructions_text})
    except Exception as e:
        logger.error(f"獲取說明文字失敗: {e}")
        return jsonify({'instructions': '✦ 點歌教學\n1. 掃下方 QR Code\n2. 搜尋並加入歌曲\n3. 立即播放！'})


@api_blueprint.route('/current-song')
def current_song():
    """獲取當前播放的歌曲信息"""
    try:
        song_data = ytmd_service.get_current_song()
        return jsonify(song_data)
    except Exception as e:
        logger.error(f"獲取當前歌曲失敗: {e}")
        return jsonify({'error': 'YTMD connection failed'}), 500


@api_blueprint.route('/config')
def get_config():
    """提供配置信息給前端和插件"""
    config_data = config_service.get_client_config()
    return jsonify(config_data)
