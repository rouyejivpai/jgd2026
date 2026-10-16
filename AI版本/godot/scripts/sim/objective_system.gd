class_name ObjectiveSystem
extends RefCounted
## 胜负判定（01 §6.9）：每步在伤害与死亡之后评估，失败优先于胜利。
## 同时输出 UI 进度：剩余秒数、保护对象生命、"威胁已清除"。


static func evaluate(world: SimWorld) -> void:
	_update_progress(world)
	if world.result != SimTypes.BattleResult.NONE:
		return
	for o: ObjectiveDef in world.lose_objectives:
		if _met(o, world):
			_finish(world, SimTypes.BattleResult.LOSE, o.id)
			return
	for o: ObjectiveDef in world.win_objectives:
		if _met(o, world):
			_finish(world, SimTypes.BattleResult.WIN, o.id)
			return


static func _finish(world: SimWorld, result: int, objective_id: String) -> void:
	world.result = result
	world.result_objective = objective_id
	world.emit_event(SimTypes.EventType.BATTLE_ENDED, { "result": result, "reason": SimTypes.ReasonCode.OK, "objective": objective_id })


static func _met(o: ObjectiveDef, world: SimWorld) -> bool:
	match o.type:
		SimTypes.ObjectiveType.ANNIHILATE:
			return enemies_cleared(world)
		SimTypes.ObjectiveType.DESTROY:
			for sid: String in o.targets:
				var u: SimUnit = world.get_spawn(sid)
				if u != null and u.alive:
					return false
			return true
		SimTypes.ObjectiveType.SURVIVE:
			var p: SimUnit = world.get_spawn(o.target)
			return p != null and p.alive and world.clock.time >= o.seconds - SimTypes.TIME_EPS
		SimTypes.ObjectiveType.UNIT_DEAD:
			var t: SimUnit = world.get_spawn(o.target)
			return t != null and not t.alive
		SimTypes.ObjectiveType.ALL_ALLIES_DEAD:
			for u: SimUnit in world.units:
				if u.alive and u.faction == SimTypes.Faction.ALLY and u.kind == SimTypes.UnitKind.UNIT:
					return false
			return true
		SimTypes.ObjectiveType.REACH_ZONE:
			if o.target == ObjectiveDef.ANY_ALLY:      # 07 §9：任意己方单位（不含建筑）到达，满 count 名即成立
				var n: int = 0
				for u: SimUnit in world.units:
					if u.alive and u.faction == SimTypes.Faction.ALLY and u.kind == SimTypes.UnitKind.UNIT and o.cells.has(u.cell()):
						n += 1
				return n >= o.count
			var z: SimUnit = world.get_spawn(o.target)
			return z != null and z.alive and o.cells.has(z.cell())
		SimTypes.ObjectiveType.ESCORT:              # 07 §9：被护送者存活并到达区域（其死亡由关卡 lose 的 unit_dead 判负）
			var e: SimUnit = world.get_spawn(o.target)
			return e != null and e.alive and o.cells.has(e.cell())
	return false


## 全歼口径：counts_for_annihilate 的敌方"单位"（建筑不计）全部死亡
static func enemies_cleared(world: SimWorld) -> bool:
	for u: SimUnit in world.units:
		if u.alive and u.faction == SimTypes.Faction.ENEMY and u.kind == SimTypes.UnitKind.UNIT and u.counts_for_annihilate:
			return false
	return true


static func _update_progress(world: SimWorld) -> void:
	var prog: Dictionary = world.objective_progress
	for o: ObjectiveDef in world.win_objectives:
		if o.type == SimTypes.ObjectiveType.SURVIVE:
			prog["time_left"] = maxf(0.0, o.seconds - world.clock.time)
			var p: SimUnit = world.get_spawn(o.target)
			if p != null:
				prog["target_hp"] = p.hp
				prog["target_max_hp"] = p.max_hp
			var cleared: bool = enemies_cleared(world)
			if cleared and not bool(prog.get("threat_cleared", false)):
				world.emit_event(SimTypes.EventType.OBJECTIVE_PROGRESS, { "threat_cleared": true })
			prog["threat_cleared"] = cleared
