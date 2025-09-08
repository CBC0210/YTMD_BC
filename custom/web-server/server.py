"""
YTMD Web Server
重構版本 - 使用模組化架構
"""

import logging
import signal
import sys
import os

from app.app_factory import create_app
from app.services.monitor_service import MonitorService
from app.utils.network import get_server_ip

# 設置日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 全局變量
monitor_service = None


def signal_handler(sig, frame):
    """處理中斷信號"""
    global monitor_service
    
    logger.info("🛑 收到中斷信號，正在關閉服務器...")
    
    if monitor_service:
        monitor_service.stop_monitoring()
    
    sys.exit(0)


def main():
    """主函數"""
    global monitor_service
    
    # 註冊信號處理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("🚀 啟動 YTMD Web Server...")
    
    # 創建 Flask 應用程式
    app = create_app()
    
    # 創建並啟動監控服務
    monitor_service = MonitorService()
    monitor_service.start_monitoring()
    
    # 顯示啟動信息
    ytmd_api = os.getenv('YTMD_API', 'http://localhost:26538/api/v1')
    server_ip = get_server_ip()
    
    logger.info(f"🔗 YTMD API 端點: {ytmd_api}")
    logger.info(f"🌐 服務器 IP: {server_ip}")
    logger.info(f"📱 Web 介面: http://{server_ip}:8080")
    
    # 根據環境變數決定是否啟用調試模式
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    try:
        app.run(host='0.0.0.0', port=8080, debug=debug_mode, use_reloader=False)
    except KeyboardInterrupt:
        logger.info("🛑 收到鍵盤中斷，正在關閉...")
    except Exception as e:
        logger.error(f"❌ 服務器錯誤: {e}")
    finally:
        if monitor_service:
            monitor_service.stop_monitoring()
        logger.info("👋 YTMD Web Server 已關閉")


if __name__ == '__main__':
    main()
