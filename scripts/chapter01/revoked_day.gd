extends Node3D

const PLAYER := preload("res://scenes/player.tscn")
const HUD := preload("res://scripts/chapter01/chapter_hud.gd")
const FEEDBACK := preload("res://scripts/combat_feedback.gd")
const ECHO := preload("res://scripts/chapter01/office_echo.gd")
const PAPER := preload("res://scripts/chapter01/paper_body.gd")
const STAMPER := preload("res://scripts/chapter01/stamper.gd")
const PAINTED_MAP := preload("res://scripts/chapter01/painted_map.gd")
const SKILLS := preload("res://scripts/cards/card_skills.gd")

@export var card_practice := false
@export var rogue_enabled := true
@export var combat_only := true
var _fast_blade: MeshInstance3D
var battle_wave := 0
var battle_wave_limit := 5
var _battle_transition_pending := false
var _batch_queue: Array[Dictionary] = []
var _batch_alive := 0
var _batch_number := 0
var _batch_total := 0
var _batch_pending := false
var rogue: Node

const EVIDENCE := [
	["迟交记录", "[可核对 · 提交系统]\n两次报告晚于约定时间，其中一份存在遗漏。记录说明任务完成遇到了困难；它没有记录一个人的价值。"],
	["请假邮件", "[可核对 · 邮件原文]\n我写下：最近睡眠紊乱，注意力与表达都受到干扰，想请假复诊，并申请明确的书面任务清单。"],
	["主管回复", "[可核对 · 回复原文]\n回复要求按时交付，没有回应调整清单的请求。辞退通知随后发出；现存邮件没有显示进一步讨论支持方案的安排。"],
	["会议纪要", "[可核对 · 会议纪要]\n会议记录只写有进度与交接安排。座位被标记为缺席，没有写下我听见的所有议论。"],
	["一段录音", "[可核对 · 录音转录]\n可辨认的一句是“他最近状态不好”。其余声音含混，不能据此确认每个人都在嘲笑或否定我。"],
	["我的感受", "[主观体验 · 自述]\n我仿佛听见所有人都在说“你没有用”。那份害怕和羞耻是真实的感受；关于别人怎么想，仍需要资料核对。"],
]
const BILLS := [
	["房租", "租金 1800 元；付款期限没有因工资停发而延后。"],
	["食物", "本周食物预算 180 元；缩减支出已经开始影响正常进餐。"],
	["交通", "交通预算 90 元；面试与复诊都需要出门。"],
	["复诊", "复诊支出 120 元；我把预约信搁在一旁，迟迟没有拆。"],
	["药物", "药物支出 210 元；账目只记录压力，不给出自行改变治疗的指令。"],
]

var player: FairytalePlayer
var stamper: Node3D
var hud: CanvasLayer
var skills: Node3D
var world: Node3D
var camera: Camera3D
var stage := 0
var records: Array[int] = []
var bills_done: Array[int] = []
var office_fought := false
var wave_started := false
var enemies_left := 0
var won := false
var _interactions: Array[Dictionary] = []
var _subjective: Array[Node3D] = []
var _elapsed := 0.0
var _half := Vector2(22, 18)
var _camera_focus := Vector3.ZERO
var _wanted_focus := Vector3.ZERO
var _time_to_shrink := 4.0
var _shrink_step := 0
var _arena_limit := Vector2(14, 12)
var _danger_edges: Array[MeshInstance3D] = []
var _changing := false
var _art: Node3D
var _last_player_position := Vector3.ZERO

func _ready() -> void:
	var state := get_node_or_null("/root/RunState")
	if state != null:
		state.carried_health = -1.0
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.065, 0.085, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.72, 0.76)
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -25, 0)
	key.light_color = Color(0.85, 0.88, 0.82)
	key.light_energy = 1.1
	key.shadow_enabled = true
	add_child(key)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21.0
	camera.rotation_degrees.x = -55.0
	camera.current = true
	add_child(camera)
	var feedback := Node3D.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(FEEDBACK)
	add_child(feedback)
	player = PLAYER.instantiate() as FairytalePlayer
	player.name = "Player"
	player.external_pause_control = true
	player.melee_speed_multiplier = 2.0
	player.melee_range_multiplier = 1.35
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.get_node("Visual").scale = Vector3.ONE * 1.25
	_fast_blade = _box("FastKnife", Vector3(0.10, 0.035, 0.65), Vector3(0.4, 0.85, 0), Color(0.85, 0.92, 1), false, player)
	skills = SKILLS.new()
	skills.name = "CardSkills"
	add_child(skills)
	if rogue_enabled and not card_practice:
		rogue = load("res://scripts/rogue/chapter_run.gd").new()
		add_child(rogue)
	hud = CanvasLayer.new()
	hud.name = "ChapterHUD"
	hud.set_script(HUD)
	add_child(hud)
	if card_practice:
		_load_stage(2)
		reset_practice()
		hud.call("dialog", "五卡练习", "五张卡均已装备，冷却分别为 6 / 10 / 12 / 9 / 14 秒。\n\n滚轮选牌 → 按住中键瞄准 → 松开施放。随时可滚轮换牌。\n练习中不会受到伤害；右上角可重置目标和冷却。", ["开始练习"], [Callable()])
		return
	_load_stage(0)
	if rogue != null:
		# Spawn on the central open floor, below the artwork's solid desk footprint.
		player.position = _at(Vector2(768, 565))
		_last_player_position = player.position
		set_camera_target(player.position)
		_camera_focus = _wanted_focus
		_update_camera(1.0)
		rogue.start()
	else:
		hud.call("dialog", "第一关 · 被撤销的一天", "靠近方框资料按 E 查看；Tab 打开调查记录。", ["开始调查"], [Callable()])

func _load_stage(next: int) -> void:
	_changing = true
	if is_instance_valid(skills):
		skills.call("clear_effects")
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	_interactions.clear()
	_subjective.clear()
	_danger_edges.clear()
	stage = next
	world = Node3D.new()
	world.name = ["Office", "RainStreet", "Apartment"][stage]
	add_child(world)
	_half = Vector2(24, 19.532)
	_build_floor()
	match stage:
		0:
			if not combat_only: _build_office()
		1: _build_street()
		2: _build_apartment()
	player.position = _at([Vector2(625, 525), Vector2(750, 710), Vector2(770, 770)][stage])
	_last_player_position = player.position
	player.velocity = Vector3.ZERO
	player.cancel_beam_charge()
	set_camera_target(player.position)
	_camera_focus = _wanted_focus
	_update_camera(1.0)
	_changing = false

func _physics_process(delta: float) -> void:
	if _changing or won or player.health <= 0.0:
		return
	_elapsed += delta
	if card_practice:
		player.set("_invulnerability_timer", 1.0)
	var disturbance := records.size() / 6.0 * 0.55 if stage == 0 else (0.4 if stage == 1 else bills_done.size() / 5.0 * 0.65)
	_art.material.set_shader_parameter("disturbance", disturbance)
	for node in _subjective:
		if is_instance_valid(node):
			var origin: Vector3 = node.get_meta("origin", node.position)
			node.position = origin + Vector3(sin(_elapsed * 1.7 + origin.x) * 0.12, 0, cos(_elapsed * 1.3) * 0.08) * records.size() / 6.0
	if is_instance_valid(stamper) and not stamper.dead and stamper.phase == 2:
		_time_to_shrink -= delta
		if _time_to_shrink <= 0.0 and _shrink_step < 4:
			_time_to_shrink = 6.0
			_shrink_step += 1
			_arena_limit = Vector2(17 - _shrink_step * 1.5, 9 - _shrink_step)
			_draw_danger_edges()
		if absf(player.position.x) > _arena_limit.x or absf(player.position.z) > _arena_limit.y:
			player.apply_hit(4.0)

func _process(delta: float) -> void:
	if is_instance_valid(_fast_blade):
		var direction: Vector3 = player._attack_direction if player._attack_stage >= 0 else player._facing
		var angle := atan2(direction.x, direction.z)
		if player._attack_stage >= 0:
			angle += sin(player._attack_elapsed / player._attack_data[player._attack_stage].total_duration() * PI) * 1.8 - 0.9
		_fast_blade.rotation.y = angle
		_fast_blade.position = Vector3(sin(angle) * 0.5, 0.85, cos(angle) * 0.5)
	if is_instance_valid(camera):
		_update_camera(delta)

func _update_camera(delta: float) -> void:
	_camera_focus = _camera_focus.lerp(_wanted_focus, 1.0 - exp(-7.0 * delta))
	# Fixed pitch: smoothing translates the entire view, never rotates toward a moving target.
	camera.position = _camera_focus + Vector3(0, 24.0, 16.805)

func set_camera_target(at: Vector3) -> void:
	if camera == null:
		return
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_x := camera.size * aspect * 0.5
	var half_z := camera.size * 0.5 / sin(deg_to_rad(55.0))
	var range_x := maxf(0.0, _half.x - half_x)
	var range_z := maxf(0.0, _half.y - half_z)
	_wanted_focus = Vector3(clampf(at.x, -range_x, range_x), 0, clampf(at.z, -range_z, range_z))

func clamp_to_arena(at: Vector3, margin: float = 0.6) -> Vector3:
	var bounded := Vector3(clampf(at.x, -_half.x + margin, _half.x - margin), 0, clampf(at.z, -_half.y + margin, _half.y - margin))
	if is_instance_valid(_art):
		bounded = _art.call("clamp_player", bounded, _last_player_position)
	_last_player_position = bounded
	return bounded

func _at(pixel: Vector2) -> Vector3:
	return _art.call("to_world", pixel)

func set_camera_shake(_strength: float) -> void:
	# This chapter keeps the camera stable; impacts use particles and floor stamps.
	pass

func _unhandled_input(event: InputEvent) -> void:
	if combat_only:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if get_tree().paused or won or player.health <= 0.0:
			return
		var nearest := _nearest()
		if not nearest.is_empty():
			var callback: Callable = nearest["action"]
			callback.call()
			get_viewport().set_input_as_handled()

func _nearest() -> Dictionary:
	var result: Dictionary = {}
	var distance := 3.2
	for item in _interactions:
		if not is_instance_valid(item["node"]):
			continue
		var node: Node3D = item["node"]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var at := Vector2(node.position.x, node.position.z)
		var candidate := at.distance_to(Vector2(player.position.x, player.position.z))
		if candidate < distance:
			distance = candidate
			result = item
	return result

func get_interaction_hint() -> String:
	if combat_only and not card_practice:
		return "WASD移动 · 左键快速砍击 · 中键技能 · Shift / Space闪避 · Tab查看构筑"
	if card_practice:
		return "五卡练习 · 滚轮随时换牌，中键按住瞄准、松开施放 · 冷却结束需重新按下施放"
	if won:
		return "已获得：因果记录卡"
	var nearest := _nearest()
	if not nearest.is_empty():
		return "[E] " + str(nearest["hint"])
	return "WASD 移动 · E 查看 · Tab 调查记录 · 左键攻击 · Shift / Space 闪避"

func get_hud_status() -> String:
	if combat_only and not card_practice:
		if won: return "战斗完成 · 五波清场与盖章者已击败"
		if is_instance_valid(stamper): return "最终战 · 盖章者"
		if _battle_transition_pending: return "下一波即将抵达"
		if not wave_started: return "选择技能后开战 · 首波32只，分4批清场"
		return "第%d / %d波 · 第%d / %d批 · 当前%d · 本波剩余%d" % [maxi(1, battle_wave), battle_wave_limit, _batch_number, _batch_total, _batch_alive, enemies_left]
	if card_practice:
		return "卡牌练习 · 五种技能 · 独立冷却 · 练习中免伤"
	if stage == 0:
		if wave_started and not office_fought:
			return "第一波 · 清除残影 %d / %d" % [int(get_meta("opening_wave_total", 5)) - enemies_left, int(get_meta("opening_wave_total", 5))]
		return "办公室 · 资料 %d / 6 · %s" % [records.size(), "已清理，前往出口" if office_fought else "调查工位、会议室与档案"]
	if stage == 1 and rogue != null:
		return ("街道战斗 · 剩余 %d" % rogue.remaining) if rogue.in_combat else ("街道支路 %d / 4 · 零钱 %d · 前往出租屋入口选路" % [maxi(0, rogue.depth - 1), rogue.coins])
	if stage == 1:
		return "雨后街道 · 沿路查看信件，前往出租屋"
	return "出租屋 · 账单 %d / 5 · %s" % [bills_done.size(), "盖章者已显形" if is_instance_valid(stamper) else "查看或攻击纸墙，释放场地"]

func notebook_text() -> String:
	var result := "方框资料是可核对的原文；错位的文字是当事人的体验。\n\n"
	for id in records:
		result += "□ " + EVIDENCE[id][0] + "\n" + EVIDENCE[id][1] + "\n\n"
	if records.is_empty():
		result += "目前尚未收集办公室资料。\n"
	result += "\n经济记录（桌面原件，数字固定）\n"
	for bill in BILLS:
		result += "□ " + bill[0] + "：" + bill[1] + "\n"
	if rogue != null:
		result += "\n\n本局构筑\n" + rogue.summary()
	return result

func _build_floor() -> void:
	_art = PAINTED_MAP.new()
	world.add_child(_art)
	_art.call("build", stage)

func _build_office() -> void:
	var positions := [Vector2(426, 446), Vector2(309, 642), Vector2(921, 449), Vector2(1270, 518), Vector2(529, 795), Vector2(565, 330)]
	for i in range(6):
		_add_interaction(EVIDENCE[i][0], _at(positions[i]), _read_evidence.bind(i), i < 5)
	_add_interaction("清空的工位", _at(Vector2(664, 525)), _desk_memory)
	_add_interaction("出口 / 直接离开", _at(Vector2(744, 938)), _office_exit)
	for i in range(4):
		var at := _at([Vector2(530, 280), Vector2(1250, 420), Vector2(740, 570), Vector2(1000, 650)][i])
		var whisper := _sign(["他们都在议论我？", "缺席的座位", "我是不是没有用了？", "每个人都知道？"][i], at + Vector3.UP * 0.5, Color(0.7, 0.38, 0.37), 24)
		whisper.set_meta("origin", whisper.position)
		_subjective.append(whisper)

func _desk_memory() -> void:
	hud.call("dialog", "被清空的工位", "水杯、相框与笔记本都不见了。\n空桌子让我觉得自己仿佛从未存在，但这张桌子不能替我定义我的价值。", ["继续调查"], [Callable()])

func _read_evidence(id: int) -> void:
	var is_new := not records.has(id)
	if is_new:
		records.append(id)
		_add_stamp(Vector3(-16 + id * 5, 0.03, -1), "待核对", false)
	var callback: Callable = _completed_investigation if records.size() == 6 and is_new and not wave_started else Callable()
	hud.call("dialog", EVIDENCE[id][0], EVIDENCE[id][1], ["记入调查记录" if is_new else "关闭原文"], [callback])

func _completed_investigation() -> void:
	hud.call("dialog", "先把不同的原因拆开", "病情波动影响了工作功能，公司也没有提供清晰沟通和调整机会。\n“发生工作失误”“公司选择辞退”和“我没有价值”不是同一件事。\n\n接下来，我想先……", ["追查责任与沟通经过", "拿回私人物品", "直接走向出口"], [_trace_responsibility, _take_belongings, _start_wave])

func _trace_responsibility() -> void:
	hud.call("dialog", "责任追查", "提交记录说明了工作失误；邮件说明调整请求没有得到回应。\n证据支持区分个人功能困难和公司的选择；并不能把全部后果推导成关于自我价值的结论。", ["收好记录，面对残影"], [_start_wave])

func _take_belongings() -> void:
	_add_interaction("私人物品 · 水杯与笔记本", _at(Vector2(880, 530)), _belongings_found)

func _belongings_found() -> void:
	hud.call("dialog", "我的东西还属于我", "笔记本里有认真完成的工作，也有没做好的部分。\n我把它和水杯带走。一次辞退没有撤销过去的努力。", ["带上物品，面对残影"], [_start_wave])

func _office_exit() -> void:
	if office_fought:
		if rogue != null and rogue.pending_reward:
			rogue.reward()
			return
		_load_stage(1)
	elif wave_started:
		hud.call("dialog", "出口被纸页封住", "先清除办公室的结论残影，再离开这里。", ["返回战斗"], [Callable()])
	else:
		hud.call("dialog", "现在离开？", "目前已核对 %d / 6 份资料。\n你可以继续调查，也可以直接面对出口前的残影。尚未查看的资料仍可在办公室回看。" % records.size(), ["直接进入战斗", "继续调查"], [_start_wave, Callable()])

func _start_wave() -> void:
	if wave_started:
		return
	wave_started = true
	if rogue != null:
		if combat_only: battle_wave = 1
		_start_crowd_wave()
		return
	enemies_left = 5
	for i in range(5):
		var enemy := CharacterBody3D.new()
		enemy.set_script(ECHO)
		if i == 4:
			enemy.set("max_health", 92.0)
			enemy.set("attack_damage", 13.0)
			enemy.scale = Vector3.ONE * 1.25
		enemy.position = _at([Vector2(602, 570), Vector2(887, 550), Vector2(580, 368), Vector2(870, 315), Vector2(1110, 600)][i])
		enemy.connect("defeated", _echo_defeated)
		world.add_child(enemy)

func _start_crowd_wave() -> void:
	var pools := [[], [], [], []]
	var center: Vector3 = _at(Vector2(768, 565)) if combat_only else player.position
	# Navigation cells provide valid, collision-free spawn positions on all four sides.
	for y in range(32):
		for x in range(48):
			var cell := Vector2i(x, y)
			if _art.navigation.is_point_solid(cell): continue
			var point: Vector3 = _at(_art.navigation.get_point_position(cell))
			var offset := point - center
			if offset.length() < 7.0 or offset.length() > 15.0 or point.distance_to(player.position) < 4.0: continue
			var side := (0 if offset.x > 0 else 2) if absf(offset.x) > absf(offset.z) else (1 if offset.z > 0 else 3)
			pools[side].append(point)
	enemies_left = 0
	_batch_queue.clear()
	_batch_number = 0
	_batch_alive = 0
	_batch_pending = false
	var per_side := 8 + (maxi(1, battle_wave) - 1) * 2 if combat_only else 8
	for side in range(4): rogue._shuffle(pools[side])
	# Interleave the four sides; each group of eight contains two from each side.
	for index in range(per_side):
		for side in range(4):
			if index >= pools[side].size(): continue
			_batch_queue.append({"point":pools[side][index], "side":side, "index":index})
	enemies_left = _batch_queue.size()
	_batch_total = ceili(enemies_left / 8.0)
	set_meta("opening_wave_total", enemies_left)
	if combat_only:
		_spawn_next_batch()
	else:
		while not _batch_queue.is_empty(): _spawn_crowd_enemy(_batch_queue.pop_front(), false)

func _spawn_crowd_enemy(plan: Dictionary, preview: bool) -> void:
	var enemy := CharacterBody3D.new()
	enemy.set_script(ECHO)
	var elite := combat_only and battle_wave in [3, 5] and int(plan.index) == 0
	enemy.max_health = 60.0 if elite else (18.0 + maxi(0, battle_wave - 1) * 2.0)
	enemy.attack_damage = 6.0 if elite else (3.0 + floorf(maxi(0, battle_wave - 1) / 2.0))
	if elite: enemy.scale = Vector3.ONE * 1.2
	enemy.move_speed = rogue.rng.randf_range(1.5, 2.0)
	enemy.role = (int(plan.index) + 1 + int(plan.side)) % 3
	enemy.position = plan.point
	enemy.set_meta("spawn_side", plan.side)
	enemy.defeated.connect(_echo_defeated)
	world.add_child(enemy)
	if preview: stage_spawn(enemy, 0.0)

func _spawn_next_batch() -> void:
	_batch_pending = false
	if won or player.health <= 0 or _batch_queue.is_empty() or _batch_alive > 0: return
	_batch_number += 1
	var count := mini(8, _batch_queue.size())
	_batch_alive = count
	for i in range(count): _spawn_crowd_enemy(_batch_queue.pop_front(), true)

func _echo_defeated(_enemy: Node) -> void:
	enemies_left -= 1
	if combat_only and rogue != null:
		_batch_alive -= 1
		if _batch_alive == 0 and not _batch_queue.is_empty() and not _batch_pending:
			_batch_pending = true
			call_deferred("_spawn_next_batch")
	if enemies_left <= 0:
		if combat_only and rogue != null:
			if rogue.pending_reward or _battle_transition_pending: return
			rogue.award_combat(battle_wave in [3, 5])
			return
		office_fought = true
		if rogue != null:
			rogue.office_reward()
			return
		hud.call("dialog", "出口已打开", "那些重复的结论暂时安静下来。\n你可以回看还没读过的资料，或者从南侧中央走廊走向雨后的街道。", ["继续"], [Callable()])

func queue_next_battle() -> void:
	if _battle_transition_pending or won or player.health <= 0.0: return
	_battle_transition_pending = true
	skills.clear_effects()
	# Pause-aware intermission; choosing a reward is the only required interruption.
	await get_tree().create_timer(0.8, false).timeout
	if won or player.health <= 0.0:
		_battle_transition_pending = false
		return
	_battle_transition_pending = false
	if battle_wave >= battle_wave_limit:
		office_fought = true
		player.position = _at(Vector2(768, 730))
		_last_player_position = player.position
		player.velocity = Vector3.ZERO
		_start_boss()
	else:
		battle_wave += 1
		_start_crowd_wave()

func _build_street() -> void:
	_add_interaction("工资停发通知", _at(Vector2(1270, 665)), _street_record.bind(0))
	_add_interaction("没有拆开的信", _at(Vector2(995, 477)), _street_record.bind(1))
	_add_interaction("出租屋入口", _at(Vector2(1300, 305)), _enter_apartment)

func _street_record(id: int) -> void:
	var body := "工资停发后，房租、食物、交通与复诊支出同时挤进账本。经济压力是辞退带来的后果，也会增加恢复日常功能的困难。" if id == 0 else "我把信塞回口袋，推迟拆开它，也减少了外出。作息更混乱，睡眠与孤立感又反过来干扰注意和表达。"
	hud.call("dialog", "雨后街道", body, ["继续往出租屋走"], [Callable()])

func _enter_apartment() -> void:
	if rogue != null and rogue.depth < 5:
		rogue.route()
		return
	if rogue != null and (rogue.in_combat or rogue.pending_reward):
		return
	_enter_apartment_direct()

func _enter_apartment_direct() -> void:
	_load_stage(2)
	hud.call("dialog", "出租屋 · 经济失意", "五类账单挡住了房间。\n靠近按 E 查看账单，或用攻击撕开纸墙。桌面原件始终可以回看。\n每解开一张账单，红色盖章会更多地占据房间。", ["查看这间屋子"], [Callable()])

func _build_apartment() -> void:
	_add_interaction("桌面原件 · 固定账目", _at(Vector2(820, 280)), _original_bills)
	_arena_limit = Vector2(17, 9)
	for i in range(5):
		var body := StaticBody3D.new()
		body.set_script(PAPER)
		body.set("extent", Vector3(6.25, 1.6, 0.55))
		body.position = Vector3(-12.8 + i * 6.4, 0.8, 5.2)
		body.connect("torn", _bill_torn.bind(i))
		world.add_child(body)
		var label := Label3D.new()
		label.text = BILLS[i][0]
		label.font_size = 34
		label.pixel_size = 0.012
		label.position = Vector3(0, 0.4, 0.32)
		label.modulate = Color(0.45, 0.07, 0.08)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(label)
		_interactions.append({"node": body, "hint": "查看并解开账单：" + BILLS[i][0], "action": _read_bill.bind(i, body)})

func _read_bill(id: int, body: Node) -> void:
	hud.call("dialog", BILLS[id][0] + " · 原件", BILLS[id][1] + "\n\n账单带来现实压力，却不能替一个人盖下“无用”的结论。", ["记下原件，解开纸墙"], _bill_callbacks(body))

func _bill_callbacks(body: Node) -> Array:
	return [func():
		if is_instance_valid(body):
			body.call("receive_hit", 999.0, Vector3.ZERO, body.position)
	]

func _bill_torn(_body: Node, id: int) -> void:
	if bills_done.has(id):
		return
	bills_done.append(id)
	for i in range(8):
		var x := -13.0 + posmod(id * 5 + i * 7, 14) * 2.0
		var z := -11.0 + posmod(id * 3 + i * 5, 12) * 2.0
		_add_stamp(Vector3(x, 0.04, z), ["迟交", "患病", "被辞退", "无用？"][i % 4], false)
		_add_stamp(Vector3(-15.6 if i % 2 == 0 else 15.6, 1.5, z), "撤销", true)
	if bills_done.size() == 5:
		call_deferred("_start_boss")

func _original_bills() -> void:
	var text := "[可核对 · 桌面原件]\n"
	for bill in BILLS:
		text += bill[0] + "：" + bill[1] + "\n\n"
	hud.call("dialog", "账目没有改变", text, ["返回房间"], [Callable()])

func _start_boss() -> void:
	stamper = StaticBody3D.new()
	stamper.set_script(STAMPER)
	stamper.position = _at(Vector2(768, 565 if combat_only else 590))
	stamper.connect("defeated", _victory)
	stamper.connect("phase_changed", _boss_phase_changed)
	world.add_child(stamper)
	for i in range(14):
		var mark := _add_stamp(Vector3(-13 + i * 2, 4.5, -8), "撤销", false)
		mark.rotation_degrees.x = 180
	if combat_only: return
	hud.call("dialog", "盖章者 · 错误的因果合并", "“迟交”“患病”“被辞退”和“无用”被压成了同一个结论。\n\n躲开矩形红框的延迟落印；落印后攻击印章柄，拆开外壳。\n纸墙沿直线推进，可以用攻击撕开。", ["进入战斗"], [Callable()])

func _boss_phase_changed(_phase: int) -> void:
	_time_to_shrink = 4.0
	_draw_danger_edges()
	if combat_only: return
	hud.call("dialog", "纸芯与铁丝黑雾", "外壳被拆开了。账页开始从四边向内收拢。\n红色方格区域会造成伤害；留在内部，用攻击撕开移动纸墙，继续攻击纸芯。", ["继续战斗"], [Callable()])

func warning_rect(at: Vector3, size: Vector2, delay: float = 1.05) -> MeshInstance3D:
	var stamp := _box("FallingStamp", Vector3(size.x * 0.82, 0.5, size.y * 0.82), at + Vector3.UP * 6.0, Color(0.36, 0.08, 0.09))
	var handle := _box("StampHandle", Vector3(0.7, 2.0, 0.7), Vector3(0, 1.0, 0), Color(0.25, 0.19, 0.16), false, stamp)
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fall := create_tween()
	fall.tween_property(stamp, "position:y", 2.8, maxf(0.1, delay - 0.15))
	fall.tween_property(stamp, "position:y", 0.3, 0.15)
	fall.tween_callback(stamp.queue_free)
	return _box("StampWarning", Vector3(size.x, 0.055, size.y), at + Vector3.UP * 0.06, Color(0.95, 0.12, 0.13, 0.65))

func stamp_impact(at: Vector3, size: Vector2) -> void:
	if won:
		return
	var impact := _box("StampImpact", Vector3(size.x, 0.18, size.y), at + Vector3.UP * 0.12, Color(0.95, 0.25, 0.16, 0.9))
	var shape := Rect2(Vector2(at.x, at.z) - size * 0.5, size)
	if shape.has_point(Vector2(player.position.x, player.position.z)):
		player.apply_hit(18.0)
	_add_stamp(at + Vector3.UP * 0.04, "无用？", false)
	var tween := create_tween()
	tween.tween_property(impact, "scale:y", 0.01, 0.35)
	tween.tween_callback(impact.queue_free)

func send_paper_wall(step: int) -> void:
	if won:
		return
	# Separate segments share the same visible and collision rectangles; every segment tears.
	var horizontal := step % 2 == 0
	for i in range(5):
		var paper := StaticBody3D.new()
		paper.set_script(PAPER)
		paper.set("moving", true)
		paper.set("extent", Vector3(4.0, 2.1, 0.5) if horizontal else Vector3(0.5, 2.1, 4.0))
		paper.set("travel", Vector3(0, 0, 3.5) if horizontal else Vector3(4, 0, 0))
		paper.position = Vector3(-10 + i * 4, 1.05, -11) if horizontal else Vector3(-13, 1.05, -8 + i * 4)
		world.add_child(paper)

func _draw_danger_edges() -> void:
	for node in _danger_edges:
		if is_instance_valid(node):
			node.queue_free()
	_danger_edges.clear()
	var x := _arena_limit.x
	var z := _arena_limit.y
	for side in [-1.0, 1.0]:
		_danger_edges.append(_box("ClosingPagesX", Vector3(_half.x - x, 0.07, _half.y * 2), Vector3(side * (_half.x + x) * 0.5, 0.07, 0), Color(0.7, 0.08, 0.10, 0.72)))
		_danger_edges.append(_box("ClosingPagesZ", Vector3(x * 2, 0.07, _half.y - z), Vector3(0, 0.07, side * (_half.y + z) * 0.5), Color(0.7, 0.08, 0.10, 0.72)))

func _victory() -> void:
	won = true
	skills.call("clear_effects")
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.causal_record_obtained = true
	for child in world.get_children():
		if child.get_script() == PAPER:
			child.queue_free()
	if combat_only:
		hud.call("dialog", "清场完成", "连续击败五波敌人与盖章者。\n\n" + (rogue.summary() if rogue != null else "练习结束"), ["再来一局", "返回标题"], [Callable(hud, "restart"), Callable(hud, "to_menu")])
		return
	var body := "病情确实影响了工作功能，沟通与支持的缺失、公司的选择和经济压力也共同塑造了后果。\n\n失业不能被直接盖成“我没有价值”。\n\n获得【因果记录卡】\n功能困难 ≠ 环境选择 ≠ 个人价值\n\n办公室资料：%d / 6；账单原件：5 / 5（可在调查记录回看）。" % records.size()
	hud.call("dialog", "因果记录卡 · 被撤销的不是我", body, ["留在房间回看记录", "重新调查", "返回标题"], [Callable(), Callable(hud, "restart"), Callable(hud, "to_menu")])

func reset_practice() -> void:
	skills.call("clear_effects")
	skills.call("reset_cooldowns")
	for target in get_tree().get_nodes_in_group("card_targets"):
		if world.is_ancestor_of(target):
			target.queue_free()
	_interactions.clear()
	player.health = player.max_health
	player.position = _at(Vector2(770, 640))
	_last_player_position = player.position
	for i in range(5):
		var enemy := CharacterBody3D.new()
		enemy.set_script(ECHO)
		enemy.set("max_health", 180.0 if i == 4 else 60.0)
		enemy.set("move_speed", 0.8)
		enemy.position = _at(Vector2(540 + i * 105, 490))
		world.add_child(enemy)
	var paper := StaticBody3D.new()
	paper.set_script(PAPER)
	paper.position = _at(Vector2(1070, 650)) + Vector3.UP
	paper.set("extent", Vector3(2.5, 2.0, 0.4))
	world.add_child(paper)

func _desk(at: Vector3, monitor: bool) -> void:
	_box("Desk", Vector3(3.4, 0.2, 1.5), at + Vector3.UP * 0.9, Color(0.48, 0.44, 0.35), true)
	for side in [-1.0, 1.0]:
		_box("DeskLeg", Vector3(0.15, 0.9, 1.2), at + Vector3(side * 1.4, 0.4, 0), Color(0.2, 0.24, 0.26))
	if monitor:
		_box("Monitor", Vector3(1, 0.65, 0.12), at + Vector3(0, 1.3, -0.3), Color(0.09, 0.17, 0.19))

func _add_interaction(caption: String, at: Vector3, action: Callable, stable: bool = true) -> void:
	var marker := Node3D.new()
	marker.position = at
	world.add_child(marker)
	_interactions.append({"node": marker, "hint": caption, "action": action})
	var color := Color(0.56, 0.88, 0.88) if stable else Color(0.85, 0.51, 0.42)
	var border := _box("EvidenceBorder", Vector3(0.9, 0.035, 0.9), at + Vector3.UP * 0.02, color)
	_box("EvidenceInset", Vector3(0.77, 0.04, 0.77), at + Vector3.UP * 0.03, Color(0.08, 0.14, 0.17))
	_sign(caption + " [E]", at + Vector3.UP * 0.65, color, 24)
	if not stable:
		border.set_meta("origin", border.position)
		_subjective.append(border)

func _add_stamp(at: Vector3, caption: String, wall_stamp: bool) -> Node3D:
	var stamp := Node3D.new()
	stamp.position = at
	world.add_child(stamp)
	var red := Color(0.62, 0.06, 0.09, 0.62)
	for side in [-1.0, 1.0]:
		_box("StampLine", Vector3(1.7, 0.02, 0.10), Vector3(0, 0, side * 0.8), red, false, stamp)
		_box("StampLine", Vector3(0.10, 0.02, 1.7), Vector3(side * 0.8, 0, 0), red, false, stamp)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 40
	label.pixel_size = 0.012
	label.modulate = red
	label.rotation_degrees.x = -90
	label.position.y = 0.03
	stamp.add_child(label)
	if wall_stamp:
		stamp.rotation_degrees.z = 90
	return stamp

func _sign(value: String, at: Vector3, color: Color, font_size: int = 36) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = 0.014
	label.position = at
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	world.add_child(label)
	return label

func _box(node_name: String, size: Vector3, at: Vector3, color: Color, solid: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	mesh.position = at
	var target := parent if parent != null else world
	target.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.position = at
		body.add_child(collision)
		target.add_child(body)
	return mesh


func stage_spawn(enemy: Node3D, delay: float) -> void:
	enemy.hide()
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	await get_tree().create_timer(delay + 0.05, false).timeout
	if not is_instance_valid(enemy) or enemy._dead or won: return
	var marks: Array[Node] = []
	for side in [-1.0, 1.0]:
		marks.append(_box("SpawnFrame", Vector3(1.2, 0.04, 0.045), enemy.position + Vector3(0, 0.07, side * 0.6), Color(1, 0.57, 0.08)))
		marks.append(_box("SpawnFrame", Vector3(0.045, 0.04, 1.2), enemy.position + Vector3(side * 0.6, 0.07, 0), Color(1, 0.57, 0.08)))
	await get_tree().create_timer(0.65, false).timeout
	for mark in marks:
		if is_instance_valid(mark): mark.queue_free()
	if not is_instance_valid(enemy) or enemy._dead or won: return
	enemy.show()
	enemy.collision_layer = 2
	enemy.set_physics_process(true)
