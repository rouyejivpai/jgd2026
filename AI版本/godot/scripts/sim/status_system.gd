class_name StatusSystem
extends RefCounted
## 异常状态（易伤 / 麻痹 / 减速）与地形效果格（危险区 / 缓滞带 / 净化台）的结算。
## 口径（2026-10-12 评审后统一，见《规则统一页》）：
##   易伤 vulnerable：受到伤害 ×1.5，6 秒；再次施加刷新时长，不叠加。
##   麻痹 paralysis ：3 秒内攻击不出手（不造成伤害、不进入冷却），仍可移动、仍按指令行动。
##   减速 slow      ：移速 ×0.6，5 秒（光环为"在圈内持续生效、离开即失效"）。
##   危险区 hazard  ：站在上面每步刷新 6 秒易伤（离开后再持续 6 秒）。敌我通用。
##   缓滞带 mire    ：站在上面移速 ×0.5（与减速相乘）。敌我通用。
##   净化台 shrine  ：仅我方；站上去立即清除全部异常状态。
## 寻路代价：危险区 ×4、缓滞带 ×2（单位不会无故穿过有代价的格子，但必要时仍会走）。

const AURA_LINGER: float = 0.2          ## 光环施加的状态在离开光环后残留的秒数（略大于一步，避免逐步闪烁）
const TILE_WEIGHT: Dictionary = { "hazard": 4.0, "mire": 2.0 }


## 第 4 步之后调用：状态计时 → 地形格 → 光环
static func tick(world: SimWorld) -> void:
	for u: SimUnit in world.units:
		if not u.alive:
			continue
		for s: Variant in u.statuses.keys():
			var rem: float = float(u.statuses[s]) - SimTypes.SIM_DT
			if rem <= SimTypes.TIME_EPS:
				u.statuses.erase(s)
			else:
				u.statuses[s] = rem
	for u: SimUnit in world.units:
		if not u.alive or u.is_structure():
			continue
		var kind: String = world.tile_at(u.cell())
		if kind == "":
			continue
		var tdef: TraitDefinition = world.traits.get("tile_" + kind, null) as TraitDefinition
		if tdef == null:
			continue
		if tdef.affects == "ally_only" and u.faction != SimTypes.Faction.ALLY:
			continue
		if tdef.status != "":
			u.add_status(tdef.status, status_duration(world, tdef.status, tdef.duration))
		for c: String in tdef.clears:
			u.statuses.erase(c)
	for src: SimUnit in world.units:
		if not src.alive or src.def == null:
			continue
		for trait_id: String in src.def.traits:
			var tdef: TraitDefinition = world.traits.get(trait_id, null) as TraitDefinition
			if tdef == null or tdef.type != SimTypes.TraitType.AURA_STATUS:
				continue
			for v: SimUnit in world.units:
				if v.alive and not v.is_structure() and TargetSelector.is_hostile(src.faction, v.faction) \
						and src.pos.distance_to(v.pos) <= tdef.aura_radius + SimTypes.DIST_EPS:
					v.add_status(tdef.status, AURA_LINGER)


## 状态时长：显式给出优先，否则取状态定义的 duration
static func status_duration(world: SimWorld, status: String, explicit: float) -> float:
	if explicit > 0.0:
		return explicit
	var sdef: TraitDefinition = world.traits.get(status, null) as TraitDefinition
	return sdef.duration if sdef != null else 0.0


## 受伤倍率（结算时读取目标当前状态）
static func damage_mult(world: SimWorld, u: SimUnit) -> float:
	var m: float = 1.0
	for s: Variant in u.statuses.keys():
		var sdef: TraitDefinition = world.traits.get(str(s), null) as TraitDefinition
		if sdef != null and sdef.type == SimTypes.TraitType.STATUS:
			m *= sdef.damage_taken_mult
	return m


## 当前移速倍率：状态 × 所在地形格
static func speed_mult(world: SimWorld, u: SimUnit) -> float:
	var m: float = 1.0
	for s: Variant in u.statuses.keys():
		var sdef: TraitDefinition = world.traits.get(str(s), null) as TraitDefinition
		if sdef != null and sdef.type == SimTypes.TraitType.STATUS:
			m *= sdef.move_speed_mult
	var kind: String = world.tile_at(u.cell())
	if kind != "":
		var tdef: TraitDefinition = world.traits.get("tile_" + kind, null) as TraitDefinition
		if tdef != null:
			m *= tdef.move_speed_mult
	return m


## 是否被封攻击（麻痹）
static func attack_blocked(world: SimWorld, u: SimUnit) -> bool:
	for s: Variant in u.statuses.keys():
		var sdef: TraitDefinition = world.traits.get(str(s), null) as TraitDefinition
		if sdef != null and sdef.blocks_attack:
			return true
	return false


## 命中附加：攻击者的 on_hit_status 特性 → 目标获得状态（在本次伤害结算之后生效，本次命中不吃易伤加成）
static func on_hit(world: SimWorld, attacker: SimUnit, target: SimUnit) -> void:
	if attacker == null or attacker.def == null or target == null or not target.alive:
		return
	for trait_id: String in attacker.def.traits:
		var tdef: TraitDefinition = world.traits.get(trait_id, null) as TraitDefinition
		if tdef != null and tdef.type == SimTypes.TraitType.ON_HIT_STATUS:
			target.add_status(tdef.status, status_duration(world, tdef.status, tdef.duration))
