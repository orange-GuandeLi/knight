# 音频

两类：背景音乐 `music/`、音效 `sounds/`。

## music/

| 文件 | 规格 | 时长 | 循环 |
|---|---|---|---|
| `time_for_adventure.mp3` | 320kbps / 44100Hz / 立体声 | 40.05s | 是 |

导入时把 `.import` 里的 `loop` 设成 `true`，所以 `AudioStreamMP3.loop` 是开着的，
交给 `AudioStreamPlayer.play()` 就会自动无缝循环。

## sounds/

全是 **44100Hz / 单声道 / 8bit PCM** 的 WAV（8bit 的颗粒感正好配像素画）。

| 文件 | 时长 | 用在哪 |
|---|---|---|
| `jump.wav` | 0.09s | 玩家起跳、翻滚跳 |
| `coin.wav` | 0.20s | 吃金币 |
| `power_up.wav` | 0.36s | 吃蘑菇 / 药瓶 / 水果、通关 |
| `hurt.wav` | 0.17s | 玩家受伤 |
| `explosion.wav` | 0.45s | 史莱姆被踩死 |
| `tap.wav` | 0.03s | 顶互动块 |

## 播放方式

不用在每个场景里挂 `AudioStreamPlayer`，统一走 `scripts/autoload/audio.gd`（自动加载名 `Audio`）：

```gdscript
Audio.play_sfx("coin")     # 播一个音效，名字见上面那张表
Audio.play_music()         # 开始循环背景音乐（重复调用无害）
Audio.stop_music()
```

音效用一个 8 路的播放器池轮转，同一帧触发多个音效不会互相截断。
音乐和音效分两个播放器，音量分别写在 `audio.gd` 的 `MUSIC_DB` / `SFX_DB`。
