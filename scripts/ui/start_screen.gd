extends CanvasLayer
## 开场标题画面。
##
## 显示的时候整个游戏是暂停的（Main 会 set_tree.paused = true），
## 所以这里的 process_mode 必须是 ALWAYS，不然收不到按键。

signal start_pressed()

@onready var prompt: Label = $Center/Box/Prompt
@onready var controls: GridContainer = $Center/Box/Controls

## 操作说明：左边是动作，右边是按键
const CONTROL_ROWS := [
	["MOVE", "A D  /  ARROWS"],
	["JUMP", "SPACE   (HOLD = HIGHER)"],
	["ROLL", "S  /  DOWN"],
	["NEXT LEVEL", "ENTER"],
	["PAUSE", "ESC"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fill_controls()
	# 「PRESS SPACE」呼吸闪烁
	var tw := create_tween().set_loops()
	tw.tween_property(prompt, "modulate:a", 0.25, 0.55)
	tw.tween_property(prompt, "modulate:a", 1.0, 0.55)


func show_start() -> void:
	visible = true


func _fill_controls() -> void:
	for row in CONTROL_ROWS:
		var action := Label.new()
		action.text = row[0]
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		controls.add_child(action)

		var keys := Label.new()
		keys.text = row[1]
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		keys.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		controls.add_child(keys)


## 用 _input 而不是 _unhandled_input：
## _input 在 GUI 之前触发，盖在画面上的全屏遮罩不会把按键吃掉。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		visible = false
		start_pressed.emit()
