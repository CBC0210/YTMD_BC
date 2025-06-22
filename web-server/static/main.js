// 工具函數
const ajax = (url, options = {}) => {
    return fetch(url, options)
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return response.json();
        });
};

const showMessage = (message, type = 'info') => {
    const statusEl = document.getElementById('search-status');
    statusEl.innerHTML = `<div class="${type}">${message}</div>`;
    
    // 3秒後自動清除消息
    setTimeout(() => {
        statusEl.innerHTML = '';
    }, 3000);
};

// 載入佇列
async function loadQueue() {
    try {
        const [queueData, currentSong] = await Promise.all([
            ajax('/queue'),
            ajax('/current-song').catch(() => ({ videoId: null }))
        ]);
        
        const queueEl = document.getElementById('queue');
        queueEl.innerHTML = '';

        if (!queueData || !Array.isArray(queueData) || queueData.length === 0) {
            queueEl.innerHTML = '<li class="empty-state">目前佇列為空</li>';
            return;
        }

        const currentVideoId = currentSong?.videoId;

        queueData.forEach((song, index) => {
            const li = document.createElement('li');
            
            const numberEl = document.createElement('div');
            numberEl.className = 'queue-number';
            numberEl.textContent = index + 1;
            
            const contentEl = document.createElement('div');
            contentEl.innerHTML = `
                <div class="song-title">${escapeHtml(song.title || 'Unknown Title')}</div>
                <div class="song-info">${escapeHtml(song.artist || 'Unknown Artist')}</div>
            `;
            
            // 檢查是否為當前播放的歌曲
            if (currentVideoId && song.videoId === currentVideoId) {
                li.classList.add('current-playing');
                numberEl.innerHTML = currentSong.isPaused ? '⏸️' : '▶️';
                numberEl.style.backgroundColor = '#4ade80';
                
                // 添加播放狀態文字
                const statusEl = document.createElement('div');
                statusEl.className = 'play-status';
                statusEl.textContent = currentSong.isPaused ? '暫停中' : '播放中';
                statusEl.style.cssText = 'color: #4ade80; font-size: 12px; margin-top: 2px;';
                contentEl.appendChild(statusEl);
            }
            
            li.appendChild(numberEl);
            li.appendChild(contentEl);
            queueEl.appendChild(li);
        });
    } catch (error) {
        console.error('載入佇列失敗:', error);
        document.getElementById('queue').innerHTML = 
            '<li class="error">載入佇列失敗：無法連接到 YTMD</li>';
    }
}

// 檢查歌曲是否已在佇列中
async function checkSongInQueue(videoId) {
    try {
        const queueData = await ajax('/queue');
        if (Array.isArray(queueData)) {
            return queueData.some(song => song.videoId === videoId);
        }
        return false;
    } catch (error) {
        console.warn('無法檢查佇列狀態:', error);
        return false;
    }
}

// 搜尋功能
async function performSearch() {
    const query = document.getElementById('q').value.trim();
    const resultsEl = document.getElementById('results');
    
    if (!query) {
        showMessage('請輸入搜尋關鍵字', 'error');
        return;
    }

    // 顯示載入狀態
    resultsEl.innerHTML = '<li class="loading">搜尋中...</li>';
    showMessage('搜尋中...', 'info');

    try {
        const results = await fetch('/search', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ q: query })
        }).then(response => {
            if (!response.ok) {
                throw new Error(`搜尋失敗: ${response.status}`);
            }
            return response.json();
        });

        resultsEl.innerHTML = '';

        if (!results || results.length === 0) {
            resultsEl.innerHTML = '<li class="empty-state">沒有找到相關歌曲</li>';
            showMessage('沒有找到相關歌曲', 'error');
            return;
        }

        // 先顯示所有結果
        for (const song of results) {
            const li = document.createElement('li');
            
            const artists = Array.isArray(song.artists) ? song.artists.join(', ') : 'Unknown Artist';
            const duration = song.duration || '';
            const album = song.album || '';
            
            li.innerHTML = `
                <div class="song-title">${escapeHtml(song.title)}</div>
                <div class="song-info">
                    ${escapeHtml(artists)}
                    ${album ? ` • ${escapeHtml(album)}` : ''}
                    ${duration ? ` • ${escapeHtml(duration)}` : ''}
                </div>
            `;
            
            // 檢查是否已在佇列中
            const isInQueue = await checkSongInQueue(song.videoId);
            if (isInQueue) {
                li.style.opacity = '0.6';
                li.style.backgroundColor = '#2d1f1f';
                li.innerHTML += '<div style="color: #e74c3c; font-size: 12px; margin-top: 4px;">⚠️ 已在佇列中</div>';
                li.style.cursor = 'not-allowed';
                li.onclick = () => showMessage(`歌曲「${song.title}」已在佇列中`, 'error');
            } else {
                li.onclick = () => enqueueSong(song.videoId, song.title);
            }
            
            resultsEl.appendChild(li);
        }

        showMessage(`找到 ${results.length} 首歌曲`, 'success');
    } catch (error) {
        console.error('搜尋失敗:', error);
        resultsEl.innerHTML = '<li class="error">搜尋失敗，請稍後再試</li>';
        showMessage('搜尋失敗：' + error.message, 'error');
    }
}

// 點歌功能
async function enqueueSong(videoId, title) {
    if (!videoId) {
        showMessage('無效的歌曲 ID', 'error');
        return;
    }

    try {
        showMessage(`正在添加 "${title}" 到佇列...`, 'info');
        
        const response = await fetch('/enqueue', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ videoId: videoId })
        });

        if (response.ok) {
            showMessage(`成功添加 "${title}" 到佇列！`, 'success');
            // 重新載入佇列
            setTimeout(loadQueue, 1000);
        } else {
            // 處理不同類型的錯誤
            const errorData = await response.json();
            
            if (response.status === 409 && errorData.error === 'duplicate') {
                // 重複歌曲的特殊處理
                showMessage(errorData.message || `歌曲「${title}」已在佇列中`, 'error');
            } else {
                // 其他錯誤
                showMessage(errorData.message || `添加失敗: ${response.status}`, 'error');
            }
        }
    } catch (error) {
        console.error('點歌失敗:', error);
        showMessage(`點歌失敗: ${error.message}`, 'error');
    }
}

// HTML 轉義函數
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// 事件監聽器
document.addEventListener('DOMContentLoaded', function() {
    // 載入初始佇列
    loadQueue();
    
    // 每4秒自動更新佇列
    setInterval(loadQueue, 4000);
    
    // 搜尋框 Enter 鍵事件
    document.getElementById('q').addEventListener('keyup', function(event) {
        if (event.key === 'Enter') {
            performSearch();
        }
    });
    
    // 搜尋框自動聚焦
    document.getElementById('q').focus();
});

// 讓搜尋函數全局可用
window.performSearch = performSearch;
