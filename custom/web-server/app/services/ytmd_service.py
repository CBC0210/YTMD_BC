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
            for idx, item in enumerate(raw_data['items']):
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
                    
                    # 縮圖
                    thumb = ''
                    try:
                        # 嘗試從 renderer 中取得縮圖
                        # 不同版本可能字段不同，盡量兼容
                        if 'thumbnail' in renderer and 'thumbnails' in renderer['thumbnail']:
                            t_list = renderer['thumbnail']['thumbnails']
                            if isinstance(t_list, list) and len(t_list) > 0:
                                thumb = t_list[-1].get('url', '')
                    except Exception:
                        pass
                    if not thumb and video_id:
                        # 後備: 根據 videoId 組裝 YouTube 縮圖
                        thumb = f'https://i.ytimg.com/vi/{video_id}/hqdefault.jpg'

                    simplified_queue.append({
                        'title': title,
                        'artist': artist,
                        'duration': duration,
                        'videoId': video_id,
                        'index': idx,
                        'thumbnail': thumb,
                    })
        
        logger.info(f"Parsed {len(simplified_queue)} songs from queue")
        return simplified_queue

    def control(self, action: str) -> Tuple[bool, str]:
        """控制播放：play/pause/next/previous/toggle-play"""
        try:
            if action not in ['play', 'pause', 'next', 'previous', 'toggle-play']:
                return False, 'Unsupported action'
            response = requests.post(f'{self.base_url}/{action}', timeout=self.timeout)
            if response.status_code == 204:
                return True, 'ok'
            return False, f'YTMD API error: {response.status_code}'
        except requests.exceptions.RequestException as e:
            logger.error(f"Control action failed: {e}")
            return False, f'YTMD connection failed: {str(e)}'

    def get_volume(self) -> Dict[str, Any]:
        """取得音量狀態 { state: number, isMuted: boolean }"""
        try:
            response = requests.get(f'{self.base_url}/volume', timeout=self.timeout)
            if response.status_code == 200:
                return response.json()
            return {'state': 0, 'isMuted': False}
        except requests.exceptions.RequestException as e:
            logger.error(f"Get volume failed: {e}")
            return {'state': 0, 'isMuted': False}

    def set_volume(self, volume: int) -> Tuple[bool, str]:
        """設定音量 (0-100)"""
        try:
            response = requests.post(f'{self.base_url}/volume', json={'volume': volume}, timeout=self.timeout)
            if response.status_code == 204:
                return True, 'ok'
            return False, f'YTMD API error: {response.status_code}'
        except requests.exceptions.RequestException as e:
            logger.error(f"Set volume failed: {e}")
            return False, f'YTMD connection failed: {str(e)}'
    
    def seek_to(self, seconds: int) -> Tuple[bool, str]:
        """
        絕對時間跳轉到指定秒數
        """
        try:
            response = requests.post(f'{self.base_url}/seek-to', json={'seconds': seconds}, timeout=self.timeout)
            if response.status_code == 204:
                return True, 'ok'
            return False, f'YTMD API error: {response.status_code}'
        except requests.exceptions.RequestException as e:
            logger.error(f"Seek failed: {e}")
            return False, f'YTMD connection failed: {str(e)}'

    def remove_queue_index(self, index: int) -> Tuple[bool, str]:
        """刪除佇列中的指定索引"""
        try:
            response = requests.delete(f'{self.base_url}/queue/{index}', timeout=self.timeout)
            if response.status_code == 204:
                return True, 'ok'
            return False, f'YTMD API error: {response.status_code}'
        except requests.exceptions.RequestException as e:
            logger.error(f"Remove queue index failed: {e}")
            return False, f'YTMD connection failed: {str(e)}'
    
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
                vid = song_data.get('videoId', '')
                # 嘗試取得縮圖，若無則用 videoId 組裝
                thumb = ''
                try:
                    thumbs = song_data.get('thumbnails') or song_data.get('thumbnail')
                    if isinstance(thumbs, list) and thumbs:
                        thumb = thumbs[-1].get('url', '')
                except Exception:
                    pass
                if not thumb and vid:
                    thumb = f'https://i.ytimg.com/vi/{vid}/hqdefault.jpg'
                return {
                    'videoId': vid,
                    'title': song_data.get('title', ''),
                    'artist': song_data.get('artist', ''),
                    'isPaused': song_data.get('isPaused', True),
                    'elapsedSeconds': song_data.get('elapsedSeconds', 0),
                    'songDuration': song_data.get('songDuration', 0),
                    'thumbnail': thumb,
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
    
    def get_lyrics(self, video_id: str, title: str = "", artist: str = "") -> Dict[str, Any]:
        """獲取指定歌曲的歌詞"""
        try:
            # 嘗試從多個來源獲取歌詞，按優先級順序
            providers = [
                ('ytmusic', self._get_lyrics_from_ytmusic),
                ('lrclib', self._get_lyrics_from_lrclib),
                ('genius', self._get_lyrics_from_genius),
                ('musixmatch', self._get_lyrics_from_musixmatch),
            ]
            
            for provider_name, provider_func in providers:
                try:
                    lyrics_data = provider_func(video_id, title, artist)
                    if lyrics_data and (lyrics_data.get('lyrics') or lyrics_data.get('lines')):
                        logger.info(f"Got lyrics from {provider_name} for {title} - {artist}")
                        return lyrics_data
                except Exception as e:
                    logger.warning(f"{provider_name} failed: {e}")
                    continue
            
            # 如果都沒有找到，返回空結果
            return {
                'title': title,
                'artists': [artist] if artist else [],
                'lyrics': None,
                'lines': None,
                'source': 'none'
            }
            
        except Exception as e:
            logger.error(f"Failed to get lyrics: {e}")
            return {
                'title': title,
                'artists': [artist] if artist else [],
                'lyrics': None,
                'lines': None,
                'source': 'error',
                'error': str(e)
            }
    
    def _get_lyrics_from_ytmusic(self, video_id: str, title: str, artist: str) -> Dict[str, Any]:
        """從 YouTube Music 原生獲取歌詞"""
        try:
            # 嘗試通過 YTMD 的內部 API 獲取歌詞
            # 這需要 YTMD 的 synced-lyrics 插件支援
            response = requests.get(f'{self.base_url}/lyrics/{video_id}', timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data.get('lyrics') or data.get('lines'):
                    return {
                        'title': title,
                        'artists': [artist],
                        'lyrics': data.get('lyrics'),
                        'lines': data.get('lines'),
                        'source': 'ytmusic'
                    }
        except Exception as e:
            logger.debug(f"YouTube Music lyrics not available: {e}")
        
        return None
    
    def _get_lyrics_from_lrclib(self, video_id: str, title: str, artist: str) -> Dict[str, Any]:
        """從 LRCLib 獲取歌詞"""
        if not title or not artist:
            return None
            
        # LRCLib API 搜尋
        search_params = {
            'artist_name': artist,
            'track_name': title
        }
        
        search_url = 'https://lrclib.net/api/search'
        response = requests.get(search_url, params=search_params, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            if data and len(data) > 0:
                # 取第一個結果
                track = data[0]
                track_id = track.get('id')
                
                if track_id:
                    # 獲取歌詞詳情
                    lyrics_url = f'https://lrclib.net/api/get/{track_id}'
                    lyrics_response = requests.get(lyrics_url, timeout=10)
                    
                    if lyrics_response.status_code == 200:
                        lyrics_data = lyrics_response.json()
                        
                        # 解析 LRC 格式的歌詞
                        lrc_text = lyrics_data.get('syncedLyrics', '')
                        if lrc_text:
                            lines = self._parse_lrc_lyrics(lrc_text)
                            return {
                                'title': lyrics_data.get('trackName', title),
                                'artists': [lyrics_data.get('artistName', artist)],
                                'lyrics': None,
                                'lines': lines,
                                'source': 'lrclib'
                            }
        
        return None
    
    def _get_lyrics_from_genius(self, video_id: str, title: str, artist: str) -> Dict[str, Any]:
        """從 Genius 獲取歌詞"""
        if not title or not artist:
            return None
            
        try:
            # Genius 搜尋 API
            search_params = {
                'q': f"{artist} {title}",
                'page': '1',
                'per_page': '10'
            }
            
            search_url = 'https://genius.com/api/search/song'
            response = requests.get(search_url, params=search_params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                hits = data.get('response', {}).get('sections', [{}])[0].get('hits', [])
                
                if hits:
                    # 取第一個結果
                    song_data = hits[0].get('result', {})
                    song_path = song_data.get('path')
                    
                    if song_path:
                        # 獲取歌詞頁面
                        lyrics_url = f'https://genius.com{song_path}'
                        lyrics_response = requests.get(lyrics_url, timeout=10)
                        
                        if lyrics_response.status_code == 200:
                            # 簡單解析 HTML 獲取歌詞
                            import re
                            html_content = lyrics_response.text
                            
                            # 嘗試從 JSON 數據中提取歌詞
                            json_match = re.search(r'window\.__PRELOADED_STATE__ = JSON\.parse\(\'(.*?)\'\);', html_content)
                            if json_match:
                                import json
                                try:
                                    preloaded_data = json.loads(json_match.group(1).replace('\\"', '"'))
                                    # 這裡需要根據實際的 JSON 結構來解析歌詞
                                    # 由於 Genius 的結構複雜，暫時返回基本資訊
                                    return {
                                        'title': song_data.get('title', title),
                                        'artists': [song_data.get('primary_artist', {}).get('name', artist)],
                                        'lyrics': None,  # 需要更複雜的解析
                                        'lines': None,
                                        'source': 'genius'
                                    }
                                except:
                                    pass
                            
                            # 備用方法：從 HTML 中提取歌詞
                            lyrics_match = re.search(r'<div[^>]*class="[^"]*lyrics[^"]*"[^>]*>(.*?)</div>', html_content, re.DOTALL)
                            if lyrics_match:
                                lyrics_html = lyrics_match.group(1)
                                # 簡單清理 HTML 標籤
                                lyrics_text = re.sub(r'<[^>]+>', '', lyrics_html)
                                lyrics_text = re.sub(r'\s+', ' ', lyrics_text).strip()
                                
                                if lyrics_text:
                                    return {
                                        'title': song_data.get('title', title),
                                        'artists': [song_data.get('primary_artist', {}).get('name', artist)],
                                        'lyrics': lyrics_text,
                                        'lines': None,
                                        'source': 'genius'
                                    }
        except Exception as e:
            logger.debug(f"Genius lyrics failed: {e}")
        
        return None
    
    def _get_lyrics_from_musixmatch(self, video_id: str, title: str, artist: str) -> Dict[str, Any]:
        """從 MusixMatch 獲取歌詞（簡化版本）"""
        if not title or not artist:
            return None
            
        try:
            # MusixMatch 需要複雜的認證和 API 調用
            # 這裡實現一個簡化版本，使用公開的搜尋功能
            
            # 構建搜尋 URL
            search_query = f"{artist} {title}".replace(' ', '+')
            search_url = f"https://www.musixmatch.com/search/{search_query}"
            
            response = requests.get(search_url, timeout=10, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            })
            
            if response.status_code == 200:
                # 簡單解析 HTML 找到歌曲連結
                import re
                html_content = response.text
                
                # 尋找歌曲連結
                song_links = re.findall(r'href="(/lyrics/[^"]+)"', html_content)
                if song_links:
                    # 取第一個結果
                    song_url = f"https://www.musixmatch.com{song_links[0]}"
                    
                    # 獲取歌詞頁面
                    lyrics_response = requests.get(song_url, timeout=10, headers={
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                    })
                    
                    if lyrics_response.status_code == 200:
                        lyrics_html = lyrics_response.text
                        
                        # 提取歌詞內容
                        lyrics_match = re.search(r'<span[^>]*class="[^"]*lyrics__content__[^"]*"[^>]*>(.*?)</span>', lyrics_html, re.DOTALL)
                        if lyrics_match:
                            lyrics_text = lyrics_match.group(1)
                            # 清理 HTML 標籤
                            lyrics_text = re.sub(r'<[^>]+>', '', lyrics_text)
                            lyrics_text = re.sub(r'\s+', ' ', lyrics_text).strip()
                            
                            if lyrics_text:
                                return {
                                    'title': title,
                                    'artists': [artist],
                                    'lyrics': lyrics_text,
                                    'lines': None,
                                    'source': 'musixmatch'
                                }
        except Exception as e:
            logger.debug(f"MusixMatch lyrics failed: {e}")
        
        return None
    
    def _parse_lrc_lyrics(self, lrc_text: str) -> List[Dict[str, Any]]:
        """解析 LRC 格式的歌詞"""
        lines = []
        
        for line in lrc_text.split('\n'):
            line = line.strip()
            if not line:
                continue
                
            # 匹配時間標記 [mm:ss.xx]
            import re
            time_match = re.match(r'\[(\d{2}):(\d{2})\.(\d{2})\]', line)
            if time_match:
                minutes = int(time_match.group(1))
                seconds = int(time_match.group(2))
                centiseconds = int(time_match.group(3))
                
                time_in_ms = (minutes * 60 + seconds) * 1000 + centiseconds * 10
                time_str = f"{minutes:02d}:{seconds:02d}.{centiseconds:02d}"
                
                # 提取歌詞文字
                text = line[time_match.end():].strip()
                
                if text:
                    lines.append({
                        'time': time_str,
                        'timeInMs': time_in_ms,
                        'duration': 2000,  # 預設持續時間 2 秒
                        'text': text,
                        'status': 'upcoming'
                    })
        
        return lines

    def is_connected(self) -> bool:
        """檢查 YTMD API 是否可用"""
        try:
            response = requests.get(f'{self.base_url}/song', timeout=3)
            return response.status_code in [200, 204]
        except:
            return False
