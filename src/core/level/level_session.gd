class_name LevelSession
extends RefCounted
## 详细设计：[docs/design/06-关卡数据与胜负条件.md](../../docs/design/06-关卡数据与胜负条件.md) 4.1-4.5
##
## 一个关卡的**总指挥**：装配地图与单位 → 驱动「编制期 → 推演期 → 结算期」
## 状态机 → 每个 tick 按固定顺序调用各系统 → 检查胜负 → 重置。
##
## 【全项目唯一的 tick 编排点】
## 见详设 06 的 4.2：9 步顺序**必须**在本类里用显式调用表达，
## 不能让各系统各自 `connect(clock.tick)` —— Godot 的信号回调顺序不可靠，
## 一旦有人调整订阅顺序，玩法会**静默**改变，而这种 bug 极难查。
##
## 【两期的时间语义】编制期**不订阅** tick（时间完全冻结）；
## 点开始才连上 `_on_tick`。GameClock 本身不知道编制期的存在。

const BattleMapScript := preload("res://src/core/map/battle_map.gd")
const BattleStateScript := preload("res://src/core/map/battle_state.gd")
const UnitActorScript := preload("res://src/core/unit/unit_actor.gd")
const RuleEngineScript := preload("res://src/core/rule/rule_engine.gd")
const SignalStoreScript := preload("res://src/core/rule/signal_store.gd")
const ProjectileScript := preload("res://src/core/combat/projectile.gd")

## 会话状态
enum State { BUILD, RUN, RESULT }
## 结算结果
enum Verdict { NONE, WIN, LOSE }

const TEAM_ALLY := 0
const TEAM_ENEMY := 1
const TILE_GOAL := 2


## 进入推演期。发：LevelSession　收：HUD / 计时显示
signal state_changed(state: int)
## 结算。发：LevelSession　收：结算界面 / 最佳记录
signal finished(verdict: int)

var state: int = State.BUILD
var verdict: int = Verdict.NONE

var level = null            ## LevelData（用 RefCounted，避免 class_name 依赖）
var clock = null            ## GameClock
var map: Node2D = null      ## BattleMap
var battle_state: RefCounted = null
## 全局信号表（本 tick 生效值 + 暂存区，见 SignalStore）
var signals: RefCounted = null
## 规则引擎（每 tick 把规则表翻译成意图）
var rule_engine: RefCounted = null

## 单位列表（按 entity_id 升序由 battle_state 给出）
var units: Array = []

## 单位数值表：type_id → 数值字典。
## M1 由外部注入（M3 换成 DataLoader 提供），因此本类不依赖数据层。
var unit_stats_table: Dictionary = {}

## 装配过程中的错误（非空表示装配失败，会话不可用）
var setup_errors: Array[String] = []

## 供外部挂载的地图父节点（测试里传自己，游戏里传场景根）
var host: Node = null


# ---------------------------------------------------------------------------
# 装配
# ---------------------------------------------------------------------------

## 装配一个关卡。返回错误列表（空表示成功）。
##
## p_host  地图节点挂到哪里（必须是已在场景树里的节点）
## p_level LevelData（**已通过 validate()**，本类不重复解析 JSON）
## p_clock GameClock（可为 null，测试里手动推进时不需要）
## p_stats type_id → 数值字典
func setup(p_host: Node, p_level, p_clock, p_stats: Dictionary) -> Array[String]:
	setup_errors.clear()
	host = p_host
	level = p_level
	clock = p_clock
	unit_stats_table = p_stats
	state = State.BUILD
	verdict = Verdict.NONE

	if host == null:
		setup_errors.append("LevelSession.setup: host 不能为空")
		return setup_errors
	if level == null:
		setup_errors.append("LevelSession.setup: level 不能为空")
		return setup_errors

	# 1. 地图
	map = BattleMapScript.new()
	map.name = "BattleMap"
	host.add_child(map)
	var map_errors: Array = map.call("load_from", level.map)
	if not map_errors.is_empty():
		setup_errors.append_array(map_errors)
		return setup_errors

	# 2. 实体注册表 + 信号表 + 规则引擎
	battle_state = BattleStateScript.new()
	signals = SignalStoreScript.new()
	signals.call("setup", int(level.signal_count))
	rule_engine = RuleEngineScript.new()

	# 3. 双方单位
	units.clear()
	var all_entries: Array = []
	all_entries.append_array(level.ally_entries())
	all_entries.append_array(level.enemy_entries())
	for entry in all_entries:
		var e: Dictionary = entry
		var type_id := str(e.get("type", ""))
		var base = unit_stats_table.get(type_id)
		if not (base is Dictionary):
			setup_errors.append("units: 单位类型 \"%s\" 没有数值定义" % type_id)
			continue
		var ov = e.get("overrides", {})
		if not (ov is Dictionary):
			ov = {}
		# 与 DataLoader 同一套合成规则：**只允许覆盖已存在的字段**。
		# 两边共用 _merge_overrides，避免出现「两份实现、行为不一致」。
		var stats: Dictionary = {}
		var ov_errs: Array[String] = []
		_merge_overrides(base, ov, type_id, stats, ov_errs)
		if not ov_errs.is_empty():
			setup_errors.append_array(ov_errs)
			continue

		var team := TEAM_ALLY if str(e.get("team", "")) == "ally" else TEAM_ENEMY
		var pos_arr: Array = e.get("pos", [0, 0])
		# 【必须换成"瓦片中心"的逻辑坐标】关卡 JSON 里写的是**瓦片下标**（如 [1,1]），
		# 而逻辑坐标的约定是**瓦片中心**（瓦片 (1,1) → (1.5,1.5)）。
		# 直接把下标当逻辑坐标用，单位会被画到四格交叉的角上、整体偏半格
		# （截图 + 像素断言第一次运行就抓到了：瓦片 [1,1] 中心取到的是背景色）。
		var pos: Vector2 = map.call("tile_to_logic", int(pos_arr[0]), int(pos_arr[1]))

		var unit: Node2D = UnitActorScript.new()
		unit.name = "Unit_%s_%d" % [type_id, units.size()]
		host.add_child(unit)
		unit.call("setup", team, pos, stats)
		unit.set("type_id", type_id)
		unit.set("overrides", e.get("overrides", {}))
		unit.set("battle_map", map)
		unit.set("battle_state", battle_state)
		# 单位由**本会话**按 tick 驱动，关掉引擎的自动物理，避免重复推进
		unit.set_physics_process(false)
		battle_state.call("register_unit", unit)
		units.append(unit)

	if not setup_errors.is_empty():
		return setup_errors

	# 4. 连接时钟（编制期不接！见本类顶部说明）
	if clock != null:
		var cb := Callable(self, "_on_tick")
		if not clock.is_connected("tick", cb):
			clock.connect("tick", cb)

	state = State.BUILD
	state_changed.emit(state)
	return setup_errors


## 把基础数值与关卡覆盖合成进 `out`。
##
## 【与 DataLoader.get_unit_stats 同一套规则】只允许覆盖**已存在**的字段。
## 这样写好字段名会立刻被拒，而不是静默忽略 —— 后者会产生「我明明调了射程
## 却没生效」的幽灵 bug（详设 11 的 4.3）。
## 覆盖只影响本关这一份数值，**不写回基础表**（FR-UNIT-05）。
func _merge_overrides(base, overrides: Dictionary, type_id: String,
		out: Dictionary, errs: Array[String]) -> void:
	for k in (base as Dictionary).keys():
		out[k] = (base as Dictionary)[k]
	for key in overrides.keys():
		var k := str(key)
		if not out.has(k):
			errs.append("units[%s].overrides: 字段 \"%s\" 不存在于该单位数值中" % [type_id, k])
			continue
		out[k] = overrides[key]


# ---------------------------------------------------------------------------
# 会话流转
# ---------------------------------------------------------------------------

## 进入推演期（点「开始」）。返回是否成功。
func start() -> bool:
	if state != State.BUILD or setup_errors.size() > 0:
		return false
	if clock != null:
		clock.call("reset")
	verdict = Verdict.NONE
	state = State.RUN
	state_changed.emit(state)
	EventBus.level_started.emit(str(level.id))
	return true


## 重置关卡：回到推演前（编制期），**保留玩家的指令与信标**（需求 12.1a）。
func reset() -> void:
	if clock != null:
		clock.call("reset")
	for u in units:
		u.call("reset")
	battle_state.call("clear")
	# 单位重新登记（clear 把注册表清空了）
	for u in units:
		battle_state.call("register_unit", u)
	# 信号回到全关（信号是局内状态，重置该清）
	signals.call("setup", int(level.signal_count))
	verdict = Verdict.NONE
	state = State.BUILD
	state_changed.emit(state)


## 是否在推演期（写游戏循环时用它挡输入）
func is_running() -> bool:
	return state == State.RUN


# ---------------------------------------------------------------------------
# tick 编排（详设 06 的 4.2，**9 步顺序必须与此一致**）
# ---------------------------------------------------------------------------

func _on_tick() -> void:
	if state != State.RUN:
		return
	step_tick()


## 手动推进一步。测试直接调它，不必依赖真实时钟。
func step_tick() -> void:
	if state != State.RUN:
		return
	var tick_delta: float = 1.0 / 60.0

	# 1. 信号提交（D4：**本 tick 写入的信号下一 tick 才生效**）
	#    放在 tick 最前，保证整个 tick 内条件读到的是同一份快照。
	signals.call("commit")

	# 2. 规则求值 → Intent（按实体 id 升序，保证确定性）
	var intents: Array = []
	var ordered: Array = battle_state.call("units_sorted")
	for u in ordered:
		intents.append(rule_engine.call("evaluate_unit", u, battle_state, map, signals))

	# 3. 应用意图（延迟计时器递减；持续意图的保持与重置在 UnitActor 内）
	for i in ordered.size():
		var u: Node = ordered[i]
		if bool(u.get("is_dead")):
			continue
		u.call("apply_intents", intents[i], tick_delta)
		# 规则要求写信号 → 进暂存区，下一 tick 生效
		for w in (intents[i].get("signal_writes") as Array):
			signals.call("request_write", int(w[0]), bool(w[1]))
			EventBus.signal_changed.emit(int(w[0]), bool(w[1]))

	# 4. 移动（匀速直线、撞墙停止）
	for u in ordered:
		if not bool(u.get("is_dead")):
			u.call("step_movement", tick_delta)

	# 5. 开火与冷却（系统 05 在 M2-6 落地）
	_step_weapons(tick_delta)

	# 6. 子弹推进与命中（系统 05 在 M2-7 落地）
	_step_projectiles(tick_delta)

	# 7. 清理死亡
	_cleanup_dead()

	# 8. 胜负检查（**每 tick 都查**：reach_position 与 timeout 与死亡无关）
	_check_verdict()

	# 9. 统计采样（系统 08 在 M5 落地）
	_sample_statistics()


## 编制期主动重算**全部**指令的 `invalid_reason`（详设 09 §4.5）。
##
## 【为什么要主动算】`invalid_reason` 原本只在 `rule_engine.evaluate_unit` 里写，
## 也就是**只有推演期才更新**：玩家删掉一条被引用的信标后，指令行不会立刻标黄，
## 得按了「开始」才知道。编制期必须有这个入口。
##
## 引用校验与单位状态无关（只看信标/信号是否存在），所以可以对所有单位统一刷新。
func refresh_invalid_reasons() -> void:
	if rule_engine == null:
		return
	for u in units:
		if u == null:
			continue
		for r in (u.get("rules") as Array):
			if r == null:
				continue
			r.set("invalid_reason",
				rule_engine.call("validate_rule", r, map, signals))


## 当前有多少条无效指令（工具条角标用；需求 12.1 决策：不弹窗、不阻断）
func invalid_rule_count() -> int:
	var n := 0
	for u in units:
		if u == null:
			continue
		for r in (u.get("rules") as Array):
			if r != null and not str(r.get("invalid_reason")).is_empty():
				n += 1
	return n


## tick 第 5 步：开火与冷却（详设 05 的 4.1）
##
## 遍历顺序按实体 id 升序（确定性，FR-TEST-08）。
## **冷却只在「想开火」时递减**：停火期间保持不变，重新开火不必等冷却转完。
func _step_weapons(tick_delta: float) -> void:
	for u in battle_state.call("units_sorted"):
		if bool(u.get("is_dead")):
			continue
		if not bool(u.call("wants_to_fire")):
			continue
		var cd: float = maxf(0.0, float(u.get("cooldown_remaining")) - tick_delta)
		u.set("cooldown_remaining", cd)
		if cd > 0.0:
			continue
		# 目标必须在**射程内**（不是视野内）——射程是开火的判据
		var rng: float = float(u.call("effective_range"))
		var target = battle_state.call("query_nearest_enemy", u, rng)
		if target == null:
			continue                            # 没有合法目标就不开火，也不消耗冷却
		_spawn_projectile(u, target)
		var stats: Dictionary = u.get("stats")
		u.set("cooldown_remaining", float(stats.get("attack_interval", 1.0)))


func _spawn_projectile(shooter: Node, target: Node) -> void:
	var from_logic: Vector2 = shooter.get("position_logic")
	var to_logic: Vector2 = target.get("position_logic")
	var dir := to_logic - from_logic          # **不预判**：用开火瞬间目标的位置
	var stats: Dictionary = shooter.get("stats")
	var p: Area2D = ProjectileScript.new()
	host.add_child(p)
	p.call("setup", int(shooter.get("team")), from_logic, dir,
		float(stats.get("projectile_speed", 12.0)),
		float(shooter.call("effective_range")),   # 飞满射程即销毁
		float(stats.get("damage", 10.0)),
		float(stats.get("projectile_radius", 0.3)),
		str(stats.get("on_hit_status", "")),
		float(shooter.get("tile_px")),
		battle_state)
	battle_state.call("register_projectile", p)


## tick 第 6 步：子弹推进
func _step_projectiles(tick_delta: float) -> void:
	for k in (battle_state.get("projectiles") as Dictionary).keys():
		var p = (battle_state.get("projectiles") as Dictionary).get(k)
		if p != null and is_instance_valid(p):
			p.call("step", tick_delta)


func _cleanup_dead() -> void:
	# 死亡单位在 die() 里已自我注销；这里只做「双方是否还有活人」之外的收尾
	pass


func _sample_statistics() -> void:
	pass  # M5：统计采样


## 胜负检查。**每 tick 调用**（详设 06 的 4.5）。
func _check_verdict() -> void:
	var w := _evaluate_condition_group(level.win_conditions(), level.win_logic())
	if w:
		_end(Verdict.WIN)
		return
	var l := _evaluate_condition_group(level.lose_conditions(), level.lose_logic())
	if l:
		_end(Verdict.LOSE)


## 求值一组条件。logic == "all" 时要求全部成立，否则任一成立即真。
func _evaluate_condition_group(conditions: Array, logic: String) -> bool:
	if conditions.is_empty():
		return false
	if logic == "all":
		for c in conditions:
			if not _evaluate_condition(c as Dictionary):
				return false
		return true
	for c in conditions:
		if _evaluate_condition(c as Dictionary):
			return true
	return false


func _evaluate_condition(c: Dictionary) -> bool:
	match str(c.get("type", "")):
		"reach_position":
			return _check_reach_position(c)
		"annihilate":
			return _alive_enemies() == 0
		"all_allies_dead":
			return _alive_allies() == 0
		"timeout":
			return _check_timeout()
		"survive_until":
			return _check_survive_until(c)
		_:
			# destroy_core / custom 等 MVP 未实现的条件：恒为假，不影响判定
			return false


func _check_reach_position(c: Dictionary) -> bool:
	var area = c.get("area", [])
	if not (area is Array):
		return false
	var goals: Array = area
	for u in units:
		if bool(u.get("is_dead")):
			continue
		if int(u.get("team")) != TEAM_ALLY:
			continue
		var p: Vector2 = u.get("position_logic")
		# 【必须用地图自己的 logic_to_tile，不要在这里 round】
		# 逻辑坐标是**瓦片中心**（瓦片 6 → 6.5），而 round(6.5) = 7 —— 会算到
		# 邻格去，于是单位明明站在终点格上却判不了胜（M5 实测，排查了一轮）。
		# logic_to_tile 用的是 floor，与 world_to_tile / 地块矩形完全一致。
		var tile: Vector2i = map.call("logic_to_tile", p)
		for cell in goals:
			if not (cell is Array) or (cell as Array).size() != 2:
				continue
			if tile == Vector2i(int((cell as Array)[0]), int((cell as Array)[1])):
				return true
	return false


func _check_timeout() -> bool:
	if float(level.time_limit) <= 0.0:
		return false
	if clock == null:
		return false
	return float(clock.get("game_time")) >= float(level.time_limit)


func _check_survive_until(c: Dictionary) -> bool:
	# 「撑到 N 秒」＝ 时间到且我方还有人活着（M1 简化口径，M3 精确到指定单位）
	var secs := float(c.get("seconds", 0.0))
	if secs <= 0.0 or clock == null:
		return false
	if float(clock.get("game_time")) < secs:
		return false
	return _alive_allies() > 0


func _alive_allies() -> int:
	var n := 0
	for u in units:
		if int(u.get("team")) == TEAM_ALLY and not bool(u.get("is_dead")):
			n += 1
	return n


func _alive_enemies() -> int:
	var n := 0
	for u in units:
		if int(u.get("team")) == TEAM_ENEMY and not bool(u.get("is_dead")):
			n += 1
	return n


## 结束会话并广播。同一局只结算一次。
func _end(v: int) -> void:
	if verdict != Verdict.NONE:
		return
	verdict = v
	state = State.RESULT
	state_changed.emit(state)
	finished.emit(v)
	EventBus.level_finished.emit(v, {})


# ---------------------------------------------------------------------------
# 释放
# ---------------------------------------------------------------------------

## 销毁本会话创建的一切（地图、单位）。
## 用 immediate free 而不是 queue_free：避免「上一关的墙还在挡下一关的单位」。
func teardown() -> void:
	if clock != null:
		var cb := Callable(self, "_on_tick")
		if clock.is_connected("tick", cb):
			clock.disconnect("tick", cb)
	if battle_state != null:
		battle_state.call("clear")
	for u in units:
		if is_instance_valid(u):
			u.free()
	units.clear()
	if map != null and is_instance_valid(map):
		map.call("teardown")
		map.free()
	map = null
