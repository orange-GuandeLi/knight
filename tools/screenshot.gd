extends Node
## 截图工具：把真实渲染的一帧存成 PNG，用来肉眼查 UI / 排版。
##
## 用法（必须带窗口，不能 --headless，否则渲染不出来）：
##   Godot --path . res://tools/Screenshot.tscn --resolution 1280x720
##   Godot --path . res://tools/Screenshot.tscn --resolution 1280x720 -- clear   # 顺带触发通关提示
##
## 输出：/tmp/game_shot.png（或 /tmp/game_shot_clear.png）

func _ready() -> void:
	var main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	for i in 40:
		await get_tree().process_frame
	var out := "/tmp/game_shot.png"
	for arg in OS.get_cmdline_user_args():
		if arg == "clear":
			Game.clear_level()
			out = "/tmp/game_shot_clear.png"
			for i in 10:
				await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("已保存 ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()
