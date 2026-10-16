class_name ConditionDef
extends RefCounted
## 指令条件（02 §3 ConditionDef）。参数在 JSON 中与 type 平铺。

var type: int = SimTypes.ConditionType.ALWAYS
var ratio: float = 0.0                  ## self_hp_below
var op: String = "<"                    ## target_distance："<" 或 ">"
var value: float = 0.0                  ## target_distance
var threat_radius: float = -1.0         ## retreat_possible；< 0 表示使用单位视野
var search_depth: int = SimTypes.DEFAULT_SEARCH_DEPTH  ## retreat_possible
var flee: String = "max_min"            ## retreat_possible：与 retreat.flee 相同口径
var sig: String = ""                    ## signal_is：Boss 信号颜色（red / yellow / blue）
var beacon: String = ""                 ## at_beacon：信标编号（07 §3.3；10 §6.3 起为数字字符串）


static func from_dict(d: Dictionary, ctx: String) -> ConditionDef:
	var c := ConditionDef.new()
	var raw: String = DataReader.req_str(d, "type", ctx)
	c.type = DataReader.enum_value(SimTypes.parse_condition(raw), raw, "条件类型", ctx)
	match c.type:
		SimTypes.ConditionType.SELF_HP_BELOW:
			c.ratio = DataReader.req_num(d, "ratio", ctx)
			if c.ratio <= 0.0 or c.ratio > 1.0:
				DataReader.report(ctx, "self_hp_below.ratio 必须在 (0,1]")
		SimTypes.ConditionType.TARGET_DISTANCE:
			c.op = DataReader.req_str(d, "op", ctx)
			if c.op != "<" and c.op != ">":
				DataReader.report(ctx, "target_distance.op 必须是 '<' 或 '>'")
			c.value = DataReader.req_num(d, "value", ctx)
		SimTypes.ConditionType.RETREAT_POSSIBLE:
			c.threat_radius = DataReader.opt_num(d, "threat_radius", -1.0, ctx)
			c.search_depth = int(DataReader.opt_num(d, "search_depth", float(SimTypes.DEFAULT_SEARCH_DEPTH), ctx))
			c.flee = DataReader.opt_str(d, "flee", "max_min", ctx)
		SimTypes.ConditionType.AT_BEACON:
			c.beacon = DataReader.beacon_id(DataReader.req_str(d, "beacon", ctx), ctx, "at_beacon.beacon")
		SimTypes.ConditionType.SIGNAL_IS:
			c.sig = DataReader.req_str(d, "signal", ctx)
	return c


func to_dict() -> Dictionary:
	var d: Dictionary = { "type": SimTypes.condition_to_string(type) }
	match type:
		SimTypes.ConditionType.SELF_HP_BELOW:
			d["ratio"] = ratio
		SimTypes.ConditionType.TARGET_DISTANCE:
			d["op"] = op
			d["value"] = value
		SimTypes.ConditionType.RETREAT_POSSIBLE:
			if threat_radius >= 0.0:
				d["threat_radius"] = threat_radius
			d["search_depth"] = search_depth
			if flee != "max_min":
				d["flee"] = flee
		SimTypes.ConditionType.AT_BEACON:
			d["beacon"] = beacon
		SimTypes.ConditionType.SIGNAL_IS:
			d["signal"] = sig
	return d
