extends Node2D
## 碎块粒子。砸箱子的碎木块、踩史莱姆的碎渣。
##
## 用纯色方块模拟，不新增美术：颜色从被砸的东西身上取。

const GRAVITY := 760.0
const LIFETIME := 0.55
const PIECE_SIZE := 2.0

var _pieces: Array = []
var _age := 0.0


## 生成一堆碎块。
## color 用被砸物件的颜色，count 是碎块数，speed 是初速度。
func setup(color: Color, count: int, speed: float = 130.0) -> void:
	for i in count:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-PIECE_SIZE, -PIECE_SIZE), Vector2(PIECE_SIZE, -PIECE_SIZE),
			Vector2(PIECE_SIZE, PIECE_SIZE), Vector2(-PIECE_SIZE, PIECE_SIZE)])
		poly.color = color
		add_child(poly)
		_pieces.append({
			"node": poly,
			"vel": Vector2(randf_range(-speed, speed), randf_range(-speed * 1.8, -speed * 0.5)),
			"spin": randf_range(-14.0, 14.0),
		})


func _process(delta: float) -> void:
	_age += delta
	for piece in _pieces:
		var node: Polygon2D = piece["node"]
		var vel: Vector2 = piece["vel"]
		vel.y += GRAVITY * delta
		node.position += vel * delta
		node.rotation += float(piece["spin"]) * delta
	# 越老越淡
	var fade := 1.0 - clampf(_age / LIFETIME, 0.0, 1.0)
	for piece in _pieces:
		var node: Polygon2D = piece["node"]
		var c := node.color
		c.a = fade
		node.color = c
	if _age >= LIFETIME:
		queue_free()
