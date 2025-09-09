"""
使用者服務：儲存使用者歷史與喜歡歌曲
簡單檔案型存儲 (JSON) 以避免依賴資料庫
"""

from __future__ import annotations

import json
import os
import threading
from typing import Dict, List


class UserService:
    def __init__(self) -> None:
        base_dir = os.path.dirname(os.path.dirname(__file__))  # app/
        data_dir = os.path.join(base_dir, 'data')
        os.makedirs(data_dir, exist_ok=True)
        self._path = os.path.join(data_dir, 'users.json')
        self._lock = threading.Lock()
        if not os.path.exists(self._path):
            self._write({'users': {}})

    def _read(self) -> Dict:
        with self._lock:
            try:
                with open(self._path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception:
                return {'users': {}}

    def _write(self, data: Dict) -> None:
        with self._lock:
            with open(self._path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

    def _ensure_user(self, nickname: str) -> Dict:
        data = self._read()
        users = data.setdefault('users', {})
        user = users.setdefault(nickname, {'history': [], 'likes': []})
        self._write(data)
        return user

    # History
    def add_history(self, nickname: str, item) -> None:
        data = self._read()
        user = data.setdefault('users', {}).setdefault(nickname, {'history': [], 'likes': []})
        user['history'] = [x for x in user['history'] if x.get('videoId') != item.get('videoId')]
        user['history'].insert(0, item)
        # 只保留最近 200 筆
        user['history'] = user['history'][:200]
        self._write(data)

    def get_history(self, nickname: str) -> List[dict]:
        user = self._ensure_user(nickname)
        return user.get('history', [])

    def clear_history(self, nickname: str) -> None:
        data = self._read()
        user = data.setdefault('users', {}).setdefault(nickname, {'history': [], 'likes': []})
        user['history'] = []
        self._write(data)

    def remove_history_item(self, nickname: str, video_id: str) -> None:
        data = self._read()
        user = data.setdefault('users', {}).setdefault(nickname, {'history': [], 'likes': []})
        user['history'] = [x for x in user.get('history', []) if x.get('videoId') != video_id]
        self._write(data)

    # Likes
    def like_song(self, nickname: str, item) -> None:
        data = self._read()
        user = data.setdefault('users', {}).setdefault(nickname, {'history': [], 'likes': []})
        if item and item.get('videoId') and all(x.get('videoId') != item.get('videoId') for x in user['likes']):
            user['likes'].append(item)
        self._write(data)

    def unlike_song(self, nickname: str, video_id: str) -> None:
        data = self._read()
        user = data.setdefault('users', {}).setdefault(nickname, {'history': [], 'likes': []})
        user['likes'] = [x for x in user.get('likes', []) if x.get('videoId') != video_id]
        self._write(data)

    def get_likes(self, nickname: str) -> List[dict]:
        user = self._ensure_user(nickname)
        return user.get('likes', [])
