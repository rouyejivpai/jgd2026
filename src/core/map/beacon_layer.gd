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

## 信标列表：第 i 个元素的序号是 i+1（**全局序号**，配额与计分按它算）
var placements: Array[Vector2i] = []
## 【D-22】与 placements 等长的**归属**数组：第 i 个信标归哪个单位（entity_id），0＝无主。
## 用它回答"这个单位自己的信标是哪些、分别是它的第几个"。
var owners: Array[int] = []

## 本关配额（可放信标总数）
var quota := 0

## 目标地图（把放置结果同步过去）
var battle_map = null


## 绑定地图与配额。会清空已有信标。
func setup(map, beacon_quota: int) -> void:
	battle_map = map
	quota = maxi(beacon_quota, 0)
	placements.clear()
	owners.clear()
	push_to_map()
	_emit_changed()


## 把当前信标同步到地图（地图是单位移动时读取的权威来源）
func push_to_map() -> void:
	if battle_map == null:
		return
	# 优先走带归属的接口（D-22）；老接口保留兼容
	if battle_map.has_method("set_beacons_owned"):
		battle_map.call("set_beacons_owned", placements, owners)
	elif battle_map.has_method("set_beacons"):
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

## 放一个信标。成功返回它的**全局序号**（1 起），失败返回 0。
## 失败原因：配额已满 / 格子不可放 / 地图未绑定。
## `owner` 是归属单位（D-22）：0 表示无主（编辑器/旧用例）。
func add_beacon(tile: Vector2i, owner: int = 0) -> int:
	if battle_map == null:
		return 0
	if is_full():
		return 0
	if not can_place(tile):
		return 0
	placements.append(tile)
	owners.append(owner)
	push_to_map()
	_emit_changed()
	return placements.size()


# ---------------------------------------------------------------------------
# 归属查询（D-22：每个单位有自己的信标，不可公用）
# ---------------------------------------------------------------------------

## 第 index 个信标（1 起）归谁；0＝无主
func owner_at(index: int) -> int:
	if index < 1 or index > owners.size():
		return 0
	return owners[index - 1]


## 某单位已放的信标数
func count_of(owner: int) -> int:
	var n := 0
	for o in owners:
		if o == owner:
			n += 1
	return n


## 某单位自己的信标（按它的序号排列）
func beacons_of(owner: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in placements.size():
		if owners[i] == owner:
			out.append(placements[i])
	return out


## 第 index 个信标（1 起）是**它归属单位的第几个**；无主时返回全局序号
func owner_ordinal(index: int) -> int:
	if index < 1 or index > placements.size():
		return 0
	var owner := owners[index - 1]
	if owner <= 0:
		return index
	var k := 0
	for i in range(0, index):
		if owners[i] == owner:
			k += 1
	return k


## 某单位最后一个信标的**全局序号**（右键撤回用）；没有则返回 0
func last_index_of(owner: int) -> int:
	for i in range(placements.size() - 1, -1, -1):
		if owners[i] == owner:
			return i + 1
	return 0


## 撤回第 index 个信标（1 起）。成功返回 true。
## **后面的序号会自动前移**。
func remove_at(index: int) -> bool:
	if index < 1 or index > placements.size():
		return false
	placements.remove_at(index - 1)
	owners.remove_at(index - 1)
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
	owners.clear()
	push_to_map()
	_emit_changed()


## 重置关卡：**保留**信标，只把地图同步一次（需求 12.1a：重置保留信标）
func resync() -> void:
	push_to_map()
	_emit_changed()


func _emit_changed() -> void:
	changed.emit(placements.size(), quota)
	EventBus.beacon_changed.emit(placements.size(), quota)
