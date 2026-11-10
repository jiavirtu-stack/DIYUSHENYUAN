extends Node

const RELICS := [
	["旧工牌", "技能伤害提高18%"], ["迟到的回执", "技能伤害提高35%，冷却延长20%"],
	["轻装鞋", "移动速度提高15%"], ["破损铃舌", "闪避冷却缩短25%"],
	["厚封皮", "生命上限增加25，并恢复25生命"], ["便携药盒", "每次战斗获胜恢复8生命"],
	["备用电池", "所有技能冷却缩短15%"], ["补给袋", "立即恢复15生命，此后每次战斗额外恢复5生命"]
]
const MUTATIONS := [
	["分叉电稿：光波变为三束，每束造成65%伤害", "复核雷击：满蓄力后0.5秒沿原线再打一次，伤害60%"],
	["散落信笺：主爆炸周围额外产生三个小爆炸", "长明余烬：火区半径增加35%，持续时间增加2秒"],
	["连续归档：沿施法方向展开三个较小冰阵", "脆裂冰页：冻结普通怪被技能击败时释放伤害冰环"],
	["五魂追猎：骷髅由三枚增加至五枚，每枚伤害降为8", "幽魂蓄势：骷髅等待超过1秒后，命中伤害增加50%"],
	["游走回廊：旋风向施法方向缓慢移动", "强压终章：结束风压伤害翻倍，击退距离增加"]
]
var room: Node
var enabled := [false, false, false, false, false]
var mutations := [-1, -1, -1, -1, -1]
var relics: Array[int] = []
var damage_scale := 1.0
var cooldown_scale := 1.0
var coins := 0
var depth := 0
var in_combat := false
var remaining := 0
var route_ready := false
var picks: Array = []
var history: Array[String] = []
var rng := RandomNumberGenerator.new()
var route_depth := -1
var route_options: Array = []
var settled := false
var pending_reward := false

func _ready() -> void:
	room = get_parent()
	rng.randomize()

func start() -> void:
	if enabled.has(true):
		return
	var pool := [0, 1, 3]
	_shuffle(pool)
	var labels: Array = []
	var callbacks: Array = []
	for id in pool:
		labels.append(room.skills.TITLES[id] + " · CD %d秒 · " % room.skills.COOLDOWNS[id] + ["瞄准直线贯穿，可蓄力", "抛射爆炸，留下持续火区", "冰阵控制", "三枚暗影骷髅追踪附近敌人", "旋风聚怪"][id])
		callbacks.append(_take_start.bind(id))
	show_choice("选好技能，立即开战", "第一波32只敌人从四面接近，连续五波后挑战Boss。\nWASD移动，左键快速砍击，中键按住瞄准、松开释放技能。\n每波结束三选一，选完自动进入下一波。" if room.combat_only else "选技能后迎战第一波，战后探索街道支路。", labels, callbacks)

func _take_start(id: int) -> void:
	if enabled.has(true): return
	enabled[id] = true
	room.hud._selected = id
	room.player.set_selected_card(id)
	history.append("起始：" + room.skills.TITLES[id])
	room._start_wave()

func show_choice(heading: String, body: String, labels: Array, callbacks: Array) -> void:
	room.hud.dialog(heading, body, labels, callbacks)
	room.hud.choice_required = true

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap

func office_reward() -> void:
	depth = 1
	award_combat(false)

func award_combat(elite: bool) -> void:
	if not room.combat_only:
		coins += (30 if elite else 15)
	if relics.has(7): heal(5)
	if relics.has(5):
		heal(8)
	pending_reward = true
	call_deferred("reward", elite)

func reward(elite: bool = false) -> void:
	if room.won or room.player.health <= 0 or not pending_reward:
		return
	var pool: Array = []
	for i in range(5):
		if not enabled[i]:
			pool.append({"kind":"skill", "id":i, "label":"获得技能 · " + room.skills.TITLES[i]})
		elif mutations[i] < 0:
			for branch in range(2):
				pool.append({"kind":"mutation", "id":i, "branch":branch, "label":room.skills.TITLES[i] + " / " + MUTATIONS[i][branch]})
	for i in range(8):
		if not relics.has(i) and relics.size() < 4:
			pool.append({"kind":"relic", "id":i, "label":"遗物 · " + RELICS[i][0] + "：" + RELICS[i][1]})
	_shuffle(pool)
	picks = []
	# Offer a meaningful build change and an unlock whenever both remain available.
	for kind in ["mutation", "skill"]:
		for item in pool:
			if item.kind == kind:
				picks.append(item)
				break
	for item in pool:
		if picks.size() >= 3: break
		if not picks.has(item): picks.append(item)
	_shuffle(picks)
	if picks.is_empty():
		picks = [{"kind":"heal", "id":0, "label":"恢复25生命"}, {"kind":"power", "id":0, "label":"全部技能伤害提高8%"}, {"kind":"haste", "id":0, "label":"全部技能冷却缩短8%"}]
	var labels: Array = []
	var callbacks: Array = []
	for item in picks:
		labels.append(item.label)
		callbacks.append(take_reward.bind(item))
	show_choice("战后收获 · 三选一", "遗物 %d / 4 · 选择后继续战斗\n精英波额外提供遗物选择，技能与强化本局保留。" % relics.size(), labels, callbacks)
	set_meta("elite_reward", elite)

func take_reward(item: Dictionary) -> void:
	if not pending_reward or not picks.has(item):
		return
	pending_reward = false
	match str(item.kind):
		"skill": enabled[item.id] = true
		"mutation": mutations[item.id] = item.branch
		"relic": take_relic(item.id)
		"heal": heal(25)
		"coin": coins += 30
		"power": damage_scale += 0.08
		"haste": cooldown_scale *= 0.92
	history.append(item.label)
	if bool(get_meta("elite_reward", false)) and relics.size() < 4:
		set_meta("elite_reward", false)
		call_deferred("relic_reward")
	elif room.combat_only:
		room.queue_next_battle()
	elif room.stage == 1:
		route_ready = true

func relic_reward() -> void:
	var pool: Array = []
	for i in range(8):
		if not relics.has(i): pool.append(i)
	_shuffle(pool)
	var labels: Array = []
	var callbacks: Array = []
	for i in pool.slice(0, 3):
		labels.append(RELICS[i][0] + "：" + RELICS[i][1])
		callbacks.append(_finish_relic.bind(i))
	show_choice("精英遗物 · 三选一", "高风险的额外回报。", labels, callbacks)

func _finish_relic(id: int) -> void:
	take_relic(id)
	if room.combat_only:
		room.queue_next_battle()
	else:
		route_ready = true

func take_relic(id: int) -> void:
	if relics.has(id) or relics.size() >= 4: return
	relics.append(id)
	match id:
		0: damage_scale += 0.18
		1:
			damage_scale += 0.35
			cooldown_scale *= 1.2
		2: room.player.move_speed *= 1.15
		3: room.player.dodge_cooldown *= 0.75
		4:
			room.player.max_health += 25
			heal(25)
		6: cooldown_scale *= 0.85
		7: heal(15)
	history.append("遗物：" + RELICS[id][0])

func heal(amount: float) -> void:
	room.player.health = minf(room.player.max_health, room.player.health + amount)

func route() -> void:
	if in_combat or pending_reward:
		return
	if depth >= 5:
		room._enter_apartment_direct()
		return
	var options := ["普通战", "精英战", "事件", "商店", "休息"]
	_shuffle(options)
	# The first branch always includes combat; the second offers a random alternative.
	if route_depth != depth:
		route_depth = depth
		var combat: String = "精英战" if rng.randf() < 0.35 else "普通战"
		route_options = [combat, options[0] if options[0] != combat else options[1]]
	var left: String = route_options[0]
	var right: String = route_options[1]
	show_choice("街道分岔 · 节点 %d / 7" % (depth + 2), "办公室 → 街道入口 → 四个分岔节点 → 出租屋 / 盖章者\n当前零钱 %d，生命 %d / %d\n普通战：15零钱＋强化；精英：30零钱＋强化＋遗物\n商店：20零钱购买遗物；休息：恢复30生命；事件：风险与回报。" % [coins, room.player.health, room.player.max_health], [left, right, "查看本局构筑"], [enter_node.bind(left), enter_node.bind(right), show_build])

func show_build() -> void:
	show_choice("本局构筑", summary(), ["返回选路"], [route])

func summary() -> String:
	var body := ("连续战斗 · 第%d / %d波\n" % [room.battle_wave, room.battle_wave_limit]) if room.combat_only else ("零钱：%d · 已完成支路：%d / 4\n" % [coins, maxi(0, depth - 1)])
	for i in range(5):
		if enabled[i]:
			body += "\n" + room.skills.TITLES[i] + (" · " + MUTATIONS[i][mutations[i]] if mutations[i] >= 0 else " · 未变异")
	body += "\n\n遗物 %d / 4" % relics.size()
	for id in relics:
		body += "\n" + RELICS[id][0] + "：" + RELICS[id][1]
	return body

func enter_node(kind: String) -> void:
	if in_combat or depth >= 5: return
	depth += 1
	history.append("支路：" + kind)
	match kind:
		"普通战", "精英战": _fight(kind == "精英战")
		"休息":
			heal(30)
			show_choice("雨棚下的喘息", "恢复30生命，已完成本节点。", ["继续探索"], [route])
		"商店": shop()
		"事件":
			show_choice("路边的遗失包裹", "可以保守地拿取10零钱，或用15生命换取一件随机遗物。生命不足时不能交易。", ["拿取10零钱", "付出15生命换遗物", "离开"], [_event.bind(false), _event.bind(true), route])

func _event(risk: bool) -> void:
	if risk and (room.player.health <= 15 or relics.size() >= 4):
		show_choice("无法交换", "需要生命大于15，且遗物栏尚有空位。", ["继续探索"], [route])
		return
	if risk:
		room.player.health -= 15
		var pool: Array = []
		for id in range(8):
			if not relics.has(id): pool.append(id)
		take_relic(pool[rng.randi_range(0, pool.size() - 1)])
	else: coins += 10
	route()

func shop() -> void:
	var labels: Array = []
	var callbacks: Array = []
	var pool: Array = []
	for id in range(8):
		if not relics.has(id): pool.append(id)
	_shuffle(pool)
	for id in pool.slice(0, 2):
		labels.append("20零钱 · " + RELICS[id][0] + "：" + RELICS[id][1])
		callbacks.append(buy.bind(id))
	labels.append("离开商店")
	callbacks.append(route)
	show_choice("夜间小摊", "零钱 %d · 每个商店最多购买一件。" % coins, labels, callbacks)

func buy(id: int) -> void:
	if coins < 20 or relics.size() >= 4:
		show_choice("无法购买", "零钱不足20或遗物已满。", ["离开商店"], [route])
		return
	coins -= 20
	take_relic(id)
	route()

func _fight(elite: bool) -> void:
	in_combat = true
	settled = false
	set_meta("elite", elite)
	room._load_stage(1)
	remaining = rng.randi_range(4, 6) + (1 if elite else 0)
	var spawn := [Vector2(760, 400), Vector2(765, 570), Vector2(610, 550), Vector2(960, 550), Vector2(760, 290), Vector2(450, 550), Vector2(1130, 550)]
	_shuffle(spawn)
	for i in range(remaining):
		var enemy := CharacterBody3D.new()
		enemy.set_script(room.ECHO)
		var strong := elite and i < 2
		enemy.set("max_health", 90.0 if strong else rng.randf_range(32, 45))
		enemy.set("attack_damage", 13.0 if strong else 8.0)
		enemy.set("move_speed", rng.randf_range(1.4, 2.1))
		enemy.position = room._at(spawn[i])
		enemy.defeated.connect(_defeated)
		room.world.add_child(enemy)
	room.hud.dialog("精英支路" if elite else "街道遭遇", "清除全部残影，才能继续前往下个节点。\n战后选择强化，已有技能与遗物本局保留。", ["开始战斗"], [Callable()])

func _defeated(_target: Node) -> void:
	remaining -= 1
	if remaining > 0 or settled: return
	settled = true
	in_combat = false
	award_combat(bool(get_meta("elite", false)))
