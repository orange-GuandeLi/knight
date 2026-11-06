extends AnimatableBody2D
## 移动平台。左右或上下来回走，站在上面的人会被带着走。
##
## 用 AnimatableBody2D + sync_to_physics：Godot 会算出平台的移动速度，
## 把站在上面的角色一起带走，普通 StaticBody2D 做不到这个。

## 平台砖的材质
const MATERIALS := {
	"grass": "res://assets/tilesets/platforms/tiles/grass/grass_%s.png",
	"dirt": "res://assets/tilesets/platforms/tiles/dirt/dirt_%s.png",
	"gold": "res://assets/tilesets/platforms/tiles/gold/gold_%s.png",
	"ice": "res://assets/tilesets/platforms/tiles/ice/ice_%s.png",
}

## 砖块尺寸：16 宽 9 高，上面 7 行是实心部分，下面 2 行是圆角
const TILE_W := 16
const TILE_H := 9
const SOLID_H := 7

## 注意别叫 material——CanvasItem 已经有那个原生属性了
@export_enum("grass", "dirt", "gold", "ice") var tile_material := "grass"
## 平台宽几块砖
@export var tiles := 3
## 一趟走多远（像素）。y 不为 0 就是上下移动。
@export var travel := Vector2(96.0, 0.0)
## 速度（像素/秒）
@export var speed := 42.0
## 起始相位 0~1，用来错开几块平台的节奏
@export var phase := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape

var _origin := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_origin = position
	_t = phase
	_build()


## 按宽度拼出平台的贴图和碰撞体
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
			push_warning("找不到平台砖 %s" % (pattern % parts[i]))
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
	var dist := travel.length()
	if dist <= 0.0:
		return
	_t += delta * speed / dist
	# 来回走：0 → 1 → 0
	var u := fmod(_t, 2.0)
	if u > 1.0:
		u = 2.0 - u
	position = _origin + travel * u
