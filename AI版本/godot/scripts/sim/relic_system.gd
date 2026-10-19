class_name RelicSystem
extends RefCounted
## 遗物在模拟中的效果（data/relics.json）。只由玩家点按触发，不参与 RuleEvaluator；地块为空、未使用时不改变任何模拟结果。
## - tile（提灯 / 骨臂）：world.relic_tiles 中的格，每步给站在上面的敌方非建筑单位刷新状态（离开后残留 seconds 秒）。
## - strike（骨刃）：立即对一名敌人结算伤害（吃易伤倍率），死亡与胜负按常规事件 / 判定处理。
## - heal（徽章）：立即为一名己方单位回复生命（不超过上限）。


## 第 4b 步（StatusSystem.tick 内，地形格之后）：遗物地块
static func tick_tiles(world: SimWorld) -> void:
	if world.relic_tiles.is_empty():
		return
	for u: SimUnit in world.units:
		if not u.alive or u.is_structure() or u.faction != SimTypes.Faction.ENEMY:
			continue
		var t: Variant = world.relic_tiles.get(u.cell(), null)
		if t == null:
			continue
		var d: Dictionary = t as Dictionary
		u.add_status(str(d["status"]), float(d["seconds"]))


## 把遗物地块写进世界：center 周围 radius 圈内、网格内且非障碍的格
static func apply_tile(world: SimWorld, level: LevelDefinition, relic_id: String, def: Dictionary, center: Vector2i) -> void:
	for c: Vector2i in tile_cells(level, center, int(def.get("radius", 1))):
		world.relic_tiles[c] = { "relic": relic_id, "status": str(def.get("status", "")), "seconds": float(def.get("status_seconds", 1.0)) }


static func tile_cells(level: LevelDefinition, center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var c := Vector2i(center.x + dx, center.y + dy)
			if level.in_bounds(c) and not level.is_blocked(c):
				out.append(c)
	return out


## 骨刃：立即结算伤害；返回实际伤害（目标无效为 -1）
static func strike(world: SimWorld, relic_id: String, target_id: int, amount: float) -> float:
	var t: SimUnit = world.get_unit(target_id)
	if t == null or not t.alive or t.faction != SimTypes.Faction.ENEMY:
		return -1.0
	var dmg: float = amount * StatusSystem.damage_mult(world, t)
	t.hp -= dmg
	world.emit_event(SimTypes.EventType.RELIC_USED, { "relic": relic_id, "kind": "strike", "target": t.id, "amount": dmg })
	world.emit_event(SimTypes.EventType.DAMAGE_APPLIED, { "target": t.id, "amount": dmg, "source": -1, "hp_after": t.hp })
	if t.hp <= 0.0:
		t.alive = false
		t.path.clear()
		world.emit_event(SimTypes.EventType.UNIT_DIED, { "unit": t.id, "killer": -1 })
		for u: SimUnit in world.units:
			if u.lock_target == t.id:
				u.lock_target = -1
	ObjectiveSystem.evaluate(world)
	return dmg


## 徽章：立即回复；返回实际回复量（目标无效为 -1）
static func heal(world: SimWorld, relic_id: String, target_id: int, amount: float) -> float:
	var t: SimUnit = world.get_unit(target_id)
	if t == null or not t.alive or t.faction != SimTypes.Faction.ALLY or t.is_structure():
		return -1.0
	var gain: float = minf(amount, t.max_hp - t.hp)
	t.hp += gain
	world.emit_event(SimTypes.EventType.RELIC_USED, { "relic": relic_id, "kind": "heal", "target": t.id, "amount": gain })
	return gain
