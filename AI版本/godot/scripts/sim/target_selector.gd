class_name TargetSelector
extends RefCounted
## 目标候选与选敌（01 §6.5）。
## 候选：对立阵营、存活、filter 匹配、中心距 ≤ 视野（圆形感知，无视线遮挡）。
## 排序：主排序 → seen_order 升序 → unit id 升序；浮点距离用 is_equal_approx 视为同距。

const _UNSEEN: int = 1 << 30


static func is_hostile(a: int, b: int) -> bool:
	return (a == SimTypes.Faction.ALLY and b == SimTypes.Faction.ENEMY) or (a == SimTypes.Faction.ENEMY and b == SimTypes.Faction.ALLY)


static func filter_match(kind: int, filter: int) -> bool:
	match filter:
		SimTypes.TargetFilter.UNIT:
			return kind == SimTypes.UnitKind.UNIT
		SimTypes.TargetFilter.STRUCTURE:
			return kind == SimTypes.UnitKind.STRUCTURE
	return true


## 是否为对 unit 有效的可见候选
static func is_candidate(unit: SimUnit, e: SimSnapshot.Entry, filter: int) -> bool:
	return e != null and e.alive and is_hostile(unit.faction, e.faction) and filter_match(e.kind, filter) \
		and unit.pos.distance_to(e.pos) <= unit.vision + SimTypes.DIST_EPS


static func visible_candidates(unit: SimUnit, filter: int, snap: SimSnapshot) -> Array[int]:
	var out: Array[int] = []
	for oid: int in snap.ids:
		if is_candidate(unit, snap.get_entry(oid), filter):
			out.append(oid)
	return out


## 按 selector 排序（first_seen 按 seen_order）
static func sort_candidates(unit: SimUnit, ids: Array[int], selector: int, snap: SimSnapshot) -> Array[int]:
	var sorted: Array[int] = ids.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool: return _less(unit, a, b, selector, snap))
	return sorted


static func _less(unit: SimUnit, a: int, b: int, selector: int, snap: SimSnapshot) -> bool:
	var ea: SimSnapshot.Entry = snap.get_entry(a)
	var eb: SimSnapshot.Entry = snap.get_entry(b)
	if selector != SimTypes.Selector.FIRST_SEEN:
		var ka: float = 0.0
		var kb: float = 0.0
		match selector:
			SimTypes.Selector.NEAREST:
				ka = unit.pos.distance_to(ea.pos)
				kb = unit.pos.distance_to(eb.pos)
			SimTypes.Selector.FARTHEST:
				ka = -unit.pos.distance_to(ea.pos)
				kb = -unit.pos.distance_to(eb.pos)
			SimTypes.Selector.LOWEST_HP:
				ka = ea.hp
				kb = eb.hp
			SimTypes.Selector.HIGHEST_MAX_HP:   # 按血量上限（不随受伤变化）→ 锁定大目标后不转火
				ka = -ea.max_hp
				kb = -eb.max_hp
		if not is_equal_approx(ka, kb):
			return ka < kb
	var sa: int = int(unit.seen_order.get(a, _UNSEEN))
	var sb: int = int(unit.seen_order.get(b, _UNSEEN))
	if sa != sb:
		return sa < sb
	return a < b


## 规则选敌：返回排序后的候选。first_seen：锁定有效 → 仅含锁定目标；否则取 seen_order 最小者写入锁定。
static func resolve(unit: SimUnit, target: TargetDef, snap: SimSnapshot) -> Array[int]:
	if target.selector == SimTypes.Selector.FIRST_SEEN:
		if unit.lock_target >= 0:
			if is_candidate(unit, snap.get_entry(unit.lock_target), target.filter):
				return [unit.lock_target]
			unit.lock_target = -1       # 死亡/离开视野/不再敌对/不符合本条 filter → 锁定失效（01 §6.5）
		var cands: Array[int] = sort_candidates(unit, visible_candidates(unit, target.filter, snap), SimTypes.Selector.FIRST_SEEN, snap)
		if cands.is_empty():
			return []
		unit.lock_target = cands[0]
		return [cands[0]]
	return sort_candidates(unit, visible_candidates(unit, target.filter, snap), target.selector, snap)
