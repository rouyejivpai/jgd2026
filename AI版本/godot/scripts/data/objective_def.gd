class_name ObjectiveDef
extends RefCounted
## 胜负条件（01 §6.9、02 §5 objectives）。

const WIN_TYPES: Array[int] = [SimTypes.ObjectiveType.ANNIHILATE, SimTypes.ObjectiveType.DESTROY, SimTypes.ObjectiveType.SURVIVE,
	SimTypes.ObjectiveType.REACH_ZONE, SimTypes.ObjectiveType.ESCORT]   ## 07 §9：reach_zone 可作胜利；escort 护送
const ANY_ALLY: String = "any_ally"
const LOSE_TYPES: Array[int] = [SimTypes.ObjectiveType.UNIT_DEAD, SimTypes.ObjectiveType.ALL_ALLIES_DEAD, SimTypes.ObjectiveType.REACH_ZONE]

var id: String = ""
var type: int = SimTypes.ObjectiveType.ANNIHILATE
var targets: Array[String] = []         ## destroy
var target: String = ""                 ## survive / unit_dead / reach_zone
var seconds: float = 0.0                ## survive
var cells: Array[Vector2i] = []         ## reach_zone / escort
var count: int = 1                      ## reach_zone 作为胜利且 target = any_ally 时：需要到达的己方单位数
var hidden: bool = false                ## reach_zone / escort 胜利：不画紫色目标格（第一关部署区即目标区，再标一遍反而误导）
var is_win: bool = false


static func from_dict(d: Dictionary, p_is_win: bool, ctx: String) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = DataReader.req_str(d, "id", ctx)
	o.is_win = p_is_win
	var octx: String = "%s.%s" % [ctx, o.id]
	var raw: String = DataReader.req_str(d, "type", octx)
	o.type = DataReader.enum_value(SimTypes.parse_objective(raw), raw, "目标类型", octx)
	if o.type >= 0:
		var allowed: Array[int] = WIN_TYPES if p_is_win else LOSE_TYPES
		if not allowed.has(o.type):
			DataReader.report(octx, "%s 条件类型非法: %s" % ["win" if p_is_win else "lose", raw])
	match o.type:
		SimTypes.ObjectiveType.DESTROY:
			o.targets = DataReader.string_array(DataReader.req_array(d, "targets", octx), octx + ".targets")
			if o.targets.is_empty():
				DataReader.report(octx, "destroy.targets 不能为空")
		SimTypes.ObjectiveType.SURVIVE:
			o.target = DataReader.req_str(d, "target", octx)
			o.seconds = DataReader.req_num(d, "seconds", octx)
			if o.seconds <= 0.0:
				DataReader.report(octx, "survive.seconds 必须为正")
		SimTypes.ObjectiveType.UNIT_DEAD:
			o.target = DataReader.req_str(d, "target", octx)
		SimTypes.ObjectiveType.REACH_ZONE:
			o.target = DataReader.req_str(d, "target", octx)
			o.cells = DataReader.cells(DataReader.req_array(d, "cells", octx), octx + ".cells")
			o.count = int(DataReader.opt_num(d, "count", 1.0, octx))
			if o.count < 1:
				DataReader.report(octx, "reach_zone.count 必须 ≥ 1")
			if o.target == ANY_ALLY and not p_is_win:
				DataReader.report(octx, "any_ally 只能用于胜利条件")
			o.hidden = DataReader.opt_bool(d, "hidden", false, octx)
		SimTypes.ObjectiveType.ESCORT:
			o.target = DataReader.req_str(d, "target", octx)
			o.cells = DataReader.cells(DataReader.req_array(d, "cells", octx), octx + ".cells")
			o.hidden = DataReader.opt_bool(d, "hidden", false, octx)
	if (o.type == SimTypes.ObjectiveType.REACH_ZONE or o.type == SimTypes.ObjectiveType.ESCORT) and d.has("cells") and o.cells.is_empty():
		DataReader.report(octx, "cells 不能为空")
	return o


## 本条目引用的全部单位 id（spawn id）
func referenced_ids() -> Array[String]:
	var out: Array[String] = targets.duplicate()
	if target != "" and target != ANY_ALLY:
		out.append(target)
	return out
