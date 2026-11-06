extends Area2D
## 从天花板掉下来的石头。落点会先亮一个影子，警告玩家往哪躲。
##
## 影子不是贴图，是地面上一个半透明黑方块——跟着落点走。
##
## 触发方式：玩家靠近到一定距离才开始预警。
## 早先版本是用计时器定时触发的，但 SceneTree 的计时器在暂停时照样走，
## 于是标题画面那一会儿石头就砸完了，一进游戏就听见爆炸声。

signal hit_player(player: Player)

const WARNING_TIME := 0.7     # 影子预警多久
const FALL_SPEED := 420.0
## 玩家靠近到这么远才触发
const TRIGGER_RANGE := 150.0
## 砸完过多久能再砸一次
const COOLDOWN := 2.4

@onready var rock: Polygon2D = $Rock
@onready var shadow: Polygon2D = $Shadow

var target_x := 0.0           # 落点的世界 x
var ground_y := 0.0           # 地面的世界 y
var spawn_y := 0.0            # 石头起始高度（重新武装时回到这里）
var player: Player = null     # 触发依据

## 第一次触发前的等待时间。石头不会一进关卡就砸，要等玩家走近。
@export var cooldown := 1.5

# -1 = 待命，0 = 预警，1 = 下落，2 = 冷却中
var _state := -1
var _t := 0.0
var _cool := 0.0


func _ready() -> void:
	rock.visible = false
	shadow.visible = false
	shadow.modulate = Color(0, 0, 0, 0.5)
	body_entered.connect(_on_body_entered)


## 设定落点
func setup(target: Vector2, ground: Vector2) -> void:
	target_x = target.x
	ground_y = ground.y
	spawn_y = global_position.y
	global_position = Vector2(target_x, global_position.y)


func _process(delta: float) -> void:
	match _state:
		-1:
			# 待命：先等 cooldown，再等玩家走近了才开始预警
			if _cool > 0.0:
				_cool -= delta
				return
			if player != null and not player.dead:
				if absf(player.global_position.x - target_x) <= TRIGGER_RANGE:
					_state = 0
					_t = 0.0
					shadow.visible = true
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
				_cool = COOLDOWN
				_burst()
		2:
			_cool -= delta
			if _cool <= 0.0:
				_state = -1
				rock.visible = false
				shadow.visible = false
				shadow.scale = Vector2.ONE
				shadow.modulate = Color(0, 0, 0, 0.5)
				global_position.y = spawn_y
				monitoring = true


## 落地炸开。石头留在原地，冷却之后重新武装，可以再砸一次。
func _burst() -> void:
	rock.visible = false
	monitoring = false
	Audio.play_sfx("explosion")


func _on_body_entered(body: Node2D) -> void:
	if _state != 1:
		return
	if body is Player:
		hit_player.emit(body as Player)
