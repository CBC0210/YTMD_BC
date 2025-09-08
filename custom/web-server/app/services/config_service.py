"""
配置服務
負責提供應用程式配置和客戶端配置
"""

import logging
from typing import Dict, Any

from ..utils.network import get_server_ip

logger = logging.getLogger(__name__)


class ConfigService:
    """配置服務類"""
    
    def __init__(self):
        self.server_ip = get_server_ip()
    
    def get_client_config(self) -> Dict[str, Any]:
        """提供配置信息給前端和插件"""
        return {
            'serverUrl': f'http://{self.server_ip}:8080',
            'localUrl': 'http://localhost:8080',
            'serverIp': self.server_ip,
            'status': 'running'
        }
    
    def get_server_ip(self) -> str:
        """獲取服務器 IP 地址"""
        return self.server_ip
