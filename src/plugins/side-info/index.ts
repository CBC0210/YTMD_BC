import { createPlugin } from '@/utils';
import style from './style.css?inline';
import cfg from './config.json';

export default createPlugin<
  unknown,
  unknown,
  {
    observer: MutationObserver | null;
    timeoutId: NodeJS.Timeout | null;
  // 新增：控制 QR 生成的狀態與開關
  qrGenerated: boolean;
  qrDisabled: boolean;
    initializeWhenReady(): void;
    injectSideInfo(): Promise<void>;
    stop(): void;
  }
>({
  name: () => 'YTMD 點歌系統',
  description: () => '顯示點歌系統教學與 QR Code，方便手機掃描點歌',
  restartNeeded: false,
  stylesheets: [style],
  config: { enabled: true },

  renderer: {
    observer: null,
    timeoutId: null,
    
    // 避免重複生成 QR 與便於快速禁用
    qrGenerated: false,
    get qrDisabled() {
      // 允許使用者快速禁用（環境變數或 localStorage 開關）
      // - 環境變數：YTMD_NO_QR=1
      // - localStorage：localStorage.setItem('YTMD_NO_QR','1')
      try {
        // @ts-ignore
        const envNoQr = typeof process !== 'undefined' && process?.env?.YTMD_NO_QR === '1';
        const lsNoQr = typeof localStorage !== 'undefined' && localStorage.getItem('YTMD_NO_QR') === '1';
        return envNoQr || lsNoQr || cfg.showQrCode === false;
      } catch {
        return cfg.showQrCode === false;
      }
    },
    
    async start() {
      console.log('[Side Info] Plugin starting...');
      console.log('[Side Info] Document ready state:', document.readyState);
      console.log('[Side Info] Current URL:', window.location.href);
      
      // 強制顯示插件信息到頁面標題，確認插件有運行
      document.title = document.title + ' [Side Info Active]';
      
      // 使用更可靠的初始化方式
      this.initializeWhenReady();
    },

    initializeWhenReady() {
      const tryInject = () => {
        if (document.body && document.readyState === 'complete') {
          this.injectSideInfo();
        } else {
          // 如果還沒準備好，繼續等待
          setTimeout(tryInject, 100);
        }
      };

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', tryInject);
        window.addEventListener('load', tryInject);
      } else {
        tryInject();
      }

      // 設置 DOM 變化監聽器，以應對 SPA 路由變化
      if (!this.observer) {
        this.observer = new MutationObserver((mutations) => {
          // 只在真正需要時才重新注入
          let shouldReinject = false;
          
          for (const mutation of mutations) {
            // 檢查是否我們的元素被移除了
            for (const removedNode of mutation.removedNodes) {
              if (removedNode instanceof Element && 
                  (removedNode.id === 'ext-side-info' || 
                   removedNode.querySelector?.('#ext-side-info'))) {
                shouldReinject = true;
                break;
              }
            }
            
            // 檢查是否頁面結構發生重大變化（如路由切換）
            if (mutation.type === 'childList' && 
                mutation.target === document.body &&
                mutation.addedNodes.length > 0) {
              // 檢查是否是路由變化導致的主要內容更新
              for (const addedNode of mutation.addedNodes) {
                if (addedNode instanceof Element && 
                    addedNode.querySelector?.('[role="main"], #main, main')) {
                  shouldReinject = true;
                  break;
                }
              }
            }
            
            if (shouldReinject) break;
          }
          
          if (shouldReinject && !document.getElementById('ext-side-info')) {
            // 延遲執行以避免頻繁觸發
            if (this.timeoutId) {
              clearTimeout(this.timeoutId);
            }
            this.timeoutId = setTimeout(() => this.injectSideInfo(), 1000);
          }
        });
        
        this.observer.observe(document.body || document.documentElement, {
          childList: true,
          subtree: false // 只監聽直接子元素變化，避免過度觸發
        });
      }
    },

  async injectSideInfo() {
      // 先移除現有元素
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
        console.log('[Side Info] 嘗試獲取自定義說明文字...');
        const response = await fetch('http://localhost:8080/instructions', { 
          signal: AbortSignal.timeout(3000),
          mode: 'cors'
        });
        if (response.ok) {
          const data = await response.json() as { instructions?: string };
          console.log('[Side Info] 獲取到自定義說明:', data);
          if (data.instructions) {
            // 將第一行作為標題處理
            const lines = data.instructions.split('\n');
            const title = lines[0].includes('✦') ? lines[0] : `✦ ${lines[0]}`;
            const content = lines.slice(1).join('<br/>');
            msg.innerHTML = `<b style="color: #e74c3c;">${title}</b><br/>${content}`;
            console.log('[Side Info] 使用自定義說明文字');
          }
        } else {
          console.log('[Side Info] 說明文字 API 返回錯誤:', response.status);
        }
      } catch (error) {
        console.log('[Side Info] 無法獲取自定義說明文字，使用默認:', error);
      }
      
      side.appendChild(msg);

      // 下卡片：QR Code（可延後、可禁用）
      const qr = document.createElement('div');
      qr.style.cssText = `
        background: #2a2a2a !important;
        border-radius: 8px !important;
        padding: 12px !important;
        text-align: center !important;
      `;
      const statusMsg = document.createElement('div');
      statusMsg.style.cssText = 'color: #fff !important; font-size: 12px !important; margin-bottom: 8px !important;';
      const canvas = document.createElement('canvas');
      canvas.style.cssText = 'width: 100% !important; height: auto !important; max-width: 200px !important;';

      if (this.qrDisabled) {
        statusMsg.textContent = 'QR Code 已停用';
        statusMsg.style.color = '#999';
        qr.appendChild(statusMsg);
      } else {
        statusMsg.textContent = '等待閒置後生成 QR Code…';
        qr.appendChild(statusMsg);
        qr.appendChild(canvas);
      }
      side.appendChild(qr);
      
      document.body.appendChild(side);
      console.log('[Side Info] Element added to body');
      console.log('[Side Info] Element bounds:', side.getBoundingClientRect());

      // 生成 QR Code（延後到頁面閒置）
      const scheduleQr = () => {
        if (this.qrDisabled || this.qrGenerated) return;
        const run = async () => {
          if (this.qrDisabled || this.qrGenerated) return;
          this.qrGenerated = true;
          statusMsg.textContent = '正在生成 QR Code...';
          try {
            // 動態載入，避免在啟動階段佔用主執行緒
            const { default: QR } = await import('qrcode');
            let url = cfg.serverUrl || 'http://localhost:8080';

            // 1) 優先使用 /public-links
            try {
              console.log('[Side Info] 嘗試從 /public-links 讀取公開連結...');
              const resp = await fetch('http://localhost:8080/public-links', {
                method: 'GET',
                signal: AbortSignal.timeout(2000),
                mode: 'cors'
              });
              if (resp.ok) {
                const data = await resp.json() as {
                  frontend?: { public?: string | null; local?: string | null };
                  backend?: { public?: string | null; local?: string | null };
                };
                const pref = data?.frontend?.public || data?.frontend?.local;
                if (pref && typeof pref === 'string') {
                  url = pref;
                  console.log('[Side Info] 使用 public-links 前端網址:', url);
                } else {
                  console.log('[Side Info] public-links 無可用的前端網址，使用後備策略');
                }
              } else {
                console.log('[Side Info] /public-links 回應非 200:', resp.status);
              }
            } catch (e) {
              console.log('[Side Info] 讀取 /public-links 失敗，將使用後備策略:', e);
            }

            // 2) 自動檢測 IP（可透過 YTMD_QR_NO_SCAN/LS 禁用）
            const skipScan = (() => {
              try {
                // @ts-ignore
                const envNoScan = typeof process !== 'undefined' && process?.env?.YTMD_QR_NO_SCAN === '1';
                const lsNoScan = typeof localStorage !== 'undefined' && localStorage.getItem('YTMD_QR_NO_SCAN') === '1';
                return envNoScan || lsNoScan;
              } catch { return false; }
            })();

            if (!skipScan && cfg.autoDetectIp && (!url || url === 'http://localhost:8080' || url === cfg.serverUrl)) {
              try {
                console.log('[Side Info] 嘗試獲取服務器配置...');
                const configResponse = await fetch('http://localhost:8080/config', { 
                  method: 'GET',
                  signal: AbortSignal.timeout(2000),
                  mode: 'cors'
                });
                if (configResponse.ok) {
                  const config = await configResponse.json() as { serverUrl?: string; serverIp?: string };
                  if (config.serverUrl) {
                    url = config.serverUrl;
                    console.log('[Side Info] 使用服務器配置的 URL:', url);
                  } else if (config.serverIp) {
                    url = `http://${config.serverIp}:8080`;
                    console.log('[Side Info] 使用檢測到的 IP 構建 URL:', url);
                  }
                }
              } catch (error) {
                console.log('[Side Info] 無法獲取服務器配置，跳過高成本掃描:', error);
              }
            }

            console.log('[Side Info] Generating QR Code for URL:', url);
            await QR.toCanvas(canvas, url, { width: 200, margin: 1 });
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
        };

        // 優先使用 requestIdleCallback，並設定超時保險
        try {
          const idle = (window as any).requestIdleCallback as ((cb: () => void, opts?: { timeout?: number }) => number) | undefined;
          if (idle) {
            idle(run, { timeout: 3000 });
          } else {
            setTimeout(run, 2000);
          }
        } catch {
          setTimeout(run, 2000);
        }
      };

      if (!this.qrDisabled) scheduleQr();

      // 額外的調試信息
      console.log('[Side Info] Plugin injection completed');
      console.log('[Side Info] Final element in DOM:', document.getElementById('ext-side-info'));
    },
    
    stop() {
      // 清理資源
      if (this.observer) {
        this.observer.disconnect();
        this.observer = null;
      }
      
      if (this.timeoutId) {
        clearTimeout(this.timeoutId);
        this.timeoutId = null;
      }
      
      // 移除 DOM 元素
      const existingSide = document.getElementById('ext-side-info');
      if (existingSide) {
        existingSide.remove();
      }
      
      console.log('[Side Info] Plugin stopped and cleaned up');
    }
  }
});
