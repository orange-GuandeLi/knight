extends CharacterBody2D
## BOSS。放大的紫史莱姆，会跳、会砸地产生冲击波、打死会分裂成小史莱姆。
##
## 和普通史莱姆共用绿/紫史莱姆的贴图，放大 3 倍用。

signal defeated()

const FRAMES := preload("res://assets/sprites/slime/slime_purple_frames.tres")
const SLIME_SCENE := preload("res://scenes/actors/Slime.tscn")
const DEBRIS_SCENE := preload("res://scenes/objects/Debris.tscn")

const GRAVITY := 720.0
const MAX_FALL := 340.0

const SPEED := 46.0
const JUMP_VELOCITY := -330.0
const JUMP_COOLDOWN := 1.4
const TRIGGER_DIST := 190.0
const SCALE := 3.0

## 血量：踩中要几下
const MAX_HP := 5
const HURT_FLASH := 0.22

## 砸地冲击波
const SHOCK_SPEED := 210.0
const SHOCK_LIFE := 0.85
const SHOCK_DAMAGE := 1

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape

var target: Player = null
var hp := MAX_HP
var dead := false
var dir := 1
var _jump_cd := 0.0
var _flash := 0.0
var _on_floor := true
## 正在飞的冲击波。每条记录自己的位置和方向。
var _shocks: Array = []


func _ready() -> void:
	sprite.sprite_frames = FRAMES
	sprite.play(&"idle")
	sprite.scale = Vector2(SCALE, SCALE)
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(15 * SCALE, 10 * SCALE)
	shape.position = Vector2(0, -5 * SCALE)


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		return

	_jump_cd = maxf(0.0, _jump_cd - delta)
	_flash = maxf(0.0, _flash - delta)
	sprite.modulate = Color(1, 0.55, 0.55) if _flash > 0.0 else Color.WHITE

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		velocity.y = 0.0
		# 落地了，朝玩家跳一下
		if _jump_cd <= 0.0 and target != null and not target.dead:
			var dx := target.global_position.x - global_position.x
			if absf(dx) < TRIGGER_DIST:
				dir = 1 if dx > 0.0 else -1
				sprite.flip_h = dir < 0
				velocity.y = JUMP_VELOCITY
				_jump_cd = JUMP_COOLDOWN

	velocity.x = dir * SPEED
	move_and_slide()

	sprite.flip_h = dir < 0
	_update_shocks(delta)

	# 落地那一刻砸出冲击波
	var now_floor := is_on_floor()
	if now_floor and not _on_floor:
		_slam()
	_on_floor = now_floor


## 砸地：左右各放一道冲击波
func _slam() -> void:
	Game.hitstop(4)
	Audio.play_sfx("explosion")
	var d := DEBRIS_SCENE.instantiate()
	d.position = global_position
	d.setup(Color(0xB7, 0x3D, 0x94), 12, 170.0)
	get_parent().add_child(d)
	if target != null:
		target.add_shake(4.0)
	# 冲击波从脚底往两边飞
	for sd in [-1, 1]:
		var wave := Polygon2D.new()
		wave.polygon = PackedVector2Array([
			Vector2(-7, -5), Vector2(7, -5), Vector2(5, 5), Vector2(-5, 5)])
		wave.color = Color(0xB7, 0x3D, 0x94)
		wave.position = Vector2(float(sd) * 14.0, -4.0)
		get_parent().add_child(wave)
		_shocks.append({"node": wave, "dir": sd, "life": SHOCK_LIFE})


## 推进冲击波，顺便看有没有撞到玩家
func _update_shocks(delta: float) -> void:
	var alive: Array = []
	for s in _shocks:
		var node: Polygon2D = s["node"]
		var life: float = float(s["life"]) - delta
		var sd: int = int(s["dir"])
		node.position.x += float(sd) * SHOCK_SPEED * delta
		node.modulate.a = clampf(life / SHOCK_LIFE, 0.0, 1.0)
		# 撞到玩家
		if target != null and not target.dead and not target.is_shielded():
			var p := target.global_position
			var c := node.global_position
			if absf(p.x - c.x) < 11.0 and absf(p.y - c.y) < 14.0:
				target.take_damage(c.x)
				node.queue_free()
				continue
		if life <= 0.0:
			node.queue_free()
			continue
		s["life"] = life
		alive.append(s)
	_shocks = alive


## 被踩到
func stomp() -> void:
	if dead:
		return
	hp -= 1
	_flash = HURT_FLASH
	Audio.play_sfx("hurt")
	if hp > 0:
		# 没打死：弹开一下
		velocity.y = -200.0
		velocity.x = (1 if target.global_position.x > global_position.x else -1) * 120.0
		return
	_die()


func _die() -> void:
	dead = true
	Game.add_score(1000)
	Game.hitstop(8)
	Audio.play_sfx("explosion")
	var d := DEBRIS_SCENE.instantiate()
	d.position = global_position
	d.setup(Color(0xB7, 0x3D, 0x94), 20, 210.0)
	get_parent().add_child(d)
	# 分裂成三只小史莱姆
	for i in 3:
		var s := SLIME_SCENE.instantiate()
		s.variant = "purple"
		s.position = global_position + Vector2((i - 1) * 18.0, -8.0)
		s.scale = Vector2(0.55, 0.55)
		get_parent().add_child(s)
	defeated.emit()
	queue_free()
