extends CanvasLayer
## 顶部状态条 + 中间提示文字。
##
## 状态条只用图标，不写文字：金币图标 + 数量 / 爱心 / 骑士头像 + 数量 / 纯数字分数。
## 另外加了连击倍率（≥2 才显示）和关卡倒计时。

const HEART_FULL := preload("res://assets/ui/icons/icon_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/icons/icon_heart_empty.png")

## 倒计时剩不到这么多秒就变红
const DANGER_TIME := 10.0

@onready var coins_label: Label = $Row/Coins/Count
@onready var hearts: Array[TextureRect] = [
	get_node("Row/Hearts/H1") as TextureRect,
	get_node("Row/Hearts/H2") as TextureRect,
	get_node("Row/Hearts/H3") as TextureRect,
]
@onready var lives_label: Label = $Row/Lives/Count
@onready var combo_label: Label = $Row/Combo
@onready var time_label: Label = $Row/Time
@onready var score_label: Label = $Row/Score
@onready var message: Label = $Message


func _ready() -> void:
	Game.score_changed.connect(_on_changed)
	Game.coins_changed.connect(_on_coins)
	Game.health_changed.connect(_on_changed)
	Game.lives_changed.connect(_on_changed)
	Game.combo_changed.connect(_on_changed)
	Game.time_changed.connect(_on_time)
	Game.game_over.connect(_on_game_over)
	Game.level_cleared.connect(_on_cleared)
	Game.all_levels_cleared.connect(_on_all_cleared)
	Game.level_started.connect(_on_level_started)
	message.text = ""
	_refresh()


## 换关 / 重开：把上一关的通关提示清掉，不然会挡住新一关的画面
func _on_level_started() -> void:
	message.text = ""


func _on_changed(_v: int) -> void:
	_refresh()


func _on_coins(_c: int, _t: int) -> void:
	_refresh()


func _on_time(_t: float) -> void:
	_refresh()


func _refresh() -> void:
	coins_label.text = "%d/%d" % [Game.coins, Game.total_coins]
	score_label.text = str(Game.score)
	lives_label.text = "x%d" % Game.lives

	# 爱心：掉的血变成暗色的空心爱心
	for i in hearts.size():
		var h := hearts[i]
		h.visible = i < Game.MAX_HEALTH
		if h.visible:
			h.texture = HEART_FULL if i < Game.health else HEART_EMPTY

	# 连击：≥2 才显示，免得一直挂着个 x1 碍眼
	combo_label.visible = Game.combo >= 2
	if combo_label.visible:
		combo_label.text = "x%d" % Game.combo

	# 倒计时：没开计时就不占位
	time_label.visible = Game.time_left > 0.0
	if time_label.visible:
		time_label.text = _format_time(Game.time_left)
		time_label.modulate = (
			Color(1.0, 0.35, 0.3) if Game.time_left <= DANGER_TIME else Color.WHITE)


## 秒数转成 M:SS
func _format_time(seconds: float) -> String:
	var t := int(ceil(maxf(0.0, seconds)))
	return "%d:%02d" % [t / 60, t % 60]


func _on_game_over() -> void:
	message.text = "GAME OVER\nPRESS R TO RETRY"


func _on_cleared() -> void:
	var tail := "PRESS ENTER" if not Game.all_cleared else "PRESS R"
	message.text = "LEVEL CLEAR!\nSCORE %d   %s" % [Game.score, tail]


func _on_all_cleared() -> void:
	message.text = "ALL LEVELS CLEAR!\nSCORE %d   PRESS R" % Game.score
