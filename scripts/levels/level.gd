extends Node2D
## 关卡 01：按 level01.json 里的字符地图铺砖、生成实体。

const DATA_PATH := "res://scenes/levels/level01.json"

const COIN_SCENE := preload("res://scenes/objects/Coin.tscn")
const SLIME_SCENE := preload("res://scenes/actors/Slime.tscn")
const PICKUP_SCENE := preload("res://scenes/objects/Pickup.tscn")

const TILE := 16
const CLEAR_COL := 4             # 离右边界还剩几列就算通关
const DECOR_MARK := "P"          # 关卡数据里植物占位用的字符，不铺地形砖

var width := 0
var height := 0
var top_rows := 0
var map_rows: Array = []
var tile_names: Dictionary = {}
var entity_names: Dictionary = {}
var spawn := Vector2i(4, 26)
var trees: Array = []
var grass: Array = []

@onready var terrain: TileMapLayer = $Terrain
@onready var background: TileMapLayer = $Background
@onready var decor: TileMapLayer = $Decor
@onready var entities: Node2D = $Entities
@onready var player: Player = $Player


func _ready() -> void:
	_load_data()
	LevelBounds.RIGHT = float(width * TILE)
	LevelBounds.BOTTOM = float(height * TILE)

	Game.set_health(Game.MAX_HEALTH)

	_setup_player()
	_paint_background()
	_paint_map()
	_paint_decor()
	_spawn_entities()

	Game.set_total_coins(_count_char("o"))


## 把关卡数据从 json 读进来
func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("读不到关卡数据 %s" % DATA_PATH)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		push_error("关卡数据格式不对")
		return
	width = int(d.get("width", 0))
	height = int(d.get("height", 0))
	top_rows = int(d.get("top_rows", 0))
	map_rows = d.get("map", [])
	tile_names = d.get("tiles", {})
	entity_names = d.get("entities", {})
	var sp: Array = d.get("spawn", [4, 26])
	spawn = Vector2i(int(sp[0]), int(sp[1]))
	var deco: Dictionary = d.get("decor", {})
	trees = deco.get("trees", [])
	grass = deco.get("grass", [])


func _setup_player() -> void:
	player.level_bottom = LevelBounds.BOTTOM
	player.position = Vector2(spawn.x * TILE + TILE / 2.0, spawn.y * TILE)
	player.head_bump.connect(_on_head_bump)
	player.died.connect(_on_player_died)

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
					entities.add_child(slime)
					slimes += 1
	print("[关卡] 金币 %d 个，史莱姆 %d 只" % [coins, slimes])


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
	Audio.play_sfx("tap")

	var kind := "mushroom" if key.ends_with("_question") else "potion"
	var p := PICKUP_SCENE.instantiate()
	p.kind = kind
	p.position = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE - TILE / 2.0)
	entities.add_child(p)
	p.pop_from(p.position.y)


# ---------------------------------------------------------------- 通关 / 死亡

func _process(_delta: float) -> void:
	if Game.finished or player == null or player.dead:
		return
	if player.global_position.x >= float((width - CLEAR_COL) * TILE):
		Audio.play_sfx("power_up")
		Game.clear_level()


func _on_player_died() -> void:
	Game.lose_life()
	if Game.finished:
		return
	await get_tree().create_timer(0.35).timeout
	_respawn()


## 原地复活：世界状态（吃过的金币、顶过的块）保留
func _respawn() -> void:
	Game.set_health(Game.MAX_HEALTH)
	player.respawn(Vector2(spawn.x * TILE + TILE / 2.0, spawn.y * TILE))
