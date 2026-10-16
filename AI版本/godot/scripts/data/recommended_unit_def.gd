class_name RecommendedUnitDef
extends RefCounted
## 关卡「推荐阵型」中的一名单位（07 §2 recommended.units[]）：部署位置 + 推荐指令 + 信标。
## fixed 模式用 slot，free 模式用 form；两者都给时以 roster.mode 为准（第一阶段关卡均为 fixed）。

var slot_id: String = ""                ## JSON 键 "slot"
var form: String = ""
var pos: Vector2i = Vector2i(-1, -1)
var rules: Array[RuleDef] = []
var beacons: Array[Dictionary] = []     ## { "id": String, "cell": Vector2i }（信标机制见 07 §3）


static func from_dict(d: Dictionary, ctx: String) -> RecommendedUnitDef:
	var r := RecommendedUnitDef.new()
	r.slot_id = DataReader.opt_str(d, "slot", "", ctx)
	r.form = DataReader.opt_str(d, "form", "", ctx)
	if r.slot_id == "" and r.form == "":
		DataReader.report(ctx, "recommended.units 条目需要 slot 或 form")
	var uctx: String = "%s.%s" % [ctx, r.slot_id if r.slot_id != "" else r.form]
	r.pos = DataReader.cell(d.get("pos", null), uctx + ".pos") if DataReader.require(d, "pos", uctx) else Vector2i(-1, -1)
	r.rules = RuleDef.from_array(DataReader.opt_array(d, "rules", uctx), uctx + ".rules")
	for item: Variant in DataReader.opt_array(d, "beacons", uctx):
		var b: Dictionary = DataReader.as_dict(item, uctx + ".beacons")
		r.beacons.append({ "id": DataReader.beacon_id(DataReader.req_str(b, "id", uctx + ".beacons"), uctx + ".beacons", "beacons[].id"), "cell": DataReader.cell(b.get("cell", null), uctx + ".beacons.cell") })
	return r
