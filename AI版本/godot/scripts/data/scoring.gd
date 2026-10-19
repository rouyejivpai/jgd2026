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


## 分数构成的多行说明（悬停提示用）：综合分 + 四项「数量 × 系数 = 分」；score 为 compute 的结果（存档里的最好成绩同结构），空则 ""
static func tip_text(score: Dictionary) -> String:
	if score.is_empty() or not score.has("parts"):
		return ""
	var c: Dictionary = coefficients()
	var parts: Dictionary = score["parts"] as Dictionary
	return DataRegistry.get_string("ui.score_tip").format({
		"total": int(score.get("total", 0)),
		"units": int(score.get("unit_count", 0)), "cu": num(c["units"]), "pu": num(parts.get("units", 0.0)),
		"rules": int(score.get("action_count", 0)) + int(score.get("condition_count", 0)), "ck": num(c["complexity"]), "pk": num(parts.get("complexity", 0.0)),
		"beacons": int(score.get("beacon_count", 0)), "cb": num(c["beacons"]), "pb": num(parts.get("beacons", 0.0)),
		"seconds": "%.1f" % float(score.get("seconds", 0.0)), "ct": num(c["time"]), "pt": num(parts.get("time", 0.0)) })


## 数字显示：整数不带小数，否则一位小数
static func num(v: Variant) -> String:
	var f: float = float(v)
	return str(int(round(f))) if is_equal_approx(f, round(f)) else "%.1f" % f


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
