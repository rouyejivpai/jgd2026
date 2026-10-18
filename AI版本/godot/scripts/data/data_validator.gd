class_name DataValidator
extends RefCounted
## 加载期交叉校验 D02–D06（02 §7），语义与 tools/validate_data.py 一致。
## 单字段/枚举（D01）、建筑（D07）、爆炸参数（D08）在各数据类 from_dict 中检查。


## units: id -> UnitDefinition；traits: id -> TraitDefinition
static func validate_units(units: Dictionary, traits: Dictionary) -> void:
	for uid: String in units.keys():
		var u: UnitDefinition = units[uid] as UnitDefinition
		var ctx: String = "units.json:%s" % uid
		for trait_id: String in u.traits:
			if not traits.has(trait_id):
				DataReader.report(ctx, "trait '%s' 不存在 (D02)" % trait_id)
		for i: int in u.default_rules.size():
			_check_rule_action(u.default_rules[i], u, "%s.default_rules[%d]" % [ctx, i])


## level_ids：全部关卡 id（第三阶段删除 presets.json 后，rewards.unlock_presets 只是解锁键，可追溯性改由 commands.json 一侧校验，10 §5.1）
static func validate_level(L: LevelDefinition, units: Dictionary, level_ids: Array[String]) -> void:
	var ctx: String = "%s.json" % L.id
	var grid := SimGrid.new(L.width, L.height, L.blocked)

	# D03：障碍与部署区
	for c: Vector2i in L.blocked:
		if not L.in_bounds(c):
			DataReader.report(ctx, "blocked %s 越界 (D03)" % c)
	for c: Vector2i in L.deploy_cells:
		if not L.in_bounds(c):
			DataReader.report(ctx, "部署格 %s 越界 (D03)" % c)
		if L.is_blocked(c):
			DataReader.report(ctx, "部署格 %s 与障碍重叠 (D03)" % c)

	# 路线：D03 路点在网格内且不在障碍上；D04 相邻路点可达
	for rid: String in L.routes.keys():
		var r: RouteDef = L.routes[rid] as RouteDef
		for p: Vector2i in r.points:
			if not L.in_bounds(p) or L.is_blocked(p):
				DataReader.report(ctx, "路线 %s 路点 %s 越界或在障碍上 (D03)" % [rid, p])
		for i: int in range(r.points.size() - 1):
			var a: Vector2i = r.points[i]
			var b: Vector2i = r.points[i + 1]
			if L.in_bounds(a) and L.in_bounds(b) and grid.find_path(a, b).is_empty():
				DataReader.report(ctx, "路线 %s 路点 %s->%s 不可达 (D04)" % [rid, a, b])

	# 出场（07 §4.1）：fixed 槽位形态存在；free 的 available_forms 为存在且有 cost 的己方形态
	for s: SlotDef in L.slots:
		if not units.has(s.unit_id):
			DataReader.report(ctx, "槽位 %s 的 unit '%s' 不存在 (D02)" % [s.id, s.unit_id])
	for f: String in L.available_forms:
		var fd: UnitDefinition = units.get(f, null) as UnitDefinition
		if fd == null or not fd.is_ally_form():
			DataReader.report(ctx, "roster.available_forms '%s' 不是己方形态 (D02)" % f)

	# 初始单位
	var spawn_ids: Array[String] = []
	for su: SpawnDef in L.initial_units:
		if spawn_ids.has(su.id):
			DataReader.report(ctx, "initial_units id '%s' 重复" % su.id)
		spawn_ids.append(su.id)
		if not units.has(su.unit_id):
			DataReader.report(ctx, "initial_units %s 的 unit '%s' 不存在 (D02)" % [su.id, su.unit_id])
			continue
		if not L.in_bounds(su.pos) or L.is_blocked(su.pos):
			DataReader.report(ctx, "initial_units %s 位置 %s 越界或在障碍上 (D03)" % [su.id, su.pos])
		if su.faction == SimTypes.Faction.ENEMY and L.is_deploy_cell(su.pos):
			DataReader.report(ctx, "敌方初始单位 %s 位于部署区内 (D03)" % su.id)
		var udef: UnitDefinition = units[su.unit_id] as UnitDefinition
		var rules: Array[RuleDef] = su.rules if su.has_rules else udef.default_rules
		for i: int in rules.size():
			var rctx: String = "%s:initial_units.%s.rules[%d]" % [ctx, su.id, i]
			if su.has_rules:
				_check_rule_action(rules[i], udef, rctx)
			_check_rule_route(rules[i], L, rctx)

	# 07 §7 静态加成：引用的 spawn / 形态存在
	for m: ModifierDef in L.modifiers:
		if m.target_kind == "spawn" and not spawn_ids.has(m.target_value):
			DataReader.report(ctx, "modifiers 引用了不存在的单位 '%s' (D02)" % m.target_value)
		if m.target_kind == "form" and not units.has(m.target_value):
			DataReader.report(ctx, "modifiers 引用了不存在的形态 '%s' (D02)" % m.target_value)

	# 07 §9 护送：被护送者是己方可移动单位，且失败条件含其 unit_dead
	for o: ObjectiveDef in L.win:
		if o.type != SimTypes.ObjectiveType.ESCORT:
			continue
		var es: SpawnDef = L.get_spawn(o.target)
		if es == null:
			continue
		var eud: UnitDefinition = units.get(es.unit_id, null) as UnitDefinition
		if es.faction != SimTypes.Faction.ALLY or (eud != null and eud.kind != SimTypes.UnitKind.UNIT):
			DataReader.report(ctx, "escort 目标 %s 必须是己方可移动单位（kind: unit、faction: ally）" % o.target)
		var has_dead: bool = false
		for lo: ObjectiveDef in L.lose:
			has_dead = has_dead or (lo.type == SimTypes.ObjectiveType.UNIT_DEAD and lo.target == o.target)
		if not has_dead:
			DataReader.report(ctx, "escort 关卡需要失败条件 unit_dead 指向 %s（护送对象死亡即失败）" % o.target)

	# 目标引用（D02）与 reach_zone 坐标（D03）
	for o: ObjectiveDef in L.win + L.lose:
		for t: String in o.referenced_ids():
			if not spawn_ids.has(t):
				DataReader.report(ctx, "目标条件 %s 引用了不存在的单位 '%s' (D02)" % [o.id, t])
		for c: Vector2i in o.cells:
			if not L.in_bounds(c):
				DataReader.report(ctx, "reach_zone 格 %s 越界 (D03)" % c)

	# D05：提示与失败反馈
	if L.hints.size() != 4:
		DataReader.report(ctx, "hints 必须恰好 4 条 (D05)")
	if not L.fail_feedback.has("default"):
		DataReader.report(ctx, "fail_feedback.default 缺失 (D05)")
	for o: ObjectiveDef in L.lose:
		if not L.fail_feedback.has(o.id):
			DataReader.report(ctx, "fail_feedback 缺少 lose 条目 '%s' 的文本 (D05)" % o.id)

	# D04：推荐阵型（07 §2）：槽位存在且形态一致、位置在部署区内不重叠、推荐指令可用于该形态、路线存在、信标在可行走格
	var rec_cells: Array[Vector2i] = []
	var rec_slots: Array[String] = []
	for ru: RecommendedUnitDef in L.recommended_units:
		var key: String = ru.slot_id if ru.slot_id != "" else ru.form
		var form: String = ru.form
		if L.is_free():
			if form == "":
				DataReader.report(ctx, "free 模式的 recommended.units 条目需要 form")
				continue
			if L.has_available_forms and not L.available_forms.has(form):
				DataReader.report(ctx, "recommended.units %s 的形态 '%s' 不在 available_forms 中" % [key, form])
		elif ru.slot_id != "":
			var slot: SlotDef = L.get_slot(ru.slot_id)
			if slot == null:
				DataReader.report(ctx, "recommended.units 槽位 '%s' 不存在" % ru.slot_id)
				continue
			if rec_slots.has(ru.slot_id):
				DataReader.report(ctx, "recommended.units 槽位 '%s' 重复" % ru.slot_id)
			rec_slots.append(ru.slot_id)
			if form != "" and form != slot.unit_id:
				DataReader.report(ctx, "recommended.units %s 的 form '%s' 与槽位形态 '%s' 不一致" % [ru.slot_id, form, slot.unit_id])
			form = slot.unit_id
		if not L.is_deploy_cell(ru.pos):
			DataReader.report(ctx, "recommended.units %s %s 不在部署区 (D04)" % [key, ru.pos])
		if rec_cells.has(ru.pos):
			DataReader.report(ctx, "recommended.units 存在重叠格 %s" % ru.pos)
		rec_cells.append(ru.pos)
		var udef: UnitDefinition = units.get(form, null) as UnitDefinition
		if udef == null:
			DataReader.report(ctx, "recommended.units %s 的形态 '%s' 不存在 (D02)" % [key, form])
			continue
		var rec_beacon_ids: Array[String] = []
		for b: Dictionary in ru.beacons:
			rec_beacon_ids.append(str(b["id"]))
		for i: int in ru.rules.size():
			var rctx: String = "%s:recommended.%s.rules[%d]" % [ctx, key, i]
			_check_rule_action(ru.rules[i], udef, rctx)
			_check_rule_route(ru.rules[i], L, rctx)
			var bp: Array[Dictionary] = []
			DeploymentValidator.check_beacon_refs(ru.rules[i], i + 1, key, rec_beacon_ids, bp)
			for p: Dictionary in bp:
				DataReader.report(rctx, "推荐指令引用的信标不存在或没有信标（%s %s）" % [str(p["code"]), str(p["what"])])
		for b: Dictionary in ru.beacons:
			var bc: Vector2i = b["cell"] as Vector2i
			if not L.in_bounds(bc) or L.is_blocked(bc):
				DataReader.report(ctx, "recommended.units %s 信标 %s %s 越界或在障碍上 (D03)" % [key, str(b["id"]), bc])

	# 07 §4 / P3：推荐阵型在预算与人数上限内可放下（free 模式）
	if L.is_free():
		var total: int = 0
		var beacon_n: int = 0
		for ru: RecommendedUnitDef in L.recommended_units:
			var ud: UnitDefinition = units.get(ru.form, null) as UnitDefinition
			total += ud.cost if ud != null else 0
			beacon_n += ru.beacons.size()
		total += L.beacon_packs(beacon_n) * L.beacon_cost          # 信标包
		if total > L.roster_budget:
			DataReader.report(ctx, "推荐阵型 Cost %d 超出预算 %d" % [total, L.roster_budget])
		if L.recommended_units.size() > L.max_units or L.recommended_units.size() < L.min_units:
			DataReader.report(ctx, "推荐阵型人数 %d 不在 [%d, %d] 内" % [L.recommended_units.size(), L.min_units, L.max_units])

	# D06：奖励引用
	var next_level: String = str(L.rewards.get("unlock_level", ""))
	if next_level != "" and not level_ids.has(next_level):
		DataReader.report(ctx, "rewards.unlock_level '%s' 不存在 (D06)" % next_level)
	for f: String in DataReader.string_array(DataReader.opt_array(L.rewards, "unlock_forms", ctx), ctx):
		if not units.has(f):
			DataReader.report(ctx, "rewards.unlock_forms '%s' 不存在" % f)
	DataReader.string_array(DataReader.opt_array(L.rewards, "unlock_presets", ctx), ctx)
	# unlock_slots 已删除（Q-010，02 文档 1.1）；出场数量由 roster 预算决定
	for key: String in ["unlock_forms", "unlock_presets", "unlock_conditions", "unlock_selectors", "unlock_actions"]:
		DataReader.require(L.rewards, key, ctx + ".rewards")


## D06：index 1..N 不重复
static func validate_level_indices(levels: Array[LevelDefinition]) -> void:
	var seen: Dictionary = {}
	for L: LevelDefinition in levels:
		if seen.has(L.index):
			DataReader.report("%s.json" % L.id, "index %d 与 %s 重复 (D06)" % [L.index, seen[L.index]])
		seen[L.index] = L.id


static func _check_rule_action(rule: RuleDef, udef: UnitDefinition, ctx: String) -> void:
	if rule.action != null and rule.action.type >= 0 and DeploymentValidator.action_gated(rule.action.type) and not udef.allowed_actions.has(rule.action.type):
		DataReader.report(ctx, "行为 %s 不在形态 %s 的 allowed_actions 中" % [SimTypes.action_to_string(rule.action.type), udef.id])


static func _check_rule_route(rule: RuleDef, L: LevelDefinition, ctx: String) -> void:
	if rule.action != null and rule.action.type == SimTypes.ActionType.FOLLOW_ROUTE and not L.routes.has(rule.action.route_id):
		DataReader.report(ctx, "follow_route.route_id '%s' 不存在于本关 routes (D02)" % rule.action.route_id)
