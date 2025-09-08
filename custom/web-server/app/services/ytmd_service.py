"""
YTMD API 服務
負責與 YTMD 應用程式的 API 通信
"""

import requests
import logging
import os
from typing import Dict, List, Tuple, Any

logger = logging.getLogger(__name__)


class YTMDService:
    """YTMD API 服務類"""
    
    def __init__(self):
        self.base_url = os.getenv('YTMD_API', 'http://localhost:26538/api/v1')
        self.timeout = 10
    
    def get_queue(self) -> List[Dict[str, Any]]:
        """獲取當前佇列"""
        try:
            response = requests.get(f'{self.base_url}/queue', timeout=self.timeout)
            if response.status_code == 200:
                raw_data = response.json()
                return self._parse_queue_data(raw_data)
            else:
                logger.error(f"Failed to get queue: {response.status_code}")
                return []
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to YTMD failed: {e}")
            # 返回空佇列而不是拋出異常
            return []
    
    def _parse_queue_data(self, raw_data: Dict) -> List[Dict[str, Any]]:
        """解析 YTMD 的複雜佇列格式"""
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
        return simplified_queue
    
    def enqueue_song(self, video_id: str) -> Tuple[bool, str]:
        """加入歌曲到佇列最後面"""
        try:
            logger.info(f"Adding to queue: {video_id}")
            
            # 根據 API 文檔，使用正確的請求格式
            payload = {
                'videoId': video_id,
                'insertPosition': 'INSERT_AT_END'  # 加入到佇列最後面
            }
            
            response = requests.post(
                f'{self.base_url}/queue',
                json=payload,
                timeout=self.timeout
            )
            
            logger.info(f"YTMD API response: {response.status_code}")
            
            if response.status_code == 204:
                logger.info(f"Successfully added to queue: {video_id}")
                return True, f'歌曲已加入佇列: {video_id}'
            else:
                logger.error(f"YTMD API returned status {response.status_code}: {response.text}")
                return False, f'YTMD API error: {response.status_code}'
                
        except requests.exceptions.Timeout:
            logger.error("YTMD API timeout")
            return False, 'YTMD API timeout'
        except requests.exceptions.ConnectionError:
            logger.error("Cannot connect to YTMD API")
            return False, 'Cannot connect to YTMD API'
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to YTMD failed: {e}")
            return False, f'YTMD connection failed: {str(e)}'
    
    def get_current_song(self) -> Dict[str, Any]:
        """獲取當前播放的歌曲信息"""
        try:
            response = requests.get(f'{self.base_url}/song', timeout=self.timeout)
            if response.status_code == 200:
                song_data = response.json()
                # 簡化回傳格式，只包含我們需要的信息
                return {
                    'videoId': song_data.get('videoId', ''),
                    'title': song_data.get('title', ''),
                    'artist': song_data.get('artist', ''),
                    'isPaused': song_data.get('isPaused', True),
                    'elapsedSeconds': song_data.get('elapsedSeconds', 0),
                    'songDuration': song_data.get('songDuration', 0)
                }
            elif response.status_code == 204:
                # 沒有歌曲在播放
                return {'videoId': None}
            else:
                logger.error(f"Failed to get current song: {response.status_code}")
                raise Exception('Failed to get current song')
        except requests.exceptions.RequestException as e:
            logger.error(f"Request to YTMD failed: {e}")
            raise Exception('YTMD connection failed')
    
    def is_connected(self) -> bool:
        """檢查 YTMD API 是否可用"""
        try:
            response = requests.get(f'{self.base_url}/song', timeout=3)
            return response.status_code in [200, 204]
        except:
            return False
