extends Node2D
## 游戏入口：承载关卡和 HUD，处理重开。

func _ready() -> void:
	# 第一次进游戏时 Game 里的就是默认值，不用重置；
	# 之后的重置都由 R 键触发，这样死亡读档不会把命数刷回满。
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		Game.reset()
		get_tree().reload_current_scene()
