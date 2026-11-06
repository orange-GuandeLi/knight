extends AnimatableBody2D
## 会塌的地板。踩上去晃两下就塌掉，掉下去就完了（下面通常是水）。
##
## 用 AnimatableBody2D：塌之前它是个正常的平台，塌了就整体落下。

signal collapsed()

## 材质：跟平台砖共用
const MATERIALS := {
	"grass": "res://assets/tilesets/platforms/tiles/grass/grass_%s.png",
	"dirt": "res://assets/tilesets/platforms/tiles/dirt/dirt_%s.png",
	"gold": "res://assets/tilesets/platforms/tiles/gold/gold_%s.png",
	"ice": "res://assets/tilesets/platforms/tiles/ice/ice_%s.png",
}

const TILE_W := 16
const TILE_H := 9
const SOLID_H := 7

## 踩上去多久塌
const CRUMBLE_DELAY := 0.45
## 塌之前抖动多久
const SHAKE_TIME := 0.30
## 塌下去的距离
const FALL_DIST := 40.0
const FALL_TIME := 0.35

@export_enum("grass", "dirt", "gold", "ice") var tile_material := "grass"
@export var tiles := 2

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape

var _origin := Vector2.ZERO
var _timer := -1.0     # >= 0 表示已经被踩，正在计时
var _state := 0        # 0 = 正常，1 = 抖动，2 = 塌落，3 = 结束
var _fall_t := 0.0


func _ready() -> void:
	_origin = position
	_build()


func _build() -> void:
	var w := maxi(1, tiles)
	var parts: Array[String] = []
	if w == 1:
		parts.append("block")
	else:
		parts.append("left")
		for i in range(w - 2):
			parts.append("mid")
		parts.append("right")

	var pattern: String = MATERIALS[tile_material]
	var total_w := w * TILE_W
	var canvas := Image.create_empty(total_w, TILE_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	for i in parts.size():
		var tex: Texture2D = load(pattern % parts[i])
		if tex == null:
			continue
		var piece := tex.get_image()
		if piece == null:
			continue
		if piece.get_format() != Image.FORMAT_RGBA8:
			piece.convert(Image.FORMAT_RGBA8)
		canvas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(i * TILE_W, 0))

	sprite.texture = ImageTexture.create_from_image(canvas)
	sprite.centered = false
	sprite.position = Vector2.ZERO

	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(total_w, SOLID_H)
	shape.position = Vector2(total_w * 0.5, SOLID_H * 0.5)


func _physics_process(delta: float) -> void:
	match _state:
		0:
			# 没被踩的时候检查上面有没有人
			if _has_player_above():
				_timer = 0.0
				_state = 1
		1:
			_timer += delta
			# 抖
			sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if _timer >= SHAKE_TIME:
				_state = 2
				_fall_t = 0.0
				sprite.position = Vector2.ZERO
				# 塌了就别挡路了
				collision_layer = 0
				collapsed.emit()
		2:
			_fall_t += delta
			var t := clampf(_fall_t / FALL_TIME, 0.0, 1.0)
			position = _origin + Vector2(0.0, FALL_DIST * t * t)
			sprite.modulate.a = 1.0 - t
			if t >= 1.0:
				_state = 3
				queue_free()


## 头顶正上方有没有站着人
func _has_player_above() -> bool:
	for c in get_tree().get_nodes_in_group("player"):
		var p := c as Node2D
		if p == null:
			continue
		var dx: float = absf(p.global_position.x - global_position.x)
		if dx < tiles * TILE_W * 0.5 + 4.0:
			var dy: float = p.global_position.y - global_position.y
			# 脚底就在板面上方一点点
			if dy < 0.0 and dy > -18.0:
				return true
	return false
