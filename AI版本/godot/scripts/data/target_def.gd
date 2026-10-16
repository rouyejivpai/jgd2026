class_name TargetDef
extends RefCounted
## 选敌（02 §3 TargetDef）。

var selector: int = SimTypes.Selector.NEAREST
var filter: int = SimTypes.TargetFilter.ANY


static func create(p_selector: int, p_filter: int) -> TargetDef:
	var t := TargetDef.new()
	t.selector = p_selector
	t.filter = p_filter
	return t


static func from_dict(d: Dictionary, ctx: String) -> TargetDef:
	var t := TargetDef.new()
	var raw_sel: String = DataReader.req_str(d, "selector", ctx)
	t.selector = DataReader.enum_value(SimTypes.parse_selector(raw_sel), raw_sel, "选敌", ctx)
	var raw_filter: String = DataReader.opt_str(d, "filter", "any", ctx)
	t.filter = DataReader.enum_value(SimTypes.parse_filter(raw_filter), raw_filter, "过滤", ctx)
	return t


func to_dict() -> Dictionary:
	return { "selector": SimTypes.selector_to_string(selector), "filter": SimTypes.filter_to_string(filter) }
