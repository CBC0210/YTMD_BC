"""
網路工具模組
"""
import socket
import logging

logger = logging.getLogger(__name__)

def get_server_ip():
    """獲取服務器 IP 地址"""
    try:
        # 連接到外部地址來獲取本機 IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        logger.debug(f"Detected server IP: {ip}")
        return ip
    except Exception as e:
        logger.warning(f"Failed to detect server IP: {e}, using localhost")
        return "localhost"

def is_port_open(host, port, timeout=5):
    """檢查端口是否開放"""
    try:
        with socket.create_connection((host, port), timeout):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False
