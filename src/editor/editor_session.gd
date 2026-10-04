class_name EditorSession
extends RefCounted
## 详细设计：[docs/design/07-关卡编辑器.md](../../docs/design/07-关卡编辑器.md) 3-4
##
## 编辑器的**会话与数据改动层**。UI 只负责把用户操作翻译成这里的方法调用，
## 所有「改了数据会怎样、能不能改、撤销栈怎么走」的逻辑都在本类。
##
## 【为什么把逻辑与 UI 分开】这是唯一能让编辑器被 headless 冒烟测试覆盖的办法。
## UI（布局、点击、抽屉宽度）要人眼看；但「刷一格墙之后 tiles 变成什么、
## 缩小地图会不会丢单位、撤销能不能回到上一态」这些必须自动化验。
##
## 【边界约定】详设 07 的 2.3：
## · 只操作 `LevelData`，不碰 `BattleMap` / `BattleState`
## · 保存前必须调用 `LevelData.validate()`（校验口径唯一）
## · 不改变 manifest 既有顺序，除非用户显式调整

const LevelDataScript := preload("res://src/core/level/level_data.gd")
const BattleMapScript := preload("res://src/core/map/battle_map.gd")

## 瓦片类型（复用 BattleMap 的定义，保证与运行时同一套口径）
const TILE_EMPTY := BattleMapScript.TILE_EMPTY
const TILE_WALL := BattleMapScript.TILE_WALL
const TILE_GOAL := BattleMapScript.TILE_GOAL

## 当前工具（详设 07 的 3.1）
const TOOL_PAINT_EMPTY := 0
const TOOL_PAINT_WALL := 1
const TOOL_PAINT_GOAL := 2
const TOOL_PLACE_UNIT := 3
const TOOL_ERASE := 4
const TOOL_SELECT := 5

## 撤销栈深度（需求 12.1 决策）
const UNDO_DEPTH := 50

const TEAM_ALLY := "ally"
const TEAM_ENEMY := "enemy"

## 被编辑的关卡数据（LevelData）
var level_data = null
## 来源路径；空串表示「未保存的新关卡」
var source_path := ""
var active_tool := TOOL_SELECT
var selected_unit_type := "standard"
var selected_team := TEAM_ALLY
## 当前选中的对象：{kind: "tile"/"unit"/"level"/"condition", ...}
var selection: Dictionary = {}
## 有未保存改动
var dirty := false

var _undo: Array[String] = []
var _redo: Array[String] = []
## 拖拽事务：>0 表示正在一次拖拽中，中途不入栈
var _txn_depth := 0
var _txn_entry_pushed := false


func setup(p_level_data, p_source_path: String = "") -> void:
	level_data = p_level_data
	source_path = p_source_path
	_undo.clear()
	_redo.clear()
	dirty = false
	selection = {}


# ---------------------------------------------------------------------------
# 撤销 / 重做（快照式，详设 07 的 3.2）
# ---------------------------------------------------------------------------

## 开始一次事务（鼠标按下）。一次拖拽刷多格只算**一次**操作。
func begin_transaction() -> void:
	if _txn_depth == 0:
		_txn_entry_pushed = false
	_txn_depth += 1


## 结束事务（鼠标抬起）
func end_transaction() -> void:
	if _txn_depth <= 0:
		return
	_txn_depth -= 1


func in_transaction() -> bool:
	return _txn_depth > 0


## 在改动**之前**记录快照。事务内只记第一次。
func _push_undo() -> void:
	if _txn_depth > 0:
		if _txn_entry_pushed:
			return
		_txn_entry_pushed = true
	_undo.append(_snapshot())
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func _snapshot() -> String:
	return str(level_data.call("to_json_string"))


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_snapshot())
	var s: String = _undo.pop_back()
	_restore(s)
	dirty = true
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_snapshot())
	var s: String = _redo.pop_back()
	_restore(s)
	dirty = true
	return true


func _restore(snapshot: String) -> void:
	var parsed = JSON.parse_string(snapshot)
	if parsed is Dictionary:
		level_data = LevelDataScript.from_dict(parsed)


func undo_size() -> int:
	return _undo.size()


func redo_size() -> int:
	return _redo.size()


# ---------------------------------------------------------------------------
# 地图尺寸与瓦片
# ---------------------------------------------------------------------------

func map_width() -> int:
	return int(level_data.call("map_size").x)


func map_height() -> int:
	return int(level_data.call("map_size").y)


func tile_at(x: int, y: int) -> int:
	var tiles: Array = level_data.map["tiles"]
	if y < 0 or y >= tiles.size():
		return -1
	var row: Array = tiles[y]
	if x < 0 or x >= row.size():
		return -1
	return int(row[x])


## 改地图尺寸：**保留**与新区重叠区域的数据；越界单位与目标区一并清理
## （详设 07 的 4.1）。返回是否成功。
func resize_map(w: int, h: int) -> bool:
	if w <= 0 or h <= 0:
		return false
	var old_w := map_width()
	var old_h := map_height()
	if w == old_w and h == old_h:
		return false

	_push_undo()

	var old_tiles: Array = level_data.map["tiles"]
	var new_tiles: Array = []
	for j in h:
		var row: Array = []
		for i in w:
			if j < old_h and i < old_w:
				row.append(int((old_tiles[j] as Array)[i]))
			else:
				row.append(TILE_EMPTY)
		new_tiles.append(row)
	level_data.map["width"] = w
	level_data.map["height"] = h
	level_data.map["tiles"] = new_tiles

	# 越界单位清理
	var kept: Array = []
	for u in (level_data.units as Array):
		var pos_arr: Array = (u as Dictionary).get("pos", [0, 0])
		var ux := int(pos_arr[0])
		var uy := int(pos_arr[1])
		if ux >= 0 and ux < w and uy >= 0 and uy < h:
			kept.append(u)
	level_data.units = kept

	_sync_goal_area()
	return true


## 设置一格瓦片。返回是否改动成功。
## 若该格上有单位且新瓦片**不可通行** → 拒绝（详设 07 的 4.1）。
func set_tile(x: int, y: int, tile_id: int) -> bool:
	if x < 0 or x >= map_width() or y < 0 or y >= map_height():
		return false
	if tile_at(x, y) == tile_id:
		return false
	# 不可通行的瓦片不能让单位站在上面
	if tile_id != TILE_EMPTY and _unit_at(x, y) != null:
		last_error = "该格上有单位，不能改成障碍或目标区"
		return false

	_push_undo()
	var tiles: Array = level_data.map["tiles"]
	(tiles[y] as Array)[x] = tile_id
	_sync_goal_area()
	return true


## 擦除：有单位则删单位，否则置为 0（详设 07 的 4.1）
func erase_at(x: int, y: int) -> bool:
	var u = _unit_at(x, y)
	if u != null:
		return remove_unit_at(x, y)
	return set_tile(x, y, TILE_EMPTY)


## 最近一次操作的错误说明（给 UI 提示用）
var last_error := ""


# ---------------------------------------------------------------------------
# 单位
# ---------------------------------------------------------------------------

func _unit_at(x: int, y: int):
	for u in (level_data.units as Array):
		var pos_arr: Array = (u as Dictionary).get("pos", [0, 0])
		if int(pos_arr[0]) == x and int(pos_arr[1]) == y:
			return u
	return null


## 放置单位。该格已有单位 → 拒绝；瓦片不可通行 → 拒绝（详设 07 的 4.1）。
func place_unit(x: int, y: int, type_id: String, team: String = TEAM_ALLY) -> bool:
	last_error = ""
	if x < 0 or x >= map_width() or y < 0 or y >= map_height():
		last_error = "超出地图范围"
		return false
	if _unit_at(x, y) != null:
		last_error = "该格已有单位"
		return false
	if tile_at(x, y) != TILE_EMPTY:
		last_error = "该格不可通行，不能放单位"
		return false

	_push_undo()
	# `units` 是 LevelData 的数组属性，直接改它（不必走 set）
	var arr: Array = level_data.units
	arr.append({"team": team, "type": type_id, "pos": [x, y], "overrides": {}})
	return true


func remove_unit_at(x: int, y: int) -> bool:
	var u = _unit_at(x, y)
	if u == null:
		return false
	_push_undo()
	var kept: Array = []
	for other in (level_data.units as Array):
		if other != u:
			kept.append(other)
	level_data.units = kept
	return true


func unit_count(team: String = "") -> int:
	var n := 0
	for u in (level_data.units as Array):
		if team.is_empty() or str((u as Dictionary).get("team", "")) == team:
			n += 1
	return n


## 改某格单位的类型
func set_unit_type(x: int, y: int, type_id: String) -> bool:
	var u = _unit_at(x, y)
	if u == null:
		return false
	_push_undo()
	(u as Dictionary)["type"] = type_id
	return true


## 改某格单位的关卡级覆盖（只允许已存在的字段，由 LevelData 校验兜底）
func set_unit_overrides(x: int, y: int, overrides: Dictionary) -> bool:
	var u = _unit_at(x, y)
	if u == null:
		return false
	_push_undo()
	(u as Dictionary)["overrides"] = overrides.duplicate(true)
	return true


# ---------------------------------------------------------------------------
# 目标区 ↔ reach_position 自动联动（详设 07 的 4.1）
# ---------------------------------------------------------------------------

## 把所有「刷成目标区（瓦片 2）」的格子集合同步进 win 里那个
## **由编辑器自动维护**的 `reach_position` 条件（标记 `auto_area: true`）。
##
## 【为什么要标记】手写的 reach_position 条件不能被编辑器动。只有带
## auto_area 的那一个才跟着瓦片走，否则玩家手配的条件会被静默改掉。
func _sync_goal_area() -> void:
	var goals: Array = _goal_cells()
	var cond = _find_auto_area_condition()

	if goals.is_empty():
		# 没有目标格了：把自动条件的 area 清空（条件本身留着，标黄提示）
		if cond != null:
			(cond as Dictionary)["area"] = []
		return

	if cond == null:
		# 还没有自动条件 → 建一个，并追加进 win.conditions
		cond = {"type": "reach_position", "area": goals, "auto_area": true}
		var win: Dictionary = level_data.win
		if not win.has("conditions"):
			win["conditions"] = []
		(win["conditions"] as Array).append(cond)
		return

	(cond as Dictionary)["area"] = goals


func _goal_cells() -> Array:
	var out: Array = []
	var tiles: Array = level_data.map["tiles"]
	for j in tiles.size():
		for i in (tiles[j] as Array).size():
			if int((tiles[j] as Array)[i]) == TILE_GOAL:
				out.append([i, j])
	return out


func _find_auto_area_condition():
	for c in level_data.win_conditions():
		var d: Dictionary = c
		if str(d.get("type", "")) == "reach_position" and bool(d.get("auto_area", false)):
			return d
	return null


## 当前自动维护的目标区（编辑器 UI 用来显示）
func auto_goal_area() -> Array:
	var c = _find_auto_area_condition()
	if c == null:
		return []
	var a = (c as Dictionary).get("area", [])
	return a if a is Array else []


# ---------------------------------------------------------------------------
# 关卡全局字段与胜负条件
# ---------------------------------------------------------------------------

func set_beacon_quota(v: int) -> bool:
	if v < 0 or v == int(level_data.beacon_quota):
		return false
	_push_undo()
	level_data.set("beacon_quota", v)
	return true


func set_signal_count(v: int) -> bool:
	if v < 0 or v == int(level_data.signal_count):
		return false
	_push_undo()
	level_data.set("signal_count", v)
	return true


func set_win_logic(logic: String) -> bool:
	return _set_logic("win", logic)


func set_lose_logic(logic: String) -> bool:
	return _set_logic("lose", logic)


func _set_logic(which: String, logic: String) -> bool:
	if logic != "any" and logic != "all":
		return false
	var d: Dictionary = level_data.get(which)
	if str(d.get("logic", "any")) == logic:
		return false
	_push_undo()
	d["logic"] = logic
	return true


func add_condition(which: String, cond: Dictionary) -> bool:
	if which != "win" and which != "lose":
		return false
	_push_undo()
	var d: Dictionary = level_data.get(which)
	if not d.has("conditions"):
		d["conditions"] = []
	(d["conditions"] as Array).append(cond.duplicate(true))
	return true


func remove_condition(which: String, index: int) -> bool:
	if which != "win" and which != "lose":
		return false
	var d: Dictionary = level_data.get(which)
	var arr: Array = d.get("conditions", [])
	if index < 0 or index >= arr.size():
		return false
	_push_undo()
	arr.remove_at(index)
	return true


func condition_count(which: String) -> int:
	var d: Dictionary = level_data.get(which)
	var arr: Array = d.get("conditions", [])
	return arr.size()


# ---------------------------------------------------------------------------
# 存盘
# ---------------------------------------------------------------------------

## 保存前校验。返回错误列表（空表示可以存）。
func validate_before_save(known_unit_types: Array = []) -> Array[String]:
	var errs: Array = level_data.call("validate", known_unit_types)
	var out: Array[String] = []
	for e in errs:
		out.append(str(e))
	return out


## 把当前关卡写成 JSON 文本（写盘由调用方负责，便于测试与 UI 分离）
func to_json_string() -> String:
	return str(level_data.call("to_json_string"))


## 载入一个关卡数据进入编辑
func load_level(p_level_data, p_source_path: String) -> void:
	setup(p_level_data, p_source_path)


## 标记为已保存
func mark_saved(p_path: String = "") -> void:
	dirty = false
	if not p_path.is_empty():
		source_path = p_path
