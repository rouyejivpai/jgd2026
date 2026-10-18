class_name TeachingDef
extends RefCounted
## 第五阶段（2026-10-17 会议）：教学与解锁配置（data/teaching.json，由配置器 tools/config_editor 统一编辑）。
## 每关一条（键 = 关卡 id）：
##   test           true = 测试内容（引导标题前加「【测试】」，待统一配置时替换）
##   tutorial.steps 强制引导步骤（见 normalize_step）
##   allowed / rewards / hints / mechanic_hint  可选：覆盖关卡 JSON 中的同名字段（allowed、rewards 按键覆盖；hints 整组；mechanic_hint = briefing.mechanic_hint）
##   roster / objectives（按键覆盖）、deploy_zone / initial_units / modifiers（整体替换）  可选：关卡配置（数值策划），配置器「关卡配置」页编辑
## 第七关数据冻结（00 §1 铁律 5）：只允许配置引导，不允许覆盖 allowed / rewards / hints / mechanic_hint。
## style：引导遮罩 / 高亮 / 箭头 / 文字框的表现参数（数值不进代码）。

const TARGET_KINDS: Array[String] = ["none", "ui", "cell", "cells", "deploy_zone", "unit", "ally", "blocked", "ring"]
const ADVANCES: Array[String] = ["next", "click", "tap", "event"]
## 推进事件：deployed 放下一名单位；ally_selected / enemy_selected 选中己方 / 敌方；beacon_placed 放置信标；
## beacon_mode 进入信标模式；rules_changed 改了指令；battle_started 开始战斗；
## drag_started 开始拖动出场卡；beacon_mode_exit 退出信标模式（教程关引导 PPT，2026-10-18）
const EVENTS: Array[String] = ["deployed", "ally_selected", "enemy_selected", "beacon_placed", "beacon_mode", "rules_changed", "battle_started",
	"drag_started", "beacon_mode_exit"]
const COUNTED_EVENTS: Array[String] = ["deployed", "beacon_placed"]       ## 可带 count（累计数量）的事件
const RINGS: Array[String] = ["vision", "attack"]
const ARROWS: Array[String] = ["auto", "up", "down", "left", "right", "none"]
const PANELS: Array[String] = ["auto", "left", "right", "top", "bottom", "center"]
const PHASES: Array[String] = ["deploy", "running"]
const OVERRIDE_KEYS: Array[String] = ["allowed", "rewards", "hints", "mechanic_hint", "roster", "deploy_zone", "initial_units", "objectives", "modifiers"]
const LEVEL_CONFIG_KEYS: Array[String] = ["roster", "deploy_zone", "initial_units", "objectives", "modifiers"]   ## 关卡配置页负责的覆盖项
const MERGED_KEYS: Array[String] = ["allowed", "rewards", "roster", "objectives"]                              ## 按键合并；其余整体替换
const FROZEN_LEVEL: String = "level_07"
const DEFAULT_STYLE: Dictionary = {
	"dim_color": "#05030Acc", "highlight_color": "#E8C46A", "highlight_width": 3.0, "hole_pad": 10.0,
	"arrow_size": 34.0, "arrow_gap": 14.0, "arrow_bob": 8.0, "arrow_bob_hz": 1.4, "panel_width": 460.0, "panel_margin": 24.0,
	"zoom_seconds": 0.25,
}

var style: Dictionary = DEFAULT_STYLE.duplicate()
var levels: Dictionary = {}               ## level_id -> 原始条目（Dictionary）
var _steps: Dictionary = {}               ## level_id -> Array[Dictionary]（规整后的步骤）


static func from_dict(d: Dictionary, ctx: String) -> TeachingDef:
	var t := TeachingDef.new()
	var st: Dictionary = DataReader.opt_dict(d, "style", ctx)
	for k: String in st.keys():
		if not DEFAULT_STYLE.has(k):
			DataReader.report(ctx + ".style", "未知字段 %s" % k)
		t.style[k] = st[k]
	var lv: Dictionary = DataReader.opt_dict(d, "levels", ctx)
	for lid: String in lv.keys():
		var lctx: String = "%s.levels.%s" % [ctx, lid]
		var e: Dictionary = DataReader.as_dict(lv[lid], lctx)
		t.levels[lid] = e
		for k: String in e.keys():
			if k != "test" and k != "tutorial" and k != "_comment" and not OVERRIDE_KEYS.has(k):
				DataReader.report(lctx, "未知字段 %s" % k)
		if lid == FROZEN_LEVEL:
			for k: String in OVERRIDE_KEYS:
				if e.has(k):
					DataReader.report(lctx, "第七关数据冻结，不能覆盖 %s（只允许配置引导）" % k)
		var steps: Array[Dictionary] = []
		var tut: Dictionary = DataReader.opt_dict(e, "tutorial", lctx)
		var raw_steps: Array = DataReader.opt_array(tut, "steps", lctx + ".tutorial")
		for i: int in raw_steps.size():
			steps.append(normalize_step(DataReader.as_dict(raw_steps[i], "%s.tutorial.steps[%d]" % [lctx, i]), "%s.tutorial.steps[%d]" % [lctx, i]))
		t._steps[lid] = steps
	return t


## 步骤字段（缺省值见右）：
##   text      文字说明（必填）           title  标题（可空）
##   targets   高亮目标数组；第一个是箭头指向的目标。每项 { kind, node | cell | cells | spawn }：
##             ui = HUD 中的节点（node：节点名，或「名字/子路径」）；cell / cells = 地块；deploy_zone = 部署区；
##             unit = 关卡预置单位（spawn：initial_units 的 id）；ally = 第一名已部署的己方单位；none = 无高亮（只有文字框）；
##             blocked = 全部障碍格（相连的障碍格合成一处高亮）；ring = 单位的视野圈 / 射程圈（ring：vision / attack；
##             spawn：预置单位 id，省略 = 第一名己方）
##             ui 目标可带 zoom（> 1 时该元素放大显示，如出场卡 1.15）
##   advance   next（按「下一步」）/ click（点高亮处）/ tap（点屏幕任意处）/ event（等事件，见 EVENTS）
##   event     advance = event 时的事件名
##   count     event 为 deployed / beacon_placed 时：已部署单位数 / 全场信标数累计达到 count 才推进（默认 1）
##   block     true = 只允许点高亮处（默认：有高亮且不是 next 时为 true）
##   arrow     auto / up / down / left / right / none（箭头从哪一侧指向目标；auto = 自动）
##   panel     文字框位置 auto / left / right / top / bottom / center（机制说明可放右侧）
##   phase     deploy（部署阶段）/ running（战斗中，出现时暂停战斗）
##   after     phase = running 时，战斗进行到第几秒才出现（默认 0）
##   deselect  true = 出现时取消选中单位（收起侧栏，露出被它盖住的「开始」等按钮）
static func normalize_step(d: Dictionary, ctx: String) -> Dictionary:
	var s: Dictionary = {}
	s["text"] = DataReader.req_str(d, "text", ctx)
	s["title"] = DataReader.opt_str(d, "title", "", ctx)
	var targets: Array[Dictionary] = []
	for i: int in DataReader.opt_array(d, "targets", ctx).size():
		targets.append(_target((d["targets"] as Array)[i] as Dictionary if (d["targets"] as Array)[i] is Dictionary else {}, "%s.targets[%d]" % [ctx, i]))
	s["targets"] = targets
	s["advance"] = DataReader.opt_str(d, "advance", "next", ctx)
	if not ADVANCES.has(str(s["advance"])):
		DataReader.report(ctx, "advance 必须是 %s 之一" % str(ADVANCES))
	s["event"] = DataReader.opt_str(d, "event", "", ctx)
	if s["advance"] == "event" and not EVENTS.has(str(s["event"])):
		DataReader.report(ctx, "advance = event 时 event 必须是 %s 之一" % str(EVENTS))
	s["count"] = int(DataReader.opt_num(d, "count", 1.0, ctx))
	if int(s["count"]) < 1:
		DataReader.report(ctx, "count 至少为 1")
	elif int(s["count"]) > 1 and not COUNTED_EVENTS.has(str(s["event"])):
		DataReader.report(ctx, "count 只用于 %s 事件" % str(COUNTED_EVENTS))
	if s["advance"] == "click" and targets.filter(func(t: Dictionary) -> bool: return str(t["kind"]) != "none").is_empty():
		DataReader.report(ctx, "advance = click 需要至少一个高亮目标")
	var has_hole: bool = targets.any(func(t: Dictionary) -> bool: return str(t["kind"]) != "none")
	s["block"] = DataReader.opt_bool(d, "block", has_hole and s["advance"] != "next", ctx)
	s["arrow"] = DataReader.opt_str(d, "arrow", "auto", ctx)
	if not ARROWS.has(str(s["arrow"])):
		DataReader.report(ctx, "arrow 必须是 %s 之一" % str(ARROWS))
	s["panel"] = DataReader.opt_str(d, "panel", "auto", ctx)
	if not PANELS.has(str(s["panel"])):
		DataReader.report(ctx, "panel 必须是 %s 之一" % str(PANELS))
	s["phase"] = DataReader.opt_str(d, "phase", "deploy", ctx)
	if not PHASES.has(str(s["phase"])):
		DataReader.report(ctx, "phase 必须是 deploy / running")
	s["after"] = DataReader.opt_num(d, "after", 0.0, ctx)
	s["deselect"] = DataReader.opt_bool(d, "deselect", false, ctx)
	return s


static func _target(d: Dictionary, ctx: String) -> Dictionary:
	var t: Dictionary = { "kind": DataReader.req_str(d, "kind", ctx) }
	match str(t["kind"]):
		"ui":
			t["node"] = DataReader.req_str(d, "node", ctx)
			t["zoom"] = DataReader.opt_num(d, "zoom", 1.0, ctx)
			if float(t["zoom"]) <= 0.0:
				DataReader.report(ctx, "zoom 必须大于 0")
		"ring":
			t["spawn"] = DataReader.opt_str(d, "spawn", "", ctx)
			t["ring"] = DataReader.opt_str(d, "ring", "vision", ctx)
			if not RINGS.has(str(t["ring"])):
				DataReader.report(ctx, "ring 必须是 %s 之一" % str(RINGS))
		"cell":
			t["cells"] = [DataReader.cell(d.get("cell", null), ctx + ".cell")] as Array[Vector2i]
		"cells":
			var cs: Array[Vector2i] = []
			for c: Variant in DataReader.req_array(d, "cells", ctx):
				cs.append(DataReader.cell(c, ctx + ".cells"))
			if cs.is_empty():
				DataReader.report(ctx, "cells 不能为空")
			t["cells"] = cs
		"unit":
			t["spawn"] = DataReader.req_str(d, "spawn", ctx)
		"none", "deploy_zone", "ally", "blocked":
			pass
		_:
			DataReader.report(ctx, "kind 必须是 %s 之一" % str(TARGET_KINDS))
	return t


## 关卡相关的交叉校验：地块在网格内、unit 引用的预置单位存在
func validate_against(level_defs: Dictionary, ctx: String) -> void:
	for lid: String in levels.keys():
		var L: LevelDefinition = level_defs.get(lid, null) as LevelDefinition
		if L == null:
			DataReader.report("%s.levels.%s" % [ctx, lid], "关卡不存在")
			continue
		for i: int in (_steps.get(lid, []) as Array).size():
			var step: Dictionary = (_steps[lid] as Array)[i] as Dictionary
			for t: Dictionary in step["targets"] as Array[Dictionary]:
				var sctx: String = "%s.levels.%s.tutorial.steps[%d]" % [ctx, lid, i]
				for c: Vector2i in t.get("cells", []) as Array:
					if not L.in_bounds(c):
						DataReader.report(sctx, "地块 %s 越界" % str(c))
				if (str(t["kind"]) == "unit" or (str(t["kind"]) == "ring" and str(t["spawn"]) != "")) and L.get_spawn(str(t["spawn"])) == null:
					DataReader.report(sctx, "预置单位 '%s' 不存在" % str(t["spawn"]))
				if str(t["kind"]) == "blocked" and L.blocked.is_empty():
					DataReader.report(sctx, "本关没有障碍格")


func has_tutorial(level_id: String) -> bool:
	return not (_steps.get(level_id, []) as Array).is_empty()


func tutorial_steps(level_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign((_steps.get(level_id, []) as Array).duplicate(true))
	return out


func is_test(level_id: String) -> bool:
	return bool((levels.get(level_id, {}) as Dictionary).get("test", false))


## 把某关的覆盖项写进关卡原始数据（加载 LevelDefinition 之前调用；返回新字典，不改原数据）
static func apply_overrides(raw_level: Dictionary, entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return raw_level
	var out: Dictionary = raw_level.duplicate(true)
	for key: String in MERGED_KEYS:
		if entry.get(key, null) is Dictionary:
			var merged: Dictionary = (out.get(key, {}) as Dictionary).duplicate(true) if out.get(key, null) is Dictionary else {}
			var src: Dictionary = entry[key] as Dictionary
			for k: String in src.keys():
				merged[k] = src[k]
			out[key] = merged
	for key: String in ["deploy_zone", "initial_units", "modifiers"]:
		if entry.has(key):
			var v: Variant = entry[key]
			if v is Array:
				out[key] = (v as Array).duplicate(true)
			elif v is Dictionary:
				out[key] = (v as Dictionary).duplicate(true)
			else:
				out[key] = v
	if entry.get("hints", null) is Array:
		out["hints"] = (entry["hints"] as Array).duplicate()
	if entry.get("mechanic_hint", null) is String:
		var br: Dictionary = (out.get("briefing", {}) as Dictionary).duplicate(true) if out.get("briefing", null) is Dictionary else {}
		br["mechanic_hint"] = entry["mechanic_hint"]
		out["briefing"] = br
	return out
