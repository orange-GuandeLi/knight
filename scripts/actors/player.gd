class_name Player
extends CharacterBody2D
## 骑士。跑、跳、翻滚跳、游泳、爬梯、受伤、死亡。

signal head_bump(world_position: Vector2)
signal died()

# --- 手感参数（16px 一格）---
const SPEED := 110.0
const ACCEL := 800.0
const FRICTION := 1000.0
const JUMP_VELOCITY := -262.0
const ROLL_JUMP_VELOCITY := -300.0
const GRAVITY := 720.0
const MAX_FALL := 340.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

const WATER_GRAVITY := 150.0
const WATER_MAX_FALL := 55.0
const WATER_SPEED := 80.0
const WATER_SWIM := -70.0

const CLIMB_SPEED := 58.0

const ROLL_TIME := 0.34
const ROLL_SPEED := 175.0
const ROLL_COOLDOWN := 0.55

const INVULN_TIME := 1.3
const HURT_TIME := 0.28
const KNOCKBACK_X := 150.0
const KNOCKBACK_Y := -150.0
const BOUNCE_VELOCITY := -210.0

# 掉出关卡底部多少像素算摔死
const DEATH_MARGIN := 120.0

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var invuln := 0.0
var hurt_time := 0.0
var roll_time := 0.0
var roll_cd := 0.0
var in_water := false
var on_ladder := false
var climbing := false
var dead := false
var level_bottom := 768.0

var _cur_anim := ""


func _ready() -> void:
	sprite.play(&"idle")
	_cur_anim = "idle"


func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	roll_cd = maxf(0.0, roll_cd - delta)

	if dead:
		_apply_gravity(delta, GRAVITY, MAX_FALL)
		move_and_slide()
		return

	_scan_sensors()

	# 掉出关卡
	if global_position.y > level_bottom + DEATH_MARGIN:
		die()
		return

	# 受伤硬直：只受重力
	if hurt_time > 0.0:
		hurt_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		_apply_gravity(delta, GRAVITY, MAX_FALL)
		move_and_slide()
		_update_anim()
		return

	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		facing = 1 if dir > 0.0 else -1

	# 爬梯：按上下就进入攀爬，按左右就脱离
	if on_ladder and (Input.is_action_pressed("jump") or Input.is_action_pressed("down")):
		climbing = true
	if not on_ladder or absf(dir) > 0.01:
		climbing = false

	if climbing:
		velocity.x = 0.0
		if Input.is_action_pressed("jump"):
			velocity.y = -CLIMB_SPEED
		elif Input.is_action_pressed("down"):
			velocity.y = CLIMB_SPEED
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_anim()
		return

	# 翻滚计时
	if roll_time > 0.0:
		roll_time -= delta
		velocity.x = move_toward(velocity.x, facing * ROLL_SPEED, ACCEL * 2.0 * delta)
	else:
		if absf(dir) > 0.01:
			var target := dir * (WATER_SPEED if in_water else SPEED)
			velocity.x = move_toward(velocity.x, target, ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# 跳跃缓冲
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER

	if in_water:
		# 水里：可以一直按住跳跃往上浮
		if Input.is_action_pressed("jump"):
			velocity.y = WATER_SWIM
		else:
			_apply_gravity(delta, WATER_GRAVITY, WATER_MAX_FALL)
	elif jump_buffer > 0.0 and (is_on_floor() or coyote > 0.0):
		jump_buffer = 0.0
		coyote = 0.0
		if Input.is_action_pressed("down") and roll_cd <= 0.0:
			# 下 + 跳跃 = 翻滚跳
			roll_time = ROLL_TIME
			roll_cd = ROLL_COOLDOWN
			velocity.y = ROLL_JUMP_VELOCITY
		else:
			velocity.y = JUMP_VELOCITY
		_apply_gravity(delta, GRAVITY, MAX_FALL)
	else:
		_apply_gravity(delta, GRAVITY, MAX_FALL)

	if is_on_floor():
		coyote = COYOTE_TIME
	else:
		coyote = maxf(0.0, coyote - delta)

	var was_rising := velocity.y < 0.0
	move_and_slide()

	# 顶到天花板 -> 通知关卡（撞问号块）
	if was_rising and is_on_ceiling():
		var col := get_last_slide_collision()
		if col != null and col.get_normal().y > 0.4:
			head_bump.emit(Vector2(global_position.x, col.get_position().y - 1.0))
			velocity.y = 0.0

	_update_anim()


func _apply_gravity(delta: float, g: float, max_fall: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + g * delta, max_fall)


# ---------------------------------------------------------------- 感应区

## 水和木梯都在 TileSet 的独立物理层上，用形状查询判断。
func _scan_sensors() -> void:
	in_water = _probe(4, Vector2(0, -6), Vector2(8, 8))
	on_ladder = _probe(8, Vector2(0, -8), Vector2(8, 14))


func _probe(mask: int, offset: Vector2, size: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + offset)
	q.collision_mask = mask
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return not space.intersect_shape(q, 1).is_empty()


func is_rolling() -> bool:
	return roll_time > 0.0


# ---------------------------------------------------------------- 受伤 / 死亡

func take_damage(from_x: float) -> void:
	if invuln > 0.0 or dead:
		return
	invuln = INVULN_TIME
	hurt_time = HURT_TIME
	roll_time = 0.0
	climbing = false
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity.x = away * KNOCKBACK_X
	velocity.y = KNOCKBACK_Y
	if Game.damage(1):
		die()


## 复活：回到出生点，短暂无敌。
func respawn(pos: Vector2) -> void:
	dead = false
	hurt_time = 0.0
	roll_time = 0.0
	roll_cd = 0.0
	climbing = false
	invuln = INVULN_TIME
	velocity = Vector2.ZERO
	global_position = pos
	z_index = 0
	sprite.modulate.a = 1.0
	sprite.visible = true
	sprite.play(&"idle")
	_cur_anim = "idle"
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reset_smoothing()


func bounce() -> void:
	velocity.y = BOUNCE_VELOCITY
	roll_time = 0.0


func die() -> void:
	if dead:
		return
	dead = true
	hurt_time = 0.0
	roll_time = 0.0
	invuln = 0.0
	velocity = Vector2(0.0, -190.0)
	sprite.modulate.a = 1.0
	_play("death")
	z_index = 20
	await get_tree().create_timer(1.3).timeout
	died.emit()


# ---------------------------------------------------------------- 动画

func _update_anim() -> void:
	# 受伤无敌时闪烁
	if invuln > 0.0 and not dead:
		sprite.modulate.a = 0.35 if int(Time.get_ticks_msec() / 70) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0

	if dead:
		_play("death")
	elif hurt_time > 0.0:
		_play("hurt")
	elif roll_time > 0.0:
		_play("roll")
	elif climbing or in_water:
		_play("walk" if absf(velocity.x) > 5.0 or climbing else "idle")
	elif not is_on_floor():
		_play("walk" if absf(velocity.x) > 5.0 else "idle")
	elif absf(velocity.x) > 5.0:
		_play("walk")
	else:
		_play("idle")

	sprite.flip_h = facing < 0


func _play(anim: String) -> void:
	if _cur_anim == anim:
		return
	_cur_anim = anim
	sprite.play(StringName(anim))
