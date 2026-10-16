class_name TraitSystem
extends RefCounted
## 特性（01 §6.2 第 9 步、§6.8）：delayed_blast 冷却完毕且存在合法目标 → 在目标当时位置放置爆炸。
## 冷却初值 = first_delay；之后每次放置后 = cooldown。


static func tick(world: SimWorld) -> void:
	var snap: SimSnapshot = null
	for u: SimUnit in world.units:
		if not u.alive or u.def == null or u.def.traits.is_empty():
			continue
		for trait_id: String in u.def.traits:
			var tdef: TraitDefinition = world.traits.get(trait_id, null) as TraitDefinition
			if tdef == null or tdef.type != SimTypes.TraitType.DELAYED_BLAST:
				continue
			var cd: float = float(u.trait_state.get(trait_id, tdef.first_delay))
			cd = maxf(0.0, cd - SimTypes.SIM_DT)
			u.trait_state[trait_id] = cd
			if cd > SimTypes.TIME_EPS:
				continue
			if snap == null:
				snap = world.make_snapshot()   # 第 7 步移动之后的位置
			var max_dist: float = tdef.place_range if tdef.place_range > 0.0 else u.vision
			var cands: Array[int] = []
			for cid: int in TargetSelector.visible_candidates(u, tdef.filter, snap):
				if u.pos.distance_to(snap.get_entry(cid).pos) <= max_dist + SimTypes.DIST_EPS:
					cands.append(cid)
			if cands.is_empty():
				continue
			var chosen: int = TargetSelector.sort_candidates(u, cands, tdef.selector, snap)[0]
			BlastSystem.place(world, u, snap.get_entry(chosen).pos, tdef, chosen)
			u.trait_state[trait_id] = tdef.cooldown
