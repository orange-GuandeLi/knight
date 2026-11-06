class_name Player
extends CharacterBody2D
## 骑士。跑、跳、翻滚跳、地面翻滚冲刺、游泳、爬梯、墙跳、受伤、死亡。

signal head_bump(world_position: Vector2)
signal died()
## 地面翻滚时每帧发出，位置在身前一点。关卡用它判断有没有撞到木箱。
signal roll_strike(world_position: Vector2)

# --- 手感参数（16px 一格）---
const SPEED := 110.0
const ACCEL := 800.0
const FRICTION := 1000.0
# 冰上：起步慢、几乎不减速，一脚踩上去刹不住
const ICE_ACCEL := 340.0
const ICE_FRICTION := 70.0
const JUMP_VELOCITY := -262.0
const ROLL_JUMP_VELOCITY := -300.0
# 可变跳跃高度：上升途中松开跳跃键，上升速度最多保留到这个值（越接近 0 跳得越矮）
const JUMP_CUT := -130.0
# 总共能跳几次：2 = 二段跳（地面一次 + 空中一次）
const MAX_JUMPS := 2
const GRAVITY := 720.0
const MAX_FALL := 340.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

const WATER_GRAVITY := 150.0
const WATER_MAX_FALL := 55.0
const WATER_SPEED := 80.0
const WATER_SWIM := -70.0

const CLIMB_SPEED := 58.0

# 地面翻滚：站着按 ↓ 起滚，速度锁定不能转向
const ROLL_TIME := 0.34
const ROLL_SPEED := 175.0
const ROLL_COOLDOWN := 0.55
# 滚完之后留一点惯性，不然会像撞墙一样硬停
const ROLL_EXIT_SPEED := 0.45
# 翻滚跳之后保留水平速度的时间，这期间不减速也不转向
const ROLL_MOMENTUM := 0.22

# 墙跳：贴墙下滑 + 按跳蹬出去
const WALL_SLIDE_SPEED := 52.0
const WALL_JUMP_X := 145.0
const WALL_JUMP_Y := -235.0
# 蹬墙后短暂锁住方向，不然会马上又贴回墙上
const WALL_LOCK := 0.14

const INVULN_TIME := 1.3
const HURT_TIME := 0.28
const KNOCKBACK_X := 150.0
const KNOCKBACK_Y := -150.0
const BOUNCE_VELOCITY := -210.0

# 掉出关卡底部多少像素算摔死
const DEATH_MARGIN := 120.0

# 碰撞体宽 10，贴边时留一半在关卡里
const BODY_HALF := 5.0

# 感应用的物理层位（要和 tools/build_tileset.gd 里的一致）
const LAYER_WATER := 4
const LAYER_LADDER := 8
const LAYER_ICE := 16

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var invuln := 0.0
var hurt_time := 0.0
var roll_time := 0.0
var roll_cd := 0.0
var rolling := false
var momentum := 0.0         # 翻滚跳之后的惯性时间，这期间不减速
var in_water := false
var on_ice := false
var on_ladder := false
var climbing := false
var wall_dir := 0          # -1 = 墙在左边，1 = 墙在右边，0 = 没贴墙
var wall_lock := 0.0
var jumps_left := MAX_JUMPS
var dead := false
var level_bottom := 768.0
var level_left := 0.0
var level_right := 1920.0

var _cur_anim := ""


func _ready() -> void:
	sprite.play(&"idle")
	_cur_anim = "idle"


func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	wall_lock = maxf(0.0, wall_lock - delta)
	momentum = maxf(0.0, momentum - delta)

	if dead:
		_apply_gravity(delta, GRAVITY, MAX_FALL)
		_move_and_clamp()
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
		_move_and_clamp()
		_update_anim()
		return

	var dir := Input.get_axis("move_left", "move_right")
	# 翻滚中不转向，否则按一下方向键就会反向滚
	if absf(dir) > 0.01 and wall_lock <= 0.0 and not rolling:
		facing = 1 if dir > 0.0 else -1

	# 爬梯：上键 / 下键进入攀爬，按左右脱离，按跳跃蹬梯跳
	# 上键现在只负责爬梯，不再触发跳跃
	var climb_up := Input.is_action_pressed("climb_up")
	var climb_down := Input.is_action_pressed("down")
	if on_ladder and (climb_up or climb_down):
		climbing = true
	if not on_ladder or absf(dir) > 0.01:
		climbing = false

	if climbing:
		if Input.is_action_just_pressed("jump"):
			# 蹬梯跳
			climbing = false
			velocity.y = JUMP_VELOCITY
			jumps_left = MAX_JUMPS - 1
			Audio.play_sfx("jump")
			_apply_gravity(delta, GRAVITY, MAX_FALL)
			_move_and_clamp()
			_update_anim()
			return
		velocity.x = 0.0
		if climb_up:
			velocity.y = -CLIMB_SPEED
		elif climb_down:
			velocity.y = CLIMB_SPEED
		else:
			velocity.y = 0.0
		_move_and_clamp()
		_update_anim()
		return

	var on_ground := is_on_floor()
	var can_ground_jump := on_ground or coyote > 0.0
	var can_jump := can_ground_jump or jumps_left > 0

	# 跳跃缓冲
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER

	# --- 墙 ---
	wall_dir = _wall_dir()
	var pressing_wall := wall_dir != 0 and dir * float(wall_dir) > 0.0

	# 蹬墙跳：人在半空贴着墙时按跳
	if wall_dir != 0 and not on_ground and jump_buffer > 0.0:
		jump_buffer = 0.0
		velocity.x = -float(wall_dir) * WALL_JUMP_X
		velocity.y = WALL_JUMP_Y
		wall_lock = WALL_LOCK
		jumps_left = 1          # 蹬完还剩一次二段跳
		coyote = 0.0
		rolling = false
		Audio.play_sfx("jump")
		_apply_gravity(delta, GRAVITY, MAX_FALL)
		_move_and_clamp()
		_update_anim()
		return

	# 贴墙下滑：按住朝墙的方向，掉得比自由落体慢
	if wall_dir != 0 and not on_ground and pressing_wall:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		facing = wall_dir

	# --- 地面翻滚 ---
	if rolling:
		roll_time -= delta
		velocity.x = float(facing) * ROLL_SPEED
		if roll_time <= 0.0:
			rolling = false
			roll_cd = ROLL_COOLDOWN
			velocity.x = float(facing) * ROLL_SPEED * ROLL_EXIT_SPEED
		# 翻滚中撞东西
		roll_strike.emit(global_position + Vector2(float(facing) * 12.0, -8.0))
	elif Input.is_action_just_pressed("down") and can_ground_jump and roll_cd <= 0.0 \
			and not in_water and not Input.is_action_just_pressed("jump"):
		# 站着按 ↓ 起滚。同一帧还按了跳跃就留给翻滚跳。
		rolling = true
		roll_time = ROLL_TIME
		velocity.x = float(facing) * ROLL_SPEED
	elif momentum > 0.0:
		# 翻滚跳之后的惯性：速度先保持住，不急着往常态速拉
		pass
	elif wall_lock > 0.0:
		# 蹬墙后的短暂锁向：不然还按着朝墙的方向，立刻就被拽回墙边
		pass
	elif absf(dir) > 0.01:
		var target := dir * (WATER_SPEED if in_water else SPEED)
		var accel := ICE_ACCEL if on_ice else ACCEL
		velocity.x = move_toward(velocity.x, target, accel * delta)
	else:
		var friction := ICE_FRICTION if on_ice else FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if in_water:
		# 水里：可以一直按住跳跃往上浮
		if Input.is_action_pressed("jump"):
			velocity.y = WATER_SWIM
		else:
			_apply_gravity(delta, WATER_GRAVITY, WATER_MAX_FALL)
	elif jump_buffer > 0.0 and can_jump:
		jump_buffer = 0.0
		if can_ground_jump:
			coyote = 0.0
			jumps_left = MAX_JUMPS - 1      # 地面跳用掉第一段
		else:
			jumps_left -= 1                 # 空中跳
		# 翻滚跳：按着 ↓ 跳，或者翻滚途中跳
		var want_roll_jump := rolling or (Input.is_action_pressed("down") and can_ground_jump)
		rolling = false
		if want_roll_jump:
			roll_time = ROLL_TIME
			roll_cd = ROLL_COOLDOWN
			velocity.y = ROLL_JUMP_VELOCITY
			momentum = ROLL_MOMENTUM
		else:
			velocity.y = JUMP_VELOCITY
		Audio.play_sfx("jump")

	# 可变跳跃高度：还在上升却没按住跳跃键，就把上升速度砍掉
	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y = maxf(velocity.y, JUMP_CUT)

	_apply_gravity(delta, GRAVITY, MAX_FALL)

	var was_rising := velocity.y < 0.0
	_move_and_clamp()

	# 落地后才刷新跳跃次数。必须放在 move_and_slide 之后：
	# 起跳那一帧 is_on_floor() 还是 true，放前面会把次数刷回满。
	if is_on_floor():
		coyote = COYOTE_TIME
		jumps_left = MAX_JUMPS
	else:
		coyote = maxf(0.0, coyote - delta)
		# 走着掉下平台、没用地面跳的，空中只剩一段
		if coyote <= 0.0 and jumps_left == MAX_JUMPS:
			jumps_left = MAX_JUMPS - 1

	# 顶到天花板 -> 通知关卡（撞问号块）
	if was_rising and is_on_ceiling():
		var col := get_last_slide_collision()
		if col != null and col.get_normal().y > 0.4:
			head_bump.emit(Vector2(global_position.x, col.get_position().y - 1.0))
			velocity.y = 0.0

	_update_anim()


## 移动，并把角色关在关卡范围内。
##
## 关卡左右两边是敞开的（没有围墙），不拦的话往回走会走出关卡，
## 脚下没砖就直接掉进虚空摔死。
func _move_and_clamp() -> void:
	move_and_slide()
	global_position.x = clampf(global_position.x,
		level_left + BODY_HALF, level_right - BODY_HALF)


func _apply_gravity(delta: float, g: float, max_fall: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + g * delta, max_fall)


# ---------------------------------------------------------------- 感应区

## 水、冰和木梯都在 TileSet 的独立物理层上，用形状查询判断。
func _scan_sensors() -> void:
	in_water = _probe(LAYER_WATER, Vector2(0, -6), Vector2(8, 8))
	on_ladder = _probe(LAYER_LADDER, Vector2(0, -8), Vector2(8, 14))
	# 冰面只要脚下正下方那一小块，贴着冰墙不会误判
	on_ice = _probe(LAYER_ICE, Vector2(0, -1), Vector2(6, 4))


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


## 当前贴着的墙在哪边：-1 = 墙在左，1 = 墙在右，0 = 没贴墙
func _wall_dir() -> int:
	if not is_on_wall_only():
		return 0
	var n := get_wall_normal()
	if n.x > 0.5:
		return -1
	if n.x < -0.5:
		return 1
	return 0


func is_rolling() -> bool:
	return roll_time > 0.0


# ---------------------------------------------------------------- 受伤 / 死亡

func take_damage(from_x: float) -> void:
	if invuln > 0.0 or dead:
		return
	invuln = INVULN_TIME
	hurt_time = HURT_TIME
	roll_time = 0.0
	rolling = false
	momentum = 0.0
	climbing = false
	Audio.play_sfx("hurt")
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
	rolling = false
	roll_cd = 0.0
	momentum = 0.0
	climbing = false
	wall_lock = 0.0
	jumps_left = MAX_JUMPS
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
	rolling = false


func die() -> void:
	if dead:
		return
	dead = true
	hurt_time = 0.0
	roll_time = 0.0
	rolling = false
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
	elif rolling or roll_time > 0.0:
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
