extends CanvasLayer
## 暂停菜单。ESC 开关，上下键选，回车确认。
##
## 暂停时整个树是暂停的，所以这里的 process_mode 必须是 ALWAYS。

signal resume_requested()
signal restart_requested()
signal quit_requested()

@onready var items: VBoxContainer = $Center/Box/Menu

const MENU_ITEMS := ["RESUME", "RESTART LEVEL", "QUIT"]

var _index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for text in MENU_ITEMS:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("font_size", 22)
		items.add_child(label)
	_refresh()


func open() -> void:
	_index = 0
	_refresh()
	visible = true


func close() -> void:
	visible = false


## 高亮当前选中的那一项
func _refresh() -> void:
	for i in items.get_child_count():
		var label := items.get_child(i) as Label
		label.modulate = (
			Color(1, 0.84, 0.35) if i == _index else Color(0.68, 0.73, 0.83))


## 用 _input 而不是 _unhandled_input：
## _input 在 GUI 之前触发，菜单上的按键不会被界面控件吃掉。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_index = (_index + 1) % MENU_ITEMS.size()
		_refresh()
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_index = (_index - 1 + MENU_ITEMS.size()) % MENU_ITEMS.size()
		_refresh()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		match _index:
			0: resume_requested.emit()
			1: restart_requested.emit()
			2: quit_requested.emit()
