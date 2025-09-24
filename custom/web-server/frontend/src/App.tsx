import React, { useEffect, useRef, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "./components/ui/card";
import { Button } from "./components/ui/button";
import { Input } from "./components/ui/input";
import { Label } from "./components/ui/label";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "./components/ui/alert-dialog";
import { Badge } from "./components/ui/badge";
import { Slider } from "./components/ui/slider";
import {
  Search,
  Plus,
  Trash2,
  User,
  Clock,
  Star,
  Play,
  Pause,
  SkipBack,
  SkipForward,
  Volume2,
  Heart,
  RefreshCw,
  X,
  FileText,
} from "lucide-react";
import { api } from "./lib/api";

interface Song {
  id: string;
  title: string;
  artist: string;
  album?: string;
  duration?: string;
  videoId?: string;
  thumbnail?: string;
}

interface QueueItem extends Song {
  status: "playing" | "queued";
  queuePosition: number;
}

interface LyricLine {
  time: string;
  timeInMs: number;
  duration: number;
  text: string;
  status: 'previous' | 'current' | 'upcoming';
}

interface LyricResult {
  title: string;
  artists: string[];
  lyrics?: string;
  lines?: LyricLine[];
  source?: string;
}

type QueueRowProps = {
  song: QueueItem;
  isCurrent: boolean;
  onDelete: (song: QueueItem) => void;
  onClick: (song: QueueItem) => void;
};

const SwipeRow = React.forwardRef<HTMLDivElement, QueueRowProps>(({ song, isCurrent, onDelete, onClick }, ref) => {
  const startX = React.useRef<number | null>(null);
  const [dragX, setDragX] = React.useState(0);
  const [dragging, setDragging] = React.useState(false);
  const [open, setOpen] = React.useState(false);
  const max = 80;
  const openOffset = 56;
  const threshold = 48;

  const endDrag = () => {
    if (!dragging) return;
    setDragging(false);
    if (dragX <= -threshold) setOpen(true); else setOpen(false);
    setDragX(0);
  };

  const onTouchStart = (e: React.TouchEvent) => { startX.current = e.touches[0].clientX; setDragging(true); };
  const onTouchMove = (e: React.TouchEvent) => {
    if (startX.current == null) return;
    const dx = e.touches[0].clientX - startX.current;
    setDragX(Math.max(-max, Math.min(0, dx)));
  };
  const onTouchEnd = (e?: React.TouchEvent) => { if (e) e.preventDefault(); endDrag(); startX.current = null; };

  const onMouseDown = (e: React.MouseEvent) => { startX.current = e.clientX; setDragging(true); };
  const onMouseMove = (e: React.MouseEvent) => {
    if (!dragging || startX.current == null || e.buttons === 0) return;
    const dx = e.clientX - startX.current;
    setDragX(Math.max(-max, Math.min(0, dx)));
  };
  const onMouseUp = () => { endDrag(); startX.current = null; };

  const translate = dragging ? dragX : (open ? -openOffset : 0);

  return (
    <div ref={ref} className="relative overflow-hidden rounded-lg">
      <div className="absolute inset-y-0 right-0 flex items-center pr-2 pl-3">
        <Button
          onClick={(e) => { e.stopPropagation(); onDelete(song); setOpen(false); }}
          disabled={isCurrent}
          style={{ backgroundColor: "#e74c3c" }}
          className="w-9 h-9 p-0 rounded-full flex items-center justify-center text-white hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
          aria-label="刪除"
          title="刪除"
        >
          <Trash2 className="w-4 h-4" />
        </Button>
      </div>
      <div
        className="flex items-center gap-3 p-3 bg-gray-700 transition-transform select-none"
        style={{ transform: `translateX(${translate}px)` }}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onClick={() => {
          if (dragging) return;
          if (open) { setOpen(false); return; }
          onClick(song);
        }}
      >
        <span className="text-gray-400 text-sm w-8">{song.queuePosition}</span>
        {song.thumbnail && (
          <img src={song.thumbnail} alt="thumb" className="w-12 h-12 object-cover rounded" />
        )}
        <div className="flex-1">
          <h4 className="font-medium">{song.title}</h4>
          <p className="text-gray-400 text-sm">{song.artist}</p>
        </div>
        {isCurrent && (
          <Badge style={{ backgroundColor: "#e74c3c" }}>播放中</Badge>
        )}
      </div>
    </div>
  );
});
SwipeRow.displayName = "SwipeRow";

export default function App() {
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<Song[]>(
    [],
  );
  const [playQueue, setPlayQueue] = useState<QueueItem[]>([
    {
      id: "1",
      title: "夜曲",
      artist: "周杰倫",
      album: "十一月的蕭邦",
      duration: "3:45",
      status: "playing",
      queuePosition: 1,
    },
    {
      id: "2",
      title: "告白氣球",
      artist: "周杰倫",
      album: "Jay Chou 周杰倫",
      duration: "3:18",
      status: "queued",
      queuePosition: 2,
    },
  ]);
  const [nickname, setNickname] = useState("");
  const [nicknameInput, setNicknameInput] = useState("");
  const [selectedSong, setSelectedSong] =
    useState<QueueItem | null>(null);
  const [selectedHistory, setSelectedHistory] =
    useState<Song | null>(null);
  const [isPlaying, setIsPlaying] = useState(true);
  const [currentTime, setCurrentTime] = useState(0); // seconds
  const [volume, setVolume] = useState(75);
  const [songDuration, setSongDuration] = useState(0);
  const currentVideoIdRef = useRef<string | null>(null);
  const [likedSongs, setLikedSongs] = useState<Song[]>([]);
  const [history, setHistory] = useState<Song[]>([]);
  const [historyExpanded, setHistoryExpanded] = useState(false);
  const [reco, setReco] = useState<Song[]>([]);
  const [recoLoading, setRecoLoading] = useState(false);
  const [queueExpanded, setQueueExpanded] = useState(false);
  const [likedExpanded, setLikedExpanded] = useState(false);
  const lastVolChangeAt = useRef<number>(0);
  const queueTickRef = useRef<number>(0);
  // 防呆：加入佇列時的鎖與提示
  const [adding, setAdding] = useState<Set<string>>(new Set());
  const [infoMsg, setInfoMsg] = useState<string>("");
  const [toastMsg, setToastMsg] = useState<string>("");
  const toastTimerRef = useRef<number | null>(null);
  
  // 歌詞相關狀態
  const [showLyrics, setShowLyrics] = useState(false);
  const [lyricsData, setLyricsData] = useState<LyricResult | null>(null);
  const [lyricsLoading, setLyricsLoading] = useState(false);
  const [lyricsError, setLyricsError] = useState<string | null>(null);

  // 以上 mock 範例資料已移除，改由 API 取得

  const searchAbortRef = useRef<AbortController | null>(null);
  const handleSearch = async (query: string) => {
    if (!query.trim()) {
      setSearchResults([]);
      searchAbortRef.current?.abort();
      return;
    }
    searchAbortRef.current?.abort();
    const ctrl = new AbortController();
    searchAbortRef.current = ctrl;
    try {
      const res = await fetch("/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ q: query }),
        signal: ctrl.signal,
      });
      if (!ctrl.signal.aborted && res.ok) {
        const data = await res.json();
        const mapped: Song[] = (data || []).map((s: any) => ({
          id: s.videoId,
          videoId: s.videoId,
          title: s.title,
          artist: (s.artists && s.artists[0]) || "",
          album: s.album,
          duration: s.duration,
          thumbnail: s.thumbnails?.[0]?.url,
        }));
        setSearchResults(mapped);
      }
    } catch (e) {
      if (!ctrl.signal.aborted) setSearchResults([]);
    }
  };

  const clearSearch = () => {
    searchAbortRef.current?.abort();
    setSearchQuery("");
    setSearchResults([]);
  };

  // 獲取歌詞
  const fetchLyrics = async (videoId: string) => {
    if (!videoId) return;
    
    setLyricsLoading(true);
    setLyricsError(null);
    
    try {
      const response = await fetch(`/lyrics/${encodeURIComponent(videoId)}`);
      if (response.ok) {
        const data = await response.json();
        if (data.success && data.data) {
          setLyricsData(data.data);
        } else {
          setLyricsError(data.message || '未找到歌詞');
        }
      } else {
        const errorData = await response.json().catch(() => ({}));
        setLyricsError(errorData.message || '獲取歌詞失敗');
      }
    } catch (error) {
      setLyricsError('獲取歌詞失敗');
      console.error('Lyrics fetch error:', error);
    } finally {
      setLyricsLoading(false);
    }
  };

  // 打開歌詞視圖
  const openLyrics = () => {
    const currentSong = getCurrentSong();
    if (currentSong?.videoId) {
      fetchLyrics(currentSong.videoId);
      setShowLyrics(true);
    }
  };

  // 顯示加入按鈕文案（固定寬度避免抖動）
  const renderAddLabel = (id?: string) =>
    id && adding.has(id) ? "加入中…" : "加入";

  // 歷史列：改為按鈕點擊刪除（無滑動）
  const HistoryRow: React.FC<{
    song: Song;
    onDelete: (s: Song) => void;
  }> = ({ song, onDelete }) => (
    <div className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
      <div className="flex items-center gap-3 flex-1">
        {song.thumbnail && (
          <img src={song.thumbnail} alt="thumb" className="w-10 h-10 object-cover rounded" />
        )}
        <div className="flex-1">
          <h4 className="font-medium">{song.title}</h4>
          <p className="text-gray-400 text-sm">
            {song.artist}{song.album ? ` • ${song.album}` : ''}{song.duration ? ` • ${song.duration}` : ''}
          </p>
        </div>
      </div>
      <div className="flex gap-2">
        <Button
          size="sm"
          onClick={() => addToQueue(song)}
          disabled={!!(song.videoId || song.id) && adding.has(song.videoId || song.id)}
          style={{ backgroundColor: "#e74c3c" }}
          className="hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Plus className="w-4 h-4 mr-1" />
          {renderAddLabel(song.videoId || song.id)}
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => onDelete(song)}
          className="border-gray-600 text-gray-300 hover:bg-gray-700"
          aria-label="刪除"
          title="刪除"
        >
          <Trash2 className="w-4 h-4" />
        </Button>
      </div>
    </div>
  );

  const refreshRecommendations = async () => {
    if (!nickname) return;
    setRecoLoading(true);
    try {
      const r = await api.user.recommendations(nickname);
      setReco((r || []).map((s: any) => ({
        id: s.videoId,
        videoId: s.videoId,
        title: s.title,
        artist: s.artist,
        duration: s.duration,
        thumbnail: s.thumbnail,
      })));
    } catch {}
    setRecoLoading(false);
  };

  const addToQueue = async (song: Song) => {
    try {
      const sid = song.videoId || song.id;
      // 若此歌曲已在加入中，阻止重複點擊
      if (sid && adding.has(sid)) return;
      // 設定加入中狀態並顯示提示
      if (sid) setAdding((prev) => new Set(prev).add(sid));
      setInfoMsg("已送出加入佇列，請稍候…");
      const clearInfo = setTimeout(() => setInfoMsg(""), 2500);

      await api.enqueue(
        {
          videoId: song.videoId || song.id,
          title: song.title,
          artist: song.artist,
          duration: song.duration,
          thumbnail: song.thumbnail,
        },
        nickname || undefined,
      );
  // 顯示頂部 Toast 成功提示（成功後再提示）
  const title = song.title || "";
  const artist = song.artist ? ` - ${song.artist}` : "";
  const msg = `已加入到佇列：${title}${artist}`;
  setToastMsg(msg);
  if (toastTimerRef.current) window.clearTimeout(toastTimerRef.current);
  toastTimerRef.current = window.setTimeout(() => setToastMsg(""), 2500) as unknown as number;
      // refresh queue after enqueue
      const q = await api.queue();
      setPlayQueue(
        q.map((it) => ({
          id: `${it.videoId}-${it.index}`,
          title: it.title,
          artist: it.artist,
          duration: it.duration,
          videoId: it.videoId,
          thumbnail: it.thumbnail,
          // UI-only fields for compatibility
          status: "queued",
          queuePosition: it.index,
        })) as any,
      );
      // 避免刷新歷史造成彈跳，僅刷新推薦
      if (nickname) {
        try {
          const rec = await api.user.recommendations(nickname);
          setReco((rec || []).map((s: any) => ({
            id: s.videoId,
            videoId: s.videoId,
            title: s.title,
            artist: s.artist,
            duration: s.duration,
            thumbnail: s.thumbnail,
          })));
        } catch {}
      }
    } catch {}
    finally {
      const sid = song.videoId || song.id;
      if (sid) setAdding((prev) => { const s = new Set(prev); s.delete(sid); return s; });
    }
  };

  const removeFromQueue = async (songId: string) => {
    // songId is "videoId-index"; extract index suffix if present
    const idx = Number((songId.split('-').pop() as string) || '0');
    try {
      await api.queueDelete(idx);
      const q = await api.queue();
      setPlayQueue(
        q.map((it) => ({
          id: `${it.videoId}-${it.index}`,
          title: it.title,
          artist: it.artist,
          duration: it.duration,
          videoId: it.videoId,
          thumbnail: it.thumbnail,
          status: "queued",
          queuePosition: it.index,
        })) as any,
      );
    } catch {}
    setSelectedSong(null);
  };

  const jumpToQueueItem = async (song: QueueItem) => {
    // 計算目標與當前索引差距，透過多次 next/previous 跳轉
    try {
      const current = playQueue.find((s) => s.videoId === currentVideoIdRef.current);
      const currentIdx = current?.queuePosition;
      const targetIdx = song.queuePosition;
      if (currentIdx === undefined || targetIdx === undefined) return;
      let steps = targetIdx - currentIdx;
      const maxSteps = Math.min(Math.abs(steps), 25); // 安全上限避免無限循環
      for (let i = 0; i < maxSteps; i++) {
        try {
          if (steps > 0) {
            await api.control("next");
          } else if (steps < 0) {
            await api.control("previous");
          }
        } catch {}
      }
      // 更新當前歌曲與佇列
      try {
        const cs = await api.currentSong();
        currentVideoIdRef.current = cs.videoId;
        setIsPlaying(!cs.isPaused);
        setCurrentTime(cs.elapsedSeconds || 0);
        setSongDuration(cs.songDuration || 0);
      } catch {}
      try {
        const q = await api.queue();
        setPlayQueue(
          q.map((it) => ({
            id: `${it.videoId}-${it.index}`,
            title: it.title,
            artist: it.artist,
            duration: it.duration,
            videoId: it.videoId,
            thumbnail: it.thumbnail,
            status: "queued",
            queuePosition: it.index,
          })) as any,
        );
      } catch {}
    } catch {}
  };

  const clearQueue = async () => {
    try {
      // 取得目前播放的 videoId 與最新佇列
      const cs = await api.currentSong();
      const q = await api.queue();
      const playingVid = cs.videoId;
      // 找出所有非正在播放的索引，倒序刪除避免位移
      const targets = q
        .filter((it) => it.videoId !== playingVid)
        .map((it) => it.index)
        .sort((a, b) => b - a);
      for (const idx of targets) {
        try { await api.queueDelete(idx); } catch {}
      }
      const q2 = await api.queue();
      setPlayQueue(
        q2.map((it) => ({
          id: `${it.videoId}-${it.index}`,
          title: it.title,
          artist: it.artist,
          duration: it.duration,
          videoId: it.videoId,
          thumbnail: it.thumbnail,
          status: "queued",
          queuePosition: it.index,
        })) as any,
      );
    } catch {}
  };

  // History row with left-swipe delete
  const HistorySwipeRow: React.FC<{
    song: Song;
    onDelete: (s: Song) => void;
    onClick: (s: Song) => void;
  }> = ({ song, onDelete, onClick }) => {
    const startX = React.useRef<number | null>(null);
    const [dragX, setDragX] = React.useState(0);
    const [dragging, setDragging] = React.useState(false);
    const [open, setOpen] = React.useState(false);
    const max = 80;
    const openOffset = 56;
    const threshold = 48;

    const endDrag = () => {
      if (!dragging) return;
      setDragging(false);
      if (dragX <= -threshold) setOpen(true); else setOpen(false);
      setDragX(0);
    };

    const onTouchStart = (e: React.TouchEvent) => { startX.current = e.touches[0].clientX; setDragging(true); };
    const onTouchMove = (e: React.TouchEvent) => {
      if (startX.current == null) return;
      const dx = e.touches[0].clientX - startX.current;
      setDragX(Math.max(-max, Math.min(0, dx)));
    };
    const onTouchEnd = () => { endDrag(); startX.current = null; };

    const onMouseDown = (e: React.MouseEvent) => { startX.current = e.clientX; setDragging(true); };
    const onMouseMove = (e: React.MouseEvent) => {
      if (!dragging || startX.current == null || e.buttons === 0) return;
      const dx = e.clientX - startX.current;
      setDragX(Math.max(-max, Math.min(0, dx)));
    };
    const onMouseUp = () => { endDrag(); startX.current = null; };

    const translate = dragging ? dragX : (open ? -openOffset : 0);

    return (
      <div className="relative overflow-hidden rounded-lg">
        {/* 背後的刪除按鈕區 */}
        <div className="absolute inset-y-0 right-0 flex items-center pr-2 pl-3">
          <Button
            onClick={(e) => { e.stopPropagation(); onDelete(song); setOpen(false); }}
            style={{ backgroundColor: "#e74c3c" }}
            className="w-9 h-9 p-0 rounded-full flex items-center justify-center text-white hover:opacity-80"
            aria-label="刪除"
            title="刪除"
          >
            <Trash2 className="w-4 h-4" />
          </Button>
        </div>
        {/* 前景內容，可左右滑動 */}
        <div
          className="flex items-center justify-between p-3 bg-gray-700 transition-transform select-none cursor-pointer"
          style={{ transform: `translateX(${translate}px)` }}
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
          onMouseDown={onMouseDown}
          onMouseMove={onMouseMove}
          onMouseUp={onMouseUp}
          onClick={() => {
            if (dragging) return; // 拖動中不觸發 click
            if (open) { setOpen(false); return; }
            onClick(song);
          }}
        >
          <div className="flex items-center gap-3 flex-1">
            {song.thumbnail && (
              <img src={song.thumbnail} alt="thumb" className="w-10 h-10 object-cover rounded" />
            )}
            <div className="flex-1">
              <h4 className="font-medium">{song.title}</h4>
              <p className="text-gray-400 text-sm">
                {song.artist}{song.album ? ` • ${song.album}` : ''}{song.duration ? ` • ${song.duration}` : ''}
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            <Button
              size="sm"
              onClick={(e) => { e.stopPropagation(); addToQueue(song); }}
              disabled={!!(song.videoId || song.id) && adding.has(song.videoId || song.id)}
              style={{ backgroundColor: "#e74c3c" }}
              className="hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Plus className="w-4 h-4 mr-1" />
              {((song.videoId || song.id) && adding.has(song.videoId || song.id)) ? '加入中…' : '加入'}
            </Button>
          </div>
        </div>
      </div>
    );
  };

  const handleSongClick = (song: QueueItem) => {
    setSelectedSong(song);
  };

  const handleNicknameConfirm = () => {
    const n = nicknameInput.trim();
    setNickname(n);
    localStorage.setItem("ytmd_nickname", n);
    // 載入使用者資料
    if (n) {
      (async () => {
        try {
          const [hist, likes] = await Promise.all([
            api.user.history(n),
            api.user.likes(n),
          ]);
          setHistory((hist || []).map((x: any) => ({
            id: x.videoId,
            videoId: x.videoId,
            title: x.title,
            artist: x.artist,
            duration: x.duration,
            thumbnail: x.thumbnail,
          })));
          setLikedSongs((likes || []).map((x: any) => ({
            id: x.videoId,
            videoId: x.videoId,
            title: x.title,
            artist: x.artist,
            duration: x.duration,
            thumbnail: x.thumbnail,
          })));
          // 載入推薦
          try {
            const r = await api.user.recommendations(n);
            setReco((r || []).map((s: any) => ({
              id: s.videoId,
              videoId: s.videoId,
              title: s.title,
              artist: s.artist,
              duration: s.duration,
              thumbnail: s.thumbnail,
            })));
          } catch {}
        } catch {}
      })();
    }
  };

  const handleNicknameClear = () => {
    setNickname("");
    setNicknameInput("");
    localStorage.removeItem("ytmd_nickname");
  setHistory([]);
  setLikedSongs([]);
  };

  const getCurrentSong = () => {
  return playQueue.find((song) => song.videoId === currentVideoIdRef.current);
  };

  const togglePlayPause = async () => {
    try {
      await api.control("toggle-play");
      const cs = await api.currentSong();
      setIsPlaying(!cs.isPaused);
    } catch {}
  };

  const playNext = async () => {
    try {
      await api.control("next");
      setCurrentTime(0);
      const cs = await api.currentSong();
      currentVideoIdRef.current = cs.videoId;
      setIsPlaying(!cs.isPaused);
      setSongDuration(cs.songDuration || 0);
    } catch {}
  };

  const playPrevious = async () => {
    try {
      await api.control("previous");
      setCurrentTime(0);
      const cs = await api.currentSong();
      currentVideoIdRef.current = cs.videoId;
      setIsPlaying(!cs.isPaused);
      setSongDuration(cs.songDuration || 0);
    } catch {}
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  const parseDuration = (duration: string) => {
    const [mins, secs] = duration.split(":").map(Number);
    return mins * 60 + secs;
  };

  const toggleLike = (song: Song) => {
    if (!nickname) return;
    setLikedSongs((prev) => {
      const isLiked = prev.some((likedSong) => likedSong.id === song.id);
      if (isLiked) {
        // unlike
        api.user.unlike(nickname, song.videoId || song.id).catch(() => {});
        return prev.filter((likedSong) => likedSong.id !== song.id);
      } else {
        // like
        api.user
          .like(nickname, {
            videoId: song.videoId || song.id,
            title: song.title,
            artist: song.artist,
            duration: song.duration,
            thumbnail: song.thumbnail,
          })
          .catch(() => {});
        return [
          ...prev,
          {
            ...song,
            id: song.videoId || song.id,
            videoId: song.videoId || song.id,
          },
        ];
      }
    });
  };

  const isLiked = (videoId?: string | null) => {
    if (!videoId) return false;
    return likedSongs.some(song => (song.videoId || song.id) === videoId);
  };

  // init from backend
  React.useEffect(() => {
    const saved = localStorage.getItem("ytmd_nickname") || "";
    setNickname(saved);
    setNicknameInput(saved);
    (async () => {
      try {
        const q = await api.queue();
        setPlayQueue(
          q.map((it) => ({
            id: `${it.videoId}-${it.index}`,
            title: it.title,
            artist: it.artist,
            duration: it.duration,
            videoId: it.videoId,
            thumbnail: it.thumbnail,
            status: "queued",
            queuePosition: it.index,
          })) as any,
        );
        const cs = await api.currentSong();
        currentVideoIdRef.current = cs.videoId;
        setIsPlaying(!cs.isPaused);
        setCurrentTime(cs.elapsedSeconds || 0);
        setSongDuration(cs.songDuration || 0);
        const v = await api.volume.get();
        setVolume(v.state);
        if (saved) {
          const [hist, likes] = await Promise.all([
            api.user.history(saved),
            api.user.likes(saved),
          ]);
          setHistory((hist || []).map((x: any) => ({
            id: x.videoId,
            videoId: x.videoId,
            title: x.title,
            artist: x.artist,
            duration: x.duration,
            thumbnail: x.thumbnail,
          })));
          setLikedSongs((likes || []).map((x: any) => ({
            id: x.videoId,
            videoId: x.videoId,
            title: x.title,
            artist: x.artist,
            duration: x.duration,
            thumbnail: x.thumbnail,
          })));
          try {
            const r = await api.user.recommendations(saved);
            setReco((r || []).map((s: any) => ({
              id: s.videoId,
              videoId: s.videoId,
              title: s.title,
              artist: s.artist,
              duration: s.duration,
              thumbnail: s.thumbnail,
            })));
          } catch {}
        }
      } catch {}
    })();
  }, []);

  // 每秒同步：當前歌曲時間、播放狀態，並在 700ms 內未本地調整時同步音量；若歌曲變更則刷新佇列
  useEffect(() => {
    let mounted = true;
    let prevVid: string | null = null;
    const timer = setInterval(async () => {
      try {
        const cs = await api.currentSong();
        if (!mounted) return;
        const vid = cs.videoId || null;
        if (vid !== currentVideoIdRef.current) {
          currentVideoIdRef.current = vid;
        }
        setIsPlaying(!cs.isPaused);
        setCurrentTime(Math.max(0, Math.round(cs.elapsedSeconds || 0)));
        setSongDuration(cs.songDuration || 0);
        if (prevVid !== vid) {
          prevVid = vid;
          // 歌曲切換時刷新佇列
          const q = await api.queue();
          if (!mounted) return;
          setPlayQueue(
            q.map((it) => ({
              id: `${it.videoId}-${it.index}`,
              title: it.title,
              artist: it.artist,
              duration: it.duration,
              videoId: it.videoId,
              thumbnail: it.thumbnail,
              status: "queued",
              queuePosition: it.index,
            })) as any,
          );
        }
        // 每 4 秒同步一次佇列（即使歌曲未變更），避免多人操作時不同步
        queueTickRef.current = (queueTickRef.current + 1) % 4;
        if (queueTickRef.current === 0) {
          try {
            const q = await api.queue();
            if (!mounted) return;
            setPlayQueue(
              q.map((it) => ({
                id: `${it.videoId}-${it.index}`,
                title: it.title,
                artist: it.artist,
                duration: it.duration,
                videoId: it.videoId,
                thumbnail: it.thumbnail,
                status: "queued",
                queuePosition: it.index,
              })) as any,
            );
          } catch {}
        }
        // 音量：若 700ms 內沒有本地調整，才拉取伺服器值
        if (Date.now() - lastVolChangeAt.current > 700) {
          const v = await api.volume.get();
          if (!mounted) return;
          if (typeof v.state === "number") setVolume(v.state);
        }
      } catch {}
    }, 1000);
    return () => {
      mounted = false;
      clearInterval(timer);
    };
  }, []);

  // 如果顯示歌詞，則渲染歌詞頁面
  if (showLyrics) {
    return (
      <div className="min-h-screen bg-gray-900 text-white">
        {/* 歌詞頁面標題欄 */}
        <div className="flex items-center justify-between p-4 border-b border-gray-700 bg-gray-800">
          <h1 className="text-xl font-semibold">歌詞</h1>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowLyrics(false)}
            className="border-gray-600 text-gray-300 hover:bg-gray-700"
          >
            <X className="w-4 h-4 mr-2" />
            返回主頁
          </Button>
        </div>
        
        {/* 歌詞內容 */}
        <div className="h-[calc(100vh-80px)] overflow-y-auto p-6">
          {lyricsLoading ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-gray-400">載入歌詞中...</div>
            </div>
          ) : lyricsError ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-red-400">{lyricsError}</div>
            </div>
          ) : lyricsData ? (
            <div className="max-w-4xl mx-auto space-y-6">
              {/* 歌曲資訊 */}
              <div className="text-center mb-8">
                <h2 className="text-2xl font-bold mb-2">{lyricsData.title}</h2>
                <p className="text-gray-400 text-lg">{lyricsData.artists.join(', ')}</p>
                {lyricsData.source && (
                  <p className="text-sm text-gray-500 mt-2">
                    歌詞來源: {lyricsData.source}
                  </p>
                )}
              </div>

              {/* 歌詞內容 */}
              <div className="space-y-3">
                {lyricsData.lines ? (
                  // 同步歌詞（帶時間標記）
                  lyricsData.lines.map((line, index) => (
                    <div key={index} className="flex items-center gap-4 py-2">
                      <span className="text-sm text-gray-500 w-20 flex-shrink-0 font-mono">
                        {line.time}
                      </span>
                      <span className="text-gray-200 text-lg leading-relaxed">{line.text}</span>
                    </div>
                  ))
                ) : lyricsData.lyrics ? (
                  // 純文字歌詞
                  lyricsData.lyrics.split('\n').map((line, index) => (
                    <div key={index} className="text-gray-200 text-lg leading-relaxed py-1">
                      {line}
                    </div>
                  ))
                ) : (
                  <div className="text-center text-gray-400 text-lg">
                    暫無歌詞內容
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center h-full">
              <div className="text-gray-400 text-lg">暫無歌詞</div>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6 dark">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold mb-2">
            YTMD點歌系統
          </h1>
          <p className="text-gray-400">由 CBC 修改開發</p>
        </div>

        {/* Now Playing Section */}
        {getCurrentSong() && (
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="space-y-4 pt-4">
              {/* Song Info with thumbnail (stacked) */}
              <div className="flex flex-col items-center gap-3 text-center">
                {getCurrentSong()?.thumbnail && (
                  <img src={getCurrentSong()!.thumbnail} alt="thumb" className="w-16 h-16 md:w-20 md:h-20 object-cover rounded" />
                )}
                <div className="text-center">
                  <h3 className="text-lg font-medium">{getCurrentSong()?.title}</h3>
                  <p className="text-gray-400">{getCurrentSong()?.artist}</p>
                </div>
              </div>

              {/* Progress Bar */}
              <div className="space-y-2">
                <Slider
                  value={[currentTime]}
                  onValueChange={(value) => setCurrentTime(value[0])}
                  onValueCommit={async (value) => {
                    try { await api.seek(value[0]); } catch {}
                  }}
                  max={songDuration || (getCurrentSong()?.duration ? parseDuration(getCurrentSong()!.duration!) : 225)}
                  step={1}
                  className="w-full"
                />
                <div className="flex justify-between text-sm text-gray-400">
                  <span>{formatTime(currentTime)}</span>
                  <span>
                    {formatTime(
                      songDuration ||
                        (getCurrentSong()?.duration
                          ? parseDuration(getCurrentSong()!.duration!)
                          : 0)
                    )}
                  </span>
                </div>
              </div>

              {/* Control Buttons */}
              <div className="flex items-center justify-center gap-4">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={playPrevious}
                  disabled={
                    playQueue.findIndex(
                      (song) => song.status === "playing",
                    ) === 0
                  }
                  className="border-gray-600 text-gray-300 hover:bg-gray-700 disabled:opacity-50"
                >
                  <SkipBack className="w-4 h-4" />
                </Button>

                <Button
                  onClick={togglePlayPause}
                  size="sm"
                  style={{ backgroundColor: "#e74c3c" }}
                  className="hover:opacity-80 px-4"
                >
                  {isPlaying ? (
                    <Pause className="w-4 h-4" />
                  ) : (
                    <Play className="w-4 h-4" />
                  )}
                </Button>

                <Button
                  variant="outline"
                  size="sm"
                  onClick={playNext}
                  disabled={
                    playQueue.findIndex(
                      (song) => song.status === "playing",
                    ) ===
                    playQueue.length - 1
                  }
                  className="border-gray-600 text-gray-300 hover:bg-gray-700 disabled:opacity-50"
                >
                  <SkipForward className="w-4 h-4" />
                </Button>

                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => getCurrentSong() && nickname && toggleLike(getCurrentSong()!)}
                  disabled={!nickname}
                  className={`border-gray-600 hover:bg-gray-700 ${
                    getCurrentSong() && isLiked(getCurrentSong()!.videoId)
                      ? 'text-red-500 hover:text-red-400'
                      : 'text-gray-300 hover:text-red-400'
                  } disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  <Heart
                    className={`w-4 h-4 ${
                      getCurrentSong() && isLiked(getCurrentSong()!.videoId) ? 'fill-current' : ''
                    }`}
                  />
                </Button>
              </div>

              {/* Volume Control */}
              <div className="flex items-center gap-3">
                <Volume2 className="w-4 h-4 text-gray-400" />
                <Slider
                  value={[volume]}
                  onValueChange={(value) => {
                    setVolume(value[0]);
                    lastVolChangeAt.current = Date.now();
                    api.volume.set(value[0]).catch(() => {});
                  }}
                  max={100}
                  step={1}
                  className="flex-1"
                />
                <span className="text-sm text-gray-400 w-8">
                  {volume}
                </span>
                
                {/* 歌詞按鈕 */}
                <Button
                  variant="outline"
                  size="sm"
                  onClick={openLyrics}
                  disabled={!getCurrentSong()?.videoId}
                  className="border-gray-600 text-gray-300 hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  title="查看歌詞"
                >
                  <FileText className="w-4 h-4" />
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Search Section */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Search className="w-5 h-5" />
              搜尋
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-3">
              <Input
                placeholder="輸入歌曲名稱或歌手..."
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value);
                  handleSearch(e.target.value);
                }}
                className="flex-1 bg-gray-700 border-gray-600 text-white placeholder-gray-400"
              />
              <Button
                variant="outline"
                size="sm"
                onClick={clearSearch}
                disabled={!searchQuery.trim()}
                className="border-gray-600 text-gray-300 hover:bg-gray-700 disabled:opacity-50"
              >
                <X className="w-4 h-4 mr-1" />清除
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Search Results */}
        {searchQuery && (
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle>搜尋結果</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {infoMsg && (
                <div className="text-xs text-gray-400">{infoMsg}</div>
              )}
              {searchResults.length > 0 ? (
                searchResults.map((song) => (
                  <div
                    key={song.id}
                    className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                  >
                    <div className="flex items-center gap-3 flex-1">
                      {song.thumbnail && (
                        <img src={song.thumbnail} alt="thumb" className="w-12 h-12 object-cover rounded" />
                      )}
                      <div className="flex-1">
                      <h4 className="font-medium">
                        {song.title}
                      </h4>
                      <p className="text-gray-400 text-sm">
                        {song.artist} • {song.album} •{" "}
                        {song.duration}
                      </p>
                      </div>
                    </div>
                    <Button
                      size="sm"
                      onClick={() => addToQueue(song)}
                      disabled={!!(song.videoId || song.id) && adding.has(song.videoId || song.id)}
                      style={{ backgroundColor: "#e74c3c" }}
                      className="hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <Plus className="w-4 h-4 mr-1" />
                      {((song.videoId || song.id) && adding.has(song.videoId || song.id)) ? '加入中…' : '加入'}
                    </Button>
                  </div>
                ))
              ) : (
                <div className="text-center py-8 text-gray-400">
                  <Search className="w-12 h-12 mx-auto mb-3 opacity-50" />
                  <p>
                    找不到符合「{searchQuery}」的搜尋結果
                  </p>
                  <p className="text-sm mt-1">
                    請嘗試其他關鍵字
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        {/* Nickname Input */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <User className="w-5 h-5" />
              使用者設定
            </CardTitle>
            <p className="text-xs text-gray-400 mt-1">只要輸入你的暱稱就能記錄歷史與喜歡</p>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {nickname && (
                <div className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
                  <div>
                    <p className="text-sm text-gray-400">
                      目前暱稱
                    </p>
                    <p className="font-medium">{nickname}</p>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleNicknameClear}
                    className="border-gray-600 text-gray-300 hover:bg-gray-700"
                  >
                    清除暱稱
                  </Button>
                </div>
              )}
              <div className="flex gap-3">
                <Input
                  placeholder="輸入您的暱稱（選填）"
                  value={nicknameInput}
                  onChange={(e) =>
                    setNicknameInput(e.target.value)
                  }
                  onKeyPress={(e) =>
                    e.key === "Enter" &&
                    nicknameInput.trim() &&
                    handleNicknameConfirm()
                  }
                  className="flex-1 bg-gray-700 border-gray-600 text-white placeholder-gray-400"
                />
                <Button
                  onClick={handleNicknameConfirm}
                  disabled={!nicknameInput.trim()}
                  style={{ backgroundColor: "#e74c3c" }}
                  className="hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  確認
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="grid lg:grid-cols-2 gap-6">
          {/* Left Column */}
          <div className="space-y-6">
            {/* Play Queue */}
            <Card className="bg-gray-800 border-gray-700">
              <CardHeader className="flex flex-row items-center justify-between">
                <div>
                  <CardTitle>播放清單</CardTitle>
                  <p className="text-xs text-gray-400 mt-1">左滑刪除；點擊曲目跳轉。正在播放的不能刪。</p>
                </div>
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button
                      variant="outline"
                      size="sm"
                      className="border-gray-600 text-gray-300 hover:bg-gray-700"
                    >
                      清除全部
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent className="bg-gray-800 border-gray-700">
                    <AlertDialogHeader>
                      <AlertDialogTitle className="text-white">清除佇列</AlertDialogTitle>
                      <AlertDialogDescription className="text-gray-400">
                        這將刪除所有非正在播放的歌曲，確定要繼續嗎？
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel className="bg-gray-700 border-gray-600 text-white hover:bg-gray-600">取消</AlertDialogCancel>
                      <AlertDialogAction
                        onClick={() => clearQueue()}
                        style={{ backgroundColor: "#e74c3c" }}
                        className="hover:opacity-80"
                      >
                        清除
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </CardHeader>
              <CardContent className="space-y-3">
                {(() => {
                  const currIdx = playQueue.findIndex((s) => s.videoId === currentVideoIdRef.current);
                  const collapsedMax = 6; // 前 1 + 當前 + 後 4
                  const startIdx = currIdx >= 0 ? Math.max(currIdx - 1, 0) : 0;
                  const endIdx = Math.min(playQueue.length, startIdx + collapsedMax);
                  const shown = queueExpanded ? playQueue : playQueue.slice(startIdx, endIdx);
                  return shown.map((song) => (
                  <SwipeRow
                    key={song.id}
                    song={song}
                    isCurrent={song.videoId === currentVideoIdRef.current}
                    onDelete={(s) => {
                      if (s.videoId === currentVideoIdRef.current) return;
                      removeFromQueue(s.id);
                    }}
                    onClick={(s) => {
                      if (s.videoId !== currentVideoIdRef.current) handleSongClick(s as any);
                    }}
                  />
                  ));
                })()}
                {playQueue.length > 0 && (() => {
                  const currIdx = playQueue.findIndex((s) => s.videoId === currentVideoIdRef.current);
                  const collapsedMax = 6;
                  const startIdx = currIdx >= 0 ? Math.max(currIdx - 1, 0) : 0;
                  const endIdx = Math.min(playQueue.length, startIdx + collapsedMax);
                  const hiddenBefore = startIdx > 0;
                  const hiddenAfter = endIdx < playQueue.length;
                  const showToggle = queueExpanded || hiddenBefore || hiddenAfter;
                  if (!showToggle) return null;
                  return (
                    <div className="pt-1 flex justify-end">
                      <button
                        className="text-xs text-gray-300 hover:text-white underline"
                        onClick={() => setQueueExpanded((v) => !v)}
                      >
                        {queueExpanded ? '收合' : '展開'}
                      </button>
                    </div>
                  );
                })()}
              </CardContent>
            </Card>

            {/* History - Only show if nickname is provided */}
            {nickname && (
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2 justify-between">
                    <Clock className="w-5 h-5" />
                    <span>歷史記錄</span>
                    <span>
                      <AlertDialog>
                        <AlertDialogTrigger asChild>
                          <Button
                            variant="outline"
                            size="sm"
                            className="border-gray-600 text-gray-300 hover:bg-gray-700"
                          >
                            清除歷史
                          </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent className="bg-gray-800 border-gray-700">
                          <AlertDialogHeader>
                            <AlertDialogTitle className="text-white">清除歷史記錄</AlertDialogTitle>
                            <AlertDialogDescription className="text-gray-400">
                              這將刪除您所有的點歌歷史，確定要繼續嗎？
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel className="bg-gray-700 border-gray-600 text-white hover:bg-gray-600">取消</AlertDialogCancel>
                            <AlertDialogAction
                              onClick={async () => {
                                if (!nickname) return;
                                try {
                                  await api.user.clearHistory(nickname);
                                  setHistory([]);
                                } catch {}
                              }}
                              style={{ backgroundColor: "#e74c3c" }}
                              className="hover:opacity-80"
                            >
                              清除
                            </AlertDialogAction>
                          </AlertDialogFooter>
                        </AlertDialogContent>
                      </AlertDialog>
                    </span>
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  {infoMsg && (
                    <div className="text-xs text-gray-400">{infoMsg}</div>
                  )}
                  {history.length === 0 && (
                    <div className="text-gray-400 text-sm">目前沒有歷史記錄</div>
                  )}
                  {(historyExpanded ? history : history.slice(0, 5)).map((song) => (
                <HistoryRow
                  key={song.id}
                  song={song}
                  onDelete={(s) => setSelectedHistory(s)}
                />
              ))}
                  {history.length > 5 && (
                    <div className="pt-1 flex justify-end">
                      <button
                        className="text-xs text-gray-300 hover:text-white underline"
                        onClick={() => setHistoryExpanded((v) => !v)}
                      >
                        {historyExpanded ? '收合' : '展開'}
                      </button>
                    </div>
                  )}
                </CardContent>
              </Card>
            )}
          </div>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Liked Songs - Only show if nickname is provided */}
            {nickname && likedSongs.length > 0 && (
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Heart className="w-5 h-5 text-red-500" />
                    喜歡的歌曲
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  {infoMsg && (
                    <div className="text-xs text-gray-400">{infoMsg}</div>
                  )}
                  {(likedExpanded ? likedSongs : likedSongs.slice(0, 5)).map((song) => (
                    <div
                      key={song.id}
                      className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                    >
                      <div className="flex items-center gap-3 flex-1">
                        {song.thumbnail && (
                          <img src={song.thumbnail} alt="thumb" className="w-10 h-10 object-cover rounded" />
                        )}
                        <div className="flex-1">
                          <h4 className="font-medium">{song.title}</h4>
                          <p className="text-gray-400 text-sm">
                            {song.artist}{song.album ? ` • ${song.album}` : ''}{song.duration ? ` • ${song.duration}` : ''}
                          </p>
                        </div>
                      </div>
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => toggleLike(song)}
                          className="border-gray-600 text-red-500 hover:bg-gray-700 hover:text-red-400"
                        >
                          <Heart className="w-4 h-4 fill-current" />
                        </Button>
                        <Button
                          size="sm"
                          onClick={() => {
                            addToQueue(song);
                            // 將最近從「喜歡的歌曲」加入的項目移到最上面
                            setLikedSongs((prev) => {
                              const id = song.videoId || song.id;
                              const rest = prev.filter((s) => (s.videoId || s.id) !== id);
                              return [
                                { ...song, id: id, videoId: id },
                                ...rest,
                              ];
                            });
                          }}
                          disabled={!!(song.videoId || song.id) && adding.has(song.videoId || song.id)}
                          style={{ backgroundColor: "#e74c3c" }}
                          className="hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <Plus className="w-4 h-4 mr-1" />
                          {((song.videoId || song.id) && adding.has(song.videoId || song.id)) ? '加入中…' : '加入'}
                        </Button>
                      </div>
                    </div>
                  ))}
                  {likedSongs.length > 5 && (
                    <div className="pt-1 flex justify-end">
                      <button
                        className="text-xs text-gray-300 hover:text-white underline"
                        onClick={() => setLikedExpanded((v) => !v)}
                      >
                        {likedExpanded ? '收合' : '展開'}
                      </button>
                    </div>
                  )}
                </CardContent>
              </Card>
            )}

            {/* Recommendations - Only show if nickname is provided */}
            {nickname && (
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader className="flex flex-row items-center justify-between">
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      <Star className="w-5 h-5" />
                      推薦歌曲
                    </CardTitle>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={refreshRecommendations}
                    disabled={!nickname || recoLoading}
                    className="border-gray-600 text-gray-300 hover:bg-gray-700"
                  >
                    <RefreshCw className={`w-4 h-4 mr-1 ${recoLoading ? 'animate-spin' : ''}`} />
                    刷新
                  </Button>
                </CardHeader>
                <CardContent className="space-y-3">
                  {infoMsg && (
                    <div className="text-xs text-gray-400">{infoMsg}</div>
                  )}
                  {reco.map((song) => (
                    <div
                      key={song.id}
                      className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                    >
                      <div className="flex items-center gap-3 flex-1">
                        {song.thumbnail && (
                          <img src={song.thumbnail} alt="thumb" className="w-10 h-10 object-cover rounded" />
                        )}
                        <div className="flex-1">
                          <h4 className="font-medium">{song.title}</h4>
                          <p className="text-gray-400 text-sm">
                            {song.artist}{song.album ? ` • ${song.album}` : ''}{song.duration ? ` • ${song.duration}` : ''}
                          </p>
                        </div>
                      </div>
                      <Button
                        size="sm"
                        onClick={() => addToQueue(song)}
                        disabled={!!(song.videoId || song.id) && adding.has(song.videoId || song.id)}
                        style={{ backgroundColor: "#e74c3c" }}
                        className="hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        <Plus className="w-4 h-4 mr-1" />
                        {((song.videoId || song.id) && adding.has(song.videoId || song.id)) ? '加入中…' : '加入'}
                      </Button>
                    </div>
                  ))}
                  {reco.length === 0 && (
                    <div className="text-gray-400 text-sm">尚無推薦，請先點幾首歌試試。</div>
                  )}
                </CardContent>
              </Card>
            )}
          </div>
        </div>

        {/* Delete Song Dialog */}
        {/* Delete Song from Queue Dialog */}
  <AlertDialog
          open={!!selectedSong}
          onOpenChange={(open) => {
            if (!open) setSelectedSong(null);
          }}
        >
          <AlertDialogContent className="bg-gray-800 border-gray-700">
            <AlertDialogHeader>
              <AlertDialogTitle className="text-white">
                歌曲操作
              </AlertDialogTitle>
              <AlertDialogDescription className="text-gray-400">
                是否跳轉到「{selectedSong?.title}」？
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel
                onClick={() => setSelectedSong(null)}
                className="bg-gray-700 border-gray-600 text-white hover:bg-gray-600"
              >
                取消
              </AlertDialogCancel>
              <AlertDialogAction
                onClick={async () => {
                  if (selectedSong) {
                    await jumpToQueueItem(selectedSong as any);
                  }
                  setSelectedSong(null);
                }}
                style={{ backgroundColor: "#3b82f6" }}
                className="hover:opacity-80"
              >
                跳轉
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        {/* Delete History Item Dialog */}
        <AlertDialog
          open={!!selectedHistory}
          onOpenChange={(open) => {
            if (!open) setSelectedHistory(null);
          }}
        >
          <AlertDialogContent className="bg-gray-800 border-gray-700">
            <AlertDialogHeader>
              <AlertDialogTitle className="text-white">
                刪除歷史項目
              </AlertDialogTitle>
              <AlertDialogDescription className="text-gray-400">
                您要刪除「{selectedHistory?.title}」這筆歷史記錄嗎？
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel
                onClick={() => setSelectedHistory(null)}
                className="bg-gray-700 border-gray-600 text-white hover:bg-gray-600"
              >
                取消
              </AlertDialogCancel>
              <AlertDialogAction
                onClick={async () => {
                  if (!nickname || !selectedHistory) return;
                  try {
                    await api.user.removeHistoryItem(nickname, selectedHistory.videoId || selectedHistory.id);
                    setHistory((prev) => prev.filter((s) => s.id !== (selectedHistory.videoId || selectedHistory.id)));
                  } catch {}
                  setSelectedHistory(null);
                }}
                style={{ backgroundColor: "#e74c3c" }}
                className="hover:opacity-80"
              >
                刪除
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        {/* Footer Credit */}
        <footer className="text-center text-gray-500 text-xs mt-8">
          <p className="space-x-2">
            <span>
              基於 <a className="underline" href="https://github.com/th-ch/youtube-music" target="_blank" rel="noreferrer">YouTube Music Desktop App</a> 開發
            </span>
            <span>•</span>
            <span>
              點歌系統由 <strong className="text-gray-200">CBC</strong> 修改
            </span>
            <span>•</span>
            <a className="underline" href="https://github.com/CBC0210/YTMD_BC" target="_blank" rel="noreferrer">查看原始碼</a>
          </p>
        </footer>
      </div>


    {/* Top Toast */}
    {toastMsg && (
      <div className="fixed top-0 left-0 right-0 z-50 flex justify-center pointer-events-none" style={{ paddingTop: "env(safe-area-inset-top)" }}>
        <div className="mt-3 bg-black/75 text-white text-sm px-4 py-2 rounded-full shadow-md pointer-events-auto">
          {toastMsg}
        </div>
      </div>
    )}
  </div>
  );
}