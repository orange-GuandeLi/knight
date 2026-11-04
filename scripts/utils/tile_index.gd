class_name TileIndex
extends RefCounted
## 砖名 <-> 图集坐标 的双向查找。数据来自 tools/atlas_index.json。

const GROUPS := ["terrain", "props", "water", "bg", "plants"]
const INDEX_PATH := "res://tools/atlas_index.json"

static var _loaded := false
static var _by_key: Dictionary = {}
static var _by_cell: Dictionary = {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if f == null:
		push_error("读不到 %s，先跑 python3 tools/build_atlases.py" % INDEX_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		push_error("atlas_index.json 格式不对")
		return
	for gi in GROUPS.size():
		var entries: Dictionary = data.get(GROUPS[gi], {})
		for key in entries.keys():
			var raw: Array = entries[key]
			var coords := Vector2i(int(raw[0]), int(raw[1]))
			_by_key[String(key)] = {"source": gi, "coords": coords}
			_by_cell["%d:%d:%d" % [gi, coords.x, coords.y]] = String(key)


## 砖名 -> {"source": int, "coords": Vector2i}，找不到返回 {}
static func cell(key: String) -> Dictionary:
	_ensure()
	return _by_key.get(key, {})


## 图集坐标 -> 砖名，找不到返回 ""
static func key_at(source: int, coords: Vector2i) -> String:
	_ensure()
	return _by_cell.get("%d:%d:%d" % [source, coords.x, coords.y], "")
