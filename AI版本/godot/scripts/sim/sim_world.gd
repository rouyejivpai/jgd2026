class_name SimWorld
extends RefCounted
## 一场战斗的完整模拟状态（01 §6）。纯逻辑、定步长、无随机；重置 = 丢弃并重建。

var grid: SimGrid = null
var clock: SimClock = SimClock.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()   ## 接口预留，第一章不使用
var units: Array[SimUnit] = []          ## 按 id 升序
var routes: Dictionary = {}             ## route_id -> RouteDef
var traits: Dictionary = {}             ## trait_id -> TraitDefinition
var win_objectives: Array[ObjectiveDef] = []
var lose_objectives: Array[ObjectiveDef] = []
var blasts: Array[SimBlast] = []
var next_blast_id: int = 1
var damage_queue: Array[Dictionary] = []
var events: Array[Dictionary] = []
var seen_counter: int = 0
var range_counter: int = 0              ## 第五阶段：进入射程序号（first_in_range）
var result: int = SimTypes.BattleResult.NONE
var result_objective: String = ""       ## 决出胜负的 objective id（失败说明用）
var objective_progress: Dictionary = {} ## time_left / target_hp / target_max_hp / threat_cleared
var level_id: String = ""
var tiles: Dictionary = {}              ## Vector2i -> 地形效果格 kind（hazard / mire / shrine）
var relic_tiles: Dictionary = {}        ## Vector2i -> { relic, status, seconds }：遗物地块（提灯 / 骨臂），只作用于敌方，由 BattleController 写入
var boss: Dictionary = {}               ## LevelDefinition.boss 的副本
var boss_state: Dictionary = {}         ## BossSystem 运行状态
var boss_signal: String = ""            ## Boss 当前信号（signal_is 条件读取）
var phase: int = 1                      ## Boss 阶段（从 1 开始）
var phase_pending: bool = false         ## true = 换阶段暂停中：step() 不推进，等控制器（玩家重新编程 / 增援）后清除

var _by_id: Dictionary = {}             ## id -> SimUnit
var _spawn_index: Dictionary = {}       ## spawn_id -> unit id
var _next_id: Dictionary = {}           ## id 段起点 -> 下一个可用 id
var _begun: bool = false


## 从关卡构建世界。config: uid -> { "pos": Vector2i, "form": String, "index": int, "rules": Array[RuleDef]（可选）,
##   "beacons": Array（可选）, "label": String（可选）}（07 §4.2；fixed 关 uid = 槽位 id）
## 未出现在 config 中的槽位不生成单位（开始前由 DeploymentValidator 拦截）。
static func from_level(level: LevelDefinition, unit_defs: Dictionary, trait_defs: Dictionary, config: Dictionary) -> SimWorld:
	var w := SimWorld.new()
	w.level_id = level.id
	w.grid = SimGrid.new(level.width, level.height, level.blocked)
	w.boss = level.boss.duplicate(true)
	for kind: String in level.tiles.keys():
		for c: Vector2i in level.tiles[kind] as Array[Vector2i]:
			w.tiles[c] = kind
			w.grid.set_weight(c, float(StatusSystem.TILE_WEIGHT.get(kind, 1.0)))
	w.routes = level.routes
	w.traits = trait_defs
	w.win_objectives = level.win
	w.lose_objectives = level.lose
	w.rng.seed = level.rng_seed
	# 己方 id = ALLY_ID_BASE + 序号（fixed 关 = 槽位序号；free 关 = uid 编号 - 1，07 §4.2），部署阶段增减单位时 id 不漂移。
	# 条目缺 form / index 时按关卡槽位或 recommended 条目名推出（旧格式配置与测试）。
	var entries: Array[Dictionary] = []
	var max_index: int = level.slots.size() - 1
	for uid: String in config.keys():
		var entry: Dictionary = config[uid] as Dictionary
		if not entry.has("pos"):
			continue
		var index: int = int(entry.get("index", level.legacy_index(uid)))
		if index < 0:
			continue
		max_index = maxi(max_index, index)
		entries.append({ "uid": uid, "index": index, "entry": entry })
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["index"]) < int(y["index"]))
	w._next_id[SimTypes.ALLY_ID_BASE] = SimTypes.ALLY_ID_BASE + max_index + 1
	for item: Dictionary in entries:
		var uid: String = str(item["uid"])
		var entry: Dictionary = item["entry"] as Dictionary
		var form: String = str(entry.get("form", entry.get("unit", level.legacy_form(uid))))
		var udef: UnitDefinition = unit_defs.get(form, null) as UnitDefinition
		if udef == null:
			continue
		var rules: Array[RuleDef] = []   # 未给指令 = 空指令（07 §2：新放置单位指令为空）
		if entry.has("rules"):
			for r: RuleDef in entry["rules"] as Array:
				rules.append(r.clone())
		var u: SimUnit = SimUnit.create(udef, SimTypes.Faction.ALLY, SimTypes.cell_center(entry["pos"] as Vector2i), rules)
		u.dual_rules = str(entry.get("rules_format", "dual")) != "legacy"   # 第五阶段：玩家单位双组口径（"legacy" 仅供测试对照）
		u.id = SimTypes.ALLY_ID_BASE + int(item["index"])
		u.spawn_id = uid
		if entry.has("label"):
			u.display_name = str(entry["label"])
		for b: Dictionary in entry.get("beacons", []) as Array:   # 07 §3.1：{ id, cell }
			u.beacons.append({ "id": str(b["id"]), "cell": b["cell"] as Vector2i })
		ModifierDef.apply_all(u, level.modifiers)                # 07 §7 静态关卡加成
		w.add_unit(u)
	for s: SpawnDef in level.initial_units:
		var sdef: UnitDefinition = unit_defs.get(s.unit_id, null) as UnitDefinition
		if sdef == null:
			continue
		if not s.skin().is_empty():
			sdef = sdef.reskinned(s.skin())
		var srules: Array[RuleDef] = RuleDef.clone_array(s.rules if s.has_rules else sdef.default_rules)
		var su: SimUnit = SimUnit.create(sdef, s.faction, SimTypes.cell_center(s.pos), srules)
		su.spawn_id = s.id
		su.tags = s.tags.duplicate()
		su.counts_for_annihilate = s.counts_for_annihilate
		if s.display_name != "":
			su.display_name = s.display_name
		ModifierDef.apply_all(su, level.modifiers)
		var ovs: Array[ModifierDef] = []                         # 07 §9：overrides 最后应用（覆盖）
		for k: String in s.overrides.keys():
			ovs.append(ModifierDef.override(s.id, k, float(s.overrides[k])))
		ModifierDef.apply_all(su, ovs)
		w.add_unit(su)
	return w


## 加入单位；id < 0 时按阵营/类型分配（己方 1 起、敌方 101 起、建筑 201 起）
func add_unit(u: SimUnit) -> SimUnit:
	if u.id < 0:
		var base: int = SimTypes.ENEMY_ID_BASE
		if u.kind == SimTypes.UnitKind.STRUCTURE:
			base = SimTypes.STRUCTURE_ID_BASE
		elif u.faction == SimTypes.Faction.ALLY:
			base = SimTypes.ALLY_ID_BASE
		var next: int = int(_next_id.get(base, base))
		while _by_id.has(next):
			next += 1
		u.id = next
		_next_id[base] = next + 1
	units.append(u)
	units.sort_custom(func(a: SimUnit, b: SimUnit) -> bool: return a.id < b.id)
	_by_id[u.id] = u
	if u.spawn_id != "":
		_spawn_index[u.spawn_id] = u.id
	return u


func tile_at(c: Vector2i) -> String:
	return str(tiles.get(c, ""))


func get_unit(id: int) -> SimUnit:
	return _by_id.get(id, null) as SimUnit


func get_spawn(spawn_id: String) -> SimUnit:
	if not _spawn_index.has(spawn_id):
		return null
	return get_unit(int(_spawn_index[spawn_id]))


func make_snapshot() -> SimSnapshot:
	return SimSnapshot.capture(units)


## 开战瞬间：所有已可见者按 unit id 升序赋序号（01 §6.5）。step() 首次调用时自动执行。
func begin() -> void:
	if _begun:
		return
	_begun = true
	_update_seen()


func emit_event(type: int, data: Dictionary) -> void:
	data["type"] = type
	data["time"] = clock.time
	events.append(data)


## 取走并清空事件列表（BattleController 消费）
func take_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events
	events = []
	return out


func queue_damage(source: int, target: int, amount: float, on_hit: bool = false) -> void:
	damage_queue.append({ "source": source, "target": target, "damage": amount, "on_hit": on_hit })


## 推进一个固定步长（01 §6.2，顺序为策划已定）
func step() -> void:
	if result != SimTypes.BattleResult.NONE or phase_pending:
		return
	begin()
	# 1. 时钟
	clock.advance()
	damage_queue.clear()
	# 2–3. 爆炸计时与到期结算
	BlastSystem.detonate(self, BlastSystem.tick(self))
	# 4. 攻击冷却
	for u: SimUnit in units:
		if u.alive:
			u.cooldown = maxf(0.0, u.cooldown - SimTypes.SIM_DT)
	# 4b. 异常状态 / 地形效果格 / 光环
	StatusSystem.tick(self)
	# 5. 快照
	var snap: SimSnapshot = make_snapshot()
	# 6. 决策（按 id 升序，只读快照）
	var decisions: Dictionary = {}
	for u: SimUnit in units:
		if u.alive:
			var d: SimDecision = RuleEvaluator.evaluate(u, snap, self)
			u.apply_decision(d, self)
			decisions[u.id] = d
	# 7. 移动
	for u: SimUnit in units:
		if u.alive:
			Movement.apply(u, decisions[u.id] as SimDecision, snap, self)
	# 8. 普通攻击
	for u: SimUnit in units:
		if u.alive:
			Combat.try_attack(u, decisions[u.id] as SimDecision, self)
	# 9. 特性
	TraitSystem.tick(self)
	BossSystem.tick(self)
	# 10. 同步结算伤害
	_resolve_damage()
	# 11. 视野顺序
	_update_seen()
	# 12. 胜负（失败优先）
	ObjectiveSystem.evaluate(self)


func _resolve_damage() -> void:
	var died: Array[int] = []
	for entry: Dictionary in damage_queue:
		var t: SimUnit = get_unit(int(entry["target"]))
		if t == null:
			continue
		var amount: float = float(entry["damage"]) * StatusSystem.damage_mult(self, t)
		var was_alive: bool = t.alive
		var src: SimUnit = get_unit(int(entry["source"]))
		if src != null and was_alive:
			src.damage_dealt += amount        # 第五阶段 most_damage 选敌
		t.hp -= amount
		emit_event(SimTypes.EventType.DAMAGE_APPLIED, { "target": t.id, "amount": amount, "source": int(entry["source"]), "hp_after": t.hp })
		if was_alive and t.hp <= 0.0:
			t.alive = false
			died.append(t.id)
			emit_event(SimTypes.EventType.UNIT_DIED, { "unit": t.id, "killer": int(entry["source"]) })
		if bool(entry.get("on_hit", false)):
			StatusSystem.on_hit(self, get_unit(int(entry["source"])), t)
	damage_queue.clear()
	if died.is_empty():
		return
	for u: SimUnit in units:
		if died.has(u.lock_target):
			u.lock_target = -1
		if not u.alive:
			u.path.clear()


## 进入视野顺序（01 §6.5）：新进入者取全局递增序号，离开视野者移除（并清除对其的锁定）
## 第五阶段：同时维护进入射程顺序（射程内且可见；离开即移除）
func _update_seen() -> void:
	for obs: SimUnit in units:
		if not obs.alive:
			continue
		for other: SimUnit in units:
			var visible: bool = other.alive and TargetSelector.is_hostile(obs.faction, other.faction) \
				and obs.pos.distance_to(other.pos) <= obs.vision + SimTypes.DIST_EPS
			var in_range: bool = visible and obs.pos.distance_to(other.pos) <= obs.attack_range + SimTypes.DIST_EPS
			if in_range:
				if not obs.range_order.has(other.id):
					obs.range_order[other.id] = range_counter
					range_counter += 1
			elif obs.range_order.has(other.id):
				obs.range_order.erase(other.id)
			if visible:
				if not obs.seen_order.has(other.id):
					obs.seen_order[other.id] = seen_counter
					seen_counter += 1
			elif obs.seen_order.has(other.id):
				obs.seen_order.erase(other.id)
				if obs.lock_target == other.id:
					obs.lock_target = -1


## 确定性校验：所有单位 pos/hp 四舍五入到 1e-4 后拼接取 hash（01 §7）
func state_hash() -> int:
	var parts: PackedStringArray = PackedStringArray()
	for u: SimUnit in units:
		parts.append("%d:%.4f,%.4f:%.4f:%d" % [u.id, u.pos.x, u.pos.y, u.hp, 1 if u.alive else 0])
	return "|".join(parts).hash()
