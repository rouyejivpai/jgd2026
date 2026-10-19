class_name GroundLayer
extends Node2D
## GroundLayer（07 §1.1、§1.3）：玩法矩形内的地格表现。坐标为 MapLayer 局部（每格 TILE_SIZE）。
## 2026-10-18 分区域底图：不再平铺 scene.ground 地面贴图、也不再贴 ground_marks 地面标识——玩法矩形内直接露出区域底图；
## 格线与特殊地块（地形效果格、障碍、目标 / 逃离区）都由 GridOverlay 用发光线条 + 标志画出，本层在无清单时什么都不画。
## 10 §7（P7，R4）：关卡有障碍块清单（scene.obstacles）时 backdrop 是对齐底图，本层只画障碍块：每块按所占格的外接框左上锚定
## （anchor_px / size_px 为整图像素，按设计分辨率下的格像素换算到本层局部单位），按脚底从上到下排序绘制；本层位于网格与单位之下。

var level: LevelDefinition = null
var _pieces: Array[Dictionary] = []      ## R4 障碍块，已按脚底排序：{ tex, rect（本层局部）, foot }


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	_pieces = obstacle_rects(level)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


## 障碍块在本层局部坐标（每格 TILE_SIZE）中的矩形，按脚底 y 升序（靠下的后画、压在上面）。
## 用户 2026-10-20：带 upright 样式的块是立体物，由 ObstacleProps 在单位层竖立成丛，这里跳过
static func obstacle_rects(p_level: LevelDefinition) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p_level.obstacle_pieces.is_empty():
		return out
	var t: float = float(SimTypes.TILE_SIZE)
	var k: float = t / float(int(Playfield.compute(p_level, Playfield.DESIGN_SIZE)["cell_px"]))   # 整图像素 → 本层单位
	for pc: Dictionary in p_level.obstacle_pieces:
		if str(pc.get("upright", "")) != "":
			continue
		var cells: Array[Vector2i] = pc["cells"] as Array[Vector2i]
		var lo := Vector2i(cells[0])
		var hi := Vector2i(cells[0])
		for c: Vector2i in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var top_left: Vector2 = SimTypes.sim_to_screen(Vector2(lo.x, hi.y + 1), p_level.height)
		var foot: float = SimTypes.sim_to_screen(Vector2(lo.x, lo.y), p_level.height).y
		out.append({ "tex": Art.texture(str(pc["file"])), "rect": Rect2(top_left + (pc["anchor"] as Vector2) * k, (pc["size"] as Vector2) * k), "foot": foot })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["foot"]) < float(b["foot"]))
	return out


func _draw() -> void:
	if level == null or level.scene_obstacles == "":
		return
	for pc: Dictionary in _pieces:
		if pc["tex"] != null:
			draw_texture_rect(pc["tex"] as Texture2D, pc["rect"] as Rect2, false)
