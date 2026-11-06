extends Node2D
## 关卡：按关卡数据 json 里的字符地图铺砖、生成实体。
##
## 每一关一个场景（Level01 / Level02 / Level03），只有数据文件不一样。

const COIN_SCENE := preload("res://scenes/objects/Coin.tscn")
const SLIME_SCENE := preload("res://scenes/actors/Slime.tscn")
const PICKUP_SCENE := preload("res://scenes/objects/Pickup.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/objects/Checkpoint.tscn")
const DEBRIS_SCENE := preload("res://scenes/objects/Debris.tscn")
const PLATFORM_SCENE := preload("res://scenes/objects/MovingPlatform.tscn")
const CRUMBLE_SCENE := preload("res://scenes/objects/CrumbleFloor.tscn")
const ROCK_SCENE := preload("res://scenes/objects/FallingRock.tscn")
const BOSS_SCENE := preload("res://scenes/actors/Boss.tscn")

## 碎块颜色，跟地形色板一致
const DIRT_COLOR := Color(0xB6, 0x6B, 0x3A)

const TILE := 16
const SURFACE_ROW := 26
const CLEAR_COL := 4             # 离右边界还剩几列就算通关
const DECOR_MARK := "P"          # 关卡数据里植物占位用的字符，不铺地形砖

## 关卡数据。场景里可以改这一项指向别的 json。
@export_file("*.json") var data_path := "res://scenes/levels/level01.json"

var width := 0
var height := 0
var top_rows := 0
var map_rows: Array = []
var tile_names: Dictionary = {}
var entity_names: Dictionary = {}
var spawn := Vector2i(4, 26)
## 复活点。碰到检查机会被挪到那个牌子那里。
var respawn_pos := Vector2.ZERO
## 关卡限时（秒），0 = 不限时
var time_limit := 0.0
## 整份关卡数据，移动平台等要从里面读
var level_data: Dictionary = {}
## 通关要收集多少金币
var coin_goal := 0
## 这一关一共多少金币（算收集率用）
var total_coins := 0
## 当前的音乐紧张度，避免每帧重复设置
var _intensity := -1
## 已经提示过「还差多少金币」，避免每帧重复发信号
var _shown_short := -1
var trees: Array = []
var grass: Array = []

@onready var terrain: TileMapLayer = $Terrain
@onready var background: TileMapLayer = $Background
@onready var decor: TileMapLayer = $Decor
@onready var entities: Node2D = $Entities
@onready var player: Player = $Player


func _ready() -> void:
	_load_data()
	LevelBounds.LEFT = 0.0
	LevelBounds.RIGHT = float(width * TILE)
	LevelBounds.BOTTOM = float(height * TILE)

	Game.set_health(Game.MAX_HEALTH)

	_setup_player()
	_paint_background()
	_paint_map()
	_paint_decor()
	_spawn_entities()
	_spawn_platforms()
	_spawn_crumbles()
	_spawn_rocks()
	_spawn_boss()

	Game.set_coin_goal(coin_goal)
	total_coins = _count_char("o")

	# 关卡限时。开了倒计时就把 HUD 上的计时器点亮。
	Game.start_timer(time_limit)
	Game.time_up.connect(_on_time_up)


## 把关卡数据从 json 读进来
func _load_data() -> void:
	var f := FileAccess.open(data_path, FileAccess.READ)
	if f == null:
		push_error("读不到关卡数据 %s" % data_path)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		push_error("关卡数据格式不对")
		return
	level_data = d
	width = int(d.get("width", 0))
	height = int(d.get("height", 0))
	top_rows = int(d.get("top_rows", 0))
	map_rows = d.get("map", [])
	tile_names = d.get("tiles", {})
	entity_names = d.get("entities", {})
	var sp: Array = d.get("spawn", [4, 26])
	spawn = Vector2i(int(sp[0]), int(sp[1]))
	time_limit = float(d.get("time_limit", 0))
	coin_goal = int(d.get("coin_goal", 0))
	var deco: Dictionary = d.get("decor", {})
	trees = deco.get("trees", [])
	grass = deco.get("grass", [])


func _setup_player() -> void:
	player.level_bottom = LevelBounds.BOTTOM
	# 关卡左右是敞开的，告诉玩家边界在哪，免得走出关卡掉下去
	player.level_left = LevelBounds.LEFT
	player.level_right = LevelBounds.RIGHT
	respawn_pos = Vector2(spawn.x * TILE + TILE / 2.0, spawn.y * TILE)
	player.position = respawn_pos
	player.head_bump.connect(_on_head_bump)
	player.died.connect(_on_player_died)
	player.roll_strike.connect(_on_roll_strike)

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(LevelBounds.RIGHT)
		cam.limit_bottom = int(LevelBounds.BOTTOM)


# ---------------------------------------------------------------- 铺砖

func _row(y: int) -> String:
	if y < top_rows:
		return ".".repeat(width)
	var i := y - top_rows
	if i < 0 or i >= map_rows.size():
		return ".".repeat(width)
	return map_rows[i]


func _put(layer: TileMapLayer, cell: Vector2i, key: String) -> void:
	var c := TileIndex.cell(key)
	if c.is_empty():
		push_warning("找不到砖：%s" % key)
		return
	layer.set_cell(cell, c.source, c.coords)


## 背景：从上到下一条天空渐变
func _bg_key(y: int) -> String:
	var t := float(y) / float(height)
	if t < 0.14:
		return "bg_sky_1"
	if t < 0.26:
		return "bg_sky_1_2"
	if t < 0.38:
		return "bg_sky_2"
	if t < 0.50:
		return "bg_sky_2_3"
	if t < 0.62:
		return "bg_sky_3"
	if t < 0.74:
		return "bg_sky_3_4"
	return "bg_sky_4"


func _paint_background() -> void:
	var cache := {}
	for y in height:
		var key := _bg_key(y)
		if not cache.has(key):
			cache[key] = TileIndex.cell(key)
		var c: Dictionary = cache[key]
		if c.is_empty():
			continue
		for x in width:
			background.set_cell(Vector2i(x, y), c.source, c.coords)


## 植物：树 = 顶部 + body×N + 底部，草丛 = 单格
func _paint_decor() -> void:
	for g in grass:
		_put(decor, Vector2i(int(g["x"]), int(g["y"])), "grass_%s_%d" % [g["kind"], int(g["n"])])
	for t in trees:
		var x := int(t["x"])
		var y := int(t["y"])
		var kind: String = t["kind"]
		var bodies := int(t["bodies"])
		_put(decor, Vector2i(x, y), "tree_%s_bottom" % kind)
		for i in bodies:
			_put(decor, Vector2i(x, y - 1 - i), "tree_%s_body" % kind)
		_put(decor, Vector2i(x, y - 1 - bodies), "tree_%s_top" % kind)
	print("[关卡] 树 %d 棵，草丛 %d 株" % [trees.size(), grass.size()])


func _paint_map() -> void:
	var placed := 0
	for y in height:
		var row := _row(y)
		for x in width:
			var ch := row[x]
			if ch == "." or ch == DECOR_MARK or entity_names.has(ch):
				continue
			var key: String = tile_names.get(ch, "")
			if key == "":
				push_warning("地图字符 '%s' 没配砖名" % ch)
				continue
			_put(terrain, Vector2i(x, y), key)
			placed += 1
	print("[关卡] 铺砖 %d 格" % placed)


func _spawn_entities() -> void:
	var coins := 0
	var slimes := 0
	var purple := 0
	var checkpoints := 0
	var fruits := 0
	for y in height:
		var row := _row(y)
		for x in width:
			var ch := row[x]
			if not entity_names.has(ch):
				continue
			match String(entity_names[ch]):
				"coin":
					var coin := COIN_SCENE.instantiate()
					coin.position = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
					entities.add_child(coin)
					coins += 1
				"slime":
					var slime := SLIME_SCENE.instantiate()
					slime.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
					slime.target = player
					entities.add_child(slime)
					slimes += 1
				"slime_purple":
					var slime2 := SLIME_SCENE.instantiate()
					slime2.variant = "purple"
					slime2.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
					slime2.target = player
					entities.add_child(slime2)
					purple += 1
				"checkpoint":
					var cp := CHECKPOINT_SCENE.instantiate()
					cp.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
					entities.add_child(cp)
					cp.activated.connect(_on_checkpoint)
					checkpoints += 1
				"fruit":
					var fr := PICKUP_SCENE.instantiate()
					fr.kind = "fruit"
					fr.position = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
					entities.add_child(fr)
					fruits += 1
	print("[关卡] 金币 %d 个，史莱姆 %d 只（紫 %d 只），检查点 %d 个，水果 %d 个"
		% [coins, slimes, purple, checkpoints, fruits])


func _count_char(ch: String) -> int:
	var n := 0
	for y in height:
		n += _row(y).count(ch)
	return n


# ---------------------------------------------------------------- 互动块

func _key_at(cell: Vector2i) -> String:
	var src := terrain.get_cell_source_id(cell)
	if src < 0:
		return ""
	return TileIndex.key_at(src, terrain.get_cell_atlas_coords(cell))


## 头撞到天花板时，找出被撞的互动块并弹出奖励。
func _on_head_bump(world_pos: Vector2) -> void:
	var base := terrain.local_to_map(world_pos)
	for dy in [0, -1, 1]:
		var cell := base + Vector2i(0, dy)
		var key := _key_at(cell)
		if key.ends_with("_question") or key.ends_with("_exclaim"):
			_bump(cell, key)
			return


func _bump(cell: Vector2i, key: String) -> void:
	_put(terrain, cell, key + "_used")
	Game.add_score(20)
	Game.hitstop(2)
	Audio.play_sfx("tap")
	_spawn_debris(Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE), DIRT_COLOR, 6, 90.0)
	player.add_shake(1.6)

	var kind := "mushroom" if key.ends_with("_question") else "potion"
	var p := PICKUP_SCENE.instantiate()
	p.kind = kind
	p.position = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE - TILE / 2.0)
	entities.add_child(p)
	p.pop_from(p.position.y)


# ---------------------------------------------------------------- 木箱 / 检查点

## 翻滚撞到木箱：把砖从地形层抹掉，一半概率掉一枚金币。
func _on_roll_strike(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(terrain.to_local(world_pos))
	var step := 1 if player.facing > 0 else -1
	for dx in [0, step]:
		var c := cell + Vector2i(dx, 0)
		if _key_at(c).begins_with("crate_"):
			_break_crate(c)
			return


func _break_crate(cell: Vector2i) -> void:
	terrain.erase_cell(cell)
	Game.score_with_combo(50)
	Game.hitstop(3)
	Audio.play_sfx("explosion")
	_spawn_debris(Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0),
		DIRT_COLOR, 10, 150.0)
	player.add_shake(3.2)
	# 一半概率掉一枚金币
	if randf() < 0.5:
		var coin := COIN_SCENE.instantiate()
		coin.position = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
		entities.add_child(coin)


## 移动平台。它们不在字符地图里，单独从关卡数据的 platforms 段生成。
func _spawn_platforms() -> void:
	for p in level_data.get("platforms", []):
		var pl := PLATFORM_SCENE.instantiate()
		pl.tile_material = String(p.get("material", "grass"))
		pl.tiles = int(p.get("tiles", 3))
		pl.travel = Vector2(float(p.get("dx", 0.0)), float(p.get("dy", 0.0)))
		pl.speed = float(p.get("speed", 42.0))
		pl.phase = float(p.get("phase", 0.0))
		pl.position = Vector2(float(p["x"]) * TILE, float(p["y"]) * TILE)
		entities.add_child(pl)


## 会塌的地板
func _spawn_crumbles() -> void:
	for c in level_data.get("crumbles", []):
		var cf := CRUMBLE_SCENE.instantiate()
		cf.tile_material = String(c.get("material", "dirt"))
		cf.tiles = int(c.get("tiles", 2))
		cf.position = Vector2(float(c["x"]) * TILE, float(c["y"]) * TILE)
		entities.add_child(cf)

## 根据玩家在关卡的哪一段，切换音乐的紧张感
func _update_intensity() -> void:
	var col := int(player.global_position.x / TILE)
	var level := 0
	for sec in level_data.get("sections", []):
		var a: int = int(sec[1])
		var b: int = int(sec[2])
		if col >= a and col <= b:
			match String(sec[0]):
				"climax": level = 1
				"outro": level = 1
				"reward": level = 0
	if level != _intensity:
		_intensity = level
		Audio.set_music_intensity(level)


## 落石：从关卡顶部往下掉，地面有影子预警
func _spawn_rocks() -> void:
	for r in level_data.get("rocks", []):
		var x: int = int(r["x"])
		var delay: float = float(r.get("delay", 1.0))
		# 落点：那一列地面上
		var ground_y := float(_ground_row_at(x) + 1) * TILE
		var rock := ROCK_SCENE.instantiate()
		rock.position = Vector2(float(x) * TILE + TILE * 0.5, float(top_rows) * TILE)
		entities.add_child(rock)
		rock.setup(Vector2(float(x) * TILE + TILE * 0.5, 0.0), Vector2(0.0, ground_y))
		rock.hit_player.connect(_on_rock_hit)
		# 延迟开始
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(rock.start_falling)


## BOSS
func _spawn_boss() -> void:
	var b = level_data.get("boss", null)
	if b == null:
		return
	var boss := BOSS_SCENE.instantiate()
	var x := int(b["x"])
	boss.position = Vector2(float(x) * TILE + TILE * 0.5, float(_ground_row_at(x) + 1) * TILE)
	boss.target = player
	entities.add_child(boss)
	print("[关卡] BOSS 出现在 x=%d" % x)
	# BOSS 出场，音乐切到高潮
	Audio.set_music_intensity(1)


## 那一列的地面在第几行。找不到返回 SURFACE。
func _ground_row_at(x: int) -> int:
	for y in range(SURFACE_ROW, height):
		var key: String = tile_names.get(_row(y)[x], "")
		if key == "":
			continue
		if key.begins_with("bridge_") or key.begins_with("ladder_"):
			continue
		return y
	return SURFACE_ROW


## 落石砸到玩家
func _on_rock_hit(p: Player) -> void:
	if p == null or p.dead:
		return
	if p.is_shielded():
		return
	p.take_damage(p.global_position.x)
	p.add_shake(3.0)


## 撒一把碎块
func _spawn_debris(world_pos: Vector2, color: Color, count: int, speed: float = 130.0) -> void:
	var d := DEBRIS_SCENE.instantiate()
	d.position = world_pos
	d.setup(color, count, speed)
	entities.add_child(d)


## 碰到检查点：把复活点挪过来
func _on_checkpoint(pos: Vector2) -> void:
	respawn_pos = pos


## 倒计时归零：这一局结束
func _on_time_up() -> void:
	Game.fail()


# ---------------------------------------------------------------- 通关 / 死亡

func _process(_delta: float) -> void:
	if Game.finished or player == null or player.dead:
		return
	# 按关卡节奏切音乐的紧张感
	_update_intensity()
	if player.global_position.x < float((width - CLEAR_COL) * TILE):
		# 还没走到出口
		if _shown_short != 0:
			_shown_short = 0
			Game.coin_goal_short.emit(0)
		return
	# 走到出口了。金币没收够就不算通关，提示还差多少
	if Game.coins < Game.coin_goal:
		var need := Game.coin_goal - Game.coins
		if need != _shown_short:
			_shown_short = need
			Game.coin_goal_short.emit(need)
		return
	Audio.play_sfx("power_up")
	Game.clear_level()
	# 记成绩、算星星
	var stars := Progress.record_clear(
		Game.level_index, Game.time_left, time_limit,
		Game.coins, Game.coin_goal, total_coins, Game.lives)
	Game.stars_earned.emit(stars)


func _on_player_died() -> void:
	Game.lose_life()
	# 只有彻底结束（命掉光 / 超时）才不复活。
	# 关卡已经通关的话还是要能复活，不然通关后掉坑就卡死了。
	if Game.over:
		return
	await get_tree().create_timer(0.35).timeout
	_respawn()


## 原地复活：世界状态（吃过的金币、顶过的块）保留
## 复活点是最近的检查点，没碰到过检查点就是出生点。
func _respawn() -> void:
	Game.set_health(Game.MAX_HEALTH)
	player.respawn(respawn_pos)
