extends Node
## 截图工具：把真实渲染的一帧存成 PNG，用来肉眼查 UI / 排版。
##
## 用法（必须带窗口，不能 --headless，否则渲染不出来）：
##   Godot --path . res://tools/Screenshot.tscn --resolution 1280x720
##   Godot --path . res://tools/Screenshot.tscn --resolution 1280x720 -- clear   # 通关提示
##   Godot --path . res://tools/Screenshot.tscn --resolution 1280x720 -- start   # 标题画面
##   Godot --path . res://tools/Screenshot.tscn --resolution 1280x720 -- pause   # 暂停菜单
##
## 输出：/tmp/game_shot.png（或 /tmp/game_shot_<模式>.png）

func _ready() -> void:
	var main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)

	var mode := "game"
	for arg in OS.get_cmdline_user_args():
		if arg in ["clear", "start", "pause"]:
			mode = arg

	# 标题画面是开场的默认状态；其它模式要先按空格开始
	if mode != "start":
		_press(KEY_SPACE)
		await get_tree().process_frame
		await get_tree().process_frame
	if mode == "pause":
		_press(KEY_ESCAPE)
		await get_tree().process_frame
		await get_tree().process_frame
	if mode == "clear":
		Game.clear_level()
		for i in 10:
			await get_tree().process_frame

	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := "/tmp/game_shot.png"
	if mode != "game":
		out = "/tmp/game_shot_%s.png" % mode
	img.save_png(out)
	print("已保存 ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()


## 模拟按一次键。按下和松开都要发，不然动作会一直处于「按下」状态。
func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
