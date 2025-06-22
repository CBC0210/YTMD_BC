import { createPlugin } from '@/utils';
import style from './style.css?inline';
import QRCode from 'qrcode';
import cfg from './config.json';

export default createPlugin({
  name: () => 'YTMD 點歌系統',
  description: () => '顯示點歌系統教學與 QR Code，方便手機掃描點歌',
  restartNeeded: false,
  stylesheets: [style],
  config: { enabled: true },

  renderer: {
    async start() {
      console.log('[Side Info] Plugin starting...');
      console.log('[Side Info] Document ready state:', document.readyState);
      console.log('[Side Info] Current URL:', window.location.href);
      
      // 添加一個延遲確保頁面完全載入
      await new Promise(resolve => setTimeout(resolve, 2000));
      console.log('[Side Info] After 2s delay, starting plugin injection...');
      
      // 先嘗試直接添加到 body
      const existingSide = document.getElementById('ext-side-info');
      if (existingSide) {
        existingSide.remove();
        console.log('[Side Info] Removed existing element');
      }

      const side = document.createElement('div');
      side.id = 'ext-side-info';
      side.style.cssText = `
        position: fixed !important;
        top: 20px !important;
        right: 20px !important;
        width: 260px !important;
        z-index: 999999 !important;
        background: rgba(30, 30, 30, 0.95) !important;
        border: 2px solid #e74c3c !important;
        border-radius: 12px !important;
        padding: 16px !important;
        box-shadow: 0 4px 20px rgba(0,0,0,0.5) !important;
        font-family: Arial, sans-serif !important;
        pointer-events: auto !important;
      `;

      // 上卡片：使用說明文字
      const msg = document.createElement('div');
      msg.style.cssText = `
        background: #2a2a2a !important;
        border-radius: 8px !important;
        padding: 12px !important;
        margin-bottom: 12px !important;
        color: #fff !important;
        font-size: 14px !important;
        text-align: center !important;
        white-space: pre-line !important;
      `;
      
      // 先顯示默認文字
      msg.innerHTML = `<b style="color: #e74c3c;">✦ 點歌教學</b><br/>1. 掃下方 QR Code<br/>2. 搜尋並加入歌曲<br/>3. 立即播放！`;
      
      // 嘗試獲取自定義說明文字
      try {
        const response = await fetch('http://localhost:8080/instructions', { 
          signal: AbortSignal.timeout(3000)
        });
        if (response.ok) {
          const data = await response.json() as { instructions?: string };
          if (data.instructions) {
            // 將第一行作為標題處理
            const lines = data.instructions.split('\n');
            const title = lines[0].includes('✦') ? lines[0] : `✦ ${lines[0]}`;
            const content = lines.slice(1).join('\n');
            msg.innerHTML = `<b style="color: #e74c3c;">${title}</b>${content}`;
          }
        }
      } catch (error) {
        console.log('[Side Info] Using default instructions, custom fetch failed:', error);
      }
      
      side.appendChild(msg);

      // 下卡片：QR Code
      const qr = document.createElement('div');
      qr.style.cssText = `
        background: #2a2a2a !important;
        border-radius: 8px !important;
        padding: 12px !important;
        text-align: center !important;
      `;
      
      const statusMsg = document.createElement('div');
      statusMsg.style.cssText = 'color: #fff !important; font-size: 12px !important; margin-bottom: 8px !important;';
      statusMsg.textContent = '正在生成 QR Code...';
      qr.appendChild(statusMsg);
      
      const canvas = document.createElement('canvas');
      canvas.style.cssText = 'width: 100% !important; height: auto !important; max-width: 200px !important;';
      qr.appendChild(canvas);
      side.appendChild(qr);
      
      document.body.appendChild(side);
      console.log('[Side Info] Element added to body');
      console.log('[Side Info] Element bounds:', side.getBoundingClientRect());

      // 生成 QR Code
      try {
        let url = cfg.serverUrl || 'http://localhost:8080';
        
        // 如果啟用自動檢測 IP，嘗試獲取本機 IP
        if (cfg.autoDetectIp) {
          try {
            // 嘗試從多個可能的本機 IP 中找到可用的
            const response = await fetch('http://localhost:8080/queue', { 
              method: 'GET',
              signal: AbortSignal.timeout(2000)
            });
            if (response.ok) {
              url = 'http://localhost:8080';
            }
          } catch {
            // 如果 localhost 不可用，使用配置的備用 URL
            url = cfg.fallbackUrl || cfg.serverUrl || 'http://192.168.1.100:8080';
          }
        }
        
        console.log('[Side Info] Generating QR Code for URL:', url);
        await QRCode.toCanvas(canvas, url, { width: 200, margin: 1 });
        statusMsg.textContent = '掃描 QR Code 開始點歌';
        statusMsg.style.color = '#4ade80';
        console.log('[Side Info] QR Code generated successfully');
        console.log('[Side Info] Canvas dimensions:', canvas.width, 'x', canvas.height);
      } catch (error) {
        console.error('[Side Info] QR Code generation failed:', error);
        const errorMessage = error instanceof Error ? error.message : String(error);
        statusMsg.textContent = 'QR Code 生成失敗: ' + errorMessage;
        statusMsg.style.color = '#ef4444';
        canvas.style.display = 'none';
      }

      // 額外的調試信息
      console.log('[Side Info] Plugin injection completed');
      console.log('[Side Info] Final element in DOM:', document.getElementById('ext-side-info'));
    },
    
    stop() {
      const side = document.getElementById('ext-side-info');
      if (side) {
        side.remove();
        console.log('[Side Info] Plugin stopped and removed');
      }
    }
  }
});
