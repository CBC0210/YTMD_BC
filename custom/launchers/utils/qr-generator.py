#!/usr/bin/env python3
"""
QR Code 生成器
為點歌系統生成 QR Code
"""
import sys
import os

try:
    import qrcode
except ImportError:
    print("錯誤：需要安裝 qrcode 套件")
    print("請執行：pip install qrcode[pil]")
    sys.exit(1)

def generate_qr_code(url, save_image=True):
    """生成 QR Code"""
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(url)
        qr.make(fit=True)
        
        # 終端顯示
        print("📱 掃描以下 QR Code 開始點歌：")
        qr.print_ascii(invert=True)
        
        # 保存圖片
        if save_image:
            img = qr.make_image(fill_color="black", back_color="white")
            img_path = "ytmd-web-qr.png"
            img.save(img_path)
            print(f"💾 QR Code 已保存為：{img_path}")
        
        return True
    except Exception as e:
        print(f"❌ QR Code 生成失敗：{e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("使用方式：python qr-generator.py <URL>")
        sys.exit(1)
    
    url = sys.argv[1]
    save_image = "--no-save" not in sys.argv
    
    print(f"🌐 點歌系統網址：{url}")
    ok = generate_qr_code(url, save_image)
    # 顯示可點擊連結（大部分終端會自動偵測），同時提供 ANSI 超連結（支援的終端可直接點）
    try:
        ansi_link = f"\x1b]8;;{url}\x1b\\{url}\x1b]8;;\x1b\\"
        print(f"\n🔗 直接點擊連結：{url}")
        print(ansi_link)
    except Exception:
        pass
    sys.exit(0 if ok else 1)
