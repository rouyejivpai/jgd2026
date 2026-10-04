class_name BattleMap
extends Node2D
## 详细设计：[docs/design/03-网格地图.md](../../docs/design/03-网格地图.md)
##
## 维护「这张地图长什么样」的**唯一事实来源**（瓦片数据），并对外提供三件事：
## 坐标换算、通行/放置判定、障碍的静态碰撞体。
##
## 【坐标约定】
## · 瓦片中心坐标为整数：瓦片 (i,j) 的中心 = 逻辑坐标 (i, j)，因此 1 瓦片 = 1 距离。
## · 逻辑层一律用 Vector2(i, j)（单位就是「距离」），TILE_PX 只在渲染与物理体尺寸出现。
## · 二维数组下标是 tiles[j][i]（y 在前），但所有方法签名的参数顺序固定为 (i, j)。
##
## 【碰撞层】障碍生成在物理层 2（obstacle）。单位本体层 1 的掩码只有 2，
## 所以单位之间互不碰撞、只有墙挡人（D-08）。

## 瓦片类型 id
const TILE_EMPTY := 0
const TILE_WALL := 1
const TILE_GOAL := 2

## 渲染用像素尺寸。**只影响表现**，不参与任何逻辑计算。
const TILE_PX := 64.0

## 障碍所在的物理层号（见 project.godot 的 [layer_names]）
const LAYER_OBSTACLE := 2

## 地图尺寸（瓦片数）
var width := 0
var height := 0

## 瓦片数据，tiles[j][i]，取值见 TILE_*
var tiles: Array[Array] = []

## 载入过程中的错误列表。非空表示这次载入失败，地图不进入就绪状态。
var load_errors: Array[String] = []

## 障碍碰撞体的容器节点
var _walls_root: Node2D = null

## 已放置的信标：索引(1 起) → 瓦片 Vector2i。
## 由信标层写入（M1-5）；单位移动时通过 beacon_logic_position() 读目标。
var _beacons: Dictionary = {}


func _ready() -> void:
	_ensure_walls_root()


func _ensure_walls_root() -> void:
	if _walls_root == null or not is_instance_valid(_walls_root):
		_walls_root = Node2D.new()
		_walls_root.name = "Walls"
		add_child(_walls_root)


# ---------------------------------------------------------------------------
# 载入与校验
# ---------------------------------------------------------------------------

## 从关卡数据的 map 段载入。map_dict 形如 {width, height, tiles}。
## 返回错误列表：空表示成功。校验失败时地图**不**进入就绪状态
## （不会拿半个地图继续跑，见 FR-MAP-01）。
func load_from(map_dict: Dictionary) -> Array[String]:
	clear()
	load_errors.clear()

	if not (map_dict.has("width") and map_dict.has("height") and map_dict.has("tiles")):
		load_errors.append("map: 缺少 width / height / tiles 之一")
		return load_errors

	var w := int(map_dict["width"])
	var h := int(map_dict["height"])
	if w <= 0 or h <= 0:
		load_errors.append("map: width/height 必须为正（实际 %d×%d）" % [w, h])
		return load_errors

	var raw = map_dict["tiles"]
	if not (raw is Array):
		load_errors.append("map.tiles: 期望二维数组")
		return load_errors
	var rows: Array = raw
	if rows.size() != h:
		load_errors.append("map.tiles: 行数 %d 与 height %d 不符" % [rows.size(), h])
		return load_errors

	# 逐格校验，收集**全部**错误后再报出（策划改表时一次能看到所有问题）
	var parsed: Array[Array] = []
	for j in h:
		var row = rows[j]
		if not (row is Array):
			load_errors.append("map.tiles 第 %d 行: 期望数组" % j)
			continue
		var src: Array = row
		if src.size() != w:
			load_errors.append("map.tiles 第 %d 行: 长度 %d 与 width %d 不符" % [j, src.size(), w])
			continue
		var out_row: Array = []
		for i in w:
			var v := int(src[i])
			if v != TILE_EMPTY and v != TILE_WALL and v != TILE_GOAL:
				load_errors.append("map.tiles 第 %d 行第 %d 列: 非法瓦片 id %d（允许 0/1/2）" % [j, i, v])
				continue
			out_row.append(v)
		parsed.append(out_row)

	if not load_errors.is_empty():
		return load_errors

	width = w
	height = h
	tiles = parsed
	_build_walls()
	return load_errors


## 直接喂二维数组（测试与编辑器用）。同样走校验。
func set_tiles(new_tiles: Array[Array]) -> Array[String]:
	var h := new_tiles.size()
	var w := 0 if h == 0 else new_tiles[0].size()
	return load_from({"width": w, "height": h, "tiles": new_tiles})


## 是否已成功载入一张地图
func is_ready_map() -> bool:
	return width > 0 and height > 0 and tiles.size() == height


# ---------------------------------------------------------------------------
# 坐标换算
# ---------------------------------------------------------------------------

## 瓦片索引 → 世界像素坐标（瓦片**中心**）
##
## 【坐标约定的唯一真相】世界空间里，瓦片 (i,j) 覆盖
## `[i*TILE_PX, (i+1)*TILE_PX)` 这个矩形，所以它的中心是 `(i+0.5)*TILE_PX`。
## 而逻辑坐标 1 格 = 1 个 TILE_PX，因此**逻辑坐标里的瓦片中心是 (i+0.5, j+0.5)**。
##
## 曾经的坑：把 `tile_to_world` 当成"中心"返回 `(i,j)*TILE_PX`，同时又把逻辑坐标
## 当成"格下标"，于是「单位在格 (1,1)」与「墙在格 (1,1)」在屏幕上差了半格，
## 悬停高亮也跟着错位（用户实测反馈「高亮偏右」）。
## 现在统一为：**逻辑坐标 = 瓦片中心的格偏移量**。
func tile_to_world(i: int, j: int) -> Vector2:
	return (Vector2(float(i), float(j)) + Vector2(0.5, 0.5)) * TILE_PX


## 世界像素坐标 → 瓦片索引
##
## 用 `floor` 而不是 `round`：瓦片 (i,j) 占 `[i*64, (i+1)*64)`，
## 落在这个区间里的点都应归给它，而 `round(x/64)` 会把 `[i*64, i*64+32)`
## 判给 i-1，于是点击判定整体偏移半格。
func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE_PX)), int(floor(pos.y / TILE_PX)))


## 瓦片索引 → 逻辑坐标（1 瓦片 = 1 距离）。**逻辑层用这个，不要用像素。**
## 返回瓦片中心：(i, j) → (i+0.5, j+0.5)
func tile_to_logic(i: int, j: int) -> Vector2:
	return Vector2(float(i) + 0.5, float(j) + 0.5)


## 逻辑坐标 → 瓦片索引
func logic_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


## 相邻瓦片中心的逻辑距离 —— 恒为 1.0（FR-MAP-02 的判据）
func tile_spacing() -> float:
	return tile_to_logic(1, 0).distance_to(tile_to_logic(0, 0))


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

## 坐标是否在地图内
func in_bounds(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < width and j < height


## 取瓦片类型；越界返回 -1
func tile_at(i: int, j: int) -> int:
	if not in_bounds(i, j):
		return -1
	return int(tiles[j][i])


func tile_at_logic(p: Vector2) -> int:
	var t := logic_to_tile(p)
	return tile_at(t.x, t.y)


## 单位能不能站上去（需求 4.2）：越界与障碍都不可通行
func is_passable(i: int, j: int) -> bool:
	if not in_bounds(i, j):
		return false
	return tile_at(i, j) != TILE_WALL


## 能不能放信标（需求 4.2 / FR-MAP-03）：只有空地可以
func can_place_beacon(i: int, j: int) -> bool:
	if not in_bounds(i, j):
		return false
	return tile_at(i, j) == TILE_EMPTY


## 是否属于「目标区域」瓦片（终点类胜利条件用）
func is_goal(i: int, j: int) -> bool:
	return tile_at(i, j) == TILE_GOAL


## 列出全部目标区域格，供 reach_position 条件使用
func goal_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for j in height:
		for i in width:
			if tile_at(i, j) == TILE_GOAL:
				out.append(Vector2i(i, j))
	return out


# ---------------------------------------------------------------------------
# 信标查询（信标本体由信标层管理，地图只负责按索引给出坐标）
# ---------------------------------------------------------------------------

## 覆盖式设置信标放置表。索引从 1 开始（与玩家看到的序号一致）。
## placements 是瓦片坐标数组，第 1 个元素的索引是 1。
func set_beacons(placements: Array) -> void:
	_beacons.clear()
	for i in placements.size():
		var t = placements[i]
		if t is Vector2i:
			_beacons[i + 1] = t
		elif t is Vector2:
			_beacons[i + 1] = Vector2i(int(round((t as Vector2).x)), int(round((t as Vector2).y)))


func clear_beacons() -> void:
	_beacons.clear()


func has_beacon(index: int) -> bool:
	return _beacons.has(index)


func beacon_count() -> int:
	return _beacons.size()


## 信标的**逻辑坐标**（格）。索引不存在时返回 null —— 调用方必须判空，
## 这正是「指令引用了被撤回的信标 → 整条跳过」的落地点。
func beacon_logic_position(index: int) -> Variant:
	if not _beacons.has(index):
		return null
	var t: Vector2i = _beacons[index]
	return tile_to_logic(t.x, t.y)


func beacon_tile(index: int) -> Variant:
	if not _beacons.has(index):
		return null
	return _beacons[index]


# ---------------------------------------------------------------------------
# 物理碰撞体
# ---------------------------------------------------------------------------

## 按瓦片数据生成障碍的静态碰撞体。
## 决策 1：碰撞体只是网格的物理投影，网格永远是唯一事实来源，编辑器不碰物理层。
func _build_walls() -> void:
	_ensure_walls_root()
	_remove_wall_children()

	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE_PX, TILE_PX)

	for j in height:
		for i in width:
			if tile_at(i, j) != TILE_WALL:
				continue
			var body := StaticBody2D.new()
			body.name = "Wall_%d_%d" % [i, j]
			body.position = tile_to_world(i, j)
			# 满格碰撞体、不留缝隙：留缝会让单位在格与格之间被"卡住"
			var cs := CollisionShape2D.new()
			cs.shape = shape
			body.add_child(cs)
			body.collision_layer = 0
			body.collision_mask = 0
			body.set_collision_layer_value(LAYER_OBSTACLE, true)
			_walls_root.add_child(body)


## 当前障碍碰撞体数量（测试与调试用）
func wall_count() -> int:
	if _walls_root == null or not is_instance_valid(_walls_root):
		return 0
	var n := 0
	for child in _walls_root.get_children():
		if child is StaticBody2D:
			n += 1
	return n


func _remove_wall_children() -> void:
	if _walls_root == null or not is_instance_valid(_walls_root):
		return
	# 【必须 immediate free 或 queue_free】不能只 remove_child：
	# remove_child 会把节点从场景树摘下来，物理体却仍注册在 PhysicsServer 里，
	# 于是「上一张地图的墙」继续挡着下一张地图的单位
	# （M1-5 实测：map2 明明 0 个墙，却有一个 Wall_2_0 在挡路，
	#  导致精确落点用例失败、排查了很久）。
	# 也不要用「先 remove 再 queue_free」——那样 queue_free 可能根本不执行。
	for child in _walls_root.get_children():
		if child.is_inside_tree():
			_walls_root.remove_child(child)
			child.queue_free()
		else:
			child.free()


## 销毁碰撞体与全部瓦片数据（重置关卡用）
func clear() -> void:
	width = 0
	height = 0
	tiles = []
	_beacons.clear()
	_remove_wall_children()


## 立刻销毁自己（含碰撞体）。
## 用 free 而不是 queue_free：queue_free 要等到帧末，
## 期间上一张地图的墙还在物理服务器里挡着下一张地图的单位（M1-5 实测）。
func teardown() -> void:
	_remove_wall_children()
