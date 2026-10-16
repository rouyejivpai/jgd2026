class_name ModifierDef
extends RefCounted
## 静态关卡加成（07 §7，A09 最小范围）：构建 SimWorld 时一次性作用于单位的有效属性；不做时效、叠层、驱散。
## { "target": "spawn:G1" | "form:bulwark" | "faction:enemy", "stat": "max_hp|attack|attack_speed|move_speed|vision|range", "mul": 1.2, "add": 0 }
## 结果 = 当前值 × mul + add，按关卡列表顺序依次应用；SpawnDef.overrides（07 §9）以 mul = 0、add = 覆盖值 的形式最后应用。

const STATS: Array[String] = ["max_hp", "attack", "attack_speed", "move_speed", "vision", "range"]
const TARGET_KINDS: Array[String] = ["spawn", "form", "faction"]

var target_kind: String = ""
var target_value: String = ""
var stat: String = ""
var mul: float = 1.0
var add: float = 0.0


static func from_dict(d: Dictionary, ctx: String) -> ModifierDef:
	var m := ModifierDef.new()
	var target: String = DataReader.req_str(d, "target", ctx)
	m.target_kind = target.get_slice(":", 0)
	m.target_value = target.get_slice(":", 1) if target.contains(":") else ""
	if not TARGET_KINDS.has(m.target_kind) or m.target_value == "":
		DataReader.report(ctx, "modifiers.target 必须是 spawn:<id> / form:<形态> / faction:<阵营>: %s" % target)
	if m.target_kind == "faction" and SimTypes.parse_faction(m.target_value) < 0:
		DataReader.report(ctx, "modifiers.target 阵营非法: %s" % m.target_value)
	m.stat = DataReader.req_str(d, "stat", ctx)
	if not STATS.has(m.stat):
		DataReader.report(ctx, "modifiers.stat 非法: %s" % m.stat)
	m.mul = DataReader.opt_num(d, "mul", 1.0, ctx)
	m.add = DataReader.opt_num(d, "add", 0.0, ctx)
	if m.mul < 0.0:
		DataReader.report(ctx, "modifiers.mul 必须 ≥ 0")
	return m


## SpawnDef.overrides 的一项 → 覆盖型加成
static func override(spawn_id: String, p_stat: String, value: float) -> ModifierDef:
	var m := ModifierDef.new()
	m.target_kind = "spawn"
	m.target_value = spawn_id
	m.stat = p_stat
	m.mul = 0.0
	m.add = value
	return m


func applies_to(u: SimUnit) -> bool:
	match target_kind:
		"spawn":
			return u.spawn_id == target_value
		"form":
			return u.def != null and u.def.id == target_value
		"faction":
			return u.faction == SimTypes.parse_faction(target_value)
	return false


## 按顺序把适用的加成写入单位有效属性（结果不小于 0；max_hp 变化时生命同步为新上限）
static func apply_all(u: SimUnit, mods: Array[ModifierDef]) -> void:
	for m: ModifierDef in mods:
		if not m.applies_to(u):
			continue
		var v: float = maxf(0.0, stat_of(u, m.stat) * m.mul + m.add)
		match m.stat:
			"max_hp":
				u.max_hp = maxf(v, 1.0)
				u.hp = u.max_hp
			"attack":
				u.attack = v
			"attack_speed":
				u.attack_speed = v
			"move_speed":
				u.move_speed = v
			"vision":
				u.vision = v
			"range":
				u.attack_range = v


static func stat_of(u: SimUnit, p_stat: String) -> float:
	match p_stat:
		"max_hp":
			return u.max_hp
		"attack":
			return u.attack
		"attack_speed":
			return u.attack_speed
		"move_speed":
			return u.move_speed
		"vision":
			return u.vision
		"range":
			return u.attack_range
	return 0.0


## 形态定义上的基础值（面板显示"160 (+32 关卡加成)"用）
static func base_of(def: UnitDefinition, p_stat: String) -> float:
	match p_stat:
		"max_hp":
			return def.max_hp
		"attack":
			return def.attack
		"attack_speed":
			return def.attack_speed
		"move_speed":
			return def.move_speed
		"vision":
			return def.vision
		"range":
			return def.attack_range
	return 0.0
