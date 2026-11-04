extends Node
## 冒烟测试：按物理帧驱动，检查站立/跑跳/撞块/踩怪/入水/爬梯。
## 跑法： Godot --headless --path . res://tools/SmokeTest.tscn

var main: Node
var tick := 0
var p: Player
var terrain: TileMapLayer
var entities: Node2D
var results: Array[String] = []
var slimes_before := 0


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

	match tick:
		10:
			_check("站立", p.is_on_floor() and absf(p.global_position.y - 416.0) < 0.5,
				"y=%.1f floor=%s" % [p.global_position.y, p.is_on_floor()])
			Input.action_press("move_right")
		25:
			_check("跑动", p.velocity.x > 100.0, "vx=%.1f" % p.velocity.x)
			Input.action_release("move_right")
		30:
			_teleport(21 * 16 + 8, 416)
		36:
			Input.action_press("jump")
		39:
			Input.action_release("jump")
		100:
			var key := _key_at(Vector2i(21, 22))
			_check("撞块变空块", key == "block_dirt_question_used", "砖=" + key)
			_check("撞块掉出奖励", _count_pickups() > 0, "拾取物 %d 个" % _count_pickups())
		105:
			slimes_before = _count_slimes()
			var s0 := _first_slime()
			if s0 != null:
				_teleport(s0.global_position.x, s0.global_position.y - 34.0)
		190:
			_check("踩死史莱姆", _count_slimes() < slimes_before,
				"剩 %d 只（原 %d）" % [_count_slimes(), slimes_before])
		200:
			_teleport(73 * 16 + 8, 430)
		235:
			_check("人物入水", p.in_water, "in_water=%s" % p.in_water)
		245:
			_teleport(45 * 16 + 8, 416)
		255:
			_teleport(45 * 16 + 8, 416)
			Input.action_press("jump")
		305:
			var y := p.global_position.y
			Input.action_release("jump")
			_check("爬梯上升", y < 400.0, "y=%.1f（地面 416）" % y)
		# --- 摔死 -> 掉命 -> 原地复活 ---
		310:
			Game.lives = 3
			_teleport(15 * 16 + 8, 920)
		400:
			_check("掉坑摔死扣命", Game.lives == 2, "命=%d" % Game.lives)
		440:
			_check("原地复活回出生点", (not p.dead) and absf(p.global_position.x - 72.0) < 8.0,
				"pos=(%.0f,%.0f) dead=%s" % [p.global_position.x, p.global_position.y, p.dead])
		450:
			_teleport(1864, 384)
		480:
			_check("走到终点通关", Game.finished, "finished=%s" % Game.finished)
			var hud = main.get_node_or_null("HUD")
			var msg := ""
			if hud != null:
				msg = hud.get_node("Message").text
			_check("HUD 显示通关文字", msg.contains("CLEAR"), "message=%s" % msg.replace("\n", " / "))
		465:
			pass
		475:
			# HUD 图标状态：掉 2 点血 -> 第 2、3 颗爱心变空心
			var hud = main.get_node_or_null("HUD")
			Game.health = 1
			Game.health_changed.emit(1)
			var hs: Array = hud.hearts
			var full := String(hs[0].texture.resource_path).contains("full")
			var e1 := String(hs[1].texture.resource_path).contains("empty")
			var e2 := String(hs[2].texture.resource_path).contains("empty")
			_check("HUD 爱心随血量变化", full and e1 and e2,
				"血1 -> %s" % [("实心" if full else "?") + "/" + ("空心" if e1 and e2 else "?")])
			_check("HUD 命数显示", hud.lives_label.text == "x%d" % Game.lives,
				"命文本 '%s'" % hud.lives_label.text)
		490:
			print("\n===== 冒烟测试 =====")
			var ok := 0
			for r in results:
				print(r)
				if r.begins_with("PASS"):
					ok += 1
			print("通过 %d/%d" % [ok, results.size()])
			get_tree().quit()


func _teleport(x: float, y: float) -> void:
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO


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
