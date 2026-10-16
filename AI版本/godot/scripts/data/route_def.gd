class_name RouteDef
extends RefCounted
## 关卡路线（02 §5 routes）。

var id: String = ""
var display_name: String = ""           ## JSON 键 "name"
var points: Array[Vector2i] = []


static func from_dict(route_id: String, d: Dictionary, ctx: String) -> RouteDef:
	var r := RouteDef.new()
	r.id = route_id
	r.display_name = DataReader.req_str(d, "name", ctx)
	r.points = DataReader.cells(DataReader.req_array(d, "points", ctx), ctx + ".points")
	if r.points.is_empty():
		DataReader.report(ctx, "路线没有路点")
	return r
