class_name PlaytestRecord
extends RefCounted
## 试玩记录（03 §10 / 关卡册 9.3）：关卡版本、部署、指令、倍速、结果、时间、损失、目标生命。
## 第三阶段起只给脚本化试玩（tools/run_playtests）使用；游戏内的"导出本局记录"已删除（10 §6.1）。


## placements: slot_id -> Vector2i；rules: slot_id -> Array[RuleDef]；beacons: slot_id -> Array[{ id, cell }]（07 §3，有信标时才写入记录）
static func build(level: LevelDefinition, world: SimWorld, placements: Dictionary, rules: Dictionary, speed: int, notes: String = "", beacons: Dictionary = {}) -> Dictionary:
	var deploy: Dictionary = {}
	for sid: String in placements.keys():
		deploy[sid] = DataReader.cell_to_array(placements[sid] as Vector2i)
	var rule_dicts: Dictionary = {}
	for sid: String in rules.keys():
		var arr: Array[RuleDef] = []
		arr.assign(rules[sid] as Array)
		rule_dicts[sid] = RuleDef.to_array(arr)
	var losses: Array = []
	for u: SimUnit in world.units:
		if u.faction == SimTypes.Faction.ALLY and u.kind == SimTypes.UnitKind.UNIT and not u.alive:
			losses.append(u.spawn_id)
	var objective_hp: Dictionary = {}
	for o: ObjectiveDef in level.win + level.lose:
		for sid: String in o.referenced_ids():
			var t: SimUnit = world.get_spawn(sid)
			if t != null:
				objective_hp[sid] = maxf(t.hp, 0.0)
	var record: Dictionary = {
		"level_id": level.id, "level_version": level.schema_version, "data_version": "units.json@%d" % level.schema_version,
		"deploy": deploy, "rules": rule_dicts, "speed": speed,
		"result": str(SimTypes.BattleResult.keys()[world.result]).to_lower(), "time": world.clock.time,
		"losses": losses, "objective_hp": objective_hp, "notes": notes,
	}
	var beacon_dicts: Dictionary = {}
	for sid: String in beacons.keys():
		var arr: Array[Dictionary] = []
		arr.assign(beacons[sid] as Array)
		if not arr.is_empty():
			beacon_dicts[sid] = BattleController.beacons_to_raw(arr)
	if not beacon_dicts.is_empty():
		record["beacons"] = beacon_dicts
	return record

