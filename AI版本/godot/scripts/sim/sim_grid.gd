class_name SimGrid
extends RefCounted
## 模拟网格（01 §6.3）：四方向寻路，仅障碍格不可走，单位之间不堵路。

const _NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int = 0
var height: int = 0
var walkable: PackedByteArray = PackedByteArray()  ## 索引 y*width+x，1 = 可走
var _astar: AStarGrid2D


func _init(w: int, h: int, blocked: Array[Vector2i]) -> void:
	width = w
	height = h
	walkable.resize(w * h)
	walkable.fill(1)
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, w, h)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for c: Vector2i in blocked:
		if in_bounds(c):
			walkable[cell_index(c)] = 0
			_astar.set_point_solid(c, true)


## 地形代价（危险区 / 缓滞带）：寻路时按权重绕行
func set_weight(c: Vector2i, w: float) -> void:
	if in_bounds(c) and w != 1.0:
		_astar.set_point_weight_scale(c, w)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func cell_index(c: Vector2i) -> int:
	return c.y * width + c.x


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and walkable[cell_index(c)] == 1


static func cell_center(c: Vector2i) -> Vector2:
	return SimTypes.cell_center(c)


static func pos_to_cell(p: Vector2) -> Vector2i:
	return SimTypes.pos_to_cell(p)


## 含起点与终点的格路径；不可达或端点不可走返回空数组。
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(from) or not is_walkable(to):
		return []
	if from == to:
		return [from]
	return _astar.get_id_path(from, to)


## BFS：返回 depth 步以内可达格 → 步数（含起点，步数 0）。
func bfs_depths(from: Vector2i, depth: int) -> Dictionary:
	var out: Dictionary = {}
	if not is_walkable(from):
		return out
	out[from] = 0
	var frontier: Array[Vector2i] = [from]
	for d: int in range(1, depth + 1):
		var next: Array[Vector2i] = []
		for c: Vector2i in frontier:
			for n: Vector2i in _NEIGHBORS:
				var nc: Vector2i = c + n
				if is_walkable(nc) and not out.has(nc):
					out[nc] = d
					next.append(nc)
		frontier = next
	return out


## 撤离用：depth 步以内可达格，按（步数, 格索引）排序，含起点。
func reachable_within(from: Vector2i, depth: int) -> Array[Vector2i]:
	var depths: Dictionary = bfs_depths(from, depth)
	var out: Array[Vector2i] = []
	for c: Vector2i in depths.keys():
		out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = int(depths[a])
		var db: int = int(depths[b])
		if da != db:
			return da < db
		return cell_index(a) < cell_index(b))
	return out


## 追击用：从 from 出发 BFS，找"格中心到 target_pos 距离 ≤ max_dist"的最近可行走格。
## 决胜：步数少 → 距目标近 → 格索引小。无解返回 (-1,-1)。
func nearest_cell_within(from: Vector2i, target_pos: Vector2, max_dist: float) -> Vector2i:
	var none := Vector2i(-1, -1)
	if not is_walkable(from):
		return none
	var depths: Dictionary = bfs_depths(from, width * height)
	var best: Vector2i = none
	var best_depth: int = 0
	var best_dist: float = 0.0
	for c: Vector2i in depths.keys():
		var dist: float = cell_center(c).distance_to(target_pos)
		if dist > max_dist + SimTypes.DIST_EPS:
			continue
		var dep: int = int(depths[c])
		var better: bool = false
		if best == none:
			better = true
		elif dep != best_depth:
			better = dep < best_depth
		elif not is_equal_approx(dist, best_dist):
			better = dist < best_dist
		else:
			better = cell_index(c) < cell_index(best)
		if better:
			best = c
			best_depth = dep
			best_dist = dist
	return best
