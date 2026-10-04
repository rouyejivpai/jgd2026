class_name BeaconLayer
extends RefCounted
## 详细设计：[docs/design/10-主界面与HUD.md](../../docs/design/10-主界面与HUD.md) 4.2
##
## 信标层：负责「玩家怎么放信标」的**数据与规则**，以及把结果同步给地图。
##
## 【分工】
## · 本类：已放置列表、配额、序号、撤回、合法性判定、变更广播
## · `BattleMap`：信标位置的**单一事实来源**（单位移动时读它）
## · UI（M5）：点格子、右键撤回、显示「已用 n/N」
## 本类一有变更就 `push_to_map()`，因此运行时只需问地图。
##
## 【序号规则】列表下标 + 1 即玩家看到的序号。撤回中间一个，
## 后面的序号**自动前移** —— 这会让引用被撤回信标的指令失效，
## 但那正是期望行为（不去自动改玩家的规则，见详设 10 的 4.2）。

## 信标变更后广播：count 当前已放置数，quota 配额
## （同时发 EventBus.beacon_changed 供 UI 订阅）
signal changed(count: int, quota: int)

## 信标列表：第 i 个元素的序号是 i+1
var placements: Array[Vector2i] = []

## 本关配额（可放信标总数）
var quota := 0

## 目标地图（把放置结果同步过去）
var battle_map = null


## 绑定地图与配额。会清空已有信标。
func setup(map, beacon_quota: int) -> void:
	battle_map = map
	quota = maxi(beacon_quota, 0)
	placements.clear()
	push_to_map()
	_emit_changed()


## 把当前信标同步到地图（地图是单位移动时读取的权威来源）
func push_to_map() -> void:
	if battle_map != null and battle_map.has_method("set_beacons"):
		battle_map.call("set_beacons", placements)


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

func count() -> int:
	return placements.size()


## 还能再放几个
func available() -> int:
	return maxi(quota - placements.size(), 0)


func is_full() -> bool:
	return placements.size() >= quota


func can_place(tile: Vector2i) -> bool:
	if is_full():
		return false
	if battle_map == null:
		return false
	if not battle_map.has_method("can_place_beacon"):
		return false
	return bool(battle_map.call("can_place_beacon", tile.x, tile.y))


## 该格上的信标序号（1 起）；没有则 0
func index_of(tile: Vector2i) -> int:
	for i in placements.size():
		if placements[i] == tile:
			return i + 1
	return 0


## 按序号取信标；不存在返回 null
func at(index: int) -> Variant:
	if index < 1 or index > placements.size():
		return null
	return placements[index - 1]


# ---------------------------------------------------------------------------
# 编辑
# ---------------------------------------------------------------------------

## 放一个信标。成功返回它的序号（1 起），失败返回 0。
## 失败原因：配额已满 / 格子不可放 / 地图未绑定。
func add_beacon(tile: Vector2i) -> int:
	if battle_map == null:
		return 0
	if is_full():
		return 0
	if not can_place(tile):
		return 0
	placements.append(tile)
	push_to_map()
	_emit_changed()
	return placements.size()


## 撤回第 index 个信标（1 起）。成功返回 true。
## **后面的序号会自动前移**。
func remove_at(index: int) -> bool:
	if index < 1 or index > placements.size():
		return false
	placements.remove_at(index - 1)
	push_to_map()
	_emit_changed()
	return true


## 撤回某格上的信标（右键用）。成功返回 true。
func remove_tile(tile: Vector2i) -> bool:
	var idx := index_of(tile)
	if idx == 0:
		return false
	return remove_at(idx)


## 全部撤回（重置关卡时用；玩家的信标要保留，所以重置不调它）
func clear() -> void:
	placements.clear()
	push_to_map()
	_emit_changed()


## 重置关卡：**保留**信标，只把地图同步一次（需求 12.1a：重置保留信标）
func resync() -> void:
	push_to_map()
	_emit_changed()


func _emit_changed() -> void:
	changed.emit(placements.size(), quota)
	EventBus.beacon_changed.emit(placements.size(), quota)
