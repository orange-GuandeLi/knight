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
var level: Node2D
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
var ice_vx := 0.0
var wall_vx := 0.0
var ps_vy := 0.0
var plat_px := 0.0
var plat_player_x := 0.0
var q_cell := Vector2i(-1, -1)
var ladder_col := -1
var ice_cell := Vector2i(-1, -1)
var bridge_cell := Vector2i(-1, -1)
var cp_target_x := 0.0
var shaft_col := -1
var coin_a := Vector2.ZERO
var coin_b := Vector2.ZERO
var cp_x := 0.0
var _seq_done := false

const GROUND_Y := 416.0


func _ready() -> void:
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	# 开场是标题画面，整个游戏是暂停的。先确认它在，再按空格开始。
	var start_screen: CanvasLayer = main.get_node("StartScreen")
	_check("开场显示标题画面", start_screen.visible and get_tree().paused,
		"visible=%s paused=%s" % [start_screen.visible, get_tree().paused])
	_press_key(KEY_SPACE)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("标题画面按空格开始", (not start_screen.visible) and (not get_tree().paused),
		"visible=%s paused=%s" % [start_screen.visible, get_tree().paused])

	get_tree().physics_frame.connect(_on_physics)
	# 等按物理帧计数的主流程跑完
	while not _seq_done:
		await get_tree().physics_frame

	# ---------- 暂停菜单 ----------
	# 暂停会停掉整个树，physics_frame 不再发，所以这段不能放在按帧计数的流程里
	var pm: CanvasLayer = main.get_node("PauseMenu")
	_press_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("ESC 弹出暂停菜单", pm.visible and get_tree().paused,
		"visible=%s paused=%s" % [pm.visible, get_tree().paused])
	_press_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("ESC 关掉暂停菜单", (not pm.visible) and (not get_tree().paused),
		"visible=%s paused=%s" % [pm.visible, get_tree().paused])

	_summary()


## 模拟按一次键，走正常输入管线（Input.action_press 不会产生事件）
func _press_key(keycode: Key) -> void:
	# keycode 和 physical_keycode 都要设：内置的 ui_* 动作按 keycode 匹配，
	# 自己定义的 jump / next_level 按 physical_keycode 匹配。
	# 按下和松开都要发，不然动作会一直处于「按下」状态，后面的测试全乱。
	_press_keycode(keycode, true)
	_press_keycode(keycode, false)


func _press_keycode(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _summary() -> void:
	print("\n===== 冒烟测试 =====")
	var ok := 0
	for r in results:
		print(r)
		if r.begins_with("PASS"):
			ok += 1
	print("通过 %d/%d" % [ok, results.size()])
	get_tree().quit()


## 换关之后要把节点引用重新拿一遍（旧关卡已经释放了）
func _refresh_nodes() -> void:
	level = main.get_node("Level")
	p = level.get_node("Player")
	terrain = level.get_node("Terrain")
	entities = level.get_node("Entities")
	hud = main.get_node_or_null("HUD")


func _on_physics() -> void:
	tick += 1
	if p == null:
		_refresh_nodes()

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
			q_cell = _find_tile("block_dirt_question")
			_teleport(float(q_cell.x) * 16 + 8, GROUND_Y)
		36:
			Input.action_press("jump")
		80:
			Input.action_release("jump")
		105:
			var key := _key_at(q_cell)
			_check("撞块变空块", key == "block_dirt_question_used", "砖=" + key)
			_check("撞块掉出奖励", _count_pickups() > 0, "拾取物 %d 个" % _count_pickups())

		# ---------- 短按跳 vs 长按跳 ----------
		110:
			_teleport(3 * 16 + 8, GROUND_Y)
		115:
			_start_track()
			Input.action_press("jump")
		118:
			# 起跳瞬间精灵要被拉长
			_check("起跳有拉伸挤压", p.sprite.scale.x < 0.95,
				"scale=%.2f,%.2f" % [p.sprite.scale.x, p.sprite.scale.y])
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

		# ---------- 爬梯 ----------
		575:
			ladder_col = _find_ladder_col()
			_teleport(float(ladder_col) * 16 + 8, GROUND_Y)
		585:
			_teleport(float(ladder_col) * 16 + 8, GROUND_Y)
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
			_check("HUD 金币计数", hud.coins_label.text == "%d/%d" % [Game.coins, Game.coin_goal],
				"金币文本 '%s'" % hud.coins_label.text)

		# ---------- 通关（要先收够金币）----------
		810:
			# 走到出口。金币不够的话不该通关。
			# 传送高度要按那一列的实际地面算，不然会塞进实心地形里摔死
			var exit_col: int = int(level.width) - 4
			_teleport(float(exit_col) * 16 + 8, _surface_y(exit_col) - 32.0)
		840:
			_check("金币没收够不能通关", not Game.finished,
				"finished=%s coins=%d/%d" % [Game.finished, Game.coins, Game.coin_goal])
			_check("提示还差多少金币", hud.message.text.contains("NEED"),
				"提示='%s'" % hud.message.text.replace("\n", " / "))
		860:
			# 模拟金币收够了
			Game.coins = Game.coin_goal
			Game.coins_changed.emit(Game.coins, Game.coin_goal)
		880:
			_check("金币收够就通关", Game.finished, "finished=%s" % Game.finished)
			var msg := ""
			if hud != null:
				msg = hud.message.text
			_check("HUD 显示通关文字", msg.contains("CLEAR"), "message=%s" % msg.replace("\n", " / "))

		# ---------- 踩怪连踩 ----------
		900:
			Game.bump_stomp_chain()
			Game.bump_stomp_chain()
			_check("踩怪连踩能累计", Game.stomp_chain == 2,
				"chain=%d" % Game.stomp_chain)
			Game.stomp_chain = 0

		# ---------- 顿帧 ----------
		905:
			Game.hitstop(3)
			_check("顿帧生效", Engine.time_scale < 1.0,
				"time_scale=%.3f" % Engine.time_scale)
		940:
			_check("顿帧会自己恢复", Engine.time_scale == 1.0,
				"time_scale=%.3f" % Engine.time_scale)

		# ---------- 地面翻滚冲刺 ----------
		880:
			_teleport(20 * 16 + 8, GROUND_Y)
			Input.action_press("move_right")
		886:
			Input.action_release("move_right")
			Input.action_press("down")
		900:
			_check("地面翻滚冲刺", p.rolling and p.velocity.x > 150.0,
				"rolling=%s vx=%.1f" % [p.rolling, p.velocity.x])
		903:
			Input.action_release("down")

		# ---------- 关卡左边界 ----------
		# 关卡左边是敞开的，不拦的话往回走会走出关卡掉进虚空。
		# 910 开始：上一轮翻滚到 907 才停，不然会被带着往反方向冲。
		910:
			_teleport(20, GROUND_Y)
			Input.action_press("move_left")
		945:
			Input.action_release("move_left")
			_check("走不出关卡左边界",
				absf(p.global_position.x - 5.0) < 1.0 and p.is_on_floor(),
				"x=%.1f（应为 5，身体刚好卡在关卡内）" % p.global_position.x)

		# ---------- 翻滚撞碎木箱 ----------
		# 949 才开始：翻滚有 0.55 秒冷却，得等上一轮结束
		952:
			_teleport(81 * 16 - 8, GROUND_Y)
			Input.action_press("move_right")
		958:
			Input.action_release("move_right")
			Input.action_press("down")
		982:
			Input.action_release("down")
			_check("翻滚撞碎木箱", _key_at(Vector2i(81, 25)) == "",
				"砖='%s'（应为已碎）" % _key_at(Vector2i(81, 25)))

		# ---------- 冰面 ----------
		990:
			# 给个护盾：冰面上有会跳的紫史莱姆，别让它们把角色打死影响测速
			if p.dead:
				p.respawn(p.global_position)
			p.grant_shield(60.0)
			ice_cell = _find_tile("ice_stone")
			_teleport(float(ice_cell.x) * 16 + 8, GROUND_Y)
		1000:
			_check("识别到冰面", p.on_ice, "on_ice=%s" % p.on_ice)
			Input.action_press("move_right")
		1020:
			Input.action_release("move_right")
			ice_vx = p.velocity.x
		1030:
			# 冰上松手还是往前滑，普通地面早就停住了
			_check("冰面打滑不刹车", p.velocity.x > 30.0 and p.velocity.x <= ice_vx,
				"松手后 vx=%.1f（滑行前 %.1f）" % [p.velocity.x, ice_vx])

		# ---------- 连击 ----------
		1035:
			Game.break_combo()                   # 从干净状态开始数
		1040:
			# 找两枚还在的金币（前面的测试可能已经吃掉了一些）
			coin_a = _find_coin_pos()
			_teleport(coin_a.x, coin_a.y)
		1060:
			coin_b = _find_coin_pos()
			_teleport(coin_b.x, coin_b.y)
		1080:
			_check("连击累计倍率", Game.combo == 2,
				"combo=%d 倍率=%d" % [Game.combo, maxi(1, Game.combo)])

		# ---------- 检查点 ----------
		# ---------- 桥面碰撞跟着画面 ----------
		# 关卡1 的泥土桥在 27~33 列：中间是绳面（第 2 行，比地面低 2px），
		# 两头是抬高的桥墩（跟地面齐平）。桥墩那端是斜坡。
		1090:
			bridge_cell = _find_tile("bridge_dirt_middle")
			_teleport(float(bridge_cell.x) * 16 + 8, 300)   # 桥中间那块的正上方
		1140:
			_check("桥面贴着绳面", absf(p.global_position.y - (26 * 16 + 2)) < 1.5,
				"桥上 y=%.1f（绳面 %.0f，地面 %.0f）"
				% [p.global_position.y, 26 * 16 + 2, 26 * 16])
		1150:
			_teleport(float(bridge_cell.x - 1) * 16 + 2, 300)   # 桥墩那端（斜坡）
		1200:
			_check("桥头是斜坡不是直墙", p.global_position.y <= 26 * 16 + 3.0
					and p.global_position.y >= 26 * 16 - 1.0,
				"桥头 y=%.1f（地面 %.0f ~ 绳面 %.0f 之间）"
				% [p.global_position.y, 26 * 16, 26 * 16 + 2])

		# ---------- 紫史莱姆会跳 ----------
		1160:
			ps_vy = 0.0
		1165:
			_follow_purple_slime()
			ps_vy = _min_vy(ps_vy)
		1170:
			_follow_purple_slime()
			ps_vy = _min_vy(ps_vy)
		1175:
			_follow_purple_slime()
			ps_vy = _min_vy(ps_vy)
		1180:
			_follow_purple_slime()
			ps_vy = _min_vy(ps_vy)
			_check("紫史莱姆会跳扑过来", ps_vy < -40.0, "最低 vy=%.1f" % ps_vy)

		# ---------- 检查点 ----------
		1210:
			cp_target_x = _find_checkpoint_x()
			_teleport(cp_target_x, GROUND_Y)     # 走到检查点木牌上
		1230:
			cp_x = level.respawn_pos.x
			_check("碰到检查点就激活", absf(cp_x - cp_target_x) < 2.0,
				"复活点 x=%.0f（应为 %.0f）" % [cp_x, cp_target_x])

		# ---------- 从检查点复活 ----------
		1240:
			_teleport(15 * 16 + 8, 920)           # 再摔一次
		1375:
			_check("从检查点复活", (not p.dead) and absf(p.global_position.x - cp_x) < 8.0,
				"pos=(%.0f,%.0f)（检查点 x=%.0f）" % [p.global_position.x, p.global_position.y, cp_x])

		# ---------- 倒计时 ----------
		1385:
			_check("关卡有倒计时", Game.time_left > 0.0, "剩 %.0f 秒" % Game.time_left)
			_check("HUD 显示倒计时", hud.time_label.visible and hud.time_label.text.contains(":"),
				"时间文本 '%s'" % hud.time_label.text)

		# ---------- 通关后进下一关 ----------
		1395:
			# Input.action_press 不会产生事件，得走正常输入管线
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_ENTER
			ev.pressed = true
			Input.parse_input_event(ev)
		1415:
			_refresh_nodes()
			_check("通关后进下一关", Game.level_index == 1,
				"level_index=%d" % Game.level_index)
			_check("第 2 关已载入", level.data_path.ends_with("level02.json"),
				"数据=%s" % level.data_path)
			_check("换关后清掉通关提示", hud.message.text == "",
				"提示='%s'" % hud.message.text.replace("\n", " / "))

		# ---------- 雪地（第 2 关 102~112 列）----------
		# 雪地不是打滑：走得慢、跳得矮，但能刹住
		1425:
			# 给个护盾，免得附近会跳的紫史莱姆把角色撞飞，影响测速
			p.grant_shield(30.0)
			_teleport(103 * 16 + 8, GROUND_Y)
			Input.action_press("move_right")
		1450:
			_check("雪地走得慢", p.on_snow and absf(p.velocity.x - 70.0) < 6.0,
				"on_snow=%s vx=%.1f（普通地面 110）" % [p.on_snow, p.velocity.x])
			Input.action_release("move_right")
		1465:
			_check("雪地能刹住", absf(p.velocity.x) < 20.0,
				"松手后 vx=%.1f（冰上会一直滑）" % p.velocity.x)
		1470:
			_teleport(103 * 16 + 8, GROUND_Y)
			_start_track()
		1475:
			Input.action_press("jump")
		1515:
			Input.action_release("jump")
		1535:
			var snow_h := GROUND_Y - peak_y
			_check("雪地跳得矮", snow_h < 40.0, "雪地跳 %.1f px（普通地面 50）" % snow_h)

		# ---------- 墙跳（第 3 关的竖井）----------
		1545:
			Game.level_index = 2
			main.load_level()
			_refresh_nodes()
			# 竖井：找一面竖着的墙，站在它右边贴墙
			shaft_col = _find_wall_col()
			_teleport(float(shaft_col) * 16 + 14, GROUND_Y)
			Input.action_press("move_left")
		1555:
			Input.action_press("jump")
		1575:
			Input.action_release("jump")
			_check("贴墙下滑", p.wall_dir == -1 and p.velocity.y <= 60.0,
				"wall_dir=%d vy=%.1f" % [p.wall_dir, p.velocity.y])
		1585:
			Input.action_press("jump")           # 蹬墙跳
			wall_vx = 0.0
		1590:
			wall_vx = maxf(wall_vx, p.velocity.x)
		1595:
			wall_vx = maxf(wall_vx, p.velocity.x)
		1600:
			Input.action_release("jump")
			# 蹬墙后有 0.14 秒锁向，之后松手会被减速，所以取最高速
			_check("墙跳蹬出去", wall_vx > 100.0,
				"蹬墙后最高 vx=%.1f" % wall_vx)
		1610:
			Input.action_release("move_left")

		# ---------- 移动平台 ----------
		1620:
			var mp := _first_moving_platform(1)
			if mp != null:
				# 站到平台上方，让它落下来
				_teleport(mp.global_position.x + 24.0, mp.global_position.y - 40.0)
		1638:
			# 落地之后再记起点，否则量到的是落地前那一段
			var mp0 := _first_moving_platform(1)
			if mp0 != null:
				plat_px = mp0.global_position.x
				plat_player_x = p.global_position.x
				var tex: Texture2D = mp0.get_node("Sprite").texture
				_check("移动平台有贴图", tex != null,
					"贴图=%s" % (tex.get_size() if tex != null else "null"))
		1658:
			var mp2 := _first_moving_platform(1)
			if mp2 != null and plat_px != 0.0:
				# 平台的位移和角色的位移应该一致（人被带着走）
				var plat_move := mp2.global_position.x - plat_px
				var player_move := p.global_position.x - plat_player_x
				_check("移动平台会带着人走", absf(player_move - plat_move) < 10.0,
					"平台走了 %.0f，人走了 %.0f" % [plat_move, player_move])

		# ---------- 入水 = 淹死 ----------
		# 放在最后：淹死会打断后面所有测试（角色在死亡动画里动不了）
		1680:
			Game.set_lives(3)
			# 先把玩家救活（前面的测试可能已经死了）
			if p.dead:
				p.respawn(p.global_position)
			var wp := _find_water_pos()
			_teleport(wp.x, wp.y)            # 直接丢进水塘
		1710:
			_check("掉进水里会淹死", p.dead,
				"dead=%s in_water=%s" % [p.dead, p.in_water])

		1740:
			_seq_done = true


func _start_track() -> void:
	peak_y = p.global_position.y
	track = true


func _teleport(x: float, y: float) -> void:
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO
	track = false


func _check(name: String, ok: bool, detail: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + name + "  " + detail)


## 在关卡里找一个砖（按砖名开头匹配），返回格坐标。找不到返回 (-1,-1)。
func _find_tile(prefix: String) -> Vector2i:
	for y in range(level.height):
		for x in range(level.width):
			if _key_at(Vector2i(x, y)).begins_with(prefix):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## 找地面那一行上的某个砖
func _find_surface_tile(prefix: String) -> Vector2i:
	for y in range(level.height):
		for x in range(level.width):
			if _key_at(Vector2i(x, y)).begins_with(prefix):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## 找第一个检查点实体，返回它的 x（世界坐标）
func _find_checkpoint_x() -> float:
	for c in entities.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("checkpoint.gd"):
			return c.global_position.x
	return -1.0


## 找一列有梯子的地方，返回列号
func _find_ladder_col() -> int:
	for x in range(level.width):
		for y in range(level.height):
			if _key_at(Vector2i(x, y)).begins_with("ladder_"):
				return x
	return -1


## 找一个还没被吃掉的金币，返回世界坐标
func _find_coin_pos() -> Vector2:
	for c in entities.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("coin.gd"):
			return c.global_position
	return Vector2(8, 8 * 16 + 8)


## 某一列的地面在第几行（返回世界 y）。找不到返回默认地面高度。
func _surface_y(col: int) -> float:
	for y in range(level.height):
		var k := _key_at(Vector2i(col, y))
		if k != "" and not k.begins_with("bridge_") and not k.begins_with("ladder_") \
				and not k.begins_with("water_"):
			return float(y) * 16
	return GROUND_Y


## 找一滩水，返回水面的世界坐标
func _find_water_pos() -> Vector2:
	for y in range(level.height):
		for x in range(level.width):
			var k := _key_at(Vector2i(x, y))
			if k.begins_with("water_") and k != "water_ice_surface":
				return Vector2(float(x) * 16 + 8, float(y) * 16 + 8)
	return Vector2(72, 430)


## 找第 3 关竖井的墙：找一列「上面连续几行都是实心地形」的竖墙
func _find_wall_col() -> int:
	for x in range(level.width):
		# 从上往下数，连续 4 行以上都是地形的列
		var cnt := 0
		for y in range(14, 26):
			var k := _key_at(Vector2i(x, y))
			if k != "" and not k.begins_with("bridge_") and not k.begins_with("ladder_") \
					and not k.begins_with("water_"):
				cnt += 1
				if cnt >= 4:
					return x
			else:
				cnt = 0
	return -1


func _key_at(cell: Vector2i) -> String:
	var src := terrain.get_cell_source_id(cell)
	if src < 0:
		return ""
	return TileIndex.key_at(src, terrain.get_cell_atlas_coords(cell))


func _first_slime() -> Slime:
	for c in entities.get_children():
		if c is Slime:
			return c
	return null


## 站到紫史莱姆旁边，逼它跳起来
func _follow_purple_slime() -> void:
	var ps := _first_purple_slime()
	if ps == null:
		return
	p.global_position = Vector2(ps.global_position.x - 50.0, GROUND_Y)
	p.velocity = Vector2.ZERO


## 记录紫史莱姆在窗口里的最小竖直速度（它跳起来又落下，只看某一帧会漏）
func _min_vy(cur: float) -> float:
	var ps := _first_purple_slime()
	if ps == null:
		return cur
	return minf(cur, ps.velocity.y)


## 找第 n 块移动平台
func _first_moving_platform(n: int = 0) -> Node2D:
	var i := 0
	for c in entities.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("moving_platform.gd"):
			if i == n:
				return c
			i += 1
	return null


func _first_purple_slime() -> Slime:
	for c in entities.get_children():
		if c is Slime and (c as Slime).variant == "purple":
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
