@tool
extends SceneTree
## 生成项目里所有的 SpriteFrames 资源
##
## 用法:
##   godot --headless --path . --script res://tools/build_frames.gd
##
## 素材原始图集存在重复帧（导出工具按行整段切出），这里只取真正唯一的帧。

## 每个任务: [输出路径, [[动画名, 纹理路径模板, 帧数, 帧率, 是否循环], ...]]
const JOBS := [
	[
		"res://assets/sprites/knight/knight_frames.tres",
		[
			["idle", "res://assets/sprites/knight/idle/idle_%02d.png", 3, 6.0, true],
			["walk", "res://assets/sprites/knight/walk/walk_%02d.png", 4, 12.0, true],
			["roll", "res://assets/sprites/knight/roll/roll_%02d.png", 8, 16.0, false],
			["hurt", "res://assets/sprites/knight/hurt/hurt_%02d.png", 3, 12.0, false],
			["death", "res://assets/sprites/knight/death/death_%02d.png", 4, 8.0, false],
		],
	],
	[
		"res://assets/sprites/coin/coin_frames.tres",
		[
			["spin", "res://assets/sprites/coin/coin_%02d.png", 12, 12.0, true],
		],
	],
	[
		"res://assets/sprites/fruit/fruit_frames.tres",
		[
			["green", "res://assets/sprites/fruit/fruit_green_%02d.png", 3, 12.0, false],
			["orange", "res://assets/sprites/fruit/fruit_orange_%02d.png", 3, 12.0, false],
			["pink", "res://assets/sprites/fruit/fruit_pink_%02d.png", 3, 12.0, false],
			["red", "res://assets/sprites/fruit/fruit_red_%02d.png", 3, 12.0, false],
		],
	],
	[
		"res://assets/sprites/mushroom/mushroom_big_frames.tres",
		[
			["red", "res://assets/sprites/mushroom/mushroom_big_red.png", 1, 8.0, true],
			["gold", "res://assets/sprites/mushroom/mushroom_big_gold.png", 1, 8.0, true],
			["purple", "res://assets/sprites/mushroom/mushroom_big_purple.png", 1, 8.0, true],
			["green", "res://assets/sprites/mushroom/mushroom_big_green.png", 1, 8.0, true],
		],
	],
	[
		"res://assets/sprites/mushroom/mushroom_cluster_frames.tres",
		[
			["red", "res://assets/sprites/mushroom/mushroom_cluster_red.png", 1, 8.0, true],
			["gold", "res://assets/sprites/mushroom/mushroom_cluster_gold.png", 1, 8.0, true],
			["purple", "res://assets/sprites/mushroom/mushroom_cluster_purple.png", 1, 8.0, true],
			["green", "res://assets/sprites/mushroom/mushroom_cluster_green.png", 1, 8.0, true],
		],
	],
	[
		"res://assets/sprites/potion/potion_frames.tres",
		[
			["green", "res://assets/sprites/potion/potion_green.png", 1, 8.0, true],
			["gold", "res://assets/sprites/potion/potion_gold.png", 1, 8.0, true],
			["blue", "res://assets/sprites/potion/potion_blue.png", 1, 8.0, true],
			["purple", "res://assets/sprites/potion/potion_purple.png", 1, 8.0, true],
		],
	],
	[
		"res://assets/sprites/slime/slime_green_frames.tres",
		[
			["melt", "res://assets/sprites/slime/green/green_melt_%02d.png", 4, 8.0, false],
			["idle", "res://assets/sprites/slime/green/green_idle_%02d.png", 4, 8.0, true],
			["hurt", "res://assets/sprites/slime/green/green_hurt_%02d.png", 4, 12.0, false],
		],
	],
	[
		"res://assets/sprites/slime/slime_purple_frames.tres",
		[
			["melt", "res://assets/sprites/slime/purple/purple_melt_%02d.png", 4, 8.0, false],
			["idle", "res://assets/sprites/slime/purple/purple_idle_%02d.png", 4, 8.0, true],
			["hurt", "res://assets/sprites/slime/purple/purple_hurt_%02d.png", 4, 12.0, false],
		],
	],
]


func _init() -> void:
	for job in JOBS:
		_build(job)
	quit()


func _build(job: Array) -> void:
	var out_path: String = job[0]
	var anims: Array = job[1]

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")  # 去掉引擎自带的空动画

	for entry in anims:
		var anim_name: String = entry[0]
		var template: String = entry[1]
		var count: int = entry[2]
		var speed: float = entry[3]
		var loop: bool = entry[4]

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, speed)
		frames.set_animation_loop(anim_name, loop)

		for i in count:
			# 模板带 %02d 占位符时按序号展开；不带占位符就是单帧直接用
			var path: String = template % i if template.contains("%") else template
			var tex := load(path) as Texture2D
			if tex == null:
				push_error("缺少纹理: " + path)
				continue
			frames.add_frame(anim_name, tex)

		print("  %-6s %d 帧  %4.1f fps  loop=%s" % [anim_name, count, speed, loop])

	var err := ResourceSaver.save(frames, out_path)
	if err != OK:
		push_error("保存失败 (%d): %s" % [err, out_path])
	else:
		print("已保存: %s" % out_path)
	print("")
