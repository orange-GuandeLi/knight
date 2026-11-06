extends Node
## 冒烟测试：按物理帧驱动，一项项检查核心机制。
## 跑法： Godot --headless --path . res://tools/SmokeTest.tscn
##
## 注意：headless 下 process 帧比物理帧快，所以计时全部用 physics_frame 计数。

var main: Node
var tick := 0
var p: Player
var terrain: TileMapLayer
var entities: Node2D
var hud: Node
var results: Array[String] = []

# 跳跃高度测量
var peak_y := 0.0
var track := false
var h_short := 0.0
var h_long := 0.0
var h_double := 0.0
var slimes_before := 0
var climb_y := 0.0

const GROUND_Y := 416.0


func _ready() -> void:
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	get_tree().physics_frame.connect(_on_physics)


func _on_physics() -> void:
	tick += 1
	if p == null:
		p = main.get_node("Level/Player")
		terrain = main.get_node("Level/Terrain")
		entities = main.get_node("Level/Entities")
		hud = main.get_node_or_null("HUD")

	if track:
		peak_y = minf(peak_y, p.global_position.y)

	match tick:
		# ---------- 基础移动 ----------
		10:
			_check("站立", p.is_on_floor() and absf(p.global_position.y - GROUND_Y) < 0.5,
				"y=%.1f floor=%s" % [p.global_position.y, p.is_on_floor()])
			Input.action_press("move_right")
		25:
			_check("跑动", p.velocity.x > 100.0, "vx=%.1f" % p.velocity.x)
			Input.action_release("move_right")

		# ---------- 撞问号块（要按住跳才够高）----------
		30:
			_teleport(21 * 16 + 8, GROUND_Y)
		36:
			Input.action_press("jump")
		80:
			Input.action_release("jump")
		105:
			var key := _key_at(Vector2i(21, 22))
			_check("撞块变空块", key == "block_dirt_question_used", "砖=" + key)
			_check("撞块掉出奖励", _count_pickups() > 0, "拾取物 %d 个" % _count_pickups())

		# ---------- 短按跳 vs 长按跳 ----------
		110:
			_teleport(3 * 16 + 8, GROUND_Y)
		115:
			_start_track()
			Input.action_press("jump")
		120:
			Input.action_release("jump")
		175:
			h_short = GROUND_Y - peak_y
			_check("短按跳得矮", h_short > 4.0 and h_short < 40.0, "%.1f px" % h_short)

		185:
			_teleport(3 * 16 + 8, GROUND_Y)
		190:
			_start_track()
			Input.action_press("jump")
		250:
			Input.action_release("jump")
		255:
			h_long = GROUND_Y - peak_y
			_check("长按跳得更高", h_long > h_short * 1.8,
				"短按 %.1f px / 长按 %.1f px" % [h_short, h_long])

		# ---------- 二段跳 ----------
		265:
			_teleport(3 * 16 + 8, GROUND_Y)
		270:
			_start_track()
			Input.action_press("jump")
		295:
			Input.action_release("jump")
		300:
			Input.action_press("jump")
		360:
			Input.action_release("jump")
		370:
			h_double = GROUND_Y - peak_y
			_check("二段跳比单跳高", h_double > h_long * 1.4,
				"单跳 %.1f px / 二段 %.1f px" % [h_long, h_double])

		# ---------- 上键只爬梯，不再起跳 ----------
		380:
			_teleport(3 * 16 + 8, GROUND_Y)
		385:
			Input.action_press("climb_up")
		420:
			Input.action_release("climb_up")
		425:
			_check("上键不再起跳", absf(p.global_position.y - GROUND_Y) < 1.5,
				"y=%.1f（应仍是 %.0f）" % [p.global_position.y, GROUND_Y])

		# ---------- 踩史莱姆 ----------
		435:
			slimes_before = _count_slimes()
			var s0 := _first_slime()
			if s0 != null:
				_teleport(s0.global_position.x, s0.global_position.y - 34.0)
		520:
			_check("踩死史莱姆", _count_slimes() < slimes_before,
				"剩 %d 只（原 %d）" % [_count_slimes(), slimes_before])

		# ---------- 入水 ----------
		530:
			_teleport(73 * 16 + 8, 430)
		565:
			_check("人物入水", p.in_water, "in_water=%s" % p.in_water)

		# ---------- 爬梯 ----------
		575:
			_teleport(45 * 16 + 8, GROUND_Y)
		585:
			_teleport(45 * 16 + 8, GROUND_Y)
			Input.action_press("climb_up")
		645:
			climb_y = p.global_position.y
			Input.action_release("climb_up")
		650:
			_check("爬梯上升", climb_y < 400.0, "y=%.1f（地面 %.0f）" % [climb_y, GROUND_Y])

		# ---------- 摔死 -> 扣命 -> 原地复活 ----------
		660:
			Game.set_lives(3)
			_teleport(15 * 16 + 8, 920)
		750:
			_check("掉坑摔死扣命", Game.lives == 2, "命=%d" % Game.lives)
		790:
			_check("原地复活回出生点", (not p.dead) and absf(p.global_position.x - 72.0) < 8.0,
				"pos=(%.0f,%.0f) dead=%s" % [p.global_position.x, p.global_position.y, p.dead])

		# ---------- HUD ----------
		800:
			Game.set_health(1)
			var hs: Array = hud.hearts
			var full := String(hs[0].texture.resource_path).contains("full")
			var e1 := String(hs[1].texture.resource_path).contains("empty")
			var e2 := String(hs[2].texture.resource_path).contains("empty")
			_check("HUD 爱心随血量变化", full and e1 and e2, "血1 -> 实心/空心")
			_check("HUD 命数显示", hud.lives_label.text == "x%d" % Game.lives,
				"命文本 '%s'" % hud.lives_label.text)
			_check("HUD 金币计数", hud.coins_label.text == "%d/%d" % [Game.coins, Game.total_coins],
				"金币文本 '%s'" % hud.coins_label.text)

		# ---------- 通关 ----------
		810:
			_teleport(1864, 384)
		850:
			_check("走到终点通关", Game.finished, "finished=%s" % Game.finished)
			var msg := ""
			if hud != null:
				msg = hud.get_node("Message").text
			_check("HUD 显示通关文字", msg.contains("CLEAR"), "message=%s" % msg.replace("\n", " / "))

		870:
			print("\n===== 冒烟测试 =====")
			var ok := 0
			for r in results:
				print(r)
				if r.begins_with("PASS"):
					ok += 1
			print("通过 %d/%d" % [ok, results.size()])
			get_tree().quit()


func _start_track() -> void:
	peak_y = p.global_position.y
	track = true


func _teleport(x: float, y: float) -> void:
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO
	track = false


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  " + detail)


func _key_at(cell: Vector2i) -> String:
	var src := terrain.get_cell_source_id(cell)
	if src < 0:
		return "(空)"
	return TileIndex.key_at(src, terrain.get_cell_atlas_coords(cell))


func _first_slime() -> Slime:
	for c in entities.get_children():
		if c is Slime:
			return c
	return null


func _count_slimes() -> int:
	var n := 0
	for c in entities.get_children():
		if c is Slime:
			n += 1
	return n


func _count_pickups() -> int:
	var n := 0
	for c in entities.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("pickup.gd"):
			n += 1
	return n
