class_name SlotDef
extends RefCounted
## 关卡己方槽位（02 §5 slots[]）。

var id: String = ""
var unit_id: String = ""
var fixed: bool = true
var editable_rules: bool = true
var has_default_pos: bool = false
var default_pos: Vector2i = Vector2i(-1, -1)


static func from_dict(d: Dictionary, ctx: String) -> SlotDef:
	var s := SlotDef.new()
	s.id = DataReader.req_str(d, "id", ctx)
	var sctx: String = "%s.%s" % [ctx, s.id]
	s.unit_id = DataReader.req_str(d, "unit", sctx)
	s.fixed = DataReader.opt_bool(d, "fixed", true, sctx)
	s.editable_rules = DataReader.opt_bool(d, "editable_rules", true, sctx)
	if d.has("rules"):
		# 第二阶段：新放置单位指令一律为空（07 §2），槽位 rules 不再加载；推荐指令见 recommended.units
		DataReader.warn(sctx, "DEPRECATED_FIELD slots[].rules 已废弃并被忽略，推荐指令请写入 recommended.units")
	if d.has("default_pos"):
		s.has_default_pos = true
		s.default_pos = DataReader.cell(d["default_pos"], sctx + ".default_pos")
	return s
