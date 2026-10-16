class_name BlastSystem
extends RefCounted
## 延迟爆炸的计时与结算（01 §6.2 第 2–3 步、§6.8）。


## 放置一个爆炸并发 blast_placed 事件
static func place(world: SimWorld, source: SimUnit, at: Vector2, tdef: TraitDefinition, target_id: int) -> SimBlast:
	var b := SimBlast.new()
	b.id = world.next_blast_id
	world.next_blast_id += 1
	b.pos = at
	b.radius = tdef.radius
	b.damage = tdef.damage
	b.delay = tdef.delay
	b.remaining = tdef.delay
	b.source = source.id
	b.source_faction = source.faction
	b.target = target_id
	world.blasts.append(b)
	world.emit_event(SimTypes.EventType.BLAST_PLACED, {
		"blast_id": b.id, "pos": b.pos, "radius": b.radius, "remaining": b.remaining, "source": b.source, "target": target_id,
	})
	return b


## 第 2 步：递减剩余时间，返回到期的爆炸（已从列表移除）
static func tick(world: SimWorld) -> Array[SimBlast]:
	var due: Array[SimBlast] = []
	var keep: Array[SimBlast] = []
	for b: SimBlast in world.blasts:
		b.remaining -= SimTypes.SIM_DT
		if b.remaining <= SimTypes.TIME_EPS:
			due.append(b)
		else:
			keep.append(b)
	world.blasts = keep
	return due


## 第 3 步：对半径内、与施放者敌对的存活单位结算伤害（入 damage_queue）
static func detonate(world: SimWorld, due: Array[SimBlast]) -> void:
	for b: SimBlast in due:
		var hits: Array[int] = []
		for u: SimUnit in world.units:
			if u.alive and TargetSelector.is_hostile(b.source_faction, u.faction) and u.pos.distance_to(b.pos) <= b.radius + SimTypes.DIST_EPS:
				world.queue_damage(b.source, u.id, b.damage)
				hits.append(u.id)
		world.emit_event(SimTypes.EventType.BLAST_DETONATED, { "blast_id": b.id, "pos": b.pos, "hits": hits })
