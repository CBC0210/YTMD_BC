import React, { useState } from "react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "./components/ui/card";
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
} from "lucide-react";

interface Song {
  id: string;
  title: string;
  artist: string;
  album?: string;
  duration?: string;
}

interface QueueItem extends Song {
  status: "playing" | "queued";
  queuePosition: number;
}

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
  const [isPlaying, setIsPlaying] = useState(true);
  const [currentTime, setCurrentTime] = useState(95); // in seconds
  const [volume, setVolume] = useState(75);
  const [likedSongs, setLikedSongs] = useState<Song[]>([]);

  // Mock data for search results
  const mockSearchResults: Song[] = [
    {
      id: "3",
      title: "稻香",
      artist: "周杰倫",
      album: "魔杰座",
      duration: "3:44",
    },
    {
      id: "4",
      title: "青花瓷",
      artist: "周杰倫",
      album: "我很忙",
      duration: "3:58",
    },
    {
      id: "5",
      title: "彩虹",
      artist: "周杰倫",
      album: "我很忙",
      duration: "4:25",
    },
    {
      id: "6",
      title: "蒲公英的約定",
      artist: "周杰倫",
      album: "我很忙",
      duration: "3:56",
    },
    {
      id: "13",
      title: "安靜",
      artist: "周杰倫",
      album: "范特西",
      duration: "4:14",
    },
    {
      id: "14",
      title: "晴天",
      artist: "周杰倫",
      album: "葉惠美",
      duration: "4:29",
    },
    {
      id: "15",
      title: "回到過去",
      artist: "周杰倫",
      album: "八度空間",
      duration: "3:46",
    },
    {
      id: "16",
      title: "說好不哭",
      artist: "周杰倫",
      album: "說好不哭",
      duration: "4:08",
    },
    {
      id: "17",
      title: "花海",
      artist: "周杰倫",
      album: "魔杰座",
      duration: "4:21",
    },
    {
      id: "18",
      title: "世界末日",
      artist: "周杰倫",
      album: "葉惠美",
      duration: "3:42",
    },
  ];

  // Mock data for history and recommendations
  const historyData: Song[] = [
    {
      id: "7",
      title: "不能說的秘密",
      artist: "周杰倫",
      album: "不能說的秘密電影原聲帶",
      duration: "4:23",
    },
    {
      id: "8",
      title: "七里香",
      artist: "周杰倫",
      album: "七里香",
      duration: "4:05",
    },
    {
      id: "9",
      title: "簡單愛",
      artist: "周杰倫",
      album: "范特西",
      duration: "4:25",
    },
  ];

  const recommendationsData: Song[] = [
    {
      id: "10",
      title: "楓",
      artist: "周杰倫",
      album: "十一月的蕭邦",
      duration: "4:33",
    },
    {
      id: "11",
      title: "髮如雪",
      artist: "周杰倫",
      album: "十二新作",
      duration: "5:02",
    },
    {
      id: "12",
      title: "東風破",
      artist: "周杰倫",
      album: "葉惠美",
      duration: "3:49",
    },
  ];

  const handleSearch = (query: string) => {
    if (query.trim()) {
      const searchTerm = query.toLowerCase();
      setSearchResults(
        mockSearchResults.filter(
          (song) =>
            song.title.toLowerCase().includes(searchTerm) ||
            song.artist.toLowerCase().includes(searchTerm) ||
            (song.album &&
              song.album.toLowerCase().includes(searchTerm)),
        ),
      );
    } else {
      setSearchResults([]);
    }
  };

  const addToQueue = (song: Song) => {
    const newQueueItem: QueueItem = {
      ...song,
      status: "queued",
      queuePosition: playQueue.length + 1,
    };
    setPlayQueue([...playQueue, newQueueItem]);
  };

  const removeFromQueue = (songId: string) => {
    setPlayQueue((prev) =>
      prev
        .filter((item) => item.id !== songId)
        .map((item, index) => ({
          ...item,
          queuePosition: index + 1,
        })),
    );
    setSelectedSong(null);
  };

  const clearQueue = () => {
    setPlayQueue((prev) =>
      prev.filter((item) => item.status === "playing"),
    );
  };

  const handleSongClick = (song: QueueItem) => {
    setSelectedSong(song);
  };

  const handleNicknameConfirm = () => {
    setNickname(nicknameInput.trim());
  };

  const handleNicknameClear = () => {
    setNickname("");
    setNicknameInput("");
  };

  const getCurrentSong = () => {
    return playQueue.find((song) => song.status === "playing");
  };

  const togglePlayPause = () => {
    setIsPlaying(!isPlaying);
  };

  const playNext = () => {
    const currentIndex = playQueue.findIndex(
      (song) => song.status === "playing",
    );
    if (currentIndex < playQueue.length - 1) {
      const newQueue = playQueue.map((song, index) => ({
        ...song,
        status:
          index === currentIndex + 1
            ? ("playing" as const)
            : ("queued" as const),
      }));
      setPlayQueue(newQueue);
      setCurrentTime(0);
    }
  };

  const playPrevious = () => {
    const currentIndex = playQueue.findIndex(
      (song) => song.status === "playing",
    );
    if (currentIndex > 0) {
      const newQueue = playQueue.map((song, index) => ({
        ...song,
        status:
          index === currentIndex - 1
            ? ("playing" as const)
            : ("queued" as const),
      }));
      setPlayQueue(newQueue);
      setCurrentTime(0);
    }
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
    setLikedSongs(prev => {
      const isLiked = prev.some(likedSong => likedSong.id === song.id);
      if (isLiked) {
        return prev.filter(likedSong => likedSong.id !== song.id);
      } else {
        return [...prev, song];
      }
    });
  };

  const isLiked = (songId: string) => {
    return likedSongs.some(song => song.id === songId);
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6 dark">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold mb-2">
            音樂點播系統
          </h1>
          <p className="text-gray-400">享受您的音樂時光</p>
        </div>

        {/* Now Playing Section */}
        {getCurrentSong() && (
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle>正在播放</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Song Info */}
              <div className="text-center">
                <h3 className="text-lg font-medium">
                  {getCurrentSong()?.title}
                </h3>
                <p className="text-gray-400">
                  {getCurrentSong()?.artist}
                </p>
              </div>

              {/* Progress Bar */}
              <div className="space-y-2">
                <Slider
                  value={[currentTime]}
                  onValueChange={(value) =>
                    setCurrentTime(value[0])
                  }
                  max={
                    getCurrentSong()?.duration
                      ? parseDuration(
                          getCurrentSong()!.duration!,
                        )
                      : 225
                  }
                  step={1}
                  className="w-full"
                />
                <div className="flex justify-between text-sm text-gray-400">
                  <span>{formatTime(currentTime)}</span>
                  <span>
                    {getCurrentSong()?.duration || "3:45"}
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
                  onClick={() => getCurrentSong() && toggleLike(getCurrentSong()!)}
                  className={`border-gray-600 hover:bg-gray-700 ${
                    getCurrentSong() && isLiked(getCurrentSong()!.id)
                      ? 'text-red-500 hover:text-red-400'
                      : 'text-gray-300 hover:text-red-400'
                  }`}
                >
                  <Heart
                    className={`w-4 h-4 ${
                      getCurrentSong() && isLiked(getCurrentSong()!.id) ? 'fill-current' : ''
                    }`}
                  />
                </Button>
              </div>

              {/* Volume Control */}
              <div className="flex items-center gap-3">
                <Volume2 className="w-4 h-4 text-gray-400" />
                <Slider
                  value={[volume]}
                  onValueChange={(value) => setVolume(value[0])}
                  max={100}
                  step={1}
                  className="flex-1"
                />
                <span className="text-sm text-gray-400 w-8">
                  {volume}
                </span>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Search Section */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Search className="w-5 h-5" />
              搜尋音樂
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Input
              placeholder="輸入歌曲名稱或歌手..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                handleSearch(e.target.value);
              }}
              className="bg-gray-700 border-gray-600 text-white placeholder-gray-400"
            />
          </CardContent>
        </Card>

        {/* Search Results */}
        {searchQuery && (
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle>搜尋結果</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {searchResults.length > 0 ? (
                searchResults.map((song) => (
                  <div
                    key={song.id}
                    className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                  >
                    <div className="flex-1">
                      <h4 className="font-medium">
                        {song.title}
                      </h4>
                      <p className="text-gray-400 text-sm">
                        {song.artist} • {song.album} •{" "}
                        {song.duration}
                      </p>
                    </div>
                    <Button
                      size="sm"
                      onClick={() => addToQueue(song)}
                      style={{ backgroundColor: "#e74c3c" }}
                      className="hover:opacity-80"
                    >
                      <Plus className="w-4 h-4 mr-1" />
                      加入佇列
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
                <CardTitle>播放佇列</CardTitle>
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button
                      variant="outline"
                      size="sm"
                      className="border-gray-600 text-gray-300 hover:bg-gray-700"
                    >
                      <Trash2 className="w-4 h-4 mr-1" />
                      清除佇列
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent className="bg-gray-800 border-gray-700">
                    <AlertDialogHeader>
                      <AlertDialogTitle className="text-white">
                        確認清除佇列
                      </AlertDialogTitle>
                      <AlertDialogDescription className="text-gray-400">
                        這將刪除除了目前播放歌曲之外的所有歌曲。此操作無法復原。
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel className="bg-gray-700 border-gray-600 text-white hover:bg-gray-600">
                        取消
                      </AlertDialogCancel>
                      <AlertDialogAction
                        onClick={clearQueue}
                        style={{ backgroundColor: "#e74c3c" }}
                        className="hover:opacity-80"
                      >
                        確認清除
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </CardHeader>
              <CardContent className="space-y-3">
                {playQueue.map((song) => (
                  <div
                    key={song.id}
                    className="flex items-center gap-3 p-3 bg-gray-700 rounded-lg cursor-pointer hover:bg-gray-600 transition-colors"
                    onClick={() => handleSongClick(song)}
                  >
                    <span className="text-gray-400 text-sm w-8">
                      {song.queuePosition}
                    </span>
                    <div className="flex-1">
                      <h4 className="font-medium">
                        {song.title}
                      </h4>
                      <p className="text-gray-400 text-sm">
                        {song.artist}
                      </p>
                    </div>
                    <Badge
                      variant={
                        song.status === "playing"
                          ? "default"
                          : "secondary"
                      }
                      style={
                        song.status === "playing"
                          ? { backgroundColor: "#e74c3c" }
                          : {}
                      }
                    >
                      {song.status === "playing"
                        ? "播放中"
                        : "等待中"}
                    </Badge>
                  </div>
                ))}
              </CardContent>
            </Card>

            {/* History - Only show if nickname is provided */}
            {nickname && (
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Clock className="w-5 h-5" />
                    歷史記錄
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  {historyData.map((song) => (
                    <div
                      key={song.id}
                      className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                    >
                      <div className="flex-1">
                        <h4 className="font-medium">
                          {song.title}
                        </h4>
                        <p className="text-gray-400 text-sm">
                          {song.artist} • {song.album} •{" "}
                          {song.duration}
                        </p>
                      </div>
                      <Button
                        size="sm"
                        onClick={() => addToQueue(song)}
                        style={{ backgroundColor: "#e74c3c" }}
                        className="hover:opacity-80"
                      >
                        <Plus className="w-4 h-4 mr-1" />
                        加入佇列
                      </Button>
                    </div>
                  ))}
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
                  {likedSongs.map((song) => (
                    <div
                      key={song.id}
                      className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                    >
                      <div className="flex-1">
                        <h4 className="font-medium">
                          {song.title}
                        </h4>
                        <p className="text-gray-400 text-sm">
                          {song.artist} • {song.album} •{" "}
                          {song.duration}
                        </p>
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
                          onClick={() => addToQueue(song)}
                          style={{ backgroundColor: "#e74c3c" }}
                          className="hover:opacity-80"
                        >
                          <Plus className="w-4 h-4 mr-1" />
                          加入佇列
                        </Button>
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}

            {/* Recommendations - Only show if nickname is provided */}
            {nickname && (
              <Card className="bg-gray-800 border-gray-700">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Star className="w-5 h-5" />
                    推薦歌曲
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  {recommendationsData.map((song) => (
                    <div
                      key={song.id}
                      className="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
                    >
                      <div className="flex-1">
                        <h4 className="font-medium">
                          {song.title}
                        </h4>
                        <p className="text-gray-400 text-sm">
                          {song.artist} • {song.album} •{" "}
                          {song.duration}
                        </p>
                      </div>
                      <Button
                        size="sm"
                        onClick={() => addToQueue(song)}
                        style={{ backgroundColor: "#e74c3c" }}
                        className="hover:opacity-80"
                      >
                        <Plus className="w-4 h-4 mr-1" />
                        加入佇列
                      </Button>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}
          </div>
        </div>

        {/* Delete Song Dialog */}
        <AlertDialog
          open={!!selectedSong}
          onOpenChange={() => setSelectedSong(null)}
        >
          <AlertDialogContent className="bg-gray-800 border-gray-700">
            <AlertDialogHeader>
              <AlertDialogTitle className="text-white">
                刪除歌曲
              </AlertDialogTitle>
              <AlertDialogDescription className="text-gray-400">
                您要從佇列中刪除「{selectedSong?.title}」嗎？
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
                onClick={() =>
                  selectedSong &&
                  removeFromQueue(selectedSong.id)
                }
                style={{ backgroundColor: "#e74c3c" }}
                className="hover:opacity-80"
              >
                刪除
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </div>
  );
}