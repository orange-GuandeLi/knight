class_name Slime
extends CharacterBody2D
## 史莱姆：来回巡逻，撞墙或到平台边缘就掉头。
## 被踩会压扁融化；从侧面碰到玩家会让玩家受伤。
##
## 两种颜色：绿的是普通兵，紫的更快更值钱。

const GRAVITY := 720.0
const MAX_FALL := 340.0

const DEBRIS_SCENE := preload("res://scenes/objects/Debris.tscn")
const POPUP_SCENE := preload("res://scenes/objects/ScorePopup.tscn")

## 每种史莱姆的碎块颜色
const VARIANT_COLORS := {
	"green": Color(0xBA, 0xD2, 0x00),
	"purple": Color(0xB7, 0x3D, 0x94),
}

## 会跳的敌人：玩家靠近就起跳扑过来
const JUMPING_VARIANTS := ["purple"]
const JUMP_TRIGGER_DIST := 72.0
const JUMP_VELOCITY := -235.0
const JUMP_COOLDOWN := 1.5

## 会滚的敌人：绿史莱姆缩成球滚过来
const ROLLING_VARIANTS := ["green"]
const ROLL_TRIGGER_DIST := 88.0
const ROLL_SPEED := 155.0
const ROLL_COOLDOWN := 2.2
## 滚起来之后能持续多久
const ROLL_DURATION := 1.1
## 滚之前先缩一下，给玩家反应时间
const ROLL_WINDUP := 0.35

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
@onready var body_shape: CollisionShape2D = $Body

## 史莱姆本体的碰撞尺寸（滚成球的时候要一起缩小）
const BODY_SIZE := Vector2(11, 10)
## 滚成球时缩到多少
const ROLL_SCALE := 0.78

var dir := 1
var dead := false
var speed := 30.0
var score_value := 200
var target: Player = null       # 关卡生成时塞进来的玩家
var _jump_cd := 0.0
var _roll_cd := 0.0
var _roll_t := 0.0
## 0 = 正常，1 = 起手缩身，2 = 滚动中
var _roll_state := 0


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

	_jump_cd = maxf(0.0, _jump_cd - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		velocity.y = 0.0

	# 起跳要放在上面那段之后：站着的时候 velocity.y 会被清零，
	# 放在前面就等于跳不起来
	_try_jump()
	_try_roll()

	if _roll_state == 2:
		# 滚球：方向锁定朝玩家，速度更快
		_roll_t -= delta
		velocity.x = float(dir) * ROLL_SPEED
		# 滚球时精灵转起来
		sprite.rotation += delta * 9.0 * dir
		if _roll_t <= 0.0:
			_stop_roll()
	elif _roll_state == 1:
		# 起手缩身：预告一下要滚了，站着不动
		_roll_t -= delta
		velocity.x = 0.0
		var k := clampf(1.0 - _roll_t / ROLL_WINDUP, 0.0, 1.0)
		var grow := 1.0 + 0.22 * k
		sprite.scale = Vector2.ONE * grow
		_set_body_size(grow)
		if _roll_t <= 0.0:
			_roll_state = 2
			_roll_t = ROLL_DURATION
			sprite.scale = Vector2.ONE * ROLL_SCALE
			_set_body_size(ROLL_SCALE)
			Game.hitstop(2)
			Audio.play_sfx("tap")
	else:
		velocity.x = dir * speed
	move_and_slide()

	# 撞墙掉头
	if is_on_wall():
		if _roll_state == 2:
			_stop_roll()
		_turn()
	# 平台边缘掉头：前脚下探不到地面就掉头。
	# 探针要够远够深，不然在冰面上会走出自己的平台。
	edge_ray.position = Vector2(dir * 10.0, -2.0)
	edge_ray.force_raycast_update()
	if is_on_floor() and not edge_ray.is_colliding():
		if _roll_state == 2:
			_stop_roll()
		_turn()
	# 走到关卡边界也要掉头
	if global_position.x < 8.0 or global_position.x > (LevelBounds.RIGHT - 8.0):
		_turn()
	# 掉出关卡就没了（敌人不会死，但也不能一直往下掉）
	if global_position.y > LevelBounds.BOTTOM + 60.0:
		queue_free()
		return

	sprite.flip_h = dir < 0


func _turn() -> void:
	dir = -dir
	velocity.x = dir * speed
	sprite.flip_h = dir < 0

## 绿史莱姆会滚：玩家靠得够近就缩身蓄力，然后滚过来。
## 蓄力那一下是给玩家的反应时间，可以趁机跳上去。
func _try_roll() -> void:
	if _roll_state != 0:
		return
	if variant not in ROLLING_VARIANTS:
		return
	if not is_on_floor() or _roll_cd > 0.0:
		return
	if target == null or target.dead:
		return
	var dx := target.global_position.x - global_position.x
	if absf(dx) > ROLL_TRIGGER_DIST:
		return
	# 贴这么近已经能踩了，不用滚
	if absf(dx) < 22.0:
		return
	# 玩家在头顶（正要踩下来）就别滚了，那是给玩家的机会
	if target.global_position.y < global_position.y - 6.0:
		return
	# 玩家在爬梯的时候躲不开，别打扰人家
	if target.on_ladder:
		return
	dir = 1 if dx > 0.0 else -1
	sprite.flip_h = dir < 0
	_roll_state = 1
	_roll_t = ROLL_WINDUP
	_roll_cd = ROLL_COOLDOWN


func _stop_roll() -> void:
	_roll_state = 0
	_roll_t = 0.0
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	_set_body_size(1.0)
	velocity.x = dir * speed


## 缩放碰撞体，让判定框和看得见的球一样大
func _set_body_size(k: float) -> void:
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE * k
	body_shape.shape = rect


## 紫史莱姆会跳：玩家靠得够近就朝他跳过来。
## 绿史莱姆会滚球。
func _try_jump() -> void:
	if variant not in JUMPING_VARIANTS:
		return
	if not is_on_floor() or _jump_cd > 0.0:
		return
	if target == null or target.dead:
		return
	var dx := target.global_position.x - global_position.x
	if absf(dx) > JUMP_TRIGGER_DIST:
		return
	dir = 1 if dx > 0.0 else -1
	sprite.flip_h = dir < 0
	velocity.y = JUMP_VELOCITY
	_jump_cd = JUMP_COOLDOWN


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
		squash(player)
	elif player.is_rolling():
		# 翻滚撞上去也算击杀
		player.bounce()
		squash(player)
	elif player.is_shielded():
		# 有护盾：直接撞碎，角色不受影响
		squash(player)
	else:
		player.take_damage(global_position.x)


func squash(p: Player = null) -> void:
	if dead:
		return
	dead = true
	# 踩怪连踩：滞空期间接着踩下一只，倍率往上翻
	var chain := Game.bump_stomp_chain()
	var gained := score_value * chain
	Game.add_score(gained)
	Game.hitstop(3)
	Audio.play_sfx("explosion")
	_spawn_debris()
	_spawn_popup(gained, chain)
	if p != null:
		p.add_shake(2.5)
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	sprite.play(&"melt")
	await sprite.animation_finished
	queue_free()


## 飘起来的加分提示
func _spawn_popup(gained: int, chain: int) -> void:
	var pop := POPUP_SCENE.instantiate()
	pop.text = "+%d" % gained
	if chain >= 2:
		pop.text = "x%d  +%d" % [chain, gained]
		pop.add_theme_font_size_override("font_size", 18)
		pop.add_theme_color_override("font_color", Color(1, 0.72, 0.25))
	pop.position = global_position + Vector2(-30.0, -20.0)
	get_parent().add_child(pop)


## 踩碎的渣子
func _spawn_debris() -> void:
	var d := DEBRIS_SCENE.instantiate()
	d.position = global_position
	d.setup(VARIANT_COLORS.get(variant, VARIANT_COLORS["green"]), 8, 120.0)
	get_parent().add_child(d)
