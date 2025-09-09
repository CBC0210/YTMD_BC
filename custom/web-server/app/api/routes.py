"""
API 路由定義
包含所有 REST API 端點
"""

from flask import Blueprint, render_template, request, jsonify
import os
import json
import logging
import random

from ..services.ytmd_service import YTMDService
from ..services.user_service import UserService
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
user_service = UserService()


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
    """獲取當前佇列 (含 index 與縮圖)"""
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
            # 紀錄使用者點歌歷史
            nickname = data.get('nickname')
            if nickname:
                # 儲存簡單中繼資料方便前端顯示
                meta = {
                    'videoId': video_id,
                    'title': data.get('title') or '',
                    'artist': data.get('artist') or '',
                    'thumbnail': data.get('thumbnail') or '',
                    'duration': data.get('duration') or '',
                }
                user_service.add_history(nickname, meta)
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


@api_blueprint.route('/controls/<action>', methods=['POST'])
def controls(action: str):
    """播放控制: play/pause/next/previous/toggle-play"""
    ok, msg = ytmd_service.control(action)
    if ok:
        return ('', 204)
    return jsonify({'error': msg}), 500


@api_blueprint.route('/seek', methods=['POST'])
def seek():
    """將目前歌曲跳轉到指定的秒數"""
    try:
        data = request.get_json() or {}
        seconds = int(data.get('seconds', 0))
        ok, msg = ytmd_service.seek_to(seconds)
        if ok:
            return ('', 204)
        return jsonify({'error': msg}), 500
    except Exception as e:
        logger.error(f"Seek failed: {e}")
        return jsonify({'error': 'Seek failed'}), 500

@api_blueprint.route('/volume', methods=['GET', 'POST'])
def volume():
    """音量同步：GET 取得、POST 設定"""
    if request.method == 'GET':
        return jsonify(ytmd_service.get_volume())
    data = request.get_json() or {}
    vol = int(data.get('volume', 0))
    ok, msg = ytmd_service.set_volume(vol)
    if ok:
        return ('', 204)
    return jsonify({'error': msg}), 500


@api_blueprint.route('/queue/<int:index>', methods=['DELETE'])
def queue_delete(index: int):
    """刪除佇列中指定索引（正在播放的索引不應由前端呼叫）"""
    ok, msg = ytmd_service.remove_queue_index(index)
    if ok:
        return ('', 204)
    return jsonify({'error': msg}), 500


@api_blueprint.route('/user/<nickname>/history', methods=['GET', 'DELETE'])
def user_history(nickname: str):
    """取得或清除使用者點歌歷史"""
    if request.method == 'GET':
        return jsonify(user_service.get_history(nickname))
    user_service.clear_history(nickname)
    return ('', 204)


@api_blueprint.route('/user/<nickname>/history/<video_id>', methods=['DELETE'])
def user_history_delete_item(nickname: str, video_id: str):
    """刪除使用者歷史中的單筆項目"""
    user_service.remove_history_item(nickname, video_id)
    return ('', 204)


@api_blueprint.route('/user/<nickname>/likes', methods=['GET', 'POST', 'DELETE'])
def user_likes(nickname: str):
    """取得/新增/刪除使用者喜歡的歌曲"""
    if request.method == 'GET':
        return jsonify(user_service.get_likes(nickname))
    data = request.get_json() or {}
    video_id = (data.get('videoId') or '').strip()
    if request.method == 'POST':
        meta = {
            'videoId': video_id,
            'title': data.get('title') or '',
            'artist': data.get('artist') or '',
            'thumbnail': data.get('thumbnail') or '',
            'duration': data.get('duration') or '',
        }
        user_service.like_song(nickname, meta)
        return ('', 204)
    # DELETE
    user_service.unlike_song(nickname, video_id)
    return ('', 204)


@api_blueprint.route('/user/<nickname>/recommendations')
def user_recommendations(nickname: str):
    """根據使用者歷史與喜歡的歌曲推薦：
    - 歷史中抽取最近的不同歌手（優先，最多 4 位）
    - 不足則由喜歡清單補齊不同歌手（合計最多 4 位）
    - 針對每位歌手搜尋歌曲，排除歷史與喜歡清單已存在的 videoId
    - 以輪詢方式合併結果，盡量避免同歌手連續，並限制總數
    """
    try:
        history = user_service.get_history(nickname) or []
        likes = user_service.get_likes(nickname) or []
        if not history and not likes:
            return jsonify([])

        # 收集種子歌手（歷史優先，其次喜歡）
        seed_artists = []
        seen_artists = set()
        for item in reversed(history[-30:]):
            artist = (item.get('artist') or '').strip()
            if artist and artist not in seen_artists:
                seen_artists.add(artist)
                seed_artists.append(artist)
            if len(seed_artists) >= 4:
                break
        if len(seed_artists) < 4:
            for li in reversed(likes[-50:]):
                artist = (li.get('artist') or '').strip()
                if artist and artist not in seen_artists:
                    seen_artists.add(artist)
                    seed_artists.append(artist)
                if len(seed_artists) >= 4:
                    break

        if not seed_artists:
            return jsonify([])

        # 輕度隨機化：打散歌手順序，讓合併時順序略有變化
        try:
            random.shuffle(seed_artists)
        except Exception:
            pass

        # 排除集合：歷史 + 喜歡
        existing_ids = {x.get('videoId') for x in history if x.get('videoId')}
        existing_ids.update({x.get('videoId') for x in likes if x.get('videoId')})

        # 搜尋每位歌手
        per_artist_results = []
        for a in seed_artists:
            try:
                r = youtube_service.search_songs(a, limit=10)
            except Exception:
                r = []
            cleaned = []
            for s in r:
                vid = s.get('videoId')
                if not vid or vid in existing_ids:
                    continue
                # 第一位歌手名稱
                artist_name = ''
                try:
                    aa = s.get('artists') or []
                    artist_name = aa[0] if aa and isinstance(aa[0], str) else (aa[0].get('name') if aa and isinstance(aa[0], dict) else '')
                except Exception:
                    pass
                # 最大縮圖
                thumb = ''
                try:
                    tlist = s.get('thumbnails') or []
                    if tlist:
                        thumb = (tlist[-1].get('url') if isinstance(tlist[-1], dict) else '') or ''
                except Exception:
                    pass
                cleaned.append({
                    'videoId': vid,
                    'title': s.get('title') or '',
                    'artist': artist_name,
                    'duration': s.get('duration') or '',
                    'thumbnail': thumb,
                })
            # 輕度隨機化：每位歌手清單打散，避免總是出現前幾首固定歌曲
            try:
                random.shuffle(cleaned)
            except Exception:
                pass
            per_artist_results.append(cleaned)

        # 輪詢合併，避免同歌手連續
        merged = []
        limit = 12
        buckets = [list(lst) for lst in per_artist_results if lst]
        used = set()
        while buckets and len(merged) < limit:
            for i in range(len(buckets)):
                if len(merged) >= limit:
                    break
                if not buckets[i]:
                    continue
                item = buckets[i].pop(0)
                vid = item.get('videoId')
                if vid in used:
                    continue
                used.add(vid)
                merged.append(item)
            buckets = [b for b in buckets if b]

        return jsonify(merged)
    except Exception as e:
        logger.error(f"推薦產生失敗: {e}")
        return jsonify([]), 200

@api_blueprint.route('/config')
def get_config():
    """提供配置信息給前端和插件"""
    config_data = config_service.get_client_config()
    return jsonify(config_data)


@api_blueprint.route('/public-links')
def public_links():
    """提供對外（ngrok/LAN）連結，供手機端讀取"""
    try:
        base_dir = os.path.dirname(os.path.dirname(__file__))  # app/
        links_path = os.path.join(base_dir, 'public_links.json')
        if os.path.exists(links_path):
            with open(links_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        else:
            data = {
                'generatedAt': None,
                'frontend': {
                    'local': None,
                    'public': None,
                }
            }
        return jsonify(data)
    except Exception as e:
        logger.error(f"讀取 public_links.json 失敗: {e}")
        return jsonify({'error': 'failed to read public links'}), 500
