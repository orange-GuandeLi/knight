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
	total_coins = 0
	finished = false
	# 重置也走信号，订阅方（HUD）不用自己去拉状态
	score_changed.emit(score)
	lives_changed.emit(lives)
	health_changed.emit(health)
	coins_changed.emit(coins, total_coins)

func add_score(v: int) -> void:
	score += v
	score_changed.emit(score)

func add_coin() -> void:
	coins += 1
	add_score(100)
	coins_changed.emit(coins, total_coins)

## 直接设定血量。血量只能从这里改，改完自动裁剪范围并广播。
func set_health(v: int) -> void:
	health = clampi(v, 0, MAX_HEALTH)
	health_changed.emit(health)

## 直接设定命数。
func set_lives(v: int) -> void:
	lives = v
	lives_changed.emit(lives)

## 关卡加载完才知道一共有多少金币。
func set_total_coins(n: int) -> void:
	total_coins = n
	coins_changed.emit(coins, total_coins)

func add_health(v: int) -> void:
	set_health(health + v)

func damage(v := 1) -> bool:
	set_health(health - v)
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
