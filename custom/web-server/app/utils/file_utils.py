"""
文件操作工具
負責讀取配置文件和說明文字等文件操作
"""

import os
import logging

logger = logging.getLogger(__name__)


def read_instructions() -> str:
    """讀取點歌說明文字"""
    try:
        # 嘗試讀取自定義說明文件
        # 從 web-server/app/utils/file_utils.py 往上找到專案根目錄
        instructions_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), 
            'config', 
            'instructions.txt'
        )
        
        if os.path.exists(instructions_path):
            with open(instructions_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                return content
        else:
            # 默認說明文字
            return """✦ 點歌教學
1. 掃下方 QR Code
2. 搜尋並加入歌曲
3. 立即播放！
"""
    except Exception as e:
        logger.error(f"Failed to read instructions: {e}")
        return '✦ 點歌教學\n1. 掃下方 QR Code\n2. 搜尋並加入歌曲\n3. 立即播放！'
