class_name CommandCatalog
extends RefCounted
## 指令目录（10 §5.1，data/commands.json；取代 presets.json 的"添加指令"菜单角色）。
## 四类条目：actions / conditions / selectors / filters，每条 { id, unlock_key, cost, player（仅行为）, defaults（可选） }。
## 数组顺序 = 菜单顺序 = 默认项（第一项为默认）。unlock_key 为空 = 始终可用；否则需在已解锁的 presets 键中（progression / 关卡 rewards）。
## 指令 Cost = Σ 每条指令 (action.cost + Σ condition.cost)（10 §5.5）；选敌 / 目标类型不计 Cost。
## 第五阶段：行为带 group（attack / move）；group_limits = 每组条数上限；new_unit_rules = 新放置单位的预填指令；选敌也可 player: false（不进玩家菜单）。

const KINDS: Array[String] = ["actions", "conditions", "selectors", "filters"]

var _entries: Dictionary = {}            ## kind -> Array[Dictionary]
var group_limits: Dictionary = {}        ## SimTypes.RuleGroup -> int
var _new_unit_rules: Array[RuleDef] = []


static func from_dict(d: Dictionary, ctx: String) -> CommandCatalog:
	var cat := CommandCatalog.new()
	for kind: String in KINDS:
		var list: Array[Dictionary] = []
		var seen: Array[String] = []
		for item: Variant in DataReader.req_array(d, kind, ctx):
			var e: Dictionary = DataReader.as_dict(item, "%s.%s" % [ctx, kind])
			var id: String = DataReader.req_str(e, "id", "%s.%s" % [ctx, kind])
			var ectx: String = "%s.%s.%s" % [ctx, kind, id]
			if _parse(kind, id) < 0:
				DataReader.report(ectx, "id '%s' 不是可解析的%s" % [id, kind])
			if seen.has(id):
				DataReader.report(ectx, "id 重复")
			seen.append(id)
			var c: int = int(DataReader.opt_num(e, "cost", 0.0, ectx))
			if c < 0:
				DataReader.report(ectx, "cost 不能为负")
			list.append({
				"id": id,
				"unlock_key": DataReader.opt_str(e, "unlock_key", "", ectx),
				"cost": c,
				"player": DataReader.opt_bool(e, "player", true, ectx),
				"group": DataReader.opt_str(e, "group", "", ectx),
				"defaults": DataReader.opt_dict(e, "defaults", ectx).duplicate(true),
			})
		cat._entries[kind] = list
	var gl: Dictionary = DataReader.opt_dict(d, "group_limits", ctx)
	for gk: String in ["attack", "move"]:
		cat.group_limits[SimTypes.parse_group(gk)] = int(DataReader.opt_num(gl, gk, 5.0, ctx + ".group_limits"))
	cat._new_unit_rules = RuleDef.from_array(DataReader.opt_array(d, "new_unit_rules", ctx), ctx + ".new_unit_rules")
	return cat


static func _parse(kind: String, id: String) -> int:
	match kind:
		"actions":
			return SimTypes.parse_action(id)
		"conditions":
			return SimTypes.parse_condition(id)
		"selectors":
			return SimTypes.parse_selector(id)
		"filters":
			return SimTypes.parse_filter(id)
	return -1


## 某类条目的 id（菜单顺序）
func ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in _entries.get(kind, []) as Array:
		out.append(str(e["id"]))
	return out


func entry(kind: String, id: String) -> Dictionary:
	for e: Dictionary in _entries.get(kind, []) as Array:
		if str(e["id"]) == id:
			return e
	return {}


func has(kind: String, id: String) -> bool:
	return not entry(kind, id).is_empty()


func unlock_key(kind: String, id: String) -> String:
	return str(entry(kind, id).get("unlock_key", ""))


func cost(kind: String, id: String) -> int:
	return int(entry(kind, id).get("cost", 0))


## 行为是否进玩家菜单（player: false 的只给敌人数据用）
func is_player(action_id: String) -> bool:
	return bool(entry("actions", action_id).get("player", false))


## 第五阶段：选敌是否进玩家菜单
func is_player_selector(selector_id: String) -> bool:
	return bool(entry("selectors", selector_id).get("player", false))


## 第五阶段：某组指令条数上限（默认 5）
func group_limit(group: int) -> int:
	return int(group_limits.get(group, 5))


## 第五阶段：新放置单位的预填指令（副本）
func new_unit_rules() -> Array[RuleDef]:
	return RuleDef.clone_array(_new_unit_rules)


## 新建该条件 / 行为时的参数（可能为空）
func defaults(kind: String, id: String) -> Dictionary:
	return (entry(kind, id).get("defaults", {}) as Dictionary).duplicate(true)


## unlock_key 是否已解锁（空 = 始终可用；不在目录中的条目视为未解锁）
func unlocked(kind: String, id: String, unlocked_presets: Array) -> bool:
	if not has(kind, id):
		return false
	var key: String = unlock_key(kind, id)
	return key == "" or unlocked_presets.has(key)


## 全部非空 unlock_key（校验可追溯用）
func unlock_keys() -> Array[String]:
	var out: Array[String] = []
	for kind: String in KINDS:
		for e: Dictionary in _entries.get(kind, []) as Array:
			var k: String = str(e["unlock_key"])
			if k != "" and not out.has(k):
				out.append(k)
	return out


## 一条指令的 Cost = action.cost + Σ condition.cost（不在目录中的类型计 0）
func rule_cost(r: RuleDef) -> int:
	var total: int = 0
	if r.action != null:
		total += cost("actions", SimTypes.action_to_string(r.action.type))
	for c: ConditionDef in r.conditions:
		total += cost("conditions", SimTypes.condition_to_string(c.type))
	return total


func rules_cost(rules: Array) -> int:
	var total: int = 0
	for r: RuleDef in rules:
		total += rule_cost(r)
	return total
