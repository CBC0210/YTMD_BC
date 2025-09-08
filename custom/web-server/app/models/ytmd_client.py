"""
YTMD API 客戶端
"""
import requests
import logging
from typing import Optional, Dict, Any, List

logger = logging.getLogger(__name__)

class YTMDClient:
    """YTMD API 客戶端"""
    
    def __init__(self, base_url: str, timeout: int = 5):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self._session = requests.Session()
    
    def _make_request(self, endpoint: str, method: str = 'GET', **kwargs) -> Optional[Dict[Any, Any]]:
        """發送 HTTP 請求"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        
        try:
            response = self._session.request(
                method=method,
                url=url,
                timeout=self.timeout,
                **kwargs
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.warning(f"YTMD API returned {response.status_code} for {endpoint}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.error(f"YTMD API request failed for {endpoint}: {e}")
            return None
    
    def get_queue(self) -> Optional[List[Dict[str, Any]]]:
        """獲取播放佇列"""
        raw_data = self._make_request('/queue')
        if not raw_data:
            return None
        
        # 解析 YTMD 的複雜佇列格式
        simplified_queue = []
        
        if 'items' in raw_data and isinstance(raw_data['items'], list):
            for item in raw_data['items']:
                if 'playlistPanelVideoRenderer' in item:
                    renderer = item['playlistPanelVideoRenderer']
                    
                    # 提取歌曲信息
                    song_info = self._extract_song_info(renderer)
                    if song_info:
                        simplified_queue.append(song_info)
        
        logger.info(f"Parsed {len(simplified_queue)} songs from queue")
        return simplified_queue
    
    def _extract_song_info(self, renderer: Dict[str, Any]) -> Optional[Dict[str, str]]:
        """從渲染器數據中提取歌曲信息"""
        try:
            # 提取歌曲標題
            title = 'Unknown Title'
            if 'title' in renderer and 'runs' in renderer['title']:
                title = renderer['title']['runs'][0].get('text', 'Unknown Title')
            
            # 提取藝術家名稱
            artist = 'Unknown Artist'
            if 'longBylineText' in renderer and 'runs' in renderer['longBylineText']:
                for run in renderer['longBylineText']['runs']:
                    if 'text' in run and run['text'].strip() != ' • ':
                        artist = run['text']
                        break
            
            # 提取時長
            duration = ''
            if 'lengthText' in renderer and 'runs' in renderer['lengthText']:
                duration = renderer['lengthText']['runs'][0].get('text', '')
            
            # 提取 videoId
            video_id = renderer.get('videoId', '')
            
            return {
                'title': title,
                'artist': artist,
                'duration': duration,
                'videoId': video_id
            }
        except Exception as e:
            logger.error(f"Failed to extract song info: {e}")
            return None
    
    def enqueue_song(self, video_id: str) -> bool:
        """添加歌曲到佇列"""
        data = {'videoId': video_id}
        result = self._make_request('/queue', method='POST', json=data)
        return result is not None
    
    def get_current_song(self) -> Optional[Dict[str, Any]]:
        """獲取當前播放歌曲"""
        return self._make_request('/song')
    
    def is_connected(self) -> bool:
        """檢查是否連接到 YTMD"""
        try:
            response = self._session.get(
                f"{self.base_url}/queue",
                timeout=2
            )
            return response.status_code in [200, 404]  # 404 也表示服務在運行
        except:
            return False
