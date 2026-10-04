class_name BattleState
extends RefCounted
## 详细设计：[docs/design/03-网格地图.md](../../docs/design/03-网格地图.md) 3.3
##
## 场上实体的**唯一注册表与查询入口**。为什么要有它：需求 6.2 要求
## 开火目标 = 视野内最近的敌人，而规则引擎的视野条件也要同样口径；若各自实现
## 一遍，两处口径迟早漂移。因此**只有本类允许遍历单位**，其它系统一律通过它查询。
##
## 【确定性】单位一律按 entity_id 升序遍历/返回。同距敌人取 id 更小者，
## 保证同一套规则跑出的结果可复现（FR-TEST-08）。
##
## 【本类不做逻辑】只做登记与查询，不要在这里塞玩法规则。
##
## 【无类型引用】单位只当作 Node 处理，通过 get()/set() 访问约定字段
## （entity_id / team / is_dead / position_logic）。这样本类不依赖 UnitActor，
## 测试里可以塞任何带这些字段的替身节点。

## 阵营（与 src/core/types.gd 保持一致）
const TEAM_ALLY := 0
const TEAM_ENEMY := 1

## 实体 id → 单位节点。键为 int，升序遍历。
var units: Dictionary = {}
## 实体 id → 子弹节点（由系统 05 登记，供清理与调试显示）
var projectiles: Dictionary = {}

## 自增 id 分配器。**全局单调递增**、死亡后不复用，
## 这样「id 更小」恒等于「更早出现」，排序语义稳定。
var _next_id := 1

## 调试开关：打开后 query_enemies_in_radius 会打印候选与排序结果。
## 排查「同距取 id 更小者」这类确定性问题时用。
var _debug_trace := false


# ---------------------------------------------------------------------------
# 字段存取
#
# 单位的约定字段（entity_id / team / is_dead / position_logic / is_slowed）优先
# 读属性；读不到就退回 meta。用 meta 是必要的：`Node.set()` 只写**已存在**的
# 属性，对没声明该属性的替身节点会静默失败（M1-3 实测踩到）。
# 这样测试可以塞任意替身节点，也让注册表不依赖 UnitActor。
# ---------------------------------------------------------------------------

func _get_unit_field(unit: Node, field: String) -> Variant:
	if unit == null:
		return null
	var v = unit.get(field)
	if v != null:
		return v
	if unit.has_meta(field):
		return unit.get_meta(field)
	return null


## 取 int 字段，缺失时用默认值。
## 【必须这样写】GDScript 4 里 `int(null)` 会报 "Nonexistent 'int' constructor"
## 并返回 0 —— 直接用 int(_get_unit_field(...)) 会让「字段不存在」和「值为 0」
## 混在一起，注册表就会反复拿 0 当 id 用（M1-3 实测踩到）。
func _int_field(unit: Node, field: String, fallback: int) -> int:
	var v = _get_unit_field(unit, field)
	if v == null:
		return fallback
	return int(v)


## 取 bool 字段，缺失时用默认值（同样避开 bool(null) 的构造问题）
func _bool_field(unit: Node, field: String, fallback: bool) -> bool:
	var v = _get_unit_field(unit, field)
	if v == null:
		return fallback
	return bool(v)


func _set_unit_field(unit: Node, field: String, value: Variant) -> void:
	if unit == null:
		return
	# 有该属性就直接写属性（真实单位走这条），否则写 meta（替身节点走这条）
	var wrote := false
	for p in unit.get_property_list():
		if String(p.get("name", "")) == field:
			wrote = true
			break
	if wrote:
		unit.set(field, value)
	else:
		unit.set_meta(field, value)


# ---------------------------------------------------------------------------
# 注册 / 注销
# ---------------------------------------------------------------------------

## 登记一个单位。若它还没有 entity_id 就分配一个。返回分配到的 id。
func register_unit(unit: Node) -> int:
	if unit == null:
		return 0
	var existing := _int_field(unit, "entity_id", 0)
	if existing <= 0:
		var new_id := _next_id
		_next_id += 1
		_set_unit_field(unit, "entity_id", new_id)
		existing = new_id
	units[existing] = unit
	return existing


## 注销（单位死亡时调用）。**立刻**退出一切查询，这样索敌与胜负检查都不会
## 再看到它。节点本身仍在场景树里（尸体保留，见详设 04 的 4.4）。
func unregister_unit(entity_id: int) -> void:
	units.erase(entity_id)


func register_projectile(p: Node) -> void:
	if p == null:
		return
	projectiles[p.get_instance_id()] = p


func unregister_projectile(p: Node) -> void:
	if p == null:
		return
	projectiles.erase(p.get_instance_id())


## 清空全部登记（重置关卡用）
func clear() -> void:
	units.clear()
	projectiles.clear()
	_next_id = 1


# ---------------------------------------------------------------------------
# 基础查询
# ---------------------------------------------------------------------------

## 按升序返回全部已登记单位的 id
func unit_ids_sorted() -> Array:
	var ids: Array = []
	for k in units.keys():
		ids.append(int(k))
	ids.sort()
	return ids


## 按升序返回全部已登记单位
func units_sorted() -> Array:
	var out: Array = []
	for id in unit_ids_sorted():
		out.append(units[id])
	return out


func find_unit(entity_id: int) -> Node:
	var u = units.get(entity_id)
	if u is Node:
		return u
	return null


## 求一个单位的位置（**逻辑坐标**）。取不到时返回 null。
## 优先读单位自己的 position_logic；没有则从 Node2D 的世界坐标按 TILE_PX 换算。
func unit_position(unit: Node) -> Variant:
	if unit == null:
		return null
	var p = _get_unit_field(unit, "position_logic")
	if p is Vector2:
		return p
	if unit is Node2D:
		var n2d := unit as Node2D
		var per_tile := 64.0
		var declared = _get_unit_field(unit, "tile_px")
		if declared is float and float(declared) > 0.0:
			per_tile = float(declared)
		return n2d.global_position / per_tile
	return null


func unit_team(unit: Node) -> int:
	if unit == null:
		return -1
	return _int_field(unit, "team", -1)


func is_unit_dead(unit: Node) -> bool:
	if unit == null:
		return true
	return _bool_field(unit, "is_dead", false)


## 某个阵营还有多少存活单位（「全歼敌人」「我方全灭」条件用）
func alive_count(team: int) -> int:
	var n := 0
	for id in unit_ids_sorted():
		var u: Node = units[id]
		if unit_team(u) == team and not is_unit_dead(u):
			n += 1
	return n


# ---------------------------------------------------------------------------
# 敌方查询（视野条件与开火目标共用同一口径）
# ---------------------------------------------------------------------------

## 返回 from_unit 半径内、距离 <= radius 的所有**敌方**单位，
## 按距离升序、同距按 id 升序。这是「最近敌人」的唯一实现，别在别处再写一遍。
func query_enemies_in_radius(from_unit: Node, radius: float) -> Array:
	var out: Array = []
	if from_unit == null:
		return out
	var from_pos = unit_position(from_unit)
	if from_pos == null:
		return out
	var my_team := unit_team(from_unit)
	var origin := from_pos as Vector2

	var hits: Array = []
	for id in unit_ids_sorted():
		var u: Node = units[id]
		if u == from_unit:
			continue
		if unit_team(u) == my_team or is_unit_dead(u):
			continue
		var up = unit_position(u)
		if up == null:
			continue
		var d: float = (up as Vector2).distance_to(origin)
		if d <= radius:
			hits.append({"id": id, "unit": u, "dist": d})

	# 距离升序；同距按 id 升序 —— 保证结果确定（FR-CBT-03 / FR-TEST-08）
	for h in hits:
		if _debug_trace:
			print("   [bs] 候选 id=%d dist=%.3f" % [int(h["id"]), float(h["dist"])])
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a["dist"])
		var db := float(b["dist"])
		if not is_equal_approx(da, db):
			return da < db
		return int(a["id"]) < int(b["id"]))
	if _debug_trace:
		for h in hits:
			print("   [bs] 排序后 id=%d dist=%.3f" % [int(h["id"]), float(h["dist"])])

	for h in hits:
		out.append(h["unit"])
	return out


## 视野内最近的敌人；没有则返回 null
func query_nearest_enemy(from_unit: Node, radius: float) -> Node:
	var list := query_enemies_in_radius(from_unit, radius)
	if list.is_empty():
		return null
	var first = list[0]
	if first is Node:
		return first
	return null


## 视野内是否有敌人（「视野内出现敌人」条件用）
func has_enemy_in_radius(from_unit: Node, radius: float) -> bool:
	return not query_enemies_in_radius(from_unit, radius).is_empty()


## 视野内是否有持有 / 不持有某状态的敌人（ENEMY_HAS_STATUS 条件用）。
## 口径是「**任一**敌人」而不是「最近敌人」——避免引入「单位记忆目标」的状态。
func query_any_enemy_with_status(from_unit: Node, status: String, want: bool, radius: float) -> bool:
	for u in query_enemies_in_radius(from_unit, radius):
		if _unit_has_status(u, status) == want:
			return true
	return false


func _unit_has_status(unit: Node, status: String) -> bool:
	if unit == null:
		return false
	match status:
		"slowed":
			# 减速状态就存在单位自己身上（`UnitActor.is_slowed`）。
			#
			# 【曾经有一条 `unit.health.is_slowed()` 的兼容分支，已删除】
			# 那分支要求单位上挂一个 `health` 字段，而**没有任何地方挂过** ——
			# 即永远不可能触发。**"跑不到的兼容分支"比没有分支更糟**：
			# 它看起来是一种保障，实际是没人测过、也没人走过的代码。
			#
			# 【注意】一律经 _bool_field 取值：直接 bool(_get_unit_field(...))
			# 会在字段缺失时变成 bool(null)，触发 "Nonexistent 'bool' constructor"
			# 并静默返回 false（M1-4 实测踩到）。
			#
			# 取值优先级：属性 > meta。UnitActor 自己声明了 is_slowed 属性，
			# 所以往节点上 set_meta("is_slowed", …) 是**读不到**的（属性优先），
			# 测试里要改状态请用 UnitActor.set_slowed()（M2 实测踩到）。
			return _bool_field(unit, "is_slowed", false)
		_:
			return false
