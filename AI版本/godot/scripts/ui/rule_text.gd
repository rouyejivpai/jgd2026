class_name RuleText
extends RefCounted
## 文案拼装（02 §3 整句规则）：所有词句来自 strings.json，代码只负责拼接。


static func s(key: String) -> String:
	return DataRegistry.get_string(key)


## 数字显示：整数不带小数点
static func num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else "%.1f" % v


static func condition_name(t: int) -> String:
	return s("names.conditions." + SimTypes.condition_to_string(t))


static func selector_name(t: int) -> String:
	return s("names.selectors." + SimTypes.selector_to_string(t))


static func filter_name(t: int) -> String:
	return s("names.filters." + SimTypes.filter_to_string(t))


static func action_name(t: int) -> String:
	return s("names.actions." + SimTypes.action_to_string(t))


## 枚举字符串（校验问题里的 what）→ 短名
static func what_name(what: String) -> String:
	if SimTypes.parse_condition(what) >= 0:
		return s("names.conditions." + what)
	if SimTypes.parse_selector(what) >= 0:
		return s("names.selectors." + what)
	if SimTypes.parse_action(what) >= 0:
		return s("names.actions." + what)
	var udef: UnitDefinition = DataRegistry.get_unit(what) if what != "" else null
	if udef != null:
		return udef.display_name
	return what


static func condition_sentence(c: ConditionDef) -> String:
	var key: String = SimTypes.condition_to_string(c.type)
	var template: String = s("condition_text." + key)
	return template.format({
		"ratio": num(c.ratio * 100.0), "op": c.op, "value": num(c.value),
		"threat_radius": num(c.threat_radius) if c.threat_radius >= 0.0 else "", "beacon": c.beacon,
		"signal": s("names.signals." + c.sig) if c.sig != "" else "",
	})


static func target_word(t: TargetDef) -> String:
	if t == null:
		return ""
	return s("selector_text." + SimTypes.selector_to_string(t.selector)) + s("filter_text." + SimTypes.filter_to_string(t.filter))


static func route_name(route_id: String, level: LevelDefinition) -> String:
	var r: RouteDef = level.get_route(route_id) if level != null else null
	return r.display_name if r != null else s("ui.route_none")


static func action_sentence(a: ActionDef, t: TargetDef, level: LevelDefinition) -> String:
	if a == null:
		return ""
	var template: String = s("action_text." + SimTypes.action_to_string(a.type))
	return template.format({ "target": target_word(t), "route": route_name(a.route_id, level), "from": a.from,
		"mode": beacon_mode_name(a.mode), "seconds": num(a.seconds) })


static func beacon_mode_name(mode: int) -> String:
	return s("names.beacon_modes." + SimTypes.beacon_mode_to_string(mode))


## 整句："{条件}，{行为}"；多条件按 condition_mode 以「且 / 或」连接（10 §5.3）
static func rule_sentence(r: RuleDef, level: LevelDefinition) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: ConditionDef in r.conditions:
		parts.append(condition_sentence(c))
	if parts.is_empty():
		parts.append(s("condition_text.always"))
	var joiner: String = s("ui.sentence_or" if r.condition_mode == SimTypes.ConditionMode.ANY else "ui.sentence_and")
	return s("ui.sentence").format({ "condition": joiner.join(parts), "action": action_sentence(r.action, r.target, level) })


## "{label}：{value}"
static func label_value(label_key: String, value: String) -> String:
	return s("ui.label_value").format({ "label": s(label_key), "value": value })


static func reason_text(code: int) -> String:
	return s("reason." + SimTypes.reason_to_key(code))


## 单位显示名：关卡覆盖名优先；同形态多槽位时附序号
static func unit_name(u: SimUnit, level: LevelDefinition) -> String:
	if u == null:
		return s("ui.none")
	if u.faction == SimTypes.Faction.ALLY and level != null and level.get_slot(u.spawn_id) != null:
		return slot_name(level, u.spawn_id)
	return u.display_name


static func slot_name(level: LevelDefinition, slot_id: String) -> String:
	var slot: SlotDef = level.get_slot(slot_id)
	if slot == null:
		return slot_id
	var base: String = DataRegistry.get_unit(slot.unit_id).display_name
	var same: int = 0
	var order: int = 0
	for sl: SlotDef in level.slots:
		if sl.unit_id == slot.unit_id:
			same += 1
			if sl.id == slot_id:
				order = same
	return base if same <= 1 else "%s %d" % [base, order]


static func spawn_name(level: LevelDefinition, spawn_id: String) -> String:
	var sp: SpawnDef = level.get_spawn(spawn_id)
	if sp == null:
		return spawn_id
	return sp.display_name if sp.display_name != "" else DataRegistry.get_unit(sp.unit_id).display_name


static func objective_sentence(o: ObjectiveDef, level: LevelDefinition) -> String:
	var names: PackedStringArray = PackedStringArray()
	for t: String in o.targets:
		names.append(spawn_name(level, t))
	var key: String = str(SimTypes.ObjectiveType.keys()[o.type]).to_lower()
	if o.type == SimTypes.ObjectiveType.REACH_ZONE and o.is_win:
		key = "reach_zone_win"
	var who: String = spawn_name(level, o.target)
	if o.target == ObjectiveDef.ANY_ALLY:
		who = s("ui.any_ally") if o.count <= 1 else s("ui.any_ally_count").format({ "count": o.count })
	return s("objective." + key).format({ "targets": s("ui.list_sep").join(names), "target": who, "seconds": num(o.seconds) })


## 面板六项属性（生命 / 攻击 / 攻速 / 移速 / 视野 / 射程）：有模拟单位时显示有效值，与形态基础值不同则注明关卡加成（07 §7）
static func stat_values(u: SimUnit, udef: UnitDefinition) -> Array[String]:
	var out: Array[String] = []
	for stat: String in ModifierDef.STATS:
		var base: float = ModifierDef.base_of(udef, stat)
		var eff: float = ModifierDef.stat_of(u, stat) if u != null else base
		var text: String = num(eff)
		if stat == "max_hp" and u != null:
			text = "%s/%s" % [num(maxf(u.hp, 0.0)), num(eff)]
		if u != null and absf(eff - base) > SimTypes.DIST_EPS:
			text = s("ui.stat_modified").format({ "value": text, "delta": ("+" if eff > base else "") + num(eff - base) })
		out.append(text)
	return out


## 校验问题 → 一行文案
static func problem_text(p: Dictionary, level: LevelDefinition) -> String:
	var template: String = s("validation." + str(p["code"]))
	var name: String = str(p["name"]) if p.has("name") else slot_name(level, str(p["slot"]))
	return template.format({ "slot": name, "index": int(p.get("index", 0)), "what": what_name(str(p.get("what", ""))) })


## 待机状态：0 无图标；1 待机；2 受阻/无处可退；3 目标不在射程
static func state_kind(u: SimUnit) -> int:
	if u == null or not u.alive or u.is_structure():
		return 0
	match u.reason:
		SimTypes.ReasonCode.PATH_BLOCKED, SimTypes.ReasonCode.FLEE_NO_DIRECTION:
			return 2
		SimTypes.ReasonCode.TARGET_OUT_OF_RANGE:
			return 3
		SimTypes.ReasonCode.NO_RULE_MATCHED, SimTypes.ReasonCode.NO_TARGET_CANDIDATE, SimTypes.ReasonCode.ROUTE_FINISHED, \
				SimTypes.ReasonCode.WAITING, SimTypes.ReasonCode.BEACON_MISSING:
			return 1
	return 1 if u.current_action == SimTypes.ActionType.IDLE else 0


static func state_text(u: SimUnit) -> String:
	if u.reason == SimTypes.ReasonCode.WAITING and u.wait_remaining() >= 0.0:
		return s("ui.wait_remaining").format({ "seconds": "%.1f" % u.wait_remaining() })
	if u.reason != SimTypes.ReasonCode.OK and u.reason != SimTypes.ReasonCode.COOLDOWN:
		return reason_text(u.reason)
	return s("action_text.idle")
