#!/usr/bin/env python3
"""
IP 檢測工具
獲取本機可用的 IP 地址
"""
import socket
import sys

def get_local_ip():
    """獲取本機 IP 地址"""
    try:
        # 連接到外部地址來獲取本機 IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def get_all_ips():
    """獲取所有可用的 IP 地址"""
    import netifaces
    ips = []
    
    for interface in netifaces.interfaces():
        try:
            addresses = netifaces.ifaddresses(interface)
            if netifaces.AF_INET in addresses:
                for addr in addresses[netifaces.AF_INET]:
                    ip = addr['addr']
                    if ip != '127.0.0.1':
                        ips.append(ip)
        except:
            continue
    
    return ips

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--all":
        try:
            ips = get_all_ips()
            for ip in ips:
                print(ip)
        except ImportError:
            # 如果沒有 netifaces，只返回主要 IP
            print(get_local_ip())
    else:
        print(get_local_ip())
