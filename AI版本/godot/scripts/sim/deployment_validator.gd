class_name DeploymentValidator
extends RefCounted
## 开始前的部署校验（01 §6.11、02 §7 V01–V07）与存档配置校验（01 §10）。
## 问题条目：{ code, slot, index（1 起，规则相关时）, what（枚举字符串）, blocking }。
## code 与 strings.json["validation"] 的键一致，文案由 UI 拼接。

const SLOT_NOT_PLACED: String = "SLOT_NOT_PLACED"
const OUT_OF_ZONE: String = "OUT_OF_ZONE"
const CELL_OCCUPIED: String = "CELL_OCCUPIED"
const CELL_BLOCKED: String = "CELL_BLOCKED"
const RULE_NOT_ALLOWED: String = "RULE_NOT_ALLOWED"
const RULE_LOCKED: String = "RULE_LOCKED"
const ROUTE_MISSING: String = "ROUTE_MISSING"
const EMPTY_RULES: String = "EMPTY_RULES"
const SLOT_UNKNOWN: String = "SLOT_UNKNOWN"
const RULE_INVALID: String = "RULE_INVALID"
const BEACON_MISSING: String = "BEACON_MISSING"         ## 07 §3.6：指令引用的信标不存在
const BEACON_ON_BLOCKED: String = "BEACON_ON_BLOCKED"   ## 信标在障碍格或地图外
const BEACONS_EMPTY: String = "BEACONS_EMPTY"           ## follow_beacons 但没有任何信标
const BUDGET_EXCEEDED: String = "BUDGET_EXCEEDED"       ## 07 §4.1：出场 Cost 超出预算（what = 已用/预算）
const TOO_FEW_UNITS: String = "TOO_FEW_UNITS"           ## 出场人数 < min_units（what = 下限）
const FORM_NOT_AVAILABLE: String = "FORM_NOT_AVAILABLE" ## 形态不在本关 available_forms 或未解锁（what = 形态 id）
const SAVE_MIGRATION_FAILED: String = "SAVE_MIGRATION_FAILED"  ## 存档 v1→v2 迁移有条目无法转换（原数据保留在 legacy_v1）
const ROSTER_FULL: String = "ROSTER_FULL"               ## 10 §4：放置时出场人数已满（仅 place_problem 使用）


## 07 §3 的个人信标 / 到点 / 等待是每个单位都有的通用工具，不受关卡 allowed、解锁与形态 allowed_actions 限制（Q-047）
static func condition_gated(t: int) -> bool:
	return t != SimTypes.ConditionType.AT_BEACON


static func action_gated(t: int) -> bool:
	return t != SimTypes.ActionType.FOLLOW_BEACONS and t != SimTypes.ActionType.WAIT


## config: slot_id -> { "pos": Vector2i（可选，缺省 = 未部署）, "rules": Array[RuleDef]（可选）, "unit": String（可选）,
##                      "beacons": Array[{ id, cell: Vector2i }]（可选）}
## unlocks: { "conditions": [..], "selectors": [..], "actions": [..] }（JSON 字符串）
## commands：指令目录（10 §5.5 指令 Cost 计入预算）；null = 指令 Cost 按 0 计
static func validate(level: LevelDefinition, config: Dictionary, unlocks: Dictionary, unit_defs: Dictionary, commands: CommandCatalog = null) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	var occupied: Dictionary = {}
	if level.is_free():
		_validate_free(level, config, unlocks, unit_defs, problems, occupied, commands)
		return problems
	for sid: String in config.keys():
		if level.get_slot(sid) == null:
			problems.append(_problem(SLOT_UNKNOWN, sid))
	for slot: SlotDef in level.slots:
		if not config.has(slot.id):
			problems.append(_problem(SLOT_NOT_PLACED, slot.id))
			continue
		var entry: Dictionary = config[slot.id] as Dictionary
		if not entry.has("pos"):
			problems.append(_problem(SLOT_NOT_PLACED, slot.id))   # 存档中只保存了指令、尚未部署
		var udef: UnitDefinition = unit_defs.get(str(entry.get("form", entry.get("unit", slot.unit_id))), null) as UnitDefinition
		_validate_unit(level, slot.id, entry, unlocks, udef, problems, occupied)
	return problems


## 07 §4.1 free 模式：人数下限、Cost 预算（10 §5.5：形态 Cost + 指令 Cost）、形态可用（available_forms ∩ 已解锁），
## 以及逐单位的格子/指令/信标检查。未部署（无 pos）的条目不算出场。
static func _validate_free(level: LevelDefinition, config: Dictionary, unlocks: Dictionary, unit_defs: Dictionary, problems: Array[Dictionary], occupied: Dictionary, commands: CommandCatalog) -> void:
	var placed: int = 0
	var total: int = 0
	var unlocked_forms: Array = unlocks.get("forms", []) as Array
	for uid: String in config.keys():
		var entry: Dictionary = config[uid] as Dictionary
		if not entry.has("pos"):
			continue
		placed += 1
		var form: String = str(entry.get("form", entry.get("unit", level.legacy_form(uid))))
		var udef: UnitDefinition = unit_defs.get(form, null) as UnitDefinition
		total += unit_cost(entry, unit_defs, commands, form)
		if udef == null or not udef.is_ally_form() or (level.has_available_forms and not level.available_forms.has(form)) or not unlocked_forms.has(form):
			problems.append(_named(_problem(FORM_NOT_AVAILABLE, uid, 0, form), entry))
		_validate_unit(level, uid, entry, unlocks, udef, problems, occupied)
	if placed < level.min_units:
		problems.append(_problem(TOO_FEW_UNITS, "", 0, str(level.min_units)))
	if total > level.roster_budget:
		problems.append(_problem(BUDGET_EXCEEDED, "", 0, "%d/%d" % [total, level.roster_budget]))


## 10 §4 不可放置原因（UI 只显示、不自行判断）：把 form_or_uid 放到 cell 时的第一个问题码，可放置为 ""。
## form_or_uid 为 config 中已有的 uid（或 fixed 关的槽位 id）时视为移动该单位；否则视为 free 关按形态新建一名。
## 原因 ∈ FORM_NOT_AVAILABLE / ROSTER_FULL / BUDGET_EXCEEDED（与格子无关，先判）→ OUT_OF_ZONE / CELL_BLOCKED / CELL_OCCUPIED。
## config：uid -> { form, pos, rules… }（只含已部署单位，同 validate）；unlocks.forms 为已解锁形态。
static func place_problem(level: LevelDefinition, config: Dictionary, form_or_uid: String, cell: Vector2i, unlocks: Dictionary, unit_defs: Dictionary, commands: CommandCatalog = null) -> String:
	var existing: bool = config.has(form_or_uid) or (not level.is_free() and level.get_slot(form_or_uid) != null)
	if not existing:
		var udef: UnitDefinition = unit_defs.get(form_or_uid, null) as UnitDefinition
		if not level.is_free() or udef == null or not udef.is_ally_form() or (level.has_available_forms and not level.available_forms.has(form_or_uid)) \
				or not (unlocks.get("forms", []) as Array).has(form_or_uid):
			return FORM_NOT_AVAILABLE
		var placed: int = 0
		for uid: String in config.keys():
			if (config[uid] as Dictionary).has("pos"):
				placed += 1
		if placed >= level.max_units:
			return ROSTER_FULL
		if total_cost(config, unit_defs, commands) + maxi(udef.cost, 0) > level.roster_budget:   # 新单位指令为空（07 §2）
			return BUDGET_EXCEEDED
	if level.is_blocked(cell):
		return CELL_BLOCKED
	if _spawn_at(level, cell):
		return CELL_OCCUPIED
	for uid: String in config.keys():
		var entry: Dictionary = config[uid] as Dictionary
		if uid != form_or_uid and entry.has("pos") and (entry["pos"] as Vector2i) == cell:
			return CELL_OCCUPIED
	if not level.is_deploy_cell(cell):
		return OUT_OF_ZONE
	return ""


## 已部署单位的出场 Cost 合计（10 §5.5：每名 = 形态 cost + 指令 Cost）
static func total_cost(config: Dictionary, unit_defs: Dictionary, commands: CommandCatalog = null) -> int:
	var total: int = 0
	for uid: String in config.keys():
		var entry: Dictionary = config[uid] as Dictionary
		if entry.has("pos"):
			total += unit_cost(entry, unit_defs, commands, str(entry.get("form", entry.get("unit", ""))))
	return total


## 单位总 Cost = 形态 cost + 指令 Cost（Σ 每条 action.cost + Σ condition.cost；commands 为 null 时指令按 0）
static func unit_cost(entry: Dictionary, unit_defs: Dictionary, commands: CommandCatalog, form: String) -> int:
	var udef: UnitDefinition = unit_defs.get(form, null) as UnitDefinition
	var total: int = maxi(udef.cost, 0) if udef != null else 0
	if commands != null:
		total += commands.rules_cost(entry.get("rules", []) as Array)
	return total


## 单个己方单位：格子（障碍/禁放/部署区/重叠）、空指令提醒、指令可用性、信标
static func _validate_unit(level: LevelDefinition, uid: String, entry: Dictionary, unlocks: Dictionary, udef: UnitDefinition, problems: Array[Dictionary], occupied: Dictionary) -> void:
	var before: int = problems.size()
	if entry.has("pos"):
		var pos: Vector2i = entry["pos"] as Vector2i
		if level.is_blocked(pos) or level.deploy_excluded.has(pos) or _spawn_at(level, pos):
			problems.append(_problem(CELL_BLOCKED, uid))
		elif not level.is_deploy_cell(pos):
			problems.append(_problem(OUT_OF_ZONE, uid))
		if occupied.has(pos):
			problems.append(_problem(CELL_OCCUPIED, uid))
		occupied[pos] = uid
	var rules: Array[RuleDef] = []   # 未给指令 = 空指令（07 §2）
	if entry.has("rules"):
		for r: RuleDef in entry["rules"] as Array:
			rules.append(r)
	if rules.is_empty():
		problems.append(_problem(EMPTY_RULES, uid, 0, "", false))
	var beacons: Array = entry.get("beacons", []) as Array
	var beacon_ids: Array[String] = []
	for b: Dictionary in beacons:
		beacon_ids.append(str(b["id"]))
		var bc: Vector2i = b["cell"] as Vector2i
		if not level.in_bounds(bc) or level.is_blocked(bc):
			problems.append(_problem(BEACON_ON_BLOCKED, uid, 0, str(b["id"])))
	for i: int in rules.size():
		check_rule(rules[i], i + 1, uid, level, unlocks, udef, problems)
		check_beacon_refs(rules[i], i + 1, uid, beacon_ids, problems)
	for k: int in range(before, problems.size()):
		_named(problems[k], entry)


## 条目带显示名时写入问题（UI 用于 free 关的 u1/u2 等 uid）
static func _named(p: Dictionary, entry: Dictionary) -> Dictionary:
	if entry.has("label"):
		p["name"] = str(entry["label"])
	return p


## 07 §3.6：删除信标后引用它的条件/行为在校验中被指出（不静默改指）
static func check_beacon_refs(rule: RuleDef, index: int, slot_id: String, beacon_ids: Array[String], problems: Array[Dictionary]) -> void:
	if not rule.enabled:
		return
	for c: ConditionDef in rule.conditions:
		if c.type == SimTypes.ConditionType.AT_BEACON and not beacon_ids.has(c.beacon):
			problems.append(_problem(BEACON_MISSING, slot_id, index, c.beacon))
	if rule.action != null and rule.action.type == SimTypes.ActionType.FOLLOW_BEACONS:
		if beacon_ids.is_empty():
			problems.append(_problem(BEACONS_EMPTY, slot_id, index))
		elif not beacon_ids.has(rule.action.from):
			problems.append(_problem(BEACON_MISSING, slot_id, index, rule.action.from))


## 规则是否引用了本关禁止 / 未解锁 / 形态不可用的条件、选敌、行为，或缺少路线
static func check_rule(rule: RuleDef, index: int, slot_id: String, level: LevelDefinition, unlocks: Dictionary, udef: UnitDefinition, problems: Array[Dictionary]) -> void:
	var unlocked_conditions: Array = unlocks.get("conditions", []) as Array
	var unlocked_selectors: Array = unlocks.get("selectors", []) as Array
	var unlocked_actions: Array = unlocks.get("actions", []) as Array
	for c: ConditionDef in rule.conditions:
		var name_c: String = SimTypes.condition_to_string(c.type)
		if not condition_gated(c.type):
			continue
		if not level.allowed_conditions.has(c.type):
			problems.append(_problem(RULE_NOT_ALLOWED, slot_id, index, name_c))
		elif not unlocked_conditions.has(name_c):
			problems.append(_problem(RULE_LOCKED, slot_id, index, name_c))
	if rule.target != null:
		var name_s: String = SimTypes.selector_to_string(rule.target.selector)
		if not level.allowed_selectors.has(rule.target.selector):
			problems.append(_problem(RULE_NOT_ALLOWED, slot_id, index, name_s))
		elif not unlocked_selectors.has(name_s):
			problems.append(_problem(RULE_LOCKED, slot_id, index, name_s))
	if rule.action != null and action_gated(rule.action.type):
		var name_a: String = SimTypes.action_to_string(rule.action.type)
		if not level.allowed_actions.has(rule.action.type) or (udef != null and not udef.allowed_actions.has(rule.action.type)):
			problems.append(_problem(RULE_NOT_ALLOWED, slot_id, index, name_a))
		elif not unlocked_actions.has(name_a):
			problems.append(_problem(RULE_LOCKED, slot_id, index, name_a))
		if rule.action.type == SimTypes.ActionType.FOLLOW_ROUTE and not level.routes.has(rule.action.route_id):
			problems.append(_problem(ROUTE_MISSING, slot_id, index, rule.action.route_id))


## 解析存档中某关的配置为 validate() 可用的 config：uid -> { form, index, pos?, rules, beacons, slot? }。
## v2（07 §4.2）：{ "units": [ { uid, form, slot?, pos?, rules, beacons } ], "next_uid": n }；
## 旧版槽位结构 { slot_id: { pos?, rules, beacons? } } 也接受（形态与序号由关卡槽位 / recommended 条目名推出）。
## 无法解析的规则被跳过，并在 problems 中记为 RULE_INVALID；不修改原始存档数据。
static func parse_saved_config(level: LevelDefinition, raw: Dictionary, problems: Array[Dictionary]) -> Dictionary:
	var config: Dictionary = {}
	var was_silent: bool = DataReader.silent
	DataReader.silent = true
	if raw.has("units"):
		var list: Array = raw["units"] as Array if raw["units"] is Array else []
		for i: int in list.size():
			var entry_raw: Dictionary = list[i] as Dictionary if list[i] is Dictionary else {}
			var uid: String = str(entry_raw.get("uid", entry_raw.get("slot", "")))
			if uid == "":
				continue
			var entry: Dictionary = _parse_entry(uid, entry_raw, problems)
			entry["form"] = str(entry_raw.get("form", level.legacy_form(uid)))
			var num: int = int(uid.substr(1)) if uid.begins_with("u") and uid.substr(1).is_valid_int() else 0
			entry["index"] = level.legacy_index(uid) if level.get_slot(uid) != null else (num - 1 if num > 0 else i)
			config[uid] = entry
	else:
		for sid: String in raw.keys():
			var entry_raw: Dictionary = raw[sid] as Dictionary if raw[sid] is Dictionary else {}
			var entry: Dictionary = _parse_entry(sid, entry_raw, problems)
			entry["form"] = str(entry_raw.get("unit", level.legacy_form(sid)))
			entry["index"] = level.legacy_index(sid)
			config[sid] = entry
	DataReader.silent = was_silent
	return config


static func _parse_entry(uid: String, entry_raw: Dictionary, problems: Array[Dictionary]) -> Dictionary:
	var entry: Dictionary = {}
	if entry_raw.has("pos"):
		entry["pos"] = DataReader.cell(entry_raw["pos"], "save:%s.pos" % uid)
	if entry_raw.has("beacons"):
		entry["beacons"] = parse_beacons(entry_raw["beacons"], "save:%s.beacons" % uid)
	if entry_raw.has("rules"):
		var rules: Array[RuleDef] = []
		var arr: Array = entry_raw["rules"] as Array if entry_raw["rules"] is Array else []
		for i: int in arr.size():
			var rb: int = DataReader.error_count
			var r: RuleDef = RuleDef.from_dict(arr[i] as Dictionary if arr[i] is Dictionary else {}, "save:%s.rules[%d]" % [uid, i])
			if DataReader.error_count > rb:
				problems.append(_problem(RULE_INVALID, uid, i + 1))
			else:
				r.enabled = true      # 10 §5.2：玩家配置不再有启用开关，旧存档的 enabled: false 视为 true，下次保存写回
				rules.append(r)
		entry["rules"] = rules
	return entry


## 存档 v1 → v2（07 §4.2）：旧的 { slot_id: {...} } 转为 { units: [...], next_uid }。
## fixed 关 uid = 槽位 id（未部署的槽位保留指令）；free 关按旧槽位顺序给已部署者分配 u1、u2…，形态由槽位名推出（slot_<形态>…）。
## 推不出形态或未部署而被丢弃的条目：原样保留在 legacy_v1，并返回 ok = false（存档标记 invalid，不删除）。
static func migrate_v1_config(level: LevelDefinition, raw: Dictionary) -> Dictionary:
	var units: Array = []
	var ok: bool = true
	var n: int = 1
	for sid: String in raw.keys():
		var entry_raw: Dictionary = raw[sid] as Dictionary if raw[sid] is Dictionary else {}
		var form: String = str(entry_raw.get("unit", level.legacy_form(sid)))
		if form == "" and sid.begins_with("slot_"):
			var guess: String = sid.trim_prefix("slot_")
			for f: String in DataRegistry.get_units().keys():
				if guess == f or guess.begins_with(f + "_"):
					form = f
		var e: Dictionary = entry_raw.duplicate(true)
		e.erase("unit")
		e["form"] = form
		if level.is_free():
			if form == "" or not entry_raw.has("pos"):
				ok = false
				continue
			e["uid"] = "u%d" % n
			n += 1
		else:
			if level.get_slot(sid) == null:
				ok = false
				continue
			e["uid"] = sid
			e["slot"] = sid
		units.append(e)
	var out: Dictionary = { "units": units, "next_uid": n }
	if not ok:
		out["legacy_v1"] = raw.duplicate(true)
	return { "config": out, "ok": ok }


## 信标数组（存档 / 关卡 recommended 的原始结构 [{ id, cell: [x, y] }]）→ [{ id, cell: Vector2i }]；无法识别的条目跳过。
## 10 §6.3：id 为数字字符串；旧字母 A–H 映射为 "1"–"8"。
static func parse_beacons(raw: Variant, ctx: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	for item: Variant in raw as Array:
		if not item is Dictionary:
			continue
		var d: Dictionary = item as Dictionary
		var id: String = str(d.get("id", ""))
		if not SimTypes.is_beacon_id(id):
			id = SimTypes.legacy_beacon_id(id)
		if id == "":
			continue
		var cell: Variant = d.get("cell", null)
		out.append({ "id": id, "cell": cell if cell is Vector2i else DataReader.cell(cell, ctx) })
	return out


## 存档配置校验：返回问题列表（为空表示有效）。不删除任何条目（策划已定）。
static func check_saved_config(level: LevelDefinition, raw: Dictionary, unlocks: Dictionary, unit_defs: Dictionary, commands: CommandCatalog = null) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	if raw.has("legacy_v1"):
		problems.append(_problem(SAVE_MIGRATION_FAILED, ""))
	var config: Dictionary = parse_saved_config(level, raw, problems)
	for p: Dictionary in validate(level, config, unlocks, unit_defs, commands):
		var code: String = str(p["code"])
		if code != SLOT_NOT_PLACED and code != TOO_FEW_UNITS and bool(p["blocking"]):
			problems.append(p)
	return problems


static func has_blocking(problems: Array[Dictionary]) -> bool:
	for p: Dictionary in problems:
		if bool(p["blocking"]):
			return true
	return false


static func _spawn_at(level: LevelDefinition, pos: Vector2i) -> bool:
	for s: SpawnDef in level.initial_units:
		if s.pos == pos:
			return true
	return false


static func _problem(code: String, slot_id: String, index: int = 0, what: String = "", blocking: bool = true) -> Dictionary:
	return { "code": code, "slot": slot_id, "index": index, "what": what, "blocking": blocking }
