extends Node
## 音效 + 背景音乐。
## 音效走一个 8 路的播放器池（同一帧多个音效不会互相打断），音乐单独一个循环播放器。

const SFX := {
	"coin": preload("res://assets/audio/sounds/coin.wav"),
	"explosion": preload("res://assets/audio/sounds/explosion.wav"),
	"hurt": preload("res://assets/audio/sounds/hurt.wav"),
	"jump": preload("res://assets/audio/sounds/jump.wav"),
	"power_up": preload("res://assets/audio/sounds/power_up.wav"),
	"tap": preload("res://assets/audio/sounds/tap.wav"),
}

const MUSIC_PATH := "res://assets/audio/music/time_for_adventure.mp3"

const POOL_SIZE := 8
const SFX_DB := -7.0
const MUSIC_DB := -14.0

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_stream: AudioStream = null
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_pool.append(p)

	_music_stream = load(MUSIC_PATH)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.stream = _music_stream
	_music.volume_db = MUSIC_DB
	add_child(_music)


## 退出时把还在播的音乐停掉并松开引用，否则 MP3 播放对象会泄漏在退出日志里
func _exit_tree() -> void:
	stop_music()
	if _music != null:
		_music.stream = null
	for p in _pool:
		p.stop()
		p.stream = null
	_pool.clear()
	_music_stream = null


## 播放一个音效，名字见 SFX 表的键
func play_sfx(sfx_name: String) -> void:
	if not SFX.has(sfx_name):
		push_warning("没有这个音效：%s" % sfx_name)
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SFX[sfx_name]
	p.volume_db = SFX_DB
	p.play()


func play_music() -> void:
	if _music != null and not _music.playing:
		_music.play()


func stop_music() -> void:
	if _music != null:
		_music.stop()


func set_music_volume(db: float) -> void:
	if _music != null:
		_music.volume_db = db
