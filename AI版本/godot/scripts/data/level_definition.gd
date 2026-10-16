class_name LevelDefinition
extends RefCounted
## 关卡定义（01 §5.1、02 §5）。只做字段级解析与校验；引用与坐标的交叉校验见 DataValidator。

var schema_version: int = 1
var id: String = ""
var index: int = 0
var display_index: int = 0              ## 界面显示的关号（缺省 = index）；30 关战役 index = 101…130、display_index = 1…30
var title: String = ""
var subtitle: String = ""
var summary: String = ""                ## 10 §3.1 可选：关卡特征一句话（章节地图详情面板）；空则回退 subtitle（决策 ⑫，本阶段不填）
var biome: String = ""
var scene_backdrop: String = ""         ## JSON scene.backdrop（07 §1.3，替代第一阶段 background）
var scene_ground: String = ""           ## scene.ground：玩法矩形内平铺的俯视地面贴图；空 = ground_tint 纯色
var scene_ground_tint: Color = Color.WHITE
var has_playfield_rect: bool = false    ## scene.playfield_rect 非 null：手动指定的玩法矩形（设计分辨率像素）
var playfield_rect: Rect2i = Rect2i()
## 10 §7 大地图与障碍融合（P7，R4）：scene.obstacles = 障碍块清单 obstacles.json 的路径；有清单 = backdrop 是按玩法矩形标线图画的
## 对齐底图（level_0X_base.png），按设计坐标 1:1 铺；GroundLayer 不再平铺 scene.ground / ground_marks（二者降为无资源时的占位，DEPRECATED）。
## 每块：{ file（相对清单目录）, cells（所占格，须 ⊆ blocked）, anchor_px（块左上相对所占格外接框左上，整图像素）, size_px（整图像素） }
var scene_obstacles: String = ""
var obstacle_pieces: Array[Dictionary] = []   ## { file: String（res://）, cells: Array[Vector2i], anchor: Vector2, size: Vector2 }
var bgm: String = ""
var rng_seed: int = 0                   ## JSON 键 "seed"
var width: int = 0
var height: int = 0
var blocked: Array[Vector2i] = []
var boss: Dictionary = {}               ## 多阶段 Boss 配置（信号循环 / 阶段切换），见《Boss 规则页》
var recommended_phase2: Dictionary = {}  ## Boss 换阶段暂停时的推荐重编程与增援（原样保留：{ rules: {条目名: [规则]}, reinforcements: [recommended.units 条目] }）
var tiles: Dictionary = {}              ## 地形效果格：kind（hazard / mire / shrine）-> Array[Vector2i]，对应特性 tile_<kind>
var deploy_cells: Array[Vector2i] = []  ## 最终可部署格（rect/cells 去掉 exclude）
var deploy_excluded: Array[Vector2i] = []
## 07 §4.1 出场（roster）。fixed = 第一阶段固定槽位（slots 即 roster.fixed_slots）；free = 自主选择形态，按 Cost 扣预算
const ROSTER_FIXED: String = "fixed"
const ROSTER_FREE: String = "free"
var roster_mode: String = ROSTER_FIXED
var roster_budget: int = 0
var has_available_forms: bool = false   ## false = available_forms 为 null（全部已解锁形态）
var available_forms: Array[String] = []
var max_units: int = 0
var min_units: int = 1
var slots: Array[SlotDef] = []          ## roster.fixed_slots（仅 fixed 模式）
var initial_units: Array[SpawnDef] = []
var routes: Dictionary = {}             ## route_id -> RouteDef
var allowed_conditions: Array[int] = []
var allowed_selectors: Array[int] = []
var allowed_actions: Array[int] = []
var modifiers: Array[ModifierDef] = []  ## 07 §7 静态关卡加成（可选）
var win: Array[ObjectiveDef] = []
var lose: Array[ObjectiveDef] = []
var objective_text: String = ""
var briefing: Dictionary = {}
var hints: Array[String] = []
var fail_feedback: Dictionary = {}
var recommended_units: Array[RecommendedUnitDef] = []   ## JSON recommended.units（推荐部署 + 推荐指令 + 信标）
var recommended_deploy: Dictionary = {} ## 由 recommended_units 派生：slot_id -> Vector2i（仅 slot 条目）
var rewards: Dictionary = {}
var verification: Dictionary = {}
var comment: String = ""                ## JSON 键 "_comment"（第七关锁定标记）


static func from_dict(d: Dictionary, ctx: String) -> LevelDefinition:
	var L := LevelDefinition.new()
	for key: String in ["id", "index", "title", "biome", "scene", "grid", "deploy_zone", "roster", "initial_units", "allowed", "objectives", "briefing", "hints", "fail_feedback", "recommended", "rewards", "verification"]:
		DataReader.require(d, key, ctx)
	L.schema_version = int(DataReader.opt_num(d, "schema_version", 1.0, ctx))
	L.id = DataReader.opt_str(d, "id", "", ctx)
	L.index = int(DataReader.opt_num(d, "index", 0.0, ctx))
	L.display_index = int(DataReader.opt_num(d, "display_index", float(L.index), ctx))
	L.title = DataReader.opt_str(d, "title", "", ctx)
	L.subtitle = DataReader.opt_str(d, "subtitle", "", ctx)
	L.summary = DataReader.opt_str(d, "summary", "", ctx)
	L.biome = DataReader.opt_str(d, "biome", "", ctx)
	if d.has("background"):
		DataReader.report(ctx, "DEPRECATED_FIELD background 已废弃，改用 scene.backdrop")
	var scene: Dictionary = DataReader.opt_dict(d, "scene", ctx)
	var sctx: String = ctx + ".scene"
	if d.has("scene"):
		L.scene_backdrop = DataReader.req_str(scene, "backdrop", sctx)
		L.scene_ground = DataReader.opt_str(scene, "ground", "", sctx)
		var tint: String = DataReader.opt_str(scene, "ground_tint", "#ffffff", sctx)
		if not Color.html_is_valid(tint):
			DataReader.report(sctx, "ground_tint 不是合法颜色: %s" % tint)
		L.scene_ground_tint = Color.html(tint) if Color.html_is_valid(tint) else Color.WHITE
		L.scene_obstacles = DataReader.opt_str(scene, "obstacles", "", sctx)
		var pr: Variant = scene.get("playfield_rect", null)
		if pr != null:
			var a: Array = DataReader.as_array(pr, sctx + ".playfield_rect")
			if a.size() == 4 and int(a[2]) > int(a[0]) and int(a[3]) > int(a[1]):
				L.has_playfield_rect = true
				L.playfield_rect = Rect2i(int(a[0]), int(a[1]), int(a[2]) - int(a[0]), int(a[3]) - int(a[1]))
			else:
				DataReader.report(sctx, "playfield_rect 必须是 null 或 [x0, y0, x1, y1]（x1>x0, y1>y0）")
	L.bgm = DataReader.opt_str(d, "bgm", "", ctx)
	L.rng_seed = int(DataReader.opt_num(d, "seed", 0.0, ctx))
	L.comment = DataReader.opt_str(d, "_comment", "", ctx)

	var grid: Dictionary = DataReader.opt_dict(d, "grid", ctx)
	L.width = int(DataReader.req_num(grid, "width", ctx + ".grid"))
	L.height = int(DataReader.req_num(grid, "height", ctx + ".grid"))
	if L.width <= 0 or L.height <= 0:
		DataReader.report(ctx, "grid 尺寸必须为正")
	L.blocked = DataReader.cells(DataReader.req_array(grid, "blocked", ctx + ".grid"), ctx + ".grid.blocked")
	L.boss = DataReader.opt_dict(d, "boss", ctx)
	var tile_dict: Dictionary = DataReader.opt_dict(grid, "tiles", ctx + ".grid")
	for kind: String in tile_dict.keys():
		L.tiles[kind] = DataReader.cells(DataReader.as_array(tile_dict[kind], ctx + ".grid.tiles." + kind), ctx + ".grid.tiles." + kind)
	if L.scene_obstacles != "":
		_read_obstacles(L, ctx + ".scene.obstacles")

	var dz: Dictionary = DataReader.opt_dict(d, "deploy_zone", ctx)
	var zone: Array[Vector2i] = []
	if dz.has("rect"):
		var rect: Array = DataReader.as_array(dz["rect"], ctx + ".deploy_zone.rect")
		if rect.size() == 4:
			var x0: int = int(rect[0])
			var y0: int = int(rect[1])
			var x1: int = int(rect[2])
			var y1: int = int(rect[3])
			for y: int in range(y0, y1 + 1):
				for x: int in range(x0, x1 + 1):
					zone.append(Vector2i(x, y))
		else:
			DataReader.report(ctx, "deploy_zone.rect 必须是 [x0, y0, x1, y1]")
	elif dz.has("cells"):
		zone = DataReader.cells(DataReader.as_array(dz["cells"], ctx + ".deploy_zone.cells"), ctx + ".deploy_zone.cells")
	elif d.has("deploy_zone"):
		DataReader.report(ctx, "deploy_zone 需要 rect 或 cells")
	L.deploy_excluded = DataReader.cells(DataReader.opt_array(dz, "exclude", ctx + ".deploy_zone"), ctx + ".deploy_zone.exclude")
	for c: Vector2i in zone:
		if not L.deploy_excluded.has(c) and not L.deploy_cells.has(c):
			L.deploy_cells.append(c)
	if L.deploy_cells.is_empty() and d.has("deploy_zone"):
		DataReader.report(ctx, "部署区为空")

	if d.has("slots"):
		DataReader.report(ctx, "DEPRECATED_FIELD slots 已废弃，改用 roster（fixed 模式写 roster.fixed_slots）")
	var roster: Dictionary = DataReader.opt_dict(d, "roster", ctx)
	var ro_ctx: String = ctx + ".roster"
	if d.has("roster"):
		L.roster_mode = DataReader.req_str(roster, "mode", ro_ctx)
		if L.roster_mode != ROSTER_FIXED and L.roster_mode != ROSTER_FREE:
			DataReader.report(ro_ctx, "mode 必须是 fixed 或 free: %s" % L.roster_mode)
		L.roster_budget = int(DataReader.opt_num(roster, "budget", 0.0, ro_ctx))
		var af: Variant = roster.get("available_forms", null)
		if af != null:
			L.has_available_forms = true
			L.available_forms = DataReader.string_array(DataReader.as_array(af, ro_ctx + ".available_forms"), ro_ctx + ".available_forms")
		L.min_units = int(DataReader.opt_num(roster, "min_units", 1.0, ro_ctx))
		var slot_arr: Array = DataReader.opt_array(roster, "fixed_slots", ro_ctx)
		for i: int in slot_arr.size():
			L.slots.append(SlotDef.from_dict(DataReader.as_dict(slot_arr[i], "%s.fixed_slots[%d]" % [ro_ctx, i]), ro_ctx + ".fixed_slots"))
		L.max_units = int(DataReader.opt_num(roster, "max_units", float(L.slots.size()), ro_ctx))
		if L.is_free():
			if L.roster_budget <= 0:
				DataReader.report(ro_ctx, "free 模式 budget 必须为正")
			if not L.slots.is_empty():
				DataReader.report(ro_ctx, "free 模式不使用 fixed_slots")
		elif L.slots.is_empty():
			DataReader.report(ro_ctx, "fixed 模式需要 fixed_slots")
		if L.min_units < 1 or L.max_units < L.min_units:
			DataReader.report(ro_ctx, "需要 1 ≤ min_units ≤ max_units")
	var spawn_arr: Array = DataReader.opt_array(d, "initial_units", ctx)
	for i: int in spawn_arr.size():
		L.initial_units.append(SpawnDef.from_dict(DataReader.as_dict(spawn_arr[i], "%s.initial_units[%d]" % [ctx, i]), ctx + ".initial_units"))

	var mod_arr: Array = DataReader.opt_array(d, "modifiers", ctx)
	for i: int in mod_arr.size():
		var mctx: String = "%s.modifiers[%d]" % [ctx, i]
		L.modifiers.append(ModifierDef.from_dict(DataReader.as_dict(mod_arr[i], mctx), mctx))

	var route_dict: Dictionary = DataReader.opt_dict(d, "routes", ctx)
	for rid: String in route_dict.keys():
		var rctx: String = "%s.routes.%s" % [ctx, rid]
		L.routes[rid] = RouteDef.from_dict(rid, DataReader.as_dict(route_dict[rid], rctx), rctx)

	var allowed: Dictionary = DataReader.opt_dict(d, "allowed", ctx)
	var actx: String = ctx + ".allowed"
	for raw: String in DataReader.string_array(DataReader.req_array(allowed, "conditions", actx), actx):
		L.allowed_conditions.append(DataReader.enum_value(SimTypes.parse_condition(raw), raw, "条件类型", actx))
	for raw: String in DataReader.string_array(DataReader.req_array(allowed, "selectors", actx), actx):
		L.allowed_selectors.append(DataReader.enum_value(SimTypes.parse_selector(raw), raw, "选敌", actx))
	for raw: String in DataReader.string_array(DataReader.req_array(allowed, "actions", actx), actx):
		L.allowed_actions.append(DataReader.enum_value(SimTypes.parse_action(raw), raw, "行为类型", actx))

	var obj: Dictionary = DataReader.opt_dict(d, "objectives", ctx)
	var octx: String = ctx + ".objectives"
	L.objective_text = DataReader.req_str(obj, "objective_text", octx)
	for item: Variant in DataReader.req_array(obj, "win", octx):
		L.win.append(ObjectiveDef.from_dict(DataReader.as_dict(item, octx + ".win"), true, octx + ".win"))
	for item: Variant in DataReader.req_array(obj, "lose", octx):
		L.lose.append(ObjectiveDef.from_dict(DataReader.as_dict(item, octx + ".lose"), false, octx + ".lose"))
	if obj.has("win") and L.win.is_empty():
		DataReader.report(octx, "至少需要一条 win 条件")
	if obj.has("lose") and L.lose.is_empty():
		DataReader.report(octx, "至少需要一条 lose 条件")

	L.briefing = DataReader.opt_dict(d, "briefing", ctx)
	if d.has("briefing"):
		DataReader.req_str(L.briefing, "mechanic_hint", ctx + ".briefing")
		if L.briefing.has("dialogue"):
			DataReader.report(ctx, "DEPRECATED_FIELD briefing.dialogue 已废弃：战前对白写入 data/stories/<level_id>_intro.json（07 §10.2）")
	L.hints = DataReader.string_array(DataReader.opt_array(d, "hints", ctx), ctx + ".hints")
	L.fail_feedback = DataReader.opt_dict(d, "fail_feedback", ctx)
	if d.has("recommended_deploy"):
		DataReader.report(ctx, "DEPRECATED_FIELD recommended_deploy 已废弃，改用 recommended.units")
	var rec: Dictionary = DataReader.opt_dict(d, "recommended", ctx)
	var rec_ctx: String = ctx + ".recommended"
	L.recommended_phase2 = DataReader.opt_dict(rec, "phase2", rec_ctx)
	if d.has("recommended"):
		var rec_arr: Array = DataReader.req_array(rec, "units", rec_ctx)
		for i: int in rec_arr.size():
			var ru: RecommendedUnitDef = RecommendedUnitDef.from_dict(DataReader.as_dict(rec_arr[i], "%s.units[%d]" % [rec_ctx, i]), rec_ctx + ".units")
			L.recommended_units.append(ru)
			if ru.slot_id != "":
				L.recommended_deploy[ru.slot_id] = ru.pos
	L.rewards = DataReader.opt_dict(d, "rewards", ctx)
	if L.rewards.has("story_id"):
		DataReader.report(ctx, "DEPRECATED_FIELD rewards.story_id 已废弃：剧情按 <level_id>_intro / _win / _lose 约定查找（07 §10.2）")
	L.verification = DataReader.opt_dict(d, "verification", ctx)
	return L


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func is_blocked(c: Vector2i) -> bool:
	return blocked.has(c)


func is_deploy_cell(c: Vector2i) -> bool:
	return deploy_cells.has(c)


func is_free() -> bool:
	return roster_mode == ROSTER_FREE


## 旧格式配置 / 测试中的槽位名 → 形态：fixed 关取槽位形态；free 关取 recommended.units 中同名条目的形态（无则 ""）
func legacy_form(slot_id: String) -> String:
	var slot: SlotDef = get_slot(slot_id)
	if slot != null:
		return slot.unit_id
	var ru: RecommendedUnitDef = get_recommended(slot_id)
	return ru.form if ru != null else ""


## 旧格式配置 / 测试中的槽位名 → 己方序号（模拟 id = ALLY_ID_BASE + 序号）：槽位序号或 recommended 中的位置，无则 -1
func legacy_index(slot_id: String) -> int:
	var slot: SlotDef = get_slot(slot_id)
	if slot != null:
		return slots.find(slot)
	for i: int in recommended_units.size():
		if recommended_units[i].slot_id == slot_id:
			return i
	return -1


func get_slot(slot_id: String) -> SlotDef:
	for s: SlotDef in slots:
		if s.id == slot_id:
			return s
	return null


func get_spawn(spawn_id: String) -> SpawnDef:
	for s: SpawnDef in initial_units:
		if s.id == spawn_id:
			return s
	return null


func get_route(route_id: String) -> RouteDef:
	return routes.get(route_id, null) as RouteDef


## 推荐阵型中某槽位的条目（无则 null）
func get_recommended(slot_id: String) -> RecommendedUnitDef:
	for r: RecommendedUnitDef in recommended_units:
		if r.slot_id == slot_id:
			return r
	return null


## 推荐阵型中某槽位的推荐指令（副本；无条目返回空）
func recommended_rules(slot_id: String) -> Array[RuleDef]:
	var r: RecommendedUnitDef = get_recommended(slot_id)
	return RuleDef.clone_array(r.rules) if r != null else []


## 读取障碍块清单（10 §7）：文件存在、每块字段齐全、cells 在网格内且 ⊆ blocked；有 scene.ground 时提醒 DEPRECATED
static func _read_obstacles(L: LevelDefinition, ctx: String) -> void:
	if L.scene_ground != "":
		DataReader.warn(ctx, "DEPRECATED_FIELD 有障碍块清单时 scene.ground 不再平铺（仅作无资源占位）")
	if not FileAccess.file_exists(L.scene_obstacles):
		DataReader.report(ctx, "障碍块清单不存在：%s" % L.scene_obstacles)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(L.scene_obstacles))
	if not parsed is Dictionary:
		DataReader.report(ctx, "障碍块清单不是 JSON 对象：%s" % L.scene_obstacles)
		return
	var dir: String = L.scene_obstacles.get_base_dir()
	var pieces: Array = DataReader.req_array(parsed as Dictionary, "pieces", ctx)
	for i: int in pieces.size():
		var pctx: String = "%s.pieces[%d]" % [ctx, i]
		if not pieces[i] is Dictionary:
			DataReader.report(pctx, "必须是对象")
			continue
		var pd: Dictionary = pieces[i] as Dictionary
		var file: String = dir.path_join(DataReader.opt_str(pd, "file", "", pctx))
		if not ResourceLoader.exists(file):
			DataReader.report(pctx, "障碍块贴图不存在：%s" % file)
		var cells: Array[Vector2i] = DataReader.cells(DataReader.req_array(pd, "cells", pctx), pctx + ".cells")
		if cells.is_empty():
			DataReader.report(pctx, "cells 不能为空")
		for c: Vector2i in cells:
			if c.x < 0 or c.y < 0 or c.x >= L.width or c.y >= L.height:
				DataReader.report(pctx, "格 %s 超出网格" % str(c))
			elif not L.blocked.has(c):
				DataReader.report(pctx, "格 %s 不在 grid.blocked 内（障碍块只能放在障碍格上）" % str(c))
		var anchor: Array = pd.get("anchor_px", []) as Array if pd.get("anchor_px", []) is Array else []
		var size: Array = pd.get("size_px", []) as Array if pd.get("size_px", []) is Array else []
		if anchor.size() != 2 or size.size() != 2 or float(size[0]) <= 0.0 or float(size[1]) <= 0.0:
			DataReader.report(pctx, "anchor_px 必须是 [x, y]，size_px 必须是正的 [w, h]")
			continue
		L.obstacle_pieces.append({ "file": file, "cells": cells, "anchor": Vector2(float(anchor[0]), float(anchor[1])), "size": Vector2(float(size[0]), float(size[1])) })
