"""
監控服務
負責監控 YTMD API 狀態和自動關閉機制
"""

import threading
import time
import logging
import os
import sys
from typing import Optional

from .ytmd_service import YTMDService

logger = logging.getLogger(__name__)


class MonitorService:
    """監控服務類"""
    
    def __init__(self):
        self.ytmd_service = YTMDService()
        self.server_start_time = time.time()
        self.ytmd_connected = False
        self.auto_shutdown_enabled = True
        self.shutdown_timer: Optional[threading.Timer] = None
        self.monitor_thread: Optional[threading.Thread] = None
    
    def start_monitoring(self):
        """啟動監控服務"""
        # 啟動 YTMD 監控線程
        self.monitor_thread = threading.Thread(target=self._ytmd_monitor, daemon=True)
        self.monitor_thread.start()
        
        # 設置 5 分鐘自動關閉定時器
        self.shutdown_timer = threading.Timer(300.0, self._auto_shutdown)  # 300 秒 = 5 分鐘
        self.shutdown_timer.start()
        logger.info("⏰ 設置 5 分鐘自動關閉定時器（如果 YTMD API 無法連接）")
    
    def stop_monitoring(self):
        """停止監控服務"""
        self.auto_shutdown_enabled = False
        
        if self.shutdown_timer:
            self.shutdown_timer.cancel()
            logger.info("📋 取消自動關閉定時器")
    
    def _ytmd_monitor(self):
        """監控 YTMD API 狀態的後台線程"""
        logger.info("YTMD 監控線程啟動")
        
        # 每 30 秒檢查一次 YTMD API
        while self.auto_shutdown_enabled:
            if self.ytmd_service.is_connected():
                if not self.ytmd_connected:
                    logger.info("✅ YTMD API 已連接")
                    self.ytmd_connected = True
                    # 取消自動關閉定時器
                    if self.shutdown_timer:
                        self.shutdown_timer.cancel()
                        self.shutdown_timer = None
                        logger.info("📋 取消自動關閉定時器")
            else:
                if self.ytmd_connected:
                    logger.warning("⚠️ YTMD API 連接丟失")
                    self.ytmd_connected = False
            
            time.sleep(30)  # 每 30 秒檢查一次
    
    def _auto_shutdown(self):
        """5分鐘後自動關閉伺服器（如果 YTMD 仍未連接）"""
        logger.warning("⏰ 5 分鐘自動關閉定時器觸發")
        
        if not self.ytmd_connected:
            logger.error("❌ 5 分鐘後 YTMD API 仍無法連接，自動關閉服務器")
            logger.info("💡 提示：請確保 YTMD 應用程式正在運行，然後重新啟動點歌服務")
            
            # 優雅地關閉服務器
            threading.Timer(1.0, lambda: os._exit(0)).start()
        else:
            logger.info("✅ YTMD API 已連接，取消自動關閉")
    
    def is_ytmd_connected(self) -> bool:
        """檢查 YTMD 是否已連接"""
        return self.ytmd_connected
