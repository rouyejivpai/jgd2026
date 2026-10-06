class_name LevelData
extends RefCounted
## 详细设计：[docs/design/06-关卡数据与胜负条件.md](../../docs/design/06-关卡数据与胜负条件.md) 3.1 / 4.1
##
## 一个关卡的全部数据（与 `res://data/levels/*.json` 一一对应）。
##
## 【校验分两层，别搞混】
## · 结构校验在本类：必填字段、类型、范围、坐标是否在地图内、条件参数是否齐全。
##   错误信息统一为「字段路径: 问题」，便于在编辑器里定位。
## · 语义校验在 LevelSession / BattleMap：真正建网格、生成单位时才会暴露的问题。
## 编辑器保存前**必须**调本类的 `validate()`，保证存出去的文件一定能被运行时载入。

const LOGIC_ANY := "any"
const LOGIC_ALL := "all"

## 已知的胜利条件类型（MVP 实现前三种）
const WIN_TYPES := ["annihilate", "reach_position", "survive_until", "destroy_core"]

## 胜负条件类型的**中文显示名**。
##
## 【只影响显示，不影响数据】关卡文件里存的始终是英文 id（`reach_position` 等）——
## 校验、判定、存档全都认 id。这份表只给 UI 当标签用。
## 【为什么放在这里】它必须与 `WIN_TYPES` / `LOSE_TYPES` **同处定义**，
## 否则加一个条件类型时很容易只改一处、UI 就少一项或显示成英文 id。
const CONDITION_NAMES := {
	"annihilate": "全歼敌人",
	"reach_position": "到达指定位置",
	"survive_until": "坚持到指定时间",
	"destroy_core": "摧毁核心装置",
	"all_allies_dead": "我方全灭",
	"timeout": "超时",
	"protected_died": "保护目标阵亡",
	"custom": "自定义",
}

## 条件**组之间**逻辑的中文名（组内逻辑在指令面板里是「与 / 或」，是另一个概念）
const LOGIC_NAMES := {"any": "任一满足", "all": "全部满足"}

## 单位阵营的中文名
const TEAM_NAMES := {"ally": "我方", "enemy": "敌方"}


## 条件类型的中文显示名；未知类型**原样返回**（宁可露出 id 也不要显示空白）
static func condition_display_name(type_id: String) -> String:
	return str(CONDITION_NAMES.get(type_id, type_id))


## 组间逻辑的中文显示名
static func logic_display_name(v: String) -> String:
	return str(LOGIC_NAMES.get(v, v))


## 阵营的中文显示名
static func team_display_name(v: String) -> String:
	return str(TEAM_NAMES.get(v, v))
## 已知的失败条件类型
const LOSE_TYPES := ["all_allies_dead", "timeout", "protected_died", "custom"]


## 某组的可选条件类型（编辑器下拉用）
static func condition_types(which: String) -> Array:
	return WIN_TYPES if which == "win" else LOSE_TYPES


## 条件的参数 schema —— 编辑器据此动态生成控件。
##
## 【为什么放这里而不是编辑器里】参数要求与 `_validate_condition_group` 是**同一份知识**：
## 校验器要求 `reach_position` 必须有非空 `area`，编辑器就该知道要画一个格子列表。
## 两处分开放，早晚会漂移成"编辑器让你存、校验器说你非法"。
##
## 字段含义与规则条件的 schema 一致（`key` / `type` / `label` / `default`），
## 这样编辑器的控件工厂可以直接复用。
static func condition_schema(type_id: String) -> Array:
	match type_id:
		"reach_position":
			return [{"key": "area", "type": "cell_list", "label": "目标格", "default": []}]
		"survive_until", "timeout":
			# 【step 必须与 min 对齐】min=0.1 配默认 step=0.5 时网格是 0.1+0.5n，
			# 30.0 不在格点上，SpinBox 会显示成 30.1（实测）。
			# 用 step=0.1 让 30.0 正好落格。
			return [{"key": "seconds", "type": "float", "label": "秒数", "default": 30.0,
				"min": 0.1, "max": 9999.0, "step": 0.1}]
		"protected_died":
			# 单位下标：候选项由编辑器按关卡里的我方单位数动态给出
			return [{"key": "unit_ref", "type": "int", "label": "单位下标", "default": 0,
				"min": 0, "max": 63}]
		"destroy_core":
			return [{"key": "device_id", "type": "int", "label": "装置编号", "default": 0,
				"min": 0, "max": 63}]
		_:
			return []          # annihilate / all_allies_dead / custom 无参数


## 按 schema 造一条带默认参数的条件（编辑器"加条件"用）
static func make_default_condition(type_id: String) -> Dictionary:
	var d := {"type": type_id}
	for spec in condition_schema(type_id):
		d[str((spec as Dictionary).get("key"))] = (spec as Dictionary).get("default")
	return d

var id := ""
var name := ""
var order := 0
var map: Dictionary = {}
var beacon_quota := 0
var signal_count := 0
var time_limit := 0.0
var units: Array = []
var win: Dictionary = {}
var lose: Dictionary = {}
var intro: Dictionary = {}
## 兼容位：原样保留、不做校验，供后续玩法扩展
var tags: Array = []
var extra: Dictionary = {}


# ---------------------------------------------------------------------------
# 构建
# ---------------------------------------------------------------------------

## 从解析好的 JSON 字典构建。**不做校验**，校验请另调 validate()。
##
## 【注意】这里用自己的类名 self-reference 也要小心：本沙箱环境下
## `class_name` 不会进入全局类缓存，所以脚本内部**也不能**写 `LevelData.new()`
## 或把 `LevelData` 当返回类型/类型标注 —— 会报 `Identifier not found: LevelData`。
## 用 `new()`（隐式自身）与 `RefCounted` 代替。
static func from_dict(d: Dictionary) -> RefCounted:
	var lv := new()
	lv.id = str(d.get("id", ""))
	lv.name = str(d.get("name", ""))
	lv.order = int(d.get("order", 0))
	var m = d.get("map", {})
	lv.map = m if m is Dictionary else {}
	lv.beacon_quota = int(d.get("beacon_quota", 0))
	lv.signal_count = int(d.get("signal_count", 0))
	lv.time_limit = float(d.get("time_limit", 0.0))
	var u = d.get("units", [])
	lv.units = u if u is Array else []
	var w = d.get("win", {})
	lv.win = w if w is Dictionary else {}
	var l = d.get("lose", {})
	lv.lose = l if l is Dictionary else {}
	var it = d.get("intro", {})
	lv.intro = it if it is Dictionary else {}
	var tg = d.get("tags", [])
	lv.tags = tg if tg is Array else []
	var ex = d.get("extra", {})
	lv.extra = ex if ex is Dictionary else {}
	return lv


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"order": order,
		"map": map,
		"beacon_quota": beacon_quota,
		"signal_count": signal_count,
		"time_limit": time_limit,
		"units": units,
		"win": win,
		"lose": lose,
		"intro": intro,
		"tags": tags,
		"extra": extra,
	}


func to_json_string() -> String:
	return JSON.stringify(to_dict(), "  ")


## 地图尺寸（拿不到时返回 Vector2i.ZERO）
func map_size() -> Vector2i:
	return Vector2i(int(map.get("width", 0)), int(map.get("height", 0)))


# ---------------------------------------------------------------------------
# 校验
# ---------------------------------------------------------------------------

## 结构校验。返回错误列表；**空列表才算通过**。
##
## known_unit_types 传空数组时跳过「单位类型是否存在」这一项
## （方便只做结构校验的场景，例如编辑器尚未载入 units.json）。
func validate(known_unit_types: Array = []) -> Array[String]:
	var errors: Array[String] = []

	# --- 顶层必填 ---
	if id.is_empty():
		errors.append("id: 不能为空")
	if name.is_empty():
		errors.append("name: 不能为空")
	if beacon_quota < 0:
		errors.append("beacon_quota: 不能为负（实际 %d）" % beacon_quota)
	if signal_count < 0:
		errors.append("signal_count: 不能为负（实际 %d）" % signal_count)
	if time_limit < 0.0:
		errors.append("time_limit: 不能为负（实际 %s）" % str(time_limit))

	# --- 地图 ---
	var size := map_size()
	if size.x <= 0 or size.y <= 0:
		errors.append("map.width/height: 必须为正（实际 %s）" % str(size))
	else:
		var tiles = map.get("tiles")
		if not (tiles is Array):
			errors.append("map.tiles: 期望二维数组")
		else:
			var rows: Array = tiles
			if rows.size() != size.y:
				errors.append("map.tiles: 行数 %d 与 height %d 不符" % [rows.size(), size.y])
				# 行数都不对就不必再逐行查了
				rows = []

	# --- 单位 ---
	if units.is_empty():
		errors.append("units: 至少要有一个单位")
	for i in units.size():
		var entry = units[i]
		var path := "units[%d]" % i
		if not (entry is Dictionary):
			errors.append("%s: 期望对象" % path)
			continue
		var e: Dictionary = entry

		var team := str(e.get("team", ""))
		if team != "ally" and team != "enemy":
			errors.append("%s.team: 只能是 ally 或 enemy（实际 \"%s\"）" % [path, team])

		var type_id := str(e.get("type", ""))
		if type_id.is_empty():
			errors.append("%s.type: 不能为空" % path)
		elif not known_unit_types.is_empty() and not known_unit_types.has(type_id):
			errors.append("%s.type: 单位类型 \"%s\" 不存在于 units.json" % [path, type_id])

		var pos = e.get("pos")
		if not (pos is Array) or (pos as Array).size() != 2:
			errors.append("%s.pos: 期望 [x, y]" % path)
		elif size.x > 0 and size.y > 0:
			var px := int((pos as Array)[0])
			var py := int((pos as Array)[1])
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				errors.append("%s.pos: [%d, %d] 超出地图范围 %s" % [path, px, py, str(size)])

		var ov = e.get("overrides", {})
		if not (ov is Dictionary):
			errors.append("%s.overrides: 期望对象" % path)

		# 【buff 接口预留】(D-28)：允许单位条目带 `buffs`（字符串数组）。
		# 只校验形状、不解释含义 —— 现在没有任何 buff 生效，
		# 提前定义取值集合只会给后续设计添约束。
		if e.has("buffs"):
			var bv = e["buffs"]
			if not (bv is Array):
				errors.append("%s.buffs: 期望数组" % path)
			else:
				for bi in (bv as Array).size():
					if not ((bv as Array)[bi] is String):
						errors.append("%s.buffs[%d]: 期望字符串" % [path, bi])

	# --- 胜负条件 ---
	errors.append_array(_validate_condition_group("win", win, WIN_TYPES, size))
	errors.append_array(_validate_condition_group("lose", lose, LOSE_TYPES, size))
	if win.is_empty():
		errors.append("win: 缺少胜利条件（至少要有一条）")
	if lose.is_empty():
		errors.append("lose: 缺少失败条件（至少要有一条）")

	return errors


func _validate_condition_group(group_name: String, group: Dictionary,
		allowed: Array, size: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	if group.is_empty():
		return errors

	var logic := str(group.get("logic", LOGIC_ANY))
	if logic != LOGIC_ANY and logic != LOGIC_ALL:
		errors.append("%s.logic: 只能是 any 或 all（实际 \"%s\"）" % [group_name, logic])

	var conds = group.get("conditions")
	if not (conds is Array) or (conds as Array).is_empty():
		errors.append("%s.conditions: 至少要有一条条件" % group_name)
		return errors

	var list: Array = conds
	for i in list.size():
		var path := "%s.conditions[%d]" % [group_name, i]
		var c = list[i]
		if not (c is Dictionary):
			errors.append("%s: 期望对象" % path)
			continue
		var cd: Dictionary = c
		var ctype := str(cd.get("type", ""))
		if ctype.is_empty():
			errors.append("%s.type: 不能为空" % path)
			continue
		if not allowed.has(ctype):
			errors.append("%s.type: 未知条件类型 \"%s\"（允许 %s）" % [path, ctype, ", ".join(allowed)])
			continue
		# 各类型的参数要求
		match ctype:
			"reach_position":
				var area = cd.get("area")
				if not (area is Array) or (area as Array).is_empty():
					errors.append("%s.area: reach_position 需要非空的格子列表" % path)
				elif size.x > 0 and size.y > 0:
					for j in (area as Array).size():
						var cell = (area as Array)[j]
						if not (cell is Array) or (cell as Array).size() != 2:
							errors.append("%s.area[%d]: 期望 [x, y]" % [path, j])
						else:
							var ax := int((cell as Array)[0])
							var ay := int((cell as Array)[1])
							if ax < 0 or ay < 0 or ax >= size.x or ay >= size.y:
								errors.append("%s.area[%d]: [%d, %d] 超出地图范围" % [path, j, ax, ay])
			"survive_until":
				var secs = cd.get("seconds")
				if not (secs is float or secs is int) or float(secs) <= 0.0:
					errors.append("%s.seconds: survive_until 需要正的秒数" % path)
				elif time_limit > 0.0 and float(secs) > time_limit:
					# 全局时限比条件时限还短 → 条件永远不可能达成，是明显的配置矛盾
					errors.append("%s.seconds: %s 大于 time_limit %s，条件不可能达成"
						% [path, str(secs), str(time_limit)])
			"protected_died":
				if not cd.has("unit_ref"):
					errors.append("%s.unit_ref: protected_died 需要指定单位下标" % path)
			"destroy_core":
				if not cd.has("device_id"):
					errors.append("%s.device_id: destroy_core 需要指定装置（MVP 未实现）" % path)
	return errors


# ---------------------------------------------------------------------------
# 便捷查询
# ---------------------------------------------------------------------------

## 我方单位条目
func ally_entries() -> Array:
	return _entries_of_team("ally")


## 敌方单位条目
func enemy_entries() -> Array:
	return _entries_of_team("enemy")


func _entries_of_team(team: String) -> Array:
	var out: Array = []
	for e in units:
		if e is Dictionary and str((e as Dictionary).get("team", "")) == team:
			out.append(e)
	return out


## 胜/负条件的组间逻辑，缺省为 any
func win_logic() -> String:
	return str(win.get("logic", LOGIC_ANY))


func lose_logic() -> String:
	return str(lose.get("logic", LOGIC_ANY))


func win_conditions() -> Array:
	var c = win.get("conditions", [])
	return c if c is Array else []


func lose_conditions() -> Array:
	var c = lose.get("conditions", [])
	return c if c is Array else []
