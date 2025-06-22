#!/usr/bin/env python3
"""
Web 服務狀態檢查器
檢查 Flask 服務器和 YTMD 是否正常運行
"""
import requests
import sys
import time

def check_ytmd_api(host="localhost", port=26538, timeout=5):
    """檢查 YTMD API 是否可用"""
    try:
        url = f"http://{host}:{port}/api/v1/song"
        response = requests.get(url, timeout=timeout)
        return response.status_code in [200, 204]
    except:
        return False

def check_web_server(host="localhost", port=8080, timeout=5):
    """檢查 Flask Web 服務器是否可用"""
    try:
        url = f"http://{host}:{port}/queue"
        response = requests.get(url, timeout=timeout)
        return response.status_code == 200
    except:
        return False

def wait_for_service(check_func, service_name, max_wait=30):
    """等待服務啟動"""
    print(f"⏳ 等待 {service_name} 啟動...")
    
    for i in range(max_wait):
        if check_func():
            print(f"✅ {service_name} 已啟動")
            return True
        
        if i < max_wait - 1:
            print(".", end="", flush=True)
            time.sleep(1)
    
    print(f"\n❌ {service_name} 啟動超時")
    return False

if __name__ == "__main__":
    if len(sys.argv) > 1:
        service = sys.argv[1]
        
        if service == "ytmd":
            success = check_ytmd_api()
            print("✅ YTMD API 可用" if success else "❌ YTMD API 不可用")
            sys.exit(0 if success else 1)
        elif service == "web":
            success = check_web_server()
            print("✅ Web 服務器可用" if success else "❌ Web 服務器不可用")
            sys.exit(0 if success else 1)
    
    # 檢查所有服務
    print("🔍 檢查服務狀態...")
    
    ytmd_ok = check_ytmd_api()
    web_ok = check_web_server()
    
    print(f"YTMD API:    {'✅ 運行中' if ytmd_ok else '❌ 離線'}")
    print(f"Web 服務器:   {'✅ 運行中' if web_ok else '❌ 離線'}")
    
    if ytmd_ok and web_ok:
        print("🎉 所有服務正常運行！")
        sys.exit(0)
    else:
        print("⚠️  部分服務未運行")
        sys.exit(1)
