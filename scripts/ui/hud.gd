extends CanvasLayer
## 顶部状态条 + 中间提示文字。

@onready var score_label: Label = $Top/Box/Score
@onready var coins_label: Label = $Top/Box/Coins
@onready var health_label: Label = $Top/Box/Health
@onready var lives_label: Label = $Top/Box/Lives
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
	score_label.text = "分数 %d" % Game.score
	coins_label.text = "金币 %d/%d" % [Game.coins, Game.total_coins]
	health_label.text = "血 %d/%d" % [Game.health, Game.MAX_HEALTH]
	lives_label.text = "命 %d" % Game.lives


func _on_game_over() -> void:
	message.text = "游戏结束\n按 R 重来"


func _on_cleared() -> void:
	message.text = "通关！\n分数 %d　按 R 再玩一次" % Game.score
