/* Minimal API client for backend */

const importMeta: any = import.meta;
export const BASE = importMeta?.env?.VITE_BACKEND_URL || '';

async function j<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(BASE + path, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  if (!res.ok) throw new Error(`${res.status}`);
  if (res.status === 204) return undefined as unknown as T;
  return (await res.json()) as T;
}

export type QueueItem = {
  title: string;
  artist: string;
  duration: string;
  videoId: string;
  index: number;
  thumbnail: string;
};

export type CurrentSong = {
  videoId: string | null;
  title?: string;
  artist?: string;
  isPaused?: boolean;
  elapsedSeconds?: number;
  songDuration?: number;
};

export const api = {
  health: () => j<{ status: string; queue_connected: boolean }>('/health'),
  config: () => j('/config'),
  queue: () => j<QueueItem[]>('/queue'),
  currentSong: () => j<CurrentSong>('/current-song'),
  search: (q: string) => j<any[]>('/search', { method: 'POST', body: JSON.stringify({ q }) }),
  enqueue: (song: QueueItem | { videoId: string; title?: string; artist?: string; duration?: string; thumbnail?: string }, nickname?: string) =>
    j<{ success: boolean; message: string }>('/enqueue', {
      method: 'POST',
      body: JSON.stringify({
        videoId: song.videoId,
        title: (song as any).title,
        artist: (song as any).artist,
        duration: (song as any).duration,
        thumbnail: (song as any).thumbnail,
        nickname,
      }),
    }),
  control: (action: 'play' | 'pause' | 'next' | 'previous' | 'toggle-play') =>
    j<void>(`/controls/${action}`, { method: 'POST' }),
  seek: (seconds: number) => j<void>('/seek', { method: 'POST', body: JSON.stringify({ seconds }) }),
  volume: {
    get: () => j<{ state: number; isMuted: boolean }>('/volume'),
    set: (v: number) => j<void>('/volume', { method: 'POST', body: JSON.stringify({ volume: v }) }),
  },
  queueDelete: (index: number) => j<void>(`/queue/${index}`, { method: 'DELETE' }),
  user: {
    history: (nickname: string) => j<any[]>(`/user/${encodeURIComponent(nickname)}/history`),
    clearHistory: (nickname: string) => j<void>(`/user/${encodeURIComponent(nickname)}/history`, { method: 'DELETE' }),
    removeHistoryItem: (nickname: string, videoId: string) =>
      j<void>(`/user/${encodeURIComponent(nickname)}/history/${encodeURIComponent(videoId)}`, { method: 'DELETE' }),
    likes: (nickname: string) => j<any[]>(`/user/${encodeURIComponent(nickname)}/likes`),
    like: (nickname: string, item: any) => j<void>(`/user/${encodeURIComponent(nickname)}/likes`, { method: 'POST', body: JSON.stringify(item) }),
    unlike: (nickname: string, videoId: string) => j<void>(`/user/${encodeURIComponent(nickname)}/likes`, { method: 'DELETE', body: JSON.stringify({ videoId }) }),
    recommendations: (nickname: string) => j<any[]>(`/user/${encodeURIComponent(nickname)}/recommendations`),
  },
  lyrics: {
    get: (videoId: string) => j<{ success: boolean; data?: any; message?: string }>(`/lyrics/${encodeURIComponent(videoId)}`),
    getCurrent: () => j<{ success: boolean; data?: any; message?: string }>('/current-lyrics'),
  },
};

export async function raw<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(BASE + path, init);
  if (!res.ok) throw new Error(`${res.status}`);
  if (res.status === 204) return undefined as unknown as T;
  return (await res.json()) as T;
}
