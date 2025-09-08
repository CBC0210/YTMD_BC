"""
應用配置模組
"""
import os
import logging

class Config:
    """基礎配置"""
    # Flask 配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'ytmd-web-server-secret'
    DEBUG = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    # YTMD API 配置
    YTMD_API_BASE = os.environ.get('YTMD_API', 'http://localhost:26538/api/v1')
    YTMD_CONNECTION_TIMEOUT = 5
    
    # Web 服務器配置
    HOST = os.environ.get('HOST', '0.0.0.0')
    PORT = int(os.environ.get('PORT', 8080))
    
    # CORS 配置
    CORS_ORIGINS = [
        "https://music.youtube.com",
        "https://www.youtube.com", 
        "http://localhost:*",
        "https://localhost:*"
    ]
    
    # 監控配置
    AUTO_SHUTDOWN_TIMEOUT = 300  # 5 分鐘
    HEALTH_CHECK_INTERVAL = 30   # 30 秒
    
    # 日誌配置
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

class DevelopmentConfig(Config):
    """開發環境配置"""
    DEBUG = True

class ProductionConfig(Config):
    """生產環境配置"""
    DEBUG = False

# 根據環境選擇配置
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}

def setup_logging(level=None):
    """設置日誌"""
    if level is None:
        level = Config.LOG_LEVEL
    
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    return logging.getLogger(__name__)
