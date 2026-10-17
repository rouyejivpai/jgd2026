extends RefCounted
## run_playtests.gd 的实现（运行时加载，可引用自动加载）。
## 第三阶段 P0：记录写入 state_hash（1× 终局）；基线 tools/playtest_baseline.json（每场景 result / time / losses / hash）。
## 用户参数（Godot 命令行 `--` 之后）：
##   （无）              运行全部场景，写 docs/playtests/*.json
##   --check             与基线逐场景比对，不写记录；有差异时逐行打印并以非零退出
##   --update-baseline   运行后把本次结果写成新基线（只在有意改变模拟结果、并已记 CHANGELOG 时使用）

const SCENARIOS_PATH: String = "res://tools/playtest_scenarios.json"
const BASELINE_PATH: String = "res://tools/playtest_baseline.json"
const MAX_SECONDS: float = 60.0
const TIME_TOLERANCE: float = 1e-4
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible", "signal_is"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen", "highest_max_hp"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer", "hexer", "binder"],
}

var _library: Dictionary = {}
var _rules_format: String = "legacy"     ## 场景文件的指令口径（第五阶段；缺省 legacy = 旧单列表，运行前折算）


func run() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var check: bool = args.has("--check")
	var update: bool = args.has("--update-baseline")
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS_PATH)) as Dictionary
	_library = root.get("rule_library", {}) as Dictionary
	_rules_format = str(root.get("rules_format", "legacy"))
	var out_dir: String = ProjectSettings.globalize_path("res://").path_join("../docs/playtests").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED      # 场景按"已玩到该关"的解锁状态运行
	var failures: int = 0
	var rows: Array = []
	print("level     | kind          | result | time   | losses | 1x/2x | hash        | objective_hp")
	for raw: Variant in root.get("scenarios", []) as Array:
		var sc: Dictionary = raw as Dictionary
		var r1: Dictionary = _play(sc, 1)
		var r2: Dictionary = _play(sc, 2)
		if r1.is_empty() or r2.is_empty():
			failures += 1
			continue
		var same: bool = r1["result"] == r2["result"] and is_equal_approx(float(r1["time"]), float(r2["time"])) and r1["_hash"] == r2["_hash"]
		var record: Dictionary = r1["record"] as Dictionary
		record["notes"] = "%s；2× 复核：%s" % [str(sc.get("note", "")), "一致" if same else "不一致"]
		record["state_hash"] = int(r1["_hash"])
		rows.append({ "level": str(sc["level"]), "kind": str(sc["kind"]), "result": str(record["result"]), "time": float(record["time"]),
			"losses": (record["losses"] as Array).duplicate(), "hash": int(r1["_hash"]) })
		if not check:
			var path: String = out_dir.path_join("%s_%s.json" % [str(sc["level"]), str(sc["kind"])])
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(record, "  ", false) + "\n")
			f.close()
		print("%s | %-13s | %-6s | %5.2fs | %-6s | %-5s | %-11d | %s" % [sc["level"], sc["kind"], record["result"], float(record["time"]),
			str((record["losses"] as Array).size()), "ok" if same else "DIFF", int(r1["_hash"]), JSON.stringify(record["objective_hp"])])
		if not same:
			failures += 1
	GameState.unlocks = saved_unlocks
	print("[run_playtests] %d scenarios, %d problems -> %s" % [(root.get("scenarios", []) as Array).size(), failures, "(check only)" if check else out_dir])
	if check:
		var diffs: int = compare_with_baseline(rows, load_baseline())
		print("[run_playtests --check] %s" % ("all %d scenarios identical to baseline" % rows.size() if diffs == 0 else "%d difference(s) from baseline" % diffs))
		failures += diffs
	if update:
		save_baseline(rows)
		print("[run_playtests] baseline written: %s" % ProjectSettings.globalize_path(BASELINE_PATH))
	return 0 if failures == 0 else 1


static func load_baseline() -> Array:
	if not FileAccess.file_exists(BASELINE_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	return (parsed as Dictionary).get("scenarios", []) as Array if parsed is Dictionary else []


static func save_baseline(rows: Array) -> void:
	var doc: Dictionary = {
		"_comment": "run_playtests 基线（第三阶段 P0）：每个场景 1× 终局的 result / time / losses / state_hash。`-- --check` 与本文件逐项比对；只有在有意改变模拟结果并记入 CHANGELOG 后才用 `-- --update-baseline` 重写。",
		"scenarios": rows,
	}
	var f: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false) + "\n")
	f.close()


## 逐场景比对，打印每处差异，返回差异条数（缺失 / 多出的场景各算一条）
static func compare_with_baseline(rows: Array, baseline: Array) -> int:
	if baseline.is_empty():
		print("  baseline missing or empty: %s" % BASELINE_PATH)
		return 1
	var diffs: int = 0
	var by_key: Dictionary = {}
	for b: Variant in baseline:
		var bd: Dictionary = b as Dictionary
		by_key["%s/%s" % [bd["level"], bd["kind"]]] = bd
	var seen: Dictionary = {}
	for r: Variant in rows:
		var rd: Dictionary = r as Dictionary
		var key: String = "%s/%s" % [rd["level"], rd["kind"]]
		seen[key] = true
		if not by_key.has(key):
			print("  %s: not in baseline" % key)
			diffs += 1
			continue
		var bd: Dictionary = by_key[key] as Dictionary
		if str(bd["result"]) != str(rd["result"]):
			print("  %s: result %s -> %s" % [key, bd["result"], rd["result"]])
			diffs += 1
		if absf(float(bd["time"]) - float(rd["time"])) > TIME_TOLERANCE:
			print("  %s: time %.4f -> %.4f" % [key, float(bd["time"]), float(rd["time"])])
			diffs += 1
		if JSON.stringify(bd["losses"]) != JSON.stringify(rd["losses"]):
			print("  %s: losses %s -> %s" % [key, JSON.stringify(bd["losses"]), JSON.stringify(rd["losses"])])
			diffs += 1
		if int(bd["hash"]) != int(rd["hash"]):
			print("  %s: hash %d -> %d" % [key, int(bd["hash"]), int(rd["hash"])])
			diffs += 1
	for key: String in by_key.keys():
		if not seen.has(key):
			print("  %s: missing from this run" % key)
			diffs += 1
	return diffs


func _play(sc: Dictionary, speed: int) -> Dictionary:
	var level: LevelDefinition = DataRegistry.get_level(str(sc["level"]))
	var c := BattleController.new()
	c.setup(level)
	# P3 单位列表：free 关依次 add_unit（u1、u2…），fixed 关按 slot 放置；每个单位必须显式给出 rules
	for raw: Variant in sc.get("units", []) as Array:
		var u: Dictionary = raw as Dictionary
		var pa: Array = u["pos"] as Array
		var pos := Vector2i(int(pa[0]), int(pa[1]))
		var uid: String = ""
		if level.is_free():
			uid = c.add_unit(str(u["form"]), pos)
		elif c.place_unit(str(u.get("slot", "")), pos):
			uid = str(u["slot"])
		if uid == "" or not u.has("rules"):
			push_error("[run_playtests] %s/%s: cannot place %s or rules missing" % [sc["level"], sc["kind"], str(u)])
			c.free()
			return {}
		if u.has("copy_route"):
			c.copy_route_to_beacons(uid, str(u["copy_route"]))
		for cell: Variant in u.get("beacons", []) as Array:
			c.add_beacon(uid, Vector2i(int((cell as Array)[0]), int((cell as Array)[1])))
		var rules: Array[RuleDef] = _rules_from(u["rules"] as Array)
		for r: RuleDef in rules:
			if bool(sc.get("enable_all", false)):
				r.enabled = true
			if (sc.get("disable_actions", []) as Array).has(SimTypes.action_to_string(r.action.type)):
				r.enabled = false
		if _rules_format != "dual":
			rules = RuleDef.migrate_legacy(rules)     # 第五阶段：场景按旧单列表口径编写，折算为双组口径
		c.set_rules(uid, rules)
	c.set_speed(speed)
	if not c.start():
		push_error("[run_playtests] %s/%s: start() rejected: %s" % [sc["level"], sc["kind"], str(c.last_problems)])
		c.free()
		return {}
	var max_ticks: int = int(ceil(MAX_SECONDS / SimTypes.SIM_DT / float(speed)))
	for i: int in max_ticks:
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
	var record: Dictionary = PlaytestRecord.build(level, c.world, c.placements, c.slot_rules, speed, "", c.slot_beacons)
	var out: Dictionary = { "record": record, "result": record["result"], "time": record["time"], "_hash": c.world.state_hash() }
	c.free()
	return out


func _rules_from(arr: Array) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for item: Variant in arr:
		var key: String = str(item)
		var d: Dictionary
		if key.begins_with("route:") or key.begins_with("route_loop:"):
			d = { "conditions": [], "action": { "type": "follow_route", "route_id": key.get_slice(":", 1), "loop": key.begins_with("route_loop:") } }
		elif key.begins_with("beacons_"):      # beacons_<once|loop|pingpong>:<from>
			d = { "conditions": [], "action": { "type": "follow_beacons", "mode": key.get_slice(":", 0).trim_prefix("beacons_"), "from": key.get_slice(":", 1) } }
		elif key.begins_with("wait_at:"):      # wait_at:<信标>:<秒>
			d = { "conditions": [{ "type": "at_beacon", "beacon": key.get_slice(":", 1) }], "action": { "type": "wait", "seconds": float(key.get_slice(":", 2)) } }
		else:
			d = (_library[key] as Dictionary).duplicate(true)
		out.append(RuleDef.from_dict(d, "playtest"))
	return out
