class_name ChapterDef
extends RefCounted
## 章节（07 §10.1，data/chapters/<id>.json）：区域、节点（关卡）与连线。框架支持任意数量节点（为 24 关预留 legacy_ids 映射位）。
## 解锁规则：节点有一条"已完成的前驱连线"（某个 links 含本节点的节点已通关）即解锁；没有前驱的节点仅当在初始关卡列表中时解锁。
## 第三阶段（10 §3.1）：节点以 `id` 索引（缺省 = level）；`placeholder` 占位节点（无关卡）恒为锁定，指向它的连线按锁定色画；
## 可选 `title_key`（占位名文案键）、`node_art`（节点素材 id，R3）；章节 `map_size`（地图设计尺寸，默认 1920×1080）。

const DEFAULT_MAP_SIZE: Vector2 = Vector2(1920.0, 1080.0)

var id: String = ""
var title: String = ""
var map: String = ""
var map_size: Vector2 = DEFAULT_MAP_SIZE
var regions: Array[Dictionary] = []     ## { id, title }
## { id, level, placeholder: bool, title_key, node_art, region, pos: Vector2, links: Array[String]（节点 id）, boss: bool, story_on_unlock: String, legacy_ids: Array[String] }
var nodes: Array[Dictionary] = []


static func from_dict(d: Dictionary, ctx: String) -> ChapterDef:
	var c := ChapterDef.new()
	c.id = DataReader.req_str(d, "id", ctx)
	c.title = DataReader.req_str(d, "title", ctx)
	c.map = DataReader.opt_str(d, "map", "", ctx)
	if d.has("map_size"):
		var ms: Array = DataReader.as_array(d["map_size"], ctx + ".map_size")
		if ms.size() == 2 and float(ms[0]) > 0.0 and float(ms[1]) > 0.0:
			c.map_size = Vector2(float(ms[0]), float(ms[1]))
		else:
			DataReader.report(ctx, "map_size 必须是 [宽, 高]（正数）")
	for item: Variant in DataReader.req_array(d, "regions", ctx):
		var r: Dictionary = DataReader.as_dict(item, ctx + ".regions")
		c.regions.append({ "id": DataReader.req_str(r, "id", ctx + ".regions"), "title": DataReader.opt_str(r, "title", "", ctx + ".regions") })
	for item: Variant in DataReader.req_array(d, "nodes", ctx):
		var n: Dictionary = DataReader.as_dict(item, ctx + ".nodes")
		var level: String = DataReader.opt_str(n, "level", "", ctx + ".nodes")
		var node_id: String = DataReader.opt_str(n, "id", level, ctx + ".nodes")
		var nctx: String = "%s.nodes.%s" % [ctx, node_id if node_id != "" else "?"]
		if node_id == "":
			DataReader.report(nctx, "节点需要 level 或 id（无 level 时 id 必填）")
		var pos_arr: Array = DataReader.as_array(n.get("pos", []), nctx + ".pos")
		var pos: Vector2 = Vector2(float(pos_arr[0]), float(pos_arr[1])) if pos_arr.size() == 2 else Vector2.ZERO
		if pos_arr.size() != 2:
			DataReader.report(nctx, "pos 必须是 [x, y]")
		var placeholder: bool = DataReader.opt_bool(n, "placeholder", false, nctx)
		if placeholder and (n.has("level") or n.has("boss") or n.has("story_on_unlock")):
			DataReader.report(nctx, "placeholder 节点不得有 level、boss、story_on_unlock")
		if not placeholder and level == "":
			DataReader.report(nctx, "非占位节点必须有 level")
		c.nodes.append({
			"id": node_id,
			"level": level,
			"placeholder": placeholder,
			"title_key": DataReader.opt_str(n, "title_key", "", nctx),
			"node_art": DataReader.opt_str(n, "node_art", "", nctx),
			"region": DataReader.opt_str(n, "region", "", nctx),
			"pos": pos,
			"links": DataReader.string_array(DataReader.opt_array(n, "links", nctx), nctx + ".links"),
			"boss": DataReader.opt_bool(n, "boss", false, nctx),
			"story_on_unlock": DataReader.opt_str(n, "story_on_unlock", "", nctx),
			"legacy_ids": DataReader.string_array(DataReader.opt_array(n, "legacy_ids", nctx), nctx + ".legacy_ids"),
		})
	return c


## 按节点 id 取节点（关卡节点的 id 缺省 = 关卡 id，因此也可直接用关卡 id）；无则 {}
func node_of(node_id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if str(n["id"]) == node_id:
			return n
	return {}


## 关卡所在节点（无则 {}）
func node_of_level(level_id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if str(n["level"]) == level_id and level_id != "":
			return n
	return {}


## 本章的关卡 id（按节点顺序，不含占位节点）
func level_ids() -> Array[String]:
	var out: Array[String] = []
	for n: Dictionary in nodes:
		if not bool(n.get("placeholder", false)) and str(n.get("level", "")) != "":
			out.append(str(n["level"]))
	return out


func has_level(level_id: String) -> bool:
	return not node_of_level(level_id).is_empty()


func is_placeholder(node_id: String) -> bool:
	return bool(node_of(node_id).get("placeholder", false))


## 有连线指向 node_id 的节点 id
func predecessors(node_id: String) -> Array[String]:
	var out: Array[String] = []
	for n: Dictionary in nodes:
		if (n["links"] as Array).has(node_id):
			out.append(str(n["id"]))
	return out


## 节点解锁（参数可为关卡 id 或节点 id）：占位节点恒锁定；在初始关卡中或有一个已通关的前驱
func is_unlocked(node_or_level: String, completed: Array, initial_levels: Array) -> bool:
	var n: Dictionary = node_of(node_or_level)
	if n.is_empty():
		n = node_of_level(node_or_level)
	if n.is_empty() or bool(n["placeholder"]):
		return false
	if initial_levels.has(str(n["level"])):
		return true
	for p: String in predecessors(str(n["id"])):
		if completed.has(str(node_of(p).get("level", ""))):
			return true
	return false


## 连线状态：0 锁定（起点未通关，或终点为占位节点）、1 可挑战（起点已通关、终点未通关）、2 已完成（两端都已通关）
func link_state(from_id: String, to_id: String, completed: Array) -> int:
	var from_level: String = str(node_of(from_id).get("level", ""))
	var to_level: String = str(node_of(to_id).get("level", ""))
	if is_placeholder(to_id) or not completed.has(from_level):
		return 0
	return 2 if completed.has(to_level) else 1


func region_title(region_id: String) -> String:
	for r: Dictionary in regions:
		if str(r["id"]) == region_id:
			return str(r["title"])
	return ""


## 数据校验：节点 id 不重复、关卡存在且不重复、连线指向本章节点、区域存在
func validate(known_levels: Array[String], ctx: String) -> void:
	var seen: Array[String] = []
	var seen_levels: Array[String] = []
	var region_ids: Array[String] = []
	for r: Dictionary in regions:
		region_ids.append(str(r["id"]))
	for n: Dictionary in nodes:
		var nid: String = str(n["id"])
		if seen.has(nid):
			DataReader.report(ctx, "节点 %s 重复" % nid)
		seen.append(nid)
		var lid: String = str(n["level"])
		if lid != "":
			if seen_levels.has(lid):
				DataReader.report(ctx, "关卡 %s 出现在多个节点" % lid)
			seen_levels.append(lid)
			if not known_levels.has(lid):
				DataReader.report(ctx, "节点关卡 '%s' 不存在" % lid)
		if str(n["region"]) != "" and not region_ids.has(str(n["region"])):
			DataReader.report(ctx, "节点 %s 的区域 '%s' 不存在" % [nid, n["region"]])
	for n: Dictionary in nodes:
		for to: String in n["links"] as Array:
			if not seen.has(to):
				DataReader.report(ctx, "节点 %s 的连线指向不在本章的 '%s'" % [n["id"], to])
