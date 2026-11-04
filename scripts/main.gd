extends Node2D
## 游戏入口：承载关卡和 HUD，管音乐和重开。
##
## 第一次进游戏时 Game 里的就是默认值，不用重置；之后的重置都由 R 键触发，
## 这样死亡复活时命数不会被刷回满。

func _ready() -> void:
	Audio.play_music()
	# 自己接管退出：先停音乐再退。
	# 不然循环播放的 MP3 会在退出日志里报 2 个对象泄漏。
	get_tree().auto_accept_quit = false


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
