extends Area2D
## 从天花板掉下来的石头。落点会先亮一个影子，警告玩家往哪躲。
##
## 影子不是贴图，是地面上一个半透明黑方块——跟着落点走。

signal hit_player(player: Player)

const WARNING_TIME := 0.7     # 影子预警多久
const FALL_SPEED := 420.0
const ROCK_SIZE := 6.0

@onready var rock: Polygon2D = $Rock
@onready var shadow: Polygon2D = $Shadow

var target_x := 0.0           # 落点的世界 x
var ground_y := 0.0           # 地面的世界 y
var _state := -1              # -1 = 待命，0 = 预警，1 = 下落，2 = 结束
var _t := 0.0


func _ready() -> void:
	rock.visible = false
	shadow.visible = false
	shadow.modulate = Color(0, 0, 0, 0.5)
	body_entered.connect(_on_body_entered)


## 设定落点
func setup(target: Vector2, ground: Vector2) -> void:
	target_x = target.x
	ground_y = ground.y
	global_position = Vector2(target_x, global_position.y)


## 正式开始（由关卡延迟调用）。先亮影子警告，再掉下来。
func start_falling() -> void:
	if _state != -1:
		return
	_state = 0
	_t = 0.0
	shadow.visible = true


func _process(delta: float) -> void:
	match _state:
		-1:
			pass
		0:
			_t += delta
			# 影子越接近落点越明显
			var k := clampf(_t / WARNING_TIME, 0.0, 1.0)
			shadow.modulate.a = 0.25 + 0.45 * k
			shadow.scale = Vector2.ONE * (1.0 - 0.35 * k)
			if _t >= WARNING_TIME:
				_state = 1
				rock.visible = true
				shadow.visible = false
				Audio.play_sfx("tap")
		1:
			global_position.y += FALL_SPEED * delta
			if global_position.y >= ground_y:
				global_position.y = ground_y
				_state = 2
				_burst()


## 落地炸开
func _burst() -> void:
	collision_layer = 0
	collision_mask = 0
	Audio.play_sfx("explosion")
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _state != 1:
		return
	if body is Player:
		hit_player.emit(body as Player)
