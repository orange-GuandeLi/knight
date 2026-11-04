extends CanvasLayer
## 顶部状态条 + 中间提示文字。
##
## 状态条只用图标，不写文字：金币图标 + 数量 / 爱心 / 骑士头像 + 数量 / 纯数字分数。

const HEART_FULL := preload("res://assets/ui/icons/icon_heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/icons/icon_heart_empty.png")

@onready var coins_label: Label = $Row/Coins/Count
@onready var hearts: Array[TextureRect] = [
	get_node("Row/Hearts/H1") as TextureRect,
	get_node("Row/Hearts/H2") as TextureRect,
	get_node("Row/Hearts/H3") as TextureRect,
]
@onready var lives_label: Label = $Row/Lives/Count
@onready var score_label: Label = $Row/Score
@onready var message: Label = $Message


func _ready() -> void:
	Game.score_changed.connect(_on_changed)
	Game.coins_changed.connect(_on_coins)
	Game.health_changed.connect(_on_changed)
	Game.lives_changed.connect(_on_changed)
	Game.game_over.connect(_on_game_over)
	Game.level_cleared.connect(_on_cleared)
	message.text = ""
	_refresh()


func _on_changed(_v: int) -> void:
	_refresh()


func _on_coins(_c: int, _t: int) -> void:
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


func _on_game_over() -> void:
	message.text = "GAME OVER\nPRESS R TO RETRY"


func _on_cleared() -> void:
	message.text = "LEVEL CLEAR!\nSCORE %d   PRESS R" % Game.score
