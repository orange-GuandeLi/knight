extends Node
## 全局游戏状态：分数、生命、血量、金币、连击、倒计时。HUD 订阅信号刷新。

signal score_changed(score: int)
signal lives_changed(lives: int)
signal health_changed(health: int)
signal coins_changed(coins: int, goal: int)
signal combo_changed(combo: int)
signal time_changed(time_left: float)
signal time_up()
## 到了出口但金币没收够。参数是还差多少；0 表示已经离开出口区域
signal coin_goal_short(needed: int)
signal game_over()
signal level_cleared()
signal all_levels_cleared()
## 新一关开始（重开或换关）。HUD 靠它清掉上一关的通关提示。
signal level_started()

const MAX_HEALTH := 3
const START_LIVES := 3

# 一共几关
const LEVEL_COUNT := 3

# 连击：连续吃到东西倍率就往上翻，断开就清零
const COMBO_WINDOW := 2.0      # 两次之间最多隔这么久（秒）
const COMBO_MAX := 9           # 倍率上限

# 顿帧：把整个游戏的时间缩到几乎不动，给打击感加料
const HITSTOP_SCALE := 0.04

var score := 0
var lives := START_LIVES
var health := MAX_HEALTH
var coins := 0
var coin_goal := 0            # 通关要收集多少金币
var combo := 0
var combo_timer := 0.0
var time_left := 0.0           # 0 = 不限时
var finished := false          # 本局结束了（通关或失败）
var over := false              # 彻底结束（失败），不能再复活
var cleared := false           # 当前这关通关了
var all_cleared := false       # 全部关卡都过了
var level_index := 0           # 当前关卡序号（0 起）
var stomp_chain := 0           # 踩怪连踩的连击数，落地清零
var _hitstop_until := 0        # 顿帧到第几个物理帧


func _process(delta: float) -> void:
	# 顿帧：冻结几帧再恢复
	if _hitstop_until > 0:
		if Engine.get_physics_frames() >= _hitstop_until:
			_hitstop_until = 0
			Engine.time_scale = 1.0
		else:
			Engine.time_scale = HITSTOP_SCALE

	# 连击断线
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(combo)

	# 倒计时
	if time_left > 0.0 and not finished:
		time_left = maxf(0.0, time_left - delta)
		time_changed.emit(time_left)
		if time_left <= 0.0:
			time_up.emit()


func reset() -> void:
	score = 0
	lives = START_LIVES
	health = MAX_HEALTH
	coins = 0
	coin_goal = 0
	combo = 0
	combo_timer = 0.0
	time_left = 0.0
	finished = false
	over = false
	cleared = false
	all_cleared = false
	stomp_chain = 0
	_hitstop_until = 0
	Engine.time_scale = 1.0
	# 重置也走信号，订阅方（HUD）不用自己去拉状态
	score_changed.emit(score)
	lives_changed.emit(lives)
	health_changed.emit(health)
	coins_changed.emit(coins, coin_goal)
	combo_changed.emit(combo)
	time_changed.emit(time_left)
	level_started.emit()


## 换关时用：总分保留，血量、命数、金币、连击重置。
func reset_for_next_level() -> void:
	lives = START_LIVES
	health = MAX_HEALTH
	coins = 0
	coin_goal = 0
	combo = 0
	combo_timer = 0.0
	time_left = 0.0
	finished = false
	over = false
	cleared = false
	lives_changed.emit(lives)
	health_changed.emit(health)
	coins_changed.emit(coins, coin_goal)
	combo_changed.emit(combo)
	time_changed.emit(time_left)
	level_started.emit()


## 前进到下一关。返回 false 表示已经是最后一关了。
func next_level() -> bool:
	if level_index + 1 >= LEVEL_COUNT:
		all_cleared = true
		all_levels_cleared.emit()
		return false
	level_index += 1
	return true


func add_score(v: int) -> void:
	score += v
	score_changed.emit(score)


## 顿帧：整个游戏冻结几帧。踩怪、砸箱子、顶砖的时候用。
func hitstop(frames: int = 3) -> void:
	_hitstop_until = Engine.get_physics_frames() + frames
	Engine.time_scale = HITSTOP_SCALE


## 踩怪连踩：连续踩中不同的怪，倍率往上翻。落地就清零。
## 跟「连击」的区别：连击看时间窗口，这个看滞空——踩一只弹起来再踩下一只就翻倍。
func bump_stomp_chain() -> int:
	stomp_chain = mini(stomp_chain + 1, 8)
	return stomp_chain


## 加分并累计连击。倍率从 1 起算，断连后重新来。
func score_with_combo(base: int) -> int:
	var mult := bump_combo()
	var got := base * mult
	add_score(got)
	return got


## 记一次连击，返回当前倍率（最小 1）。
func bump_combo() -> int:
	combo = mini(combo + 1, COMBO_MAX)
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	return combo


## 打断连击。
func break_combo() -> void:
	if combo > 0:
		combo = 0
		combo_changed.emit(combo)


func add_coin() -> void:
	coins += 1
	score_with_combo(100)
	coins_changed.emit(coins, coin_goal)


## 直接设定血量。血量只能从这里改，改完自动裁剪范围并广播。
func set_health(v: int) -> void:
	health = clampi(v, 0, MAX_HEALTH)
	health_changed.emit(health)


## 直接设定命数。
func set_lives(v: int) -> void:
	lives = v
	lives_changed.emit(lives)


## 关卡加载完才知道要收多少金币。
func set_coin_goal(n: int) -> void:
	coin_goal = n
	coins_changed.emit(coins, coin_goal)


## 开一个倒计时（秒）。0 = 不限时。
func start_timer(seconds: float) -> void:
	time_left = maxf(0.0, seconds)
	time_changed.emit(time_left)


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
		over = true
		game_over.emit()


func clear_level() -> void:
	if finished:
		return
	finished = true
	cleared = true
	level_cleared.emit()


## 直接结束本局（超时之类的硬失败）。
func fail() -> void:
	if finished:
		return
	finished = true
	over = true
	game_over.emit()
