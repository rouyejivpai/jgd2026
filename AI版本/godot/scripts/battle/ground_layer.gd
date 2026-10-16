class_name GroundLayer
extends Node2D
## GroundLayer（07 §1.1、§1.3）：玩法矩形内的俯视地面 + 障碍格地面标识。坐标为 MapLayer 局部（每格 TILE_SIZE）。
## - 地面：scene.ground 贴图按每 GROUND_TILE_CELLS 格一张平铺（同生态 ground_textures 的 b 张按块交替），
##   乘 scene.ground_tint，alpha GROUND_ALPHA 叠在 backdrop 上；贴图缺失或未配置时用 ground_tint 纯色（资源未到位的占位）。
## - 障碍格：biomes.json ground_marks 的贴片（按格坐标确定性挑选），平铺在格内；贴片缺失时程序绘制碎石占位。
## 不画任何竖立物。
## 10 §7（P7，R4）：关卡有障碍块清单（scene.obstacles）时 backdrop 已是画好地面的对齐底图，本层不再铺地面与地面标识，
## 只画障碍块：每块按所占格的外接框左上锚定（anchor_px / size_px 为整图像素，按设计分辨率下的格像素换算到本层局部单位），
## 按脚底（所占格最下一行的下沿）从上到下排序绘制；本层位于网格与单位之下。scene.ground / ground_marks 只在无清单时作占位（DEPRECATED）。

const GROUND_ALPHA: float = 0.9
const GROUND_TILE_CELLS: int = 4
const MARK_DIR: String = "res://assets/sprites/ground_marks/%s.png"
const MARK_ALPHA: float = 0.85

var level: LevelDefinition = null
var _ground: Texture2D = null
var _ground_alt: Texture2D = null
var _marks: Array[Texture2D] = []
var _pieces: Array[Dictionary] = []      ## R4 障碍块，已按脚底排序：{ tex, rect（本层局部）, foot }


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	_ground = Art.texture(level.scene_ground) if level.scene_ground != "" else null
	_ground_alt = null
	if _ground != null:
		for path: String in DataRegistry.get_ground_textures(level.biome):
			if path != level.scene_ground and Art.texture(path) != null:
				_ground_alt = Art.texture(path)
				break
	_marks.clear()
	for mark_name: String in DataRegistry.get_ground_marks(level.biome):
		var tex: Texture2D = Art.texture(MARK_DIR % mark_name)
		if tex != null:
			_marks.append(tex)
	_pieces = obstacle_rects(level)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


## 障碍块在本层局部坐标（每格 TILE_SIZE）中的矩形，按脚底 y 升序（靠下的后画、压在上面）
static func obstacle_rects(p_level: LevelDefinition) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p_level.obstacle_pieces.is_empty():
		return out
	var t: float = float(SimTypes.TILE_SIZE)
	var k: float = t / float(int(Playfield.compute(p_level, Playfield.DESIGN_SIZE)["cell_px"]))   # 整图像素 → 本层单位
	for pc: Dictionary in p_level.obstacle_pieces:
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
	if level == null:
		return
	if level.scene_obstacles != "":
		for pc: Dictionary in _pieces:
			if pc["tex"] != null:
				draw_texture_rect(pc["tex"] as Texture2D, pc["rect"] as Rect2, false)
		return
	var t: float = float(SimTypes.TILE_SIZE)
	var full := Rect2(0.0, 0.0, level.width * t, level.height * t)
	var tint: Color = Color(level.scene_ground_tint, GROUND_ALPHA)
	if _ground == null:
		draw_rect(full, tint)
	else:
		var block: float = t * GROUND_TILE_CELLS
		var by: int = 0
		var y: float = 0.0
		while y < full.size.y:
			var bx: int = 0
			var x: float = 0.0
			while x < full.size.x:
				var tex: Texture2D = _ground_alt if _ground_alt != null and (bx + by) % 2 == 1 else _ground
				var dst := Rect2(x, y, minf(block, full.size.x - x), minf(block, full.size.y - y))
				var src := Rect2(Vector2.ZERO, tex.get_size() * (dst.size / block))
				draw_texture_rect_region(tex, dst, src, tint)
				x += block
				bx += 1
			y += block
			by += 1
	_draw_tiles(t)
	for cell: Vector2i in level.blocked:
		var rect := Rect2(SimTypes.sim_to_screen(Vector2(cell.x, cell.y + 1), level.height), Vector2(t, t))
		if _marks.is_empty():
			_draw_mark_placeholder(rect, cell)
		else:
			draw_texture_rect(_marks[_pick(cell, _marks.size())], rect, false, Color(1.0, 1.0, 1.0, MARK_ALPHA))


## 30 关战役的地形效果格（grid.tiles）：可走但有代价，用色块 + 记号与墙区分（素材到位前的占位画法，与关卡编辑器配色一致）
const TILE_STYLE: Dictionary = {
	"hazard": { "fill": Color(1.0, 0.36, 0.3, 0.22), "line": Color(1.0, 0.47, 0.41, 0.9) },
	"mire": { "fill": Color(0.35, 0.59, 1.0, 0.2), "line": Color(0.47, 0.67, 1.0, 0.9) },
	"shrine": { "fill": Color(0.47, 0.92, 0.67, 0.2), "line": Color(0.59, 0.96, 0.76, 0.95) },
}


func _draw_tiles(t: float) -> void:
	for kind: String in level.tiles.keys():
		var st: Dictionary = TILE_STYLE.get(kind, {}) as Dictionary
		if st.is_empty():
			continue
		var line: Color = st["line"] as Color
		for cell: Vector2i in level.tiles[kind] as Array[Vector2i]:
			var r := Rect2(SimTypes.sim_to_screen(Vector2(cell.x, cell.y + 1), level.height), Vector2(t, t)).grow(-t * 0.05)
			draw_rect(r, st["fill"] as Color)
			draw_rect(r, line, false, 2.0)
			var c: Vector2 = r.get_center()
			var k: float = t * 0.22
			match kind:
				"hazard":
					draw_line(c - Vector2(k, k), c + Vector2(k, k), line, 3.0)
					draw_line(c + Vector2(-k, k), c + Vector2(k, -k), line, 3.0)
				"mire":
					for dy: float in [-k * 0.6, k * 0.6]:
						draw_polyline(PackedVector2Array([c + Vector2(-k, dy), c + Vector2(-k * 0.33, dy - k * 0.35), c + Vector2(k * 0.33, dy + k * 0.35), c + Vector2(k, dy)]), line, 2.5)
				"shrine":
					draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -k), c + Vector2(k, k * 0.8), c + Vector2(-k, k * 0.8)]), Color(line, 0.55))


## 确定性挑选（同一格每次相同）
func _pick(cell: Vector2i, n: int) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % n


## 占位：压暗的碎石块 + 骨白裂纹（扁平、俯视，无竖立感）
func _draw_mark_placeholder(rect: Rect2, cell: Vector2i) -> void:
	var t: float = rect.size.x
	draw_rect(rect.grow(-t * 0.04), Color(Palette.BG_DEEP, 0.72))
	var seed_i: int = _pick(cell, 997)
	for k: int in 4:
		var a := Vector2(float((seed_i * (k + 3)) % 97) / 97.0, float((seed_i * (k + 7)) % 89) / 89.0)
		var b := Vector2(float((seed_i * (k + 11)) % 83) / 83.0, float((seed_i * (k + 13)) % 79) / 79.0)
		draw_line(rect.position + a * t * 0.8 + Vector2(t, t) * 0.1, rect.position + b * t * 0.8 + Vector2(t, t) * 0.1, Color(Palette.BONE_DIM, 0.35), 2.0)
	draw_rect(rect.grow(-t * 0.04), Color(Palette.VIOLET_MUTE, 0.6), false, 2.0)
