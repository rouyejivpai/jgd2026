class_name RuleDef
extends RefCounted
## 一条指令（02 §3 RuleDef）——敌我、默认、玩家配置、预设共用。

var enabled: bool = true
## 第四阶段「覆盖」：条件成立时无视上方非覆盖指令的优先级、直接接管（覆盖指令之间仍按列表顺序）。
## 例：1 始终→沿信标；2 射程内敌人→撤离（覆盖）= 平时沿信标走，有敌人时撤离，敌人离开后回到路线继续。
var override: bool = false
var condition_mode: int = SimTypes.ConditionMode.ALL
var conditions: Array[ConditionDef] = []
var target: TargetDef = null            ## idle / retreat / follow_route 可为空
var action: ActionDef = null


static func from_dict(d: Dictionary, ctx: String) -> RuleDef:
	var r := RuleDef.new()
	r.enabled = DataReader.opt_bool(d, "enabled", true, ctx)
	r.override = DataReader.opt_bool(d, "override", false, ctx)
	var raw_mode: String = DataReader.opt_str(d, "condition_mode", "all", ctx)
	r.condition_mode = DataReader.enum_value(SimTypes.parse_mode(raw_mode), raw_mode, "条件模式", ctx)
	var conds: Array = DataReader.req_array(d, "conditions", ctx)
	for i: int in conds.size():
		var cctx: String = "%s.conditions[%d]" % [ctx, i]
		r.conditions.append(ConditionDef.from_dict(DataReader.as_dict(conds[i], cctx), cctx))
	if d.has("target"):
		r.target = TargetDef.from_dict(DataReader.as_dict(d["target"], ctx + ".target"), ctx + ".target")
	r.action = ActionDef.from_dict(DataReader.req_dict(d, "action", ctx), ctx + ".action")
	if r.target == null and (r.action.needs_target() or r.has_condition(SimTypes.ConditionType.TARGET_DISTANCE)):
		DataReader.report(ctx, "行为或条件需要 target 但缺失")
	return r


static func from_array(arr: Array, ctx: String) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for i: int in arr.size():
		var rctx: String = "%s[%d]" % [ctx, i]
		out.append(RuleDef.from_dict(DataReader.as_dict(arr[i], rctx), rctx))
	return out


static func to_array(rules: Array[RuleDef]) -> Array:
	var out: Array = []
	for r: RuleDef in rules:
		out.append(r.to_dict())
	return out


static func clone_array(rules: Array[RuleDef]) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for r: RuleDef in rules:
		out.append(r.clone())
	return out


func has_condition(t: int) -> bool:
	for c: ConditionDef in conditions:
		if c.type == t:
			return true
	return false


func to_dict() -> Dictionary:
	var conds: Array = []
	for c: ConditionDef in conditions:
		conds.append(c.to_dict())
	var d: Dictionary = {
		"enabled": enabled,
		"condition_mode": "any" if condition_mode == SimTypes.ConditionMode.ANY else "all",
		"conditions": conds,
		"action": action.to_dict() if action != null else {},
	}
	if target != null:
		d["target"] = target.to_dict()
	if override:
		d["override"] = true          # 缺省不写（旧存档 / 关卡数据不变）
	return d


func clone() -> RuleDef:
	return RuleDef.from_dict(to_dict(), "clone")
