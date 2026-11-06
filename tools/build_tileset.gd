extends SceneTree
## 用 tools/atlas_index.json 建 TileSet。
## 物理层：0 = 实体碰撞，1 = 水（感应），2 = 木梯（感应），3 = 冰面（感应）
##
## 运行： Godot --headless --path . --script res://tools/build_tileset.gd

const ATLAS_DIR := "res://assets/tilesets/world/atlases"
const OUT := "res://assets/tilesets/world/world_tileset.tres"
const GROUPS := ["terrain", "props", "water", "bg", "plants"]

# 物理层 -> 碰撞位
const LAYER_WORLD := 0    # 位 1
const LAYER_WATER := 1    # 位 4
const LAYER_LADDER := 2   # 位 8
const LAYER_ICE := 3      # 位 16
const LAYER_SNOW := 4     # 位 32

# 冰砖：又滑又刹不住
const ICE_TILES := ["ice", "ice_stone"]
# 雪砖：不难走，是跳不高
const SNOW_TILES := ["snow_ice", "snow_stone"]



func _init() -> void:
	var idx: Dictionary = _read_index()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	_add_layer(ts, 1)
	_add_layer(ts, 4)
	_add_layer(ts, 8)
	_add_layer(ts, 16)
	_add_layer(ts, 32)

	var counts := {}
	for gi in GROUPS.size():
		var group: String = GROUPS[gi]
		var entries: Dictionary = idx[group]
		var src := TileSetAtlasSource.new()
		src.texture = load(ATLAS_DIR + "/" + group + ".png")
		src.texture_region_size = Vector2i(16, 16)
		var sid := ts.add_source(src)
		if sid != gi:
			push_error("图集 source id 不是预期的 %d（实际 %d）" % [gi, sid])
		var n := 0
		for key in entries.keys():
			var raw: Array = entries[key]
			var coords := Vector2i(int(raw[0]), int(raw[1]))
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			for layer in _physics_for(group, String(key)):
				td.add_collision_polygon(layer)
				td.set_collision_polygon_points(layer, 0, _collision_shape(group, String(key)))
			n += 1
		counts[group] = n

	if ResourceSaver.save(ts, OUT) != OK:
		push_error("保存失败")
	else:
		print("已保存 %s" % OUT)
		for g in GROUPS:
			print("  source %d  %-8s %3d 块" % [GROUPS.find(g), g, counts[g]])
	quit()


func _add_layer(ts: TileSet, collision_layer: int) -> void:
	ts.add_physics_layer()
	var i := ts.get_physics_layers_count() - 1
	ts.set_physics_layer_collision_layer(i, collision_layer)
	ts.set_physics_layer_collision_mask(i, 0)


## 返回这个砖该加在哪些物理层上，空数组 = 不加碰撞
func _physics_for(group: String, key: String) -> Array:
	match group:
		"terrain":
			if key in ICE_TILES:
				return [LAYER_WORLD, LAYER_ICE]
			if key in SNOW_TILES:
				return [LAYER_WORLD, LAYER_SNOW]
			return [LAYER_WORLD]
		"water":
			return [LAYER_WATER]
		"bg", "plants":
			return []   # 装饰，不挡路
		"props":
			if key.begins_with("ladder_"):
				return [LAYER_LADDER]
			if key.begins_with("sign_"):
				return []
			# 桥 / 互动块 / 空块 / 木箱 都挡路
			return [LAYER_WORLD]
	return []


## 碰撞多边形，相对砖中心（砖是 16x16，所以 -8..+8）。
##
## 默认用整块砖。桥是例外：它是悬空的绳桥，整块矩形会挡住画面里
## 根本没画东西的地方，必须贴着绳面来。
func _collision_shape(group: String, key: String) -> PackedVector2Array:
	if group == "props" and key.begins_with("bridge_"):
		return _bridge_shape(key)
	return PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])


## 绳桥的碰撞：一条贴着绳面的窄带，不是整块砖。
##
## 画面里每块桥砖画的是两段绳：
## - start：左边是抬高的桥墩（顶在第 0 行），右边绳子落到第 2 行
## - middle：两段绳子，顶面都在第 2 行
## - end：左边绳子在第 2 行，右边是抬高的桥墩（第 0 行）
##
## 所以整条桥是个「两头高、中间低 2px」的浅弧：桥墩那端跟地面齐平，
## 绳面比地面低 2px。碰撞就照这个画。
func _bridge_shape(key: String) -> PackedVector2Array:
	const ROPE := -6.0      # 绳面：砖的第 2 行
	const BANK := -8.0      # 桥墩：砖的第 0 行，跟地面齐平
	const BOTTOM := 0.0     # 绳底：砖的第 8 行
	var left := ROPE
	var right := ROPE
	if key.ends_with("_start"):
		left = BANK
	elif key.ends_with("_end"):
		right = BANK
	return PackedVector2Array([
		Vector2(-8, left), Vector2(8, right),
		Vector2(8, BOTTOM), Vector2(-8, BOTTOM)])


func _read_index() -> Dictionary:
	var f := FileAccess.open("res://tools/atlas_index.json", FileAccess.READ)
	if f == null:
		push_error("读不到 atlas_index.json，先跑 python3 tools/build_atlases.py")
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}
