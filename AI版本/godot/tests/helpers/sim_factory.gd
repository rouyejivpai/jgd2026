class_name SimFactory
extends RefCounted
## 测试辅助（05 §1）：构建世界、单位、网格，运行到结束。


## 用关卡构建世界。deploy: slot_id -> Vector2i 或 [x, y]；rules_override: slot_id -> Array[RuleDef] 或 Array[Dictionary]
## 第五阶段：己方单位按双组口径求值；Array[Dictionary] 视为旧单列表写法并经 RuleDef.migrate_legacy() 折算，Array[RuleDef] 原样使用
## 未覆盖的槽位使用推荐阵型中的推荐指令（= 第一阶段的槽位初始指令，07 §2）
static func make_world(level_id: String, deploy: Dictionary, rules_override: Dictionary = {}) -> SimWorld:
	var level: LevelDefinition = DataRegistry.get_level(level_id)
	return SimWorld.from_level(level, DataRegistry.get_units(), DataRegistry.get_traits(), make_config(level, deploy, rules_override))


## 生成 SimWorld.from_level / DeploymentValidator 使用的 config
static func make_config(level: LevelDefinition, deploy: Dictionary, rules_override: Dictionary = {}) -> Dictionary:
	var config: Dictionary = {}
	for sid: String in deploy.keys():
		# 第二阶段 free 关没有槽位：测试仍用推荐阵型的条目名（原槽位名）作 uid，形态/序号由关卡推出，
		# 使模拟 id 与第一阶段一致（07 §4.2）
		var entry: Dictionary = { "pos": to_cell(deploy[sid]), "form": level.legacy_form(sid), "index": level.legacy_index(sid),
			"label": RuleText.slot_name(level, sid) if level.get_slot(sid) != null else DataRegistry.get_unit(level.legacy_form(sid)).display_name }
		if rules_override.has(sid):
			var arr: Array = rules_override[sid] as Array
			var rs: Array[RuleDef] = to_rules(arr)
			if not arr.is_empty() and arr[0] is Dictionary:
				rs = RuleDef.migrate_legacy(rs)     # 第五阶段：字典写法 = 旧单列表口径（测试原意），折算为双组；RuleDef 列表原样使用
			entry["rules"] = rs
		elif level.get_recommended(sid) != null:
			entry["rules"] = level.recommended_rules(sid)
		config[sid] = entry
	return config


## 推荐阵型：推荐部署 + 推荐指令
static func make_recommended_world(level_id: String) -> SimWorld:
	var level: LevelDefinition = DataRegistry.get_level(level_id)
	return make_world(level_id, level.recommended_deploy)


static func run_steps(world: SimWorld, n: int) -> void:
	for i: int in n:
		world.step()


## 运行到出结果或超时；返回 SimTypes.BattleResult
static func run_until_end(world: SimWorld, max_seconds: float) -> int:
	var max_steps: int = int(ceil(max_seconds / SimTypes.SIM_DT))
	for i: int in max_steps:
		if world.result != SimTypes.BattleResult.NONE:
			break
		world.step()
	return world.result


## 空世界（指定网格）
static func make_empty_world(w: int, h: int, blocked: Array[Vector2i] = []) -> SimWorld:
	var world := SimWorld.new()
	world.grid = tiny_grid(w, h, blocked)
	world.traits = DataRegistry.get_traits()
	return world


static func tiny_grid(w: int, h: int, blocked: Array[Vector2i] = []) -> SimGrid:
	return SimGrid.new(w, h, blocked)


## 以 units.json 定义创建单位；pos 为格中心坐标（Vector2）或格（Vector2i）；rules 为 Array[RuleDef] 或 Array[Dictionary]
static func make_unit(def_id: String, faction: int, pos: Variant, rules: Array = []) -> SimUnit:
	var udef: UnitDefinition = DataRegistry.get_unit(def_id)
	var p: Vector2 = SimTypes.cell_center(pos as Vector2i) if pos is Vector2i else pos as Vector2
	return SimUnit.create(udef, faction, p, to_rules(rules))


## 创建单位并加入世界
static func add(world: SimWorld, def_id: String, faction: int, pos: Variant, rules: Array = [], spawn_id: String = "") -> SimUnit:
	var u: SimUnit = make_unit(def_id, faction, pos, rules)
	u.spawn_id = spawn_id
	return world.add_unit(u)


static func rule(d: Dictionary) -> RuleDef:
	return RuleDef.from_dict(d, "test")


static func to_rules(arr: Array) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for item: Variant in arr:
		if item is RuleDef:
			out.append(item as RuleDef)
		else:
			out.append(rule(item as Dictionary))
	return out


static func to_cell(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v as Vector2i
	var a: Array = v as Array
	return Vector2i(int(a[0]), int(a[1]))


static func objective(d: Dictionary, is_win: bool) -> ObjectiveDef:
	return ObjectiveDef.from_dict(d, is_win, "test")


## 事件筛选
static func events_of(world: SimWorld, type: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in world.events:
		if int(e["type"]) == type:
			out.append(e)
	return out


# ---- 常用规则字典 ----
static func r_attack_in_range(selector: String = "nearest", filter: String = "any") -> Dictionary:
	return { "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": selector, "filter": filter }, "action": { "type": "attack" } }


static func r_chase_attack_visible(selector: String = "nearest", filter: String = "any") -> Dictionary:
	return { "conditions": [{ "type": "enemy_visible" }], "target": { "selector": selector, "filter": filter }, "action": { "type": "chase_attack" } }


static func r_idle() -> Dictionary:
	return { "conditions": [], "action": { "type": "idle" } }
