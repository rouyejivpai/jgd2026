extends RefCounted
## elite_probe.gd 的实现。场景格式（tools/elite_scenarios.json）：
## { "level": id, "kind": 名称, "expect": "WIN" | "LOSE",
##   "units": "recommended" | [ { form, pos: [x, y], beacons: [[x, y], …], rules: [规则字典…] } ],
##   "relics": [遗物 id…]（视为已获得）, "relic_tile": { relic, cell: [x, y] }（开战前放下）,
##   "relic_uses": [ { relic, at: 秒, target: 初始单位 id（spawn id）或 "ally:<序号>" } ] }
## 不满足 expect 的场景计为问题，退出码非零。

const SCENARIOS_PATH: String = "res://tools/elite_scenarios.json"
const MAX_SECONDS: float = 180.0
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible", "at_beacon", "signal_is"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen", "highest_max_hp"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route", "follow_beacons", "wait"],
	"forms": ["striker", "bulwark", "swift", "lancer", "hexer", "binder"],
	"presets": [],
	"relics": [],
}


func run() -> int:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS_PATH)) as Dictionary
	var saved: Dictionary = GameState.unlocks
	var problems: int = 0
	for raw: Variant in root.get("scenarios", []) as Array:
		var sc: Dictionary = raw as Dictionary
		if not only.is_empty() and not only.has(str(sc["level"])):
			continue
		var unlocks: Dictionary = ALL_UNLOCKED.duplicate(true)
		unlocks["relics"] = (sc.get("relics", []) as Array).duplicate()
		GameState.unlocks = unlocks
		var r: Dictionary = play(sc)
		var ok: bool = str(r.get("result", "")) == str(sc.get("expect", "WIN"))
		if not ok:
			problems += 1
		print("%-10s %-22s expect %-4s -> %-4s %6.1fs  %s  %s" % [sc["level"], sc["kind"], sc.get("expect", "WIN"), r.get("result", "?"), float(r.get("time", 0.0)),
			"ok " if ok else "BAD", str(r.get("hp", ""))])
	GameState.unlocks = saved
	print("[elite_probe] %d problem(s)" % problems)
	return 0 if problems == 0 else 1


static func play(sc: Dictionary) -> Dictionary:
	var level: LevelDefinition = DataRegistry.get_level(str(sc["level"]))
	if level == null:
		return { "result": "NO_LEVEL" }
	var c := BattleController.new()
	c.setup(level)
	var units: Variant = sc.get("units", "recommended")
	if units is String:
		c.apply_recommended()
	else:
		for raw: Variant in units as Array:
			var u: Dictionary = raw as Dictionary
			var pa: Array = u["pos"] as Array
			var uid: String = c.add_unit(str(u["form"]), Vector2i(int(pa[0]), int(pa[1])))
			if uid == "":
				c.free()
				return { "result": "PLACE_FAIL %s" % str(u) }
			for cell: Variant in u.get("beacons", []) as Array:
				c.add_beacon(uid, Vector2i(int((cell as Array)[0]), int((cell as Array)[1])))
			var rules: Array[RuleDef] = []
			for d: Variant in u.get("rules", []) as Array:
				rules.append(RuleDef.from_dict(d as Dictionary, "probe"))
			c.set_rules(uid, rules)
	if sc.has("relic_tile"):
		var t: Dictionary = sc["relic_tile"] as Dictionary
		var ca: Array = t["cell"] as Array
		if not c.place_relic_tile(str(t["relic"]), Vector2i(int(ca[0]), int(ca[1]))):
			c.free()
			return { "result": "RELIC_TILE_FAIL" }
	if not c.start():
		var out: Dictionary = { "result": "REJECTED %s" % str(c.last_problems) }
		c.free()
		return out
	var uses: Array = (sc.get("relic_uses", []) as Array).duplicate()
	for i: int in int(ceil(MAX_SECONDS / SimTypes.SIM_DT)):
		if c.phase != SimTypes.Phase.RUNNING:
			break
		for ru: Variant in uses.duplicate():
			var rd: Dictionary = ru as Dictionary
			if c.world.clock.time + 1e-6 >= float(rd["at"]):
				uses.erase(ru)
				var target: SimUnit = _target(c, str(rd["target"]))
				if target != null:
					c.use_relic_on(str(rd["relic"]), target.id)
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
		if bool(sc.get("trace", false)) and c.world.clock.steps % 60 == 0:
			print("    t=%5.1f  %s" % [c.world.clock.time, _hp_line(c)])
	var hp: PackedStringArray = PackedStringArray()
	for u: SimUnit in c.world.units:
		if u.alive and u.kind == SimTypes.UnitKind.UNIT:
			hp.append("%s%s:%d" % ["+" if u.faction == SimTypes.Faction.ALLY else "-", u.display_name, roundi(u.hp)])
	var res: Dictionary = { "result": str(SimTypes.BattleResult.keys()[c.world.result]), "time": c.world.clock.time, "hp": " ".join(hp) }
	c.free()
	return res


static func _hp_line(c: BattleController) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for u: SimUnit in c.world.units:
		if u.alive and u.kind == SimTypes.UnitKind.UNIT:
			parts.append("%s%s:%d@(%.1f,%.1f)" % ["+" if u.faction == SimTypes.Faction.ALLY else "-", u.display_name, roundi(u.hp), u.pos.x, u.pos.y])
	return " ".join(parts)


static func _target(c: BattleController, key: String) -> SimUnit:
	if key.begins_with("ally:"):
		var list: Array[String] = c.deployed_uids()
		var i: int = int(key.get_slice(":", 1))
		return c.world.get_unit(c.unit_id_of_slot(list[i])) if i < list.size() else null
	return c.world.get_spawn(key)
