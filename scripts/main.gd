extends Node2D
## 游戏入口：承载关卡和 HUD，管音乐、关卡切换和重开。
##
## 第一次进游戏时 Game 里的就是默认值，不用重置；之后的重置都由 R 键触发，
## 这样死亡复活时命数不会被刷回满。

## 基准视口大小。实际视口会按屏幕尺寸调整成能整数整除的值，见 _fit_to_screen()。
const BASE_SIZE := Vector2i(640, 360)

## 关卡场景，按顺序。第 N 关就是数组第 N 个。
const LEVEL_SCENES := [
	preload("res://scenes/levels/Level01.tscn"),
	preload("res://scenes/levels/Level02.tscn"),
	preload("res://scenes/levels/Level03.tscn"),
]

var level: Node2D = null


func _ready() -> void:
	Audio.play_music()
	_fit_to_screen()
	get_tree().root.size_changed.connect(_fit_to_screen)
	# 自己接管退出：先停音乐再退。
	# 不然循环播放的 MP3 会在退出日志里报 2 个对象泄漏。
	get_tree().auto_accept_quit = false
	load_level()


## 载入当前关卡。关卡节点统一叫 "Level"，方便外部按名字找。
func load_level() -> void:
	if level != null:
		# 先从树上摘掉再排队释放，不然旧关卡这一帧还会 _process，
		# 可能在新关卡就绪之前误判通关。
		remove_child(level)
		level.queue_free()
	var idx := clampi(Game.level_index, 0, LEVEL_SCENES.size() - 1)
	level = LEVEL_SCENES[idx].instantiate()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)


## 让画面恰好填满窗口、不留黑边，同时保持像素是整数倍放大。
##
## 做法：先按窗口尺寸算出一个整数倍 s，再把逻辑视口设成 ceil(窗口 / s)。
## 这样 窗口 / 视口 正好等于 s，一个像素都不多不少，既没有黑边也不是小数倍缩放。
func _fit_to_screen() -> void:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return
	var s: int = maxi(1, mini(win.x / BASE_SIZE.x, win.y / BASE_SIZE.y))
	var vp := Vector2i(ceili(win.x / float(s)), ceili(win.y / float(s)))
	var root := get_tree().root
	if root.content_scale_size != vp:
		root.content_scale_size = vp


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Audio.stop_music()
		await get_tree().process_frame
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		# 输了就从头再来；全部通关了也从头再来。
		# 只是重开本关的话关卡序号不动。
		if Game.all_cleared or (Game.finished and not Game.cleared):
			Game.level_index = 0
		Game.reset()
		load_level()
	elif event.is_action_pressed("next_level"):
		# 通关后按 Enter / 空格进下一关
		if Game.cleared and not Game.all_cleared:
			get_viewport().set_input_as_handled()
			if Game.next_level():
				Game.reset_for_next_level()
				load_level()
	elif event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_fit_to_screen.call_deferred()
