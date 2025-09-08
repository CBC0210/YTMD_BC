"""
YouTube Music API 服務
負責搜尋歌曲等與 YouTube Music 相關的功能
"""

import logging
from typing import List, Dict, Any
from ytmusicapi import YTMusic

logger = logging.getLogger(__name__)


class YouTubeService:
    """YouTube Music API 服務類"""
    
    def __init__(self):
        self.ytm = None
        self._initialize_ytm()
    
    def _initialize_ytm(self):
        """初始化 YouTube Music API"""
        try:
            self.ytm = YTMusic()
            logger.info("YouTube Music API initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize YouTube Music API: {e}")
            self.ytm = None
    
    def search_songs(self, query: str, limit: int = 15) -> List[Dict[str, Any]]:
        """搜尋歌曲"""
        if not self.ytm:
            raise Exception('YouTube Music API not available')
        
        logger.info(f"Searching for: {query}")
        results = self.ytm.search(query, filter='songs', limit=limit)
        
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
        return simplified_results
    
    def is_available(self) -> bool:
        """檢查 YouTube Music API 是否可用"""
        return self.ytm is not None
