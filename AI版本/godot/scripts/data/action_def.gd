class_name ActionDef
extends RefCounted
## 行为（02 §3 ActionDef）。参数在 JSON 中与 type 平铺。

var type: int = SimTypes.ActionType.IDLE
var route_id: String = ""               ## follow_route
var loop: bool = false                  ## follow_route
var threat_radius: float = -1.0         ## retreat；< 0 表示使用单位视野
var search_depth: int = SimTypes.DEFAULT_SEARCH_DEPTH  ## retreat
var flee: String = "max_min"            ## retreat 选方向：max_min（离最近威胁最远）/ vector_sum（背离所有威胁的合力方向）
var mode: int = SimTypes.BeaconMode.ONCE  ## follow_beacons（07 §3.2）
var from: String = "1"                  ## follow_beacons：起始信标编号（10 §6.3 数字字符串）
var seconds: float = 2.0                ## wait（07 §3.4），范围 WAIT_MIN_SECONDS–WAIT_MAX_SECONDS


static func create(p_type: int) -> ActionDef:
	var a := ActionDef.new()
	a.type = p_type
	return a


static func from_dict(d: Dictionary, ctx: String) -> ActionDef:
	var a := ActionDef.new()
	var raw: String = DataReader.req_str(d, "type", ctx)
	a.type = DataReader.enum_value(SimTypes.parse_action(raw), raw, "行为类型", ctx)
	match a.type:
		SimTypes.ActionType.FOLLOW_ROUTE:
			a.route_id = DataReader.req_str(d, "route_id", ctx)
			a.loop = DataReader.opt_bool(d, "loop", false, ctx)
		SimTypes.ActionType.RETREAT:
			a.threat_radius = DataReader.opt_num(d, "threat_radius", -1.0, ctx)
			a.search_depth = int(DataReader.opt_num(d, "search_depth", float(SimTypes.DEFAULT_SEARCH_DEPTH), ctx))
			a.flee = DataReader.opt_str(d, "flee", "max_min", ctx)
		SimTypes.ActionType.FOLLOW_BEACONS:
			var raw_mode: String = DataReader.opt_str(d, "mode", "once", ctx)
			a.mode = DataReader.enum_value(SimTypes.parse_beacon_mode(raw_mode), raw_mode, "信标模式", ctx)
			a.from = DataReader.beacon_id(DataReader.opt_str(d, "from", "1", ctx), ctx, "follow_beacons.from")
		SimTypes.ActionType.WAIT:
			a.seconds = DataReader.req_num(d, "seconds", ctx)
			if a.seconds < SimTypes.WAIT_MIN_SECONDS - SimTypes.TIME_EPS or a.seconds > SimTypes.WAIT_MAX_SECONDS + SimTypes.TIME_EPS:
				DataReader.report(ctx, "wait.seconds 必须在 %s–%s 之间" % [SimTypes.WAIT_MIN_SECONDS, SimTypes.WAIT_MAX_SECONDS])
	return a


## 该行为是否需要目标（attack / chase_attack / chase）。2026-10-18 起玩家界面的追击与攻击一样可选目标（默认最近）。
static func type_needs_target(t: int) -> bool:
	return t == SimTypes.ActionType.ATTACK or t == SimTypes.ActionType.CHASE_ATTACK or t == SimTypes.ActionType.CHASE


## 第五阶段：旧数据的「追击并攻击」被拆成 追击 + 攻击，允许列表里有 chase_attack 时视为两者都允许（就地追加）
static func expand_allowed(list: Array[int]) -> void:
	if not list.has(SimTypes.ActionType.CHASE_ATTACK):
		return
	for t: int in [SimTypes.ActionType.CHASE, SimTypes.ActionType.ATTACK]:
		if not list.has(t):
			list.append(t)


func needs_target() -> bool:
	return ActionDef.type_needs_target(type)


func to_dict() -> Dictionary:
	var d: Dictionary = { "type": SimTypes.action_to_string(type) }
	match type:
		SimTypes.ActionType.FOLLOW_ROUTE:
			d["route_id"] = route_id
			d["loop"] = loop
		SimTypes.ActionType.RETREAT:
			if threat_radius >= 0.0:
				d["threat_radius"] = threat_radius
			d["search_depth"] = search_depth
			if flee != "max_min":
				d["flee"] = flee
		SimTypes.ActionType.FOLLOW_BEACONS:
			d["mode"] = SimTypes.beacon_mode_to_string(mode)
			d["from"] = from
		SimTypes.ActionType.WAIT:
			d["seconds"] = seconds
	return d
