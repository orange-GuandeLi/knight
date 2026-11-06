extends Area2D
## 拾取物：蘑菇 / 药瓶 / 水果。可以从互动块里弹出来。

@export_enum("mushroom", "potion", "fruit") var kind := "mushroom"

const FRAMES := {
	"mushroom": preload("res://assets/sprites/mushroom/mushroom_big_frames.tres"),
	"potion": preload("res://assets/sprites/potion/potion_frames.tres"),
	"fruit": preload("res://assets/sprites/fruit/fruit_frames.tres"),
}

const ANIMS := {
	"mushroom": ["red", "gold", "purple", "green"],
	"potion": ["green", "gold", "blue", "purple"],
	"fruit": ["green", "orange", "pink", "red"],
}

const POP_VELOCITY := -190.0
const POP_GRAVITY := 900.0

@onready var sprite: AnimatedSprite2D = $Sprite

var _vy := 0.0
var _target_y := 0.0
var _popping := false


func _ready() -> void:
	sprite.sprite_frames = FRAMES[kind]
	var anims: Array = ANIMS[kind]
	sprite.play(StringName(anims[randi() % anims.size()]))
	body_entered.connect(_on_body_entered)


## 从互动块顶上弹出来。从 from_y 开始往上弹，最后落回 from_y。
func pop_from(from_y: float) -> void:
	_vy = POP_VELOCITY
	_target_y = from_y
	_popping = true


func _physics_process(delta: float) -> void:
	if not _popping:
		return
	_vy += POP_GRAVITY * delta
	position.y += _vy * delta
	if _vy > 0.0 and position.y >= _target_y:
		position.y = _target_y
		_popping = false


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var player := body as Player
	Audio.play_sfx("power_up")
	match kind:
		"potion":
			Game.add_health(1)
			Game.score_with_combo(50)
		"fruit":
			# 水果：给一层护盾，碰到敌人不会掉血
			player.grant_shield(Player.SHIELD_TIME)
			Game.score_with_combo(150)
		_:
			# 蘑菇：多给一段跳跃
			player.grant_jump()
			Game.score_with_combo(200)
	queue_free()
