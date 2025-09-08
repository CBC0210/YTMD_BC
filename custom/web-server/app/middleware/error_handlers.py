"""
錯誤處理中間件
定義全局錯誤處理器
"""

from flask import jsonify
import logging

logger = logging.getLogger(__name__)


def register_error_handlers(app):
    """註冊錯誤處理器到 Flask 應用程式"""
    
    @app.errorhandler(404)
    def not_found(error):
        logger.warning(f"404 Not Found: {error}")
        return jsonify({'error': 'Not found'}), 404

    @app.errorhandler(500)
    def internal_error(error):
        logger.error(f"500 Internal Error: {error}")
        return jsonify({'error': 'Internal server error'}), 500
    
    @app.errorhandler(Exception)
    def handle_exception(error):
        logger.error(f"Unhandled exception: {error}")
        return jsonify({'error': 'An unexpected error occurred'}), 500
