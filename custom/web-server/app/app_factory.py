"""
Flask 應用程式工廠
負責創建和配置 Flask 應用程式
"""

from flask import Flask
from flask_cors import CORS
import logging
import os

from .api.routes import api_blueprint
from .middleware.error_handlers import register_error_handlers

logger = logging.getLogger(__name__)


def create_app() -> Flask:
    """創建 Flask 應用程式"""
    # 設置正確的模板和靜態文件路徑
    import os
    base_dir = os.path.dirname(os.path.dirname(__file__))  # 回到 web-server 目錄
    template_dir = os.path.join(base_dir, 'templates')
    static_dir = os.path.join(base_dir, 'static')
    
    app = Flask(__name__, 
                template_folder=template_dir,
                static_folder=static_dir)
    
    # 配置 CORS，允許來自 YouTube Music、localhost 與 ngrok 網域
    ngrok_host = os.getenv('NGROK_HOST')  # 例如 76962366566f.ngrok-free.app
    cors_origins = [
        "https://music.youtube.com",
        "https://www.youtube.com",
        "http://localhost:*",
        "https://localhost:*",
        r"https://*.ngrok-free.app",
        r"https://*.ngrok.io",
    ]
    if ngrok_host:
        cors_origins.append(f"https://{ngrok_host}")
    CORS(app, origins=cors_origins)
    
    # 註冊藍圖
    app.register_blueprint(api_blueprint)
    
    # 註冊錯誤處理器
    register_error_handlers(app)
    
    logger.info("Flask 應用程式已創建並配置完成")
    return app
