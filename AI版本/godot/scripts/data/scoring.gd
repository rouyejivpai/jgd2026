class_name Scoring
extends RefCounted
## 结算综合分（策划案 3.6；详细设计 08）：四项相加，越低越好。系数在 data/scoring.json（可配平，不改代码）。
##   所用人数 × units + （行为数 + 条件数）× complexity + 信标数 × beacons + 用时 × time
## 只在胜利时计算；行为 / 条件统计全部已启用指令（含被同组更高优先级覆盖、未生效的），信标按本局实际放置的个数，
## 用时取游戏内时间（1× / 2× 结果一致）。

const FILE: String = "res://data/scoring.json"
const KEYS: Array[String] = ["units", "complexity", "beacons", "time"]

static var _coef: Dictionary = {}


static func coefficients() -> Dictionary:
	if _coef.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		var d: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
		for k: String in KEYS:
			_coef[k] = float(d.get(k, 1.0 if k == "time" else 10.0))
	return _coef


## 由已部署的单位、指令与信标、用时算出明细与总分
static func compute(units: int, actions: int, conditions: int, beacons: int, seconds: float) -> Dictionary:
	var c: Dictionary = coefficients()
	var parts: Dictionary = {
		"units": float(units) * float(c["units"]),
		"complexity": float(actions + conditions) * float(c["complexity"]),
		"beacons": float(beacons) * float(c["beacons"]),
		"time": seconds * float(c["time"]),
	}
	var total: float = 0.0
	for k: String in KEYS:
		total += float(parts[k])
	return { "unit_count": units, "action_count": actions, "condition_count": conditions, "beacon_count": beacons,
		"seconds": seconds, "parts": parts, "total": int(round(total)) }


## 本局（胜利时）：统计 controller 上已部署单位的指令与信标
static func from_controller(c: BattleController) -> Dictionary:
	var units: int = 0
	var actions: int = 0
	var conditions: int = 0
	var beacons: int = 0
	for uid: String in c.uids():
		if not c.placements.has(uid):
			continue
		units += 1
		for r: RuleDef in c.get_rules(uid):
			if not r.enabled:
				continue
			actions += 1 if r.action != null else 0
			conditions += r.conditions.size()
		beacons += c.get_beacons(uid).size()
	return compute(units, actions, conditions, beacons, c.world.clock.time)
