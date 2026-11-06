extends Node
## 通关记录。存在 user:// 里，跨次运行保留。
##
## 每关三个星：
## - 第一颗：通关
## - 第二颗：金币收够（收集率达标）
## - 第三颗：剩下的时间过半 / 命没用完

signal progress_changed()

const SAVE_PATH := "user://progress.json"
const STAR_COUNT := 3

## 各关的评价门槛（时间秒数 / 收集率）
const TIME_PARTS := [0.5, 0.3, 0.15]   # 一星：剩 50% 时间；二星：30%；三星：15%
const COLLECT_PARTS := [0.6, 0.8, 1.0] # 一星：收 60%；二星：80%；三星：全收

var levels: Dictionary = {}   # 关卡序号 -> {stars, best_time, best_score, cleared}
var unlocked := 1             # 已经解锁到第几关


func _ready() -> void:
	load_progress()


## 记一次通关成绩，返回拿到几颗星
func record_clear(level_index: int, time_left: float, time_limit: float,
		coins: int, coin_goal: int, total_coins: int, lives_left: int) -> int:
	var rec: Dictionary = levels.get(level_index, {
		"stars": 0, "best_time": 0.0, "best_score": 0, "cleared": false})

	var stars := 1
	# 第二颗：金币收集率
	var rate := 0.0
	if total_coins > 0:
		rate = float(coins) / float(total_coins)
	if rate >= COLLECT_PARTS[1]:
		stars = 2
	# 第三颗：时间剩得多 + 命没用完
	if time_limit > 0.0:
		var left_rate := time_left / time_limit
		if left_rate >= TIME_PARTS[1] and lives_left >= 2:
			stars = 3
	# 收集率满格也直接三星
	if rate >= COLLECT_PARTS[2] and time_limit > 0.0 \
			and time_left / time_limit >= TIME_PARTS[2]:
		stars = 3

	rec["stars"] = maxi(int(rec.get("stars", 0)), stars)
	rec["cleared"] = true
	rec["best_score"] = maxi(int(rec.get("best_score", 0)), Game.score)
	# 用时最短的一次
	var used := maxf(0.0, time_limit - time_left)
	var best_used := float(rec.get("best_time", 0.0))
	if best_used <= 0.0 or used < best_used:
		rec["best_time"] = used
	levels[level_index] = rec

	unlocked = maxi(unlocked, mini(level_index + 2, Game.LEVEL_COUNT))
	save_progress()
	progress_changed.emit()
	return stars


func get_stars(level_index: int) -> int:
	return int(levels.get(level_index, {}).get("stars", 0))


func is_cleared(level_index: int) -> bool:
	return bool(levels.get(level_index, {}).get("cleared", false))


func get_best_score(level_index: int) -> int:
	return int(levels.get(level_index, {}).get("best_score", 0))


func total_stars() -> int:
	var n := 0
	for k in levels:
		n += int(levels[k].get("stars", 0))
	return n


func max_stars() -> int:
	return Game.LEVEL_COUNT * STAR_COUNT


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("存不了进度 %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify({"levels": levels, "unlocked": unlocked}))
	f.close()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		return
	var lv = data.get("levels", {})
	if lv is Dictionary:
		levels = lv
	unlocked = int(data.get("unlocked", 1))
	progress_changed.emit()


## 重新开始（清空所有记录）
func reset_progress() -> void:
	levels = {}
	unlocked = 1
	save_progress()
	progress_changed.emit()
