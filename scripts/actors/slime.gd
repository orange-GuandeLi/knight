class_name Slime
extends CharacterBody2D
## 史莱姆：来回巡逻，撞墙或到平台边缘就掉头。
## 被踩会压扁融化；从侧面碰到玩家会让玩家受伤。
##
## 两种颜色：绿的是普通兵，紫的更快更值钱。

const GRAVITY := 720.0
const MAX_FALL := 340.0

const FRAMES := {
	"green": preload("res://assets/sprites/slime/slime_green_frames.tres"),
	"purple": preload("res://assets/sprites/slime/slime_purple_frames.tres"),
}

## 每种史莱姆的手感参数
const VARIANTS := {
	"green": {"speed": 30.0, "score": 200},
	"purple": {"speed": 52.0, "score": 300},
}

@export_enum("green", "purple") var variant := "green"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var edge_ray: RayCast2D = $EdgeRay

var dir := 1
var dead := false
var speed := 30.0
var score_value := 200


func _ready() -> void:
	var v: Dictionary = VARIANTS.get(variant, VARIANTS["green"])
	speed = float(v["speed"])
	score_value = int(v["score"])
	sprite.sprite_frames = FRAMES[variant]
	sprite.play(&"idle")
	hurtbox.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		velocity.y = 0.0

	velocity.x = dir * speed
	move_and_slide()

	# 撞墙掉头
	if is_on_wall():
		_turn()
	# 平台边缘掉头：前脚下探不到地面就掉头
	edge_ray.position = Vector2(dir * 7.0, -3.0)
	edge_ray.force_raycast_update()
	if is_on_floor() and not edge_ray.is_colliding():
		_turn()
	# 走到关卡边界也要掉头
	if global_position.x < 8.0 or global_position.x > (LevelBounds.RIGHT - 8.0):
		_turn()

	sprite.flip_h = dir < 0


func _turn() -> void:
	dir = -dir
	velocity.x = dir * speed
	sprite.flip_h = dir < 0


func _on_body_entered(body: Node2D) -> void:
	if dead or not body is Player:
		return
	var player := body as Player
	if player.dead:
		return

	# 踩踏判定：玩家在头顶、且在往下落
	var stomping := player.velocity.y > 20.0 and player.global_position.y < global_position.y - 3.0
	if stomping:
		player.bounce()
		squash()
	elif player.is_rolling():
		# 翻滚撞上去也算击杀
		player.bounce()
		squash()
	else:
		player.take_damage(global_position.x)


func squash() -> void:
	if dead:
		return
	dead = true
	Game.add_score(score_value)
	Audio.play_sfx("explosion")
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	sprite.play(&"melt")
	await sprite.animation_finished
	queue_free()
