extends Node
## 全局游戏状态：分数、生命、血量、金币。HUD 订阅信号刷新。

signal score_changed(score: int)
signal lives_changed(lives: int)
signal health_changed(health: int)
signal coins_changed(coins: int, total: int)
signal game_over()
signal level_cleared()

const MAX_HEALTH := 3
const START_LIVES := 3

var score := 0
var lives := START_LIVES
var health := MAX_HEALTH
var coins := 0
var total_coins := 0
var finished := false

func reset() -> void:
	score = 0
	lives = START_LIVES
	health = MAX_HEALTH
	coins = 0
	finished = false

func add_score(v: int) -> void:
	score += v
	score_changed.emit(score)

func add_coin() -> void:
	coins += 1
	add_score(100)
	coins_changed.emit(coins, total_coins)

func add_health(v: int) -> void:
	health = clampi(health + v, 0, MAX_HEALTH)
	health_changed.emit(health)

func damage(v := 1) -> bool:
	health = clampi(health - v, 0, MAX_HEALTH)
	health_changed.emit(health)
	return health <= 0

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0 and not finished:
		finished = true
		game_over.emit()

func clear_level() -> void:
	if finished:
		return
	finished = true
	level_cleared.emit()
