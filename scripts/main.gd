extends Node2D
## 游戏入口：承载关卡和 HUD，管音乐和重开。
##
## 第一次进游戏时 Game 里的就是默认值，不用重置；之后的重置都由 R 键触发，
## 这样死亡复活时命数不会被刷回满。

## 基准视口大小。实际视口会按屏幕尺寸调整成能整数整除的值，见 _fit_to_screen()。
const BASE_SIZE := Vector2i(640, 360)


func _ready() -> void:
	Audio.play_music()
	_fit_to_screen()
	get_tree().root.size_changed.connect(_fit_to_screen)
	# 自己接管退出：先停音乐再退。
	# 不然循环播放的 MP3 会在退出日志里报 2 个对象泄漏。
	get_tree().auto_accept_quit = false


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
		Game.reset()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_fit_to_screen.call_deferred()
