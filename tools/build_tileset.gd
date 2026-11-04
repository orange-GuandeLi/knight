extends SceneTree
## 用 tools/atlas_index.json 建 TileSet。
## 物理层：0 = 实体碰撞，1 = 水（感应），2 = 木梯（感应）
##
## 运行： Godot --headless --path . --script res://tools/build_tileset.gd

const ATLAS_DIR := "res://assets/tilesets/world/atlases"
const OUT := "res://assets/tilesets/world/world_tileset.tres"
const GROUPS := ["terrain", "props", "water", "bg"]

# 物理层 -> 碰撞位
const LAYER_WORLD := 0    # 位 1
const LAYER_WATER := 1    # 位 4
const LAYER_LADDER := 2   # 位 8



func _init() -> void:
	var idx: Dictionary = _read_index()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	_add_layer(ts, 1)
	_add_layer(ts, 4)
	_add_layer(ts, 8)

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
			var layer := _physics_for(group, String(key))
			if layer >= 0:
				td.add_collision_polygon(layer)
				# 碰撞多边形是相对砖中心的，所以是 -8..+8
				td.set_collision_polygon_points(layer, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
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


## 返回这个砖该加在哪层物理层上，-1 = 不加碰撞
func _physics_for(group: String, key: String) -> int:
	match group:
		"terrain":
			return LAYER_WORLD
		"water":
			return LAYER_WATER
		"bg":
			return -1
		"props":
			if key.begins_with("ladder_"):
				return LAYER_LADDER
			if key.begins_with("sign_"):
				return -1
			# 桥 / 互动块 / 空块 / 木箱 都挡路
			return LAYER_WORLD
	return -1


func _read_index() -> Dictionary:
	var f := FileAccess.open("res://tools/atlas_index.json", FileAccess.READ)
	if f == null:
		push_error("读不到 atlas_index.json，先跑 python3 tools/build_atlases.py")
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}
