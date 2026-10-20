class_name SpawnDef
extends RefCounted
## 关卡初始单位（02 §5 initial_units[]）。

var id: String = ""
var unit_id: String = ""
var faction: int = SimTypes.Faction.ENEMY
var pos: Vector2i = Vector2i(-1, -1)
var tags: Array[String] = []
var has_rules: bool = false
var rules: Array[RuleDef] = []
var counts_for_annihilate: bool = true
var display_name: String = ""
var overrides: Dictionary = {}          ## 07 §9：属性覆盖 { stat: 值 }（走 §7 加成机制，构建世界时最后应用）
var visuals: Dictionary = {}            ## 2026-10-20 换皮：覆盖单位 visuals 的部分键（sprite / portrait / scale / light_color…），数值不变
var description: String = ""            ## 换皮时的敌人介绍（空 = 用单位定义的）
var public_rule_text: String = ""       ## 本关的行为说明（敌人面板「公开规则」；空 = 用单位定义的）
var has_traits: bool = false            ## 2026-10-20：写了 traits = 整表替换单位特性（同机制按敌人类型拆出的特性）
var traits: Array[String] = []


static func from_dict(d: Dictionary, ctx: String) -> SpawnDef:
	var s := SpawnDef.new()
	s.id = DataReader.req_str(d, "id", ctx)
	var sctx: String = "%s.%s" % [ctx, s.id]
	s.unit_id = DataReader.req_str(d, "unit", sctx)
	var raw_faction: String = DataReader.req_str(d, "faction", sctx)
	s.faction = DataReader.enum_value(SimTypes.parse_faction(raw_faction), raw_faction, "阵营", sctx)
	s.pos = DataReader.cell(d.get("pos", null), sctx + ".pos")
	s.tags = DataReader.string_array(DataReader.opt_array(d, "tags", sctx), sctx + ".tags")
	if d.has("rules"):
		s.has_rules = true
		s.rules = RuleDef.from_array(DataReader.as_array(d["rules"], sctx + ".rules"), sctx + ".rules")
	s.counts_for_annihilate = DataReader.opt_bool(d, "counts_for_annihilate", true, sctx)
	s.display_name = DataReader.opt_str(d, "display_name", "", sctx)
	s.visuals = DataReader.opt_dict(d, "visuals", sctx)
	s.description = DataReader.opt_str(d, "description", "", sctx)
	s.public_rule_text = DataReader.opt_str(d, "public_rule_text", "", sctx)
	if d.has("traits"):
		s.has_traits = true
		s.traits = DataReader.string_array(DataReader.opt_array(d, "traits", sctx), sctx + ".traits")
	var ov: Dictionary = DataReader.opt_dict(d, "overrides", sctx)
	for k: String in ov.keys():
		if not ModifierDef.STATS.has(k):
			DataReader.report(sctx, "overrides 属性非法: %s" % k)
			continue
		var v: float = DataReader.req_num(ov, k, sctx + ".overrides")
		if v < 0.0:
			DataReader.report(sctx, "overrides.%s 必须 ≥ 0" % k)
		s.overrides[k] = v
	return s


## 换皮覆盖（UnitDefinition.reskinned 的参数）；没有任何覆盖时为空
func skin() -> Dictionary:
	var over: Dictionary = {}
	if not visuals.is_empty():
		over["visuals"] = visuals
	if description != "":
		over["description"] = description
	if public_rule_text != "":
		over["public_rule_text"] = public_rule_text
	if has_traits:
		over["traits"] = traits
	return over
