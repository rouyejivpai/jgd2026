class_name BattleController
extends Node
## 战斗控制器（01 §7）：阶段机、倍速、重置、校验、事件分发。
## 部署阶段也持有一个按当前部署构建的 SimWorld（不推进），供表现层显示初始局面。

signal world_rebuilt()   ## world 被丢弃并重建（部署变化 / 开始 / 重置）→ 表现层重建视图
signal ticked()          ## 一个物理 tick 推进完毕（1× 一步、2× 两步）→ 表现层更新插值端点
signal boss_phase_paused(next_phase: int)   ## 多阶段 Boss 到达切换阈值：战斗已暂停，等玩家重新编程 / 增援后「继续」

var level: LevelDefinition = null
var world: SimWorld = null
var phase: int = SimTypes.Phase.DEPLOY
var speed: int = 1
## 07 §4.2：己方单位以 uid 为键。fixed 关 uid = 槽位 id（每个槽位常驻，可未部署）；free 关 uid = u1、u2…（部署阶段分配、递增不复用，
## 收回 = 删除该单位并返还 Cost）。己方模拟 id = ALLY_ID_BASE + 序号（fixed = 槽位序号；free = uid 编号 - 1）。
var placements: Dictionary = {}          ## uid -> Vector2i（已部署）
var slot_rules: Dictionary = {}          ## uid -> Array[RuleDef]
var slot_beacons: Dictionary = {}        ## uid -> Array[{ id: String, cell: Vector2i }]（07 §3.1，按放置顺序）
var unit_forms: Dictionary = {}          ## uid -> 形态 id
var unit_index: Dictionary = {}          ## uid -> 己方序号
var next_uid: int = 1                    ## free 关下一个 uid 编号
var recommended_uids: Dictionary = {}    ## 推荐阵型条目名（recommended.units[].slot）-> 摆放后的 uid（测试/工具用）
var last_problems: Array[Dictionary] = []
var load_problems: Array[Dictionary] = []   ## 读档时发现的失效配置（只提示，不删除）
var persist: bool = false                ## true：退出/结束时写存档、胜利时发放奖励（战斗场景开启；测试保持关闭）
## 多阶段 Boss 换阶段暂停（2026-10-12 评审：保留战局 → 暂停 → 展示新指令 → 重新编程 → 增援 → 恢复）。
## 暂停期间：存活单位可改指令 / 信标（不重建世界、不能挪位置），可在增援区按补费放新单位；「继续」时写入世界并进入下一阶段。
var boss_pending: bool = false
var reinforce_budget: int = 0
var reinforce_max: int = 0
var reinforce_zone: Rect2i = Rect2i()    ## 格矩形（含两端）
var reinforce_uids: Array[String] = []
var _phase1_rules: Dictionary = {}       ## 暂停前的指令 / 信标快照：重开或结束时还原，存档里保留第一阶段的编程
var _phase1_beacons: Dictionary = {}
var _phase1_beacon_packs: int = 0        ## 暂停时已买的信标包（暂停期间多出的包从增援预算里扣）


## saved_raw：存档中该关的配置（07 §4.2）{ "units": [ { uid, form, slot?, pos?, rules, beacons } ], "next_uid": n }；
## 旧版槽位结构（{ slot_id: { pos?, rules } }）同样可读。无存档指令的单位为空指令（07 §2）。
func setup(p_level: LevelDefinition, saved_raw: Dictionary = {}) -> void:
	level = p_level
	_clear_units()
	load_problems.clear()
	var saved: Dictionary = DeploymentValidator.parse_saved_config(level, saved_raw, load_problems)
	if level.is_free():
		next_uid = maxi(1, int(saved_raw.get("next_uid", 1)))
		for uid: String in saved.keys():
			var entry: Dictionary = saved[uid] as Dictionary
			if not entry.has("pos"):
				continue
			_register(uid, str(entry.get("form", "")), int(entry.get("index", unit_index.size())))
			next_uid = maxi(next_uid, _uid_number(uid) + 1)
			_load_entry(uid, entry)
			if not can_place(uid, entry["pos"] as Vector2i):
				_unregister(uid)
	else:
		for i: int in level.slots.size():
			var slot: SlotDef = level.slots[i]
			_register(slot.id, slot.unit_id, i)
			_load_entry(slot.id, saved.get(slot.id, {}) as Dictionary)
	if not saved_raw.is_empty():
		for p: Dictionary in DeploymentValidator.validate(level, saved, GameState.unlocks, DataRegistry.get_units(), DataRegistry.get_commands()):
			var code: String = str(p["code"])
			if code != DeploymentValidator.SLOT_NOT_PLACED and code != DeploymentValidator.TOO_FEW_UNITS and bool(p["blocking"]):
				load_problems.append(p)
	speed = 1
	_rebuild_world()
	_set_phase(SimTypes.Phase.DEPLOY)
	EventBus.level_loaded.emit(level.id)


func _load_entry(uid: String, entry: Dictionary) -> void:
	if entry.has("rules"):                # 无存档指令 = 保留注册时的预填指令（第五阶段）
		var rules: Array[RuleDef] = []
		rules.assign(entry["rules"] as Array)
		slot_rules[uid] = rules
	var beacons: Array[Dictionary] = []
	beacons.assign(entry.get("beacons", []) as Array)
	slot_beacons[uid] = beacons
	if entry.has("pos") and can_place(uid, entry["pos"] as Vector2i):
		placements[uid] = entry["pos"] as Vector2i


func _clear_units() -> void:
	placements.clear()
	slot_rules.clear()
	slot_beacons.clear()
	unit_forms.clear()
	unit_index.clear()
	recommended_uids.clear()
	next_uid = 1


## 第五阶段：新单位预填 commands.json new_unit_rules（攻击组「始终 → 攻击·最近」、移动组「始终 → 沿信标」），取代 07 §2 的空指令
func _register(uid: String, form: String, index: int) -> void:
	unit_forms[uid] = form
	unit_index[uid] = index
	slot_rules[uid] = DataRegistry.get_commands().new_unit_rules()
	var none: Array[Dictionary] = []
	slot_beacons[uid] = none


func _unregister(uid: String) -> void:
	for d: Dictionary in [placements, slot_rules, slot_beacons, unit_forms, unit_index]:
		d.erase(uid)


static func _uid_number(uid: String) -> int:
	return int(uid.substr(1)) if uid.begins_with("u") and uid.substr(1).is_valid_int() else 0


## 当前全部己方 uid（按序号）
func uids() -> Array[String]:
	var out: Array[String] = []
	for uid: Variant in unit_index.keys():
		out.append(str(uid))
	out.sort_custom(func(a: String, b: String) -> bool: return int(unit_index[a]) < int(unit_index[b]))
	return out


func form_of(uid: String) -> String:
	return str(unit_forms.get(uid, ""))


## 单位显示名：fixed 关按槽位（同形态多槽位附序号）；free 关 = 形态名，同形态多名时按序号附 1、2…
func label_of(uid: String) -> String:
	if not level.is_free():
		return RuleText.slot_name(level, uid)
	var form: String = form_of(uid)
	var udef: UnitDefinition = DataRegistry.get_unit(form)
	var base: String = udef.display_name if udef != null else form
	var same: int = 0
	var order: int = 0
	for other: String in uids():
		if form_of(other) == form:
			same += 1
			if other == uid:
				order = same
	return base if same <= 1 else "%s %d" % [base, order]


## 存档结构（07 §4.2）：{ units: [...], next_uid }；fixed 关每个槽位都记录指令与信标（未部署无 pos），free 关只记录已部署单位
func config_to_raw() -> Dictionary:
	var units: Array = []
	for uid: String in uids():
		var rules: Array[RuleDef] = get_rules(uid)
		var entry: Dictionary = { "uid": uid, "form": form_of(uid), "rules": RuleDef.to_array(rules), "beacons": beacons_to_raw(get_beacons(uid)) }
		if not level.is_free():
			entry["slot"] = uid
		if placements.has(uid):
			entry["pos"] = DataReader.cell_to_array(placements[uid] as Vector2i)
		units.append(entry)
	return { "units": units, "next_uid": next_uid }


func save_config() -> void:
	if not persist or level == null:
		return
	SaveManager.set_level_config(level.id, config_to_raw())
	SaveManager.save()


## uid 对应的模拟单位 id；不存在为 -1
func unit_id_of_slot(uid: String) -> int:
	return SimTypes.ALLY_ID_BASE + int(unit_index[uid]) if unit_index.has(uid) else -1


func slot_of_unit(unit_id: int) -> String:
	for uid: Variant in unit_index.keys():
		if SimTypes.ALLY_ID_BASE + int(unit_index[uid]) == unit_id:
			return str(uid)
	return ""


func can_edit_rules(uid: String) -> bool:
	if level == null or not unit_index.has(uid):
		return false
	if boss_pending:
		return _alive_in_world(uid)
	if phase != SimTypes.Phase.DEPLOY:
		return false
	var slot: SlotDef = level.get_slot(uid)
	return slot == null or slot.editable_rules


## SimWorld.from_level / DeploymentValidator 使用的配置（只含已部署单位）：uid -> { form, index, label, pos, rules, beacons }
func build_config() -> Dictionary:
	var config: Dictionary = {}
	for uid: String in uids():
		if not placements.has(uid):
			continue
		config[uid] = { "form": form_of(uid), "index": int(unit_index[uid]), "label": label_of(uid), "pos": placements[uid] as Vector2i,
			"rules": get_rules(uid), "beacons": get_beacons(uid) }
	return config


func slot_at(cell: Vector2i) -> String:
	for uid: String in placements.keys():
		if placements[uid] as Vector2i == cell:
			return uid
	return ""


## 该单位能否放到 cell：部署区内、非障碍/禁放、无初始单位、无其他己方单位
func can_place(uid: String, cell: Vector2i) -> bool:
	if level == null or not unit_index.has(uid):
		return false
	return _cell_free_for(uid, cell)


func _cell_free_for(uid: String, cell: Vector2i) -> bool:
	if not level.is_deploy_cell(cell) or level.is_blocked(cell):
		return false
	for s: SpawnDef in level.initial_units:
		if s.pos == cell:
			return false
	var other: String = slot_at(cell)
	return other == "" or other == uid


func place_unit(uid: String, cell: Vector2i) -> bool:
	if phase != SimTypes.Phase.DEPLOY or not can_place(uid, cell):
		return false
	placements[uid] = cell
	_rebuild_world()
	EventBus.deployment_changed.emit()
	return true


## 收回：fixed 关 = 取消部署（保留指令）；free 关 = 删除该单位（返还 Cost）
func remove_unit(uid: String) -> bool:
	if phase != SimTypes.Phase.DEPLOY or not placements.has(uid):
		return false
	if level.is_free():
		_unregister(uid)
	else:
		placements.erase(uid)
	_rebuild_world()
	EventBus.deployment_changed.emit()
	return true


## 10 §6.1「清空」：一次移除全部已放置的己方单位（含其指令与信标）；fixed 关槽位保留但清空指令与信标。返回移除人数（仅部署阶段）
func clear_units() -> int:
	if phase != SimTypes.Phase.DEPLOY or level == null:
		return 0
	var removed: Array[String] = []
	for uid: String in uids():
		if placements.has(uid):
			removed.append(uid)
	if removed.is_empty():
		return 0
	var ids: Array[int] = []
	for uid: String in removed:
		ids.append(unit_id_of_slot(uid))
		if level.is_free():
			_unregister(uid)
		else:
			placements.erase(uid)
			slot_rules[uid] = DataRegistry.get_commands().new_unit_rules()
			var none: Array[Dictionary] = []
			slot_beacons[uid] = none
	_rebuild_world()
	EventBus.deployment_changed.emit()
	for id: int in ids:
		EventBus.rules_changed.emit(id)
		EventBus.beacons_changed.emit(id)
	return removed.size()


## 10 §4：把 form_or_uid（已有 uid = 移动；形态 id = 新建）放到 cell 的不可放置原因码（DeploymentValidator.place_problem），可放置为 ""
func place_problem(form_or_uid: String, cell: Vector2i) -> String:
	if level == null:
		return DeploymentValidator.FORM_NOT_AVAILABLE
	if boss_pending:
		return _reinforce_problem(form_or_uid, cell)
	return DeploymentValidator.place_problem(level, build_config(), form_or_uid, cell, GameState.unlocks, DataRegistry.get_units(), DataRegistry.get_commands())


# ---- free 关：出场卡、Cost 预算（07 §4）----
## 出场卡形态：available_forms（null = 全部己方形态）∩ 已解锁，按数据顺序
func card_forms() -> Array[String]:
	var out: Array[String] = []
	if level == null or not level.is_free():
		return out
	var pool: Array[String] = []
	if level.has_available_forms:
		pool = level.available_forms.duplicate()
	else:
		for f: String in DataRegistry.get_units().keys():
			if (DataRegistry.get_unit(f) as UnitDefinition).is_ally_form():
				pool.append(f)
	for f: String in pool:
		if GameState.is_unlocked("forms", f):
			out.append(f)
	return out


func cost_of(form: String) -> int:
	var udef: UnitDefinition = DataRegistry.get_unit(form)
	return udef.cost if udef != null else 0


## 10 §5.5：已用 = Σ 已部署单位的（形态 Cost + 指令 Cost）+ 信标包 Cost
func budget_used() -> int:
	var total: int = 0
	if level != null and level.is_free():
		for uid: String in placements.keys():
			if not reinforce_uids.has(uid):           # Boss 换阶段增援另有预算（reinforce_cost）
				total += cost_of(form_of(uid)) + command_cost(uid)
		total += beacon_packs_cost()
	return total


# ---- 信标购买（roster.beacon_cost / beacon_bundle）：全场共用一个池，放置时按需自动买包、删到用不着时自动退包 ----
## 已部署单位的信标总数
func beacon_total() -> int:
	var n: int = 0
	for uid: String in placements.keys():
		n += (slot_beacons.get(uid, []) as Array).size()
	return n


## 当前已买的信标包数（Boss 暂停期间为第一阶段买下的包数，多出的包算在增援预算里）
func beacon_packs() -> int:
	if level == null:
		return 0
	return _phase1_beacon_packs if boss_pending else level.beacon_packs(beacon_total())


func beacon_packs_cost() -> int:
	return beacon_packs() * level.beacon_cost if level != null else 0


## 池容量 = 已买包数 × 每包个数（暂停期间含增援预算买的包）
func beacon_stock() -> int:
	if level == null or not level.beacons_priced():
		return 0
	return maxi(level.beacon_packs(beacon_total()), beacon_packs()) * level.beacon_bundle


## 暂停期间超出第一阶段包数的信标包 Cost
func _reinforce_beacon_cost() -> int:
	if not boss_pending or level == null:
		return 0
	return maxi(level.beacon_packs(beacon_total()) - _phase1_beacon_packs, 0) * level.beacon_cost


## 再放一个信标是否要新买一包
func beacon_needs_pack() -> bool:
	return level != null and level.beacons_priced() and beacon_total() >= beacon_stock()


## 再放一个信标的 Cost 是否付得起（不需新包时恒为 true）
func can_afford_beacon() -> bool:
	if not beacon_needs_pack():
		return true
	if boss_pending:
		return reinforce_cost() + level.beacon_cost <= reinforce_budget
	return budget_used() + level.beacon_cost <= level.roster_budget


## 该单位的指令 Cost（Σ 每条 action.cost + Σ condition.cost，data/commands.json）
func command_cost(uid: String) -> int:
	return DataRegistry.get_commands().rules_cost(get_rules(uid))


## 能否再放一名该形态：可用、未超人数上限、预算足够（仅部署阶段）
func can_add_form(form: String) -> bool:
	if boss_pending:
		return card_forms().has(form) and reinforce_uids.size() < reinforce_max and reinforce_cost() + cost_of(form) <= reinforce_budget
	return phase == SimTypes.Phase.DEPLOY and card_forms().has(form) and placements.size() < level.max_units \
		and budget_used() + cost_of(form) <= level.roster_budget


## free 关：新单位能否放到 cell（部署区、非障碍/初始单位、无其他己方单位）
func can_place_new(cell: Vector2i) -> bool:
	return level != null and _cell_free_for("", cell)


## free 关放置一名新单位；返回新 uid，失败返回 ""
func add_unit(form: String, cell: Vector2i) -> String:
	if boss_pending:
		return _add_reinforcement(form, cell)
	if level == null or not level.is_free() or not can_add_form(form) or not _cell_free_for("", cell):
		return ""
	var uid: String = "u%d" % next_uid
	next_uid += 1
	_register(uid, form, _uid_number(uid) - 1)
	placements[uid] = cell
	_rebuild_world()
	EventBus.deployment_changed.emit()
	return uid


func set_rules(uid: String, rules: Array[RuleDef]) -> bool:
	if not can_edit_rules(uid):
		return false
	slot_rules[uid] = RuleDef.clone_array(rules)
	if not boss_pending:
		_rebuild_world()
	EventBus.rules_changed.emit(unit_id_of_slot(uid))
	return true


func get_rules(uid: String) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	out.assign(slot_rules.get(uid, []) as Array)
	return out


## 推荐阵型条目名 → uid（fixed 关即槽位 id）
func recommended_uid(entry_name: String) -> String:
	return str(recommended_uids.get(entry_name, entry_name))


## 10 §5.2：玩家指令不再有"停用"状态（勾选框已删）。推荐阵型数据中 enabled: false 的条目（第 2、6、7 关）摆放时略去——
## 评估器本来就跳过停用规则，略去后决策完全相同（Q-059），只是不再在面板上显示一条永不执行、又无法启用的指令。
static func enabled_only(rules: Array[RuleDef]) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for r: RuleDef in rules:
		if r.enabled:
			out.append(r.clone())
	return out


## 「推荐阵型」（07 §2）：用关卡 recommended.units 覆盖当前部署、指令与信标（fixed 关未列出的槽位收回并清空指令；
## free 关清空全部单位后按 form 依次放置，uid 从 u1 重新分配），预算按 roster 扣减，然后校验一次（结果存于 last_problems）。仅部署阶段可用。
func apply_recommended() -> bool:
	if boss_pending:
		return apply_recommended_phase2()
	if phase != SimTypes.Phase.DEPLOY or level == null:
		return false
	if level.is_free():
		_clear_units()
		for ru: RecommendedUnitDef in level.recommended_units:
			var uid: String = "u%d" % next_uid
			next_uid += 1
			_register(uid, ru.form, _uid_number(uid) - 1)
			_apply_recommended_entry(uid, ru)
			if not placements.has(uid):
				_unregister(uid)
	else:
		placements.clear()
		recommended_uids.clear()
		for slot: SlotDef in level.slots:
			slot_rules[slot.id] = [] as Array[RuleDef]
			var none: Array[Dictionary] = []
			slot_beacons[slot.id] = none
		for ru: RecommendedUnitDef in level.recommended_units:
			if ru.slot_id != "" and unit_index.has(ru.slot_id):
				_apply_recommended_entry(ru.slot_id, ru)
	_rebuild_world()
	last_problems = DeploymentValidator.validate(level, build_config(), GameState.unlocks, DataRegistry.get_units(), DataRegistry.get_commands())
	EventBus.deployment_changed.emit()
	for uid: String in uids():
		EventBus.rules_changed.emit(unit_id_of_slot(uid))
		EventBus.beacons_changed.emit(unit_id_of_slot(uid))
	return true


func _apply_recommended_entry(uid: String, ru: RecommendedUnitDef) -> void:
	recommended_uids[ru.slot_id if ru.slot_id != "" else uid] = uid
	slot_rules[uid] = enabled_only(ru.rules)
	var bs: Array[Dictionary] = []
	for b: Dictionary in ru.beacons:
		bs.append({ "id": str(b["id"]), "cell": b["cell"] as Vector2i })
	slot_beacons[uid] = bs
	if can_place(uid, ru.pos):
		placements[uid] = ru.pos


# ---- 个人信标（07 §3.1，仅部署阶段）----
func get_beacons(slot_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in slot_beacons.get(slot_id, []) as Array:
		out.append({ "id": str(b["id"]), "cell": b["cell"] as Vector2i })
	return out


func can_edit_beacons(uid: String) -> bool:
	if boss_pending:
		return level != null and unit_index.has(uid) and _alive_in_world(uid)
	return level != null and unit_index.has(uid) and phase == SimTypes.Phase.DEPLOY


## 信标能否放在 cell：网格内的可行走格（含部署区外），且不与本单位已有信标重叠
func can_place_beacon(slot_id: String, cell: Vector2i, ignore_id: String = "") -> bool:
	if not can_edit_beacons(slot_id) or not level.in_bounds(cell) or level.is_blocked(cell):
		return false
	for b: Dictionary in get_beacons(slot_id):
		if b["cell"] as Vector2i == cell and str(b["id"]) != ignore_id:
			return false
	return true


## 10 §6.3：下一个编号 = 现有最大编号 + 1（删除后不重排、不复用）；已达防呆上限 BEACON_SOFT_CAP 则为 ""
func next_beacon_id(slot_id: String) -> String:
	var beacons: Array[Dictionary] = get_beacons(slot_id)
	if beacons.size() >= SimTypes.BEACON_SOFT_CAP:
		return ""
	var top: int = 0
	for b: Dictionary in beacons:
		top = maxi(top, int(str(b["id"])) if SimTypes.is_beacon_id(str(b["id"])) else 0)
	return str(top + 1)


## 追加信标（需要时自动买一包）；返回新编号，失败返回 ""（含预算不够买新包）
func add_beacon(slot_id: String, cell: Vector2i) -> String:
	var id: String = next_beacon_id(slot_id)
	if id == "" or not can_place_beacon(slot_id, cell) or not can_afford_beacon():
		return ""
	var beacons: Array[Dictionary] = get_beacons(slot_id)
	beacons.append({ "id": id, "cell": cell })
	_set_beacons(slot_id, beacons)
	return id


## 删除信标（编号不重排；引用它的条件/行为由校验报 BEACON_MISSING）
func remove_beacon(slot_id: String, beacon_id: String) -> bool:
	if not can_edit_beacons(slot_id):
		return false
	var beacons: Array[Dictionary] = get_beacons(slot_id)
	for i: int in beacons.size():
		if str(beacons[i]["id"]) == beacon_id:
			beacons.remove_at(i)
			_set_beacons(slot_id, beacons)
			return true
	return false


func move_beacon(slot_id: String, beacon_id: String, cell: Vector2i) -> bool:
	if not can_place_beacon(slot_id, cell, beacon_id):
		return false
	var beacons: Array[Dictionary] = get_beacons(slot_id)
	for b: Dictionary in beacons:
		if str(b["id"]) == beacon_id:
			b["cell"] = cell
			_set_beacons(slot_id, beacons)
			return true
	return false


## 第四阶段：已部署单位的编号（1 起，按 uid 序号）——数字键进入信标模式、地图上的编号牌
func deployed_uids() -> Array[String]:
	var out: Array[String] = []
	for uid: String in uids():
		if placements.has(uid):
			out.append(uid)
	return out


## 该单位「沿我的信标」指令的移动方式（取第一条；没有为 -1）
func beacon_follow_mode(uid: String) -> int:
	for r: RuleDef in get_rules(uid):
		if r.action != null and r.action.type == SimTypes.ActionType.FOLLOW_BEACONS:
			return r.action.mode
	return -1


## 第四阶段信标边栏：把该单位全部「沿我的信标」指令的方式改为 mode；没有这类指令时在末尾追加「始终 → 沿我的信标（从第一个信标起）」
func set_beacon_follow_mode(uid: String, mode: int) -> bool:
	if not can_edit_rules(uid):
		return false
	var rules: Array[RuleDef] = RuleDef.clone_array(get_rules(uid))
	var found: bool = false
	for r: RuleDef in rules:
		if r.action != null and r.action.type == SimTypes.ActionType.FOLLOW_BEACONS:
			r.action.mode = mode
			found = true
	if not found:
		var bs: Array[Dictionary] = get_beacons(uid)
		var from: String = str(bs[0]["id"]) if not bs.is_empty() else "1"
		rules.append(RuleDef.from_dict({ "conditions": [], "action": { "type": "follow_beacons", "mode": SimTypes.beacon_mode_to_string(mode), "from": from } }, "beacon_mode"))
	return set_rules(uid, rules)


## 单位面板"复制预设路线为我的信标"：用路线路点替换该单位的信标，编号从 1 起（最多 BEACON_SOFT_CAP 个）
func copy_route_to_beacons(slot_id: String, route_id: String) -> bool:
	var route: RouteDef = level.get_route(route_id) if level != null else null
	if route == null or not can_edit_beacons(slot_id):
		return false
	var beacons: Array[Dictionary] = []
	for p: Vector2i in route.points:
		if beacons.size() >= SimTypes.BEACON_SOFT_CAP:
			break
		beacons.append({ "id": str(beacons.size() + 1), "cell": p })
	_set_beacons(slot_id, beacons)
	return true


## 信标 → 存档结构 [{ id, cell: [x, y] }]
static func beacons_to_raw(beacons: Array[Dictionary]) -> Array:
	var out: Array = []
	for b: Dictionary in beacons:
		out.append({ "id": str(b["id"]), "cell": DataReader.cell_to_array(b["cell"] as Vector2i) })
	return out


func _set_beacons(slot_id: String, beacons: Array[Dictionary]) -> void:
	slot_beacons[slot_id] = beacons
	if not boss_pending:
		_rebuild_world()      # 部署阶段修改信标 → 游标随世界重建而重置（07 §3.2）
	EventBus.beacons_changed.emit(unit_id_of_slot(slot_id))


## 校验 → 重建世界 → RUNNING。校验有阻塞问题时返回 false 并发 validation_failed。
func start() -> bool:
	if phase != SimTypes.Phase.DEPLOY:
		return false
	last_problems = DeploymentValidator.validate(level, build_config(), GameState.unlocks, DataRegistry.get_units(), DataRegistry.get_commands())
	if DeploymentValidator.has_blocking(last_problems):
		EventBus.validation_failed.emit(last_problems)
		return false
	_rebuild_world()
	if persist and GameState.setting_bool("sim_log"):
		DebugLog.begin(level.id)
	_set_phase(SimTypes.Phase.RUNNING)
	return true


func pause() -> void:
	if phase == SimTypes.Phase.RUNNING:
		_set_phase(SimTypes.Phase.PAUSED)


func resume() -> void:
	if phase == SimTypes.Phase.PAUSED:
		if boss_pending:
			_finish_boss_pause()
		_set_phase(SimTypes.Phase.RUNNING)


func set_speed(multiplier: int) -> void:
	var m: int = 2 if multiplier >= 2 else 1
	if m == speed:
		return
	speed = m
	EventBus.battle_speed_changed.emit(speed)


## 丢弃旧世界、按关卡与当前配置重建，回到部署阶段（01 §6.11）
func reset() -> void:
	if level == null:
		return
	DebugLog.end("reset")
	_clear_boss_state()
	_rebuild_world()
	_set_phase(SimTypes.Phase.DEPLOY)


## 保存配置到存档 → 返回选关
func exit() -> void:
	DebugLog.end("exit")
	_clear_boss_state()
	save_config()
	SceneRouter.goto_level_select()


func _exit_tree() -> void:
	DebugLog.end("closed")


func _physics_process(_delta: float) -> void:
	if phase == SimTypes.Phase.RUNNING:
		advance_tick()


## 推进一个物理 tick：speed 次 step()，逐条转发事件；出结果则进入 ENDED
func advance_tick() -> void:
	if phase != SimTypes.Phase.RUNNING or world == null:
		return
	for i: int in speed:
		world.step()
		for e: Dictionary in world.take_events():
			DebugLog.write_event(e)
			EventBus.sim_event.emit(e)
		if world.result != SimTypes.BattleResult.NONE:
			break
	ticked.emit()
	if world.phase_pending and not boss_pending and world.result == SimTypes.BattleResult.NONE:
		_enter_boss_pause()
		return
	if world.result != SimTypes.BattleResult.NONE:
		_finish_battle()


func _finish_battle() -> void:
	_clear_boss_state()
	_set_phase(SimTypes.Phase.ENDED)
	DebugLog.end(str(SimTypes.BattleResult.keys()[world.result]).to_lower())
	if world.result == SimTypes.BattleResult.LOSE:
		GameState.record_fail(level.id)
	save_config()
	if world.result == SimTypes.BattleResult.WIN and persist:
		SaveManager.complete_level(level.id, level.rewards)
		EventBus.level_completed.emit(level.id, level.rewards)
	EventBus.battle_ended.emit(world.result, SimTypes.ReasonCode.OK)


func _rebuild_world() -> void:
	world = SimWorld.from_level(level, DataRegistry.get_units(), DataRegistry.get_traits(), build_config())
	world_rebuilt.emit()


func _set_phase(p: int) -> void:
	phase = p
	EventBus.battle_phase_changed.emit(phase)



# ---- 多阶段 Boss：换阶段暂停（重新编程 / 增援）----
func _alive_in_world(uid: String) -> bool:
	if world == null or not placements.has(uid):
		return false
	var u: SimUnit = world.get_unit(unit_id_of_slot(uid))
	return u != null and u.alive


func _enter_boss_pause() -> void:
	boss_pending = true
	var rf: Dictionary = BossSystem.next_reinforce(world)
	reinforce_budget = int(rf.get("budget", 0))
	reinforce_max = int(rf.get("max_units", 0))
	var z: Array = rf.get("zone", []) as Array
	reinforce_zone = Rect2i(int(z[0]), int(z[1]), int(z[2]) - int(z[0]) + 1, int(z[3]) - int(z[1]) + 1) if z.size() == 4 else Rect2i()
	reinforce_uids.clear()
	_phase1_rules = slot_rules.duplicate()
	_phase1_beacons = slot_beacons.duplicate()
	_phase1_beacon_packs = level.beacon_packs(beacon_total())
	_set_phase(SimTypes.Phase.PAUSED)
	boss_phase_paused.emit(world.phase + 1)


func reinforce_cost() -> int:
	var total: int = _reinforce_beacon_cost()
	for uid: String in reinforce_uids:
		total += cost_of(form_of(uid))
	return total


func reinforce_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(reinforce_zone.position.y, reinforce_zone.end.y):
		for x: int in range(reinforce_zone.position.x, reinforce_zone.end.x):
			out.append(Vector2i(x, y))
	return out


func _reinforce_problem(form: String, cell: Vector2i) -> String:
	if unit_index.has(form):
		return DeploymentValidator.OUT_OF_ZONE      # 暂停时不能挪动已有单位
	if not card_forms().has(form):
		return DeploymentValidator.FORM_NOT_AVAILABLE
	if reinforce_uids.size() >= reinforce_max:
		return DeploymentValidator.ROSTER_FULL
	if reinforce_cost() + cost_of(form) > reinforce_budget:
		return DeploymentValidator.BUDGET_EXCEEDED
	if not reinforce_zone.has_point(cell):
		return DeploymentValidator.OUT_OF_ZONE
	if level.is_blocked(cell):
		return DeploymentValidator.CELL_BLOCKED
	for u: SimUnit in world.units:
		if u.alive and u.cell() == cell:
			return DeploymentValidator.CELL_OCCUPIED
	return ""


## 增援：立即放进当前世界（暂停中，不推进），指令为空，等玩家编辑；「继续」时与其他单位一起写入指令
func _add_reinforcement(form: String, cell: Vector2i) -> String:
	if world == null or _reinforce_problem(form, cell) != "":
		return ""
	var uid: String = "u%d" % next_uid
	next_uid += 1
	_register(uid, form, _uid_number(uid) - 1)
	placements[uid] = cell
	reinforce_uids.append(uid)
	var u: SimUnit = SimUnit.create(DataRegistry.get_unit(form), SimTypes.Faction.ALLY, SimTypes.cell_center(cell), [] as Array[RuleDef])
	u.dual_rules = true
	u.id = unit_id_of_slot(uid)
	u.spawn_id = uid
	u.display_name = label_of(uid)
	ModifierDef.apply_all(u, level.modifiers)
	world.add_unit(u)
	EventBus.deployment_changed.emit()
	return uid


func _rules_from(arr: Array) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for d: Variant in arr:
		out.append(RuleDef.from_dict(d as Dictionary, "recommended.phase2"))
	return level.player_rules(out)


## 暂停时的「推荐」：按关卡 recommended.phase2 重新编程存活单位并放置增援
func apply_recommended_phase2() -> bool:
	if not boss_pending or level == null:
		return false
	var p2: Dictionary = level.recommended_phase2
	var rules_map: Dictionary = p2.get("rules", {}) as Dictionary
	for entry: String in rules_map.keys():
		var uid: String = recommended_uid(entry)
		if _alive_in_world(uid):
			slot_rules[uid] = _rules_from(rules_map[entry] as Array)
			EventBus.rules_changed.emit(unit_id_of_slot(uid))
	for raw: Variant in p2.get("reinforcements", []) as Array:
		var r: Dictionary = raw as Dictionary
		var pos: Array = r.get("pos", [0, 0]) as Array
		var uid: String = _add_reinforcement(str(r.get("form", "")), Vector2i(int(pos[0]), int(pos[1])))
		if uid == "":
			continue
		recommended_uids[str(r.get("slot", uid))] = uid
		slot_rules[uid] = _rules_from(r.get("rules", []) as Array)
		var bs: Array[Dictionary] = []
		for b: Variant in r.get("beacons", []) as Array:
			var bd: Dictionary = b as Dictionary
			var c: Array = bd["cell"] as Array
			bs.append({ "id": str(bd["id"]), "cell": Vector2i(int(c[0]), int(c[1])) })
		slot_beacons[uid] = bs
		EventBus.rules_changed.emit(unit_id_of_slot(uid))
		EventBus.beacons_changed.emit(unit_id_of_slot(uid))
	return true


## 「继续」：把暂停期间的指令 / 信标写进存活单位（游标重置），进入下一阶段
func _finish_boss_pause() -> void:
	for uid: String in uids():
		if not _alive_in_world(uid):
			continue
		var u: SimUnit = world.get_unit(unit_id_of_slot(uid))
		u.rules = RuleDef.clone_array(get_rules(uid))
		u.wait_state = {}
		u.beacons.clear()
		for b: Dictionary in get_beacons(uid):
			u.beacons.append({ "id": str(b["id"]), "cell": b["cell"] as Vector2i })
		u.beacon_index = -1
		u.beacon_rejoin = Vector2i(-1, -1)
		u.path.clear()
	BossSystem.begin_next_phase(world)
	boss_pending = false


## 重开 / 结束 / 退出：删掉增援，还原第一阶段的指令（存档只保存第一阶段的编程）
func _clear_boss_state() -> void:
	for uid: String in reinforce_uids:
		_unregister(uid)
	reinforce_uids.clear()
	for uid: Variant in _phase1_rules.keys():
		if unit_index.has(uid):
			slot_rules[uid] = _phase1_rules[uid]
			slot_beacons[uid] = _phase1_beacons.get(uid, [] as Array[Dictionary])
	_phase1_rules.clear()
	_phase1_beacons.clear()
	_phase1_beacon_packs = 0
	boss_pending = false
