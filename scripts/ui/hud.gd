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
	score_label.text = "SCORE %d" % Game.score
	coins_label.text = "COINS %d/%d" % [Game.coins, Game.total_coins]
	health_label.text = "HP %d/%d" % [Game.health, Game.MAX_HEALTH]
	lives_label.text = "LIVES %d" % Game.lives


func _on_game_over() -> void:
	message.text = "GAME OVER\nPRESS R TO RETRY"


func _on_cleared() -> void:
	message.text = "LEVEL CLEAR!\nSCORE %d   PRESS R" % Game.score
