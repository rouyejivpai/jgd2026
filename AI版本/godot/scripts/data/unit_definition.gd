class_name UnitDefinition
extends RefCounted
## 单位定义（02 §1），敌我共用。

var id: String = ""
var display_name: String = ""
var kind: int = SimTypes.UnitKind.UNIT
var faction_default: int = SimTypes.Faction.ENEMY
var max_hp: float = 1.0
var attack: float = 0.0
var attack_speed: float = 0.0
var move_speed: float = 0.0
var vision: float = 0.0
var attack_range: float = 0.0           ## JSON 键 "range"
var traits: Array[String] = []
var allowed_actions: Array[int] = []
var default_rules: Array[RuleDef] = []
var visuals: Dictionary = {}
var description: String = ""
var public_rule_text: String = ""
var cost: int = -1                      ## 07 §4.1：己方形态出场 Cost（己方形态必填，敌方忽略）


static func from_dict(unit_id: String, d: Dictionary, ctx: String) -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = unit_id
	u.display_name = DataReader.req_str(d, "display_name", ctx)
	var raw_kind: String = DataReader.req_str(d, "kind", ctx)
	u.kind = DataReader.enum_value(SimTypes.parse_kind(raw_kind), raw_kind, "kind", ctx)
	var raw_faction: String = DataReader.req_str(d, "faction_default", ctx)
	u.faction_default = DataReader.enum_value(SimTypes.parse_faction(raw_faction), raw_faction, "阵营", ctx)
	u.max_hp = DataReader.req_num(d, "max_hp", ctx)
	u.attack = DataReader.req_num(d, "attack", ctx)
	u.attack_speed = DataReader.req_num(d, "attack_speed", ctx)
	u.move_speed = DataReader.req_num(d, "move_speed", ctx)
	u.vision = DataReader.req_num(d, "vision", ctx)
	u.attack_range = DataReader.req_num(d, "range", ctx)
	if u.max_hp <= 0.0:
		DataReader.report(ctx, "max_hp 必须 > 0")
	for key: String in ["attack", "attack_speed", "move_speed", "vision", "range"]:
		if d.has(key) and DataReader.opt_num(d, key, 0.0, ctx) < 0.0:
			DataReader.report(ctx, "%s 必须 ≥ 0" % key)
	u.traits = DataReader.string_array(DataReader.opt_array(d, "traits", ctx), ctx + ".traits")
	for raw_action: String in DataReader.string_array(DataReader.req_array(d, "allowed_actions", ctx), ctx + ".allowed_actions"):
		u.allowed_actions.append(DataReader.enum_value(SimTypes.parse_action(raw_action), raw_action, "行为类型", ctx))
	u.default_rules = RuleDef.from_array(DataReader.req_array(d, "default_rules", ctx), ctx + ".default_rules")
	u.visuals = DataReader.req_dict(d, "visuals", ctx)
	for key: String in ["sprite", "portrait", "projectile", "light_color"]:
		if not u.visuals.has(key):
			DataReader.report(ctx, "visuals 缺少 %s" % key)
	u.description = DataReader.opt_str(d, "description", "", ctx)
	u.public_rule_text = DataReader.opt_str(d, "public_rule_text", "", ctx)
	u.cost = int(DataReader.opt_num(d, "cost", -1.0, ctx))
	if u.is_ally_form() and u.cost <= 0:
		DataReader.report(ctx, "己方形态必须有正整数 cost（07 §4.1）")
	# D07：建筑不移动、不攻击
	if u.kind == SimTypes.UnitKind.STRUCTURE and (u.attack_speed != 0.0 or u.move_speed != 0.0):
		DataReader.report(ctx, "建筑的 attack_speed 与 move_speed 必须为 0 (D07)")
	return u


func is_structure() -> bool:
	return kind == SimTypes.UnitKind.STRUCTURE


## 己方可出场形态：faction_default = ally 且为单位
func is_ally_form() -> bool:
	return faction_default == SimTypes.Faction.ALLY and kind == SimTypes.UnitKind.UNIT
