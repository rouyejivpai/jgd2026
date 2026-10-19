class_name GridOverlay
extends Node2D
## 网格（01 §8 GridOverlay；2026-10-18 改为发光线条）：区域底图是一张完整的图，格子不画地块、不填色，
## 只用程序生成的发光线条划出可行走格（GlowLines：芯线不透明，线端越出矩形一小段后淡出）。
## 特殊地块在格线之上：地形效果格（hazard / mire / shrine）、障碍格、胜利目标区、失败逃离区——
## 各自颜色的发光边线 + 半透明着色的标志（GlowLines.draw_mark）；标志缺失时退回线条记号。
## 部署区（己方出生点）由 DeployZone、Boss 增援区由 StatusOverlay 按同样方式画（标志 spawn）。
## 胜利目标区用神性紫（与金色出生点区分）；部署阶段 DeployZone 在出生点之上再画一遍目标区（draw_goal_zones），两者重叠时目标格不被盖住。
## 2026-10-19 美术物件：地形效果格有全彩物件图（assets/sprites/tile_objects/<kind>.png：危险区 = 裂甲菌簇、缓滞带 = 僵骨地刺、
## 净化台 = 静息祭坛）时，每格画物件原色（不着色），边线照旧用类型色；没有物件图的类型仍画着色标志。
## 2026-10-19 底格线透明度分状态（BattleRoot.set_line_alpha）：底格线单独画在子节点 Lines（在特殊地块之下），
## 部署阶段常规 LINE_ALPHA_DEPLOY、开战后 LINE_ALPHA_BATTLE；拖动单位 / 选中单位看详情 / 信标模式时回到 1。特殊地块不变淡。

const BLOCKED_MARK_ALPHA: float = 0.62
const TILE_OBJECT_DIR: String = "tile_objects/%s.png"
const TILE_OBJECT_SIZE: float = 0.9      ## 物件边长（格）
const TILE_OBJECT_TINT: Color = Color(1.2, 1.2, 1.2, 0.95)   ## 略提亮抵消 CanvasModulate 的压暗
const BLOCKED_COLOR: Color = Color(0.32, 0.22, 0.36)     ## 障碍标志：深梅色（明亮底图上可读）
const SPECIAL_OVERSHOOT: float = 0.22    ## 特殊地块边线越出长度（格），比底格短，读作一块区域
## 底格线颜色：暖白发光芯线，略提亮（>1）抵消 CanvasModulate 的半压暗；GlowLines 自带深色描边
const GRID_COLOR: Color = Color(1.3, 1.25, 1.15, 1.0)
## 胜利目标区：神性紫（金色已用于出生点）
const GOAL_COLOR: Color = Color(1.0, 0.62, 1.35, 1.0)
const LINE_ALPHA_DEPLOY: float = 0.5     ## 部署阶段常规：原来的一半
const LINE_ALPHA_BATTLE: float = 0.25    ## 开战后（运行 / 暂停 / 结束）：原来的四分之一
const LINE_ALPHA_FOCUS: float = 1.0      ## 拖动 / 选中看详情 / 信标模式
const LINE_FADE_PER_SEC: float = 6.0     ## 透明度过渡速度（每秒变化量）

## 地形效果格配色（与关卡编辑器一致）
const TILE_COLOR: Dictionary = {
	"hazard": Color(1.0, 0.47, 0.41),
	"mire": Color(0.47, 0.67, 1.0),
	"shrine": Color(0.59, 0.96, 0.76),
}

var level: LevelDefinition = null
var _marks: Dictionary = {}              ## 名 → Texture2D
var _objects: Dictionary = {}            ## 地形效果格 kind → 全彩物件 Texture2D
## 用户 2026-10-20：物件图改由 ObstacleProps 在单位层竖立成丛时为 false，这里只画边线，不再平贴物件图
var draw_tile_objects: bool = true
var _lines: Lines = null                 ## 底格线（单独调透明度）
var _line_alpha_target: float = LINE_ALPHA_DEPLOY


## 底格线：画在父节点（特殊地块）之下，modulate.a 由 GridOverlay 调
class Lines extends Node2D:
	var level: LevelDefinition = null

	func _draw() -> void:
		if level == null:
			return
		var walk: Dictionary = {}
		for y: int in level.height:
			for x: int in level.width:
				if not level.is_blocked(Vector2i(x, y)):
					walk[Vector2i(x, y)] = true
		GlowLines.draw_cells(self, walk, level.height, GRID_COLOR)


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	if _lines == null:
		_lines = Lines.new()
		_lines.name = "Lines"
		_lines.show_behind_parent = true
		add_child(_lines)
	_lines.level = level
	_lines.modulate.a = _line_alpha_target
	_lines.queue_redraw()
	_marks.clear()
	_objects.clear()
	for kind: String in TILE_COLOR.keys():
		var obj: Texture2D = Art.texture(TILE_OBJECT_DIR % kind)
		if obj != null:
			_objects[kind] = obj
	for mark_name: String in ["hazard", "mire", "shrine", "blocked", "goal", "escape"]:
		var tex: Texture2D = GlowLines.mark_texture(mark_name)
		if tex != null:
			_marks[mark_name] = tex
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


## 底格线目标透明度：focus = 拖动 / 选中看详情 / 信标模式；否则部署阶段与开战后各用一档。instant = 不过渡
func set_line_state(deploy: bool, focus: bool, instant: bool = false) -> void:
	_line_alpha_target = LINE_ALPHA_FOCUS if focus else (LINE_ALPHA_DEPLOY if deploy else LINE_ALPHA_BATTLE)
	if instant and _lines != null:
		_lines.modulate.a = _line_alpha_target


func line_alpha() -> float:
	return _lines.modulate.a if _lines != null else _line_alpha_target


func _process(delta: float) -> void:
	if _lines != null and not is_equal_approx(_lines.modulate.a, _line_alpha_target):
		_lines.modulate.a = move_toward(_lines.modulate.a, _line_alpha_target, LINE_FADE_PER_SEC * delta)


func _draw() -> void:
	if level == null:
		return
	for cell: Vector2i in level.blocked:
		_draw_mark("blocked", cell, BLOCKED_COLOR, BLOCKED_MARK_ALPHA)
	for kind: String in level.tiles.keys():
		if not TILE_COLOR.has(kind):
			continue
		_draw_zone(kind, level.tiles[kind] as Array[Vector2i], TILE_COLOR[kind] as Color)
	for o: ObjectiveDef in level.lose:
		if o.type == SimTypes.ObjectiveType.REACH_ZONE:
			_draw_zone("escape", o.cells, Palette.WARN_RED)
	draw_goal_zones(self, level, _marks.get("goal") as Texture2D)


## 胜利条件 reach_zone / escort 的目标格
static func goal_cells(p_level: LevelDefinition) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: ObjectiveDef in p_level.win:
		if o.type == SimTypes.ObjectiveType.REACH_ZONE or o.type == SimTypes.ObjectiveType.ESCORT:
			for c: Vector2i in o.cells:
				if not out.has(c):
					out.append(c)
	return out


## 目标区：紫色发光边线 + 每格目标标志（GridOverlay 与部署阶段的 DeployZone 共用）
static func draw_goal_zones(ci: CanvasItem, p_level: LevelDefinition, mark: Texture2D) -> void:
	var cells: Array[Vector2i] = goal_cells(p_level)
	if cells.is_empty():
		return
	GlowLines.draw_cells(ci, GlowLines.cell_set(cells), p_level.height, GOAL_COLOR, 1.4, true, SPECIAL_OVERSHOOT)
	if mark != null:
		for c: Vector2i in cells:
			GlowLines.draw_mark(ci, mark, c, p_level.height, GOAL_COLOR)


## 一块特殊地块区域：整体发光边线 + 每格一个着色标志
func _draw_zone(kind: String, cells: Array[Vector2i], color: Color) -> void:
	GlowLines.draw_cells(self, GlowLines.cell_set(cells), level.height, color, 1.4, true, SPECIAL_OVERSHOOT)
	var obj: Texture2D = _objects.get(kind) as Texture2D
	if obj != null and not draw_tile_objects:
		return
	for cell: Vector2i in cells:
		if obj != null:
			var s: float = float(SimTypes.TILE_SIZE) * TILE_OBJECT_SIZE
			var c: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), level.height)
			draw_texture_rect(obj, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, TILE_OBJECT_TINT)
		else:
			_draw_mark(kind, cell, color, GlowLines.MARK_ALPHA)


func _draw_mark(kind: String, cell: Vector2i, color: Color, alpha: float) -> void:
	var tex: Texture2D = _marks.get(kind) as Texture2D
	if tex != null:
		GlowLines.draw_mark(self, tex, cell, level.height, color, alpha)
		return
	var t: float = float(SimTypes.TILE_SIZE)
	var c: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), level.height)
	var col := Color(color, alpha)                 # 标志缺失：线条记号占位
	var k: float = t * 0.2
	match kind:
		"hazard", "escape":
			draw_line(c - Vector2(k, k), c + Vector2(k, k), col, 3.0, true)
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), col, 3.0, true)
		"mire":
			for dy: float in [-k * 0.6, k * 0.6]:
				draw_polyline(PackedVector2Array([c + Vector2(-k, dy), c + Vector2(-k * 0.33, dy - k * 0.35), c + Vector2(k * 0.33, dy + k * 0.35), c + Vector2(k, dy)]), col, 2.5, true)
		"shrine", "goal":
			draw_polyline(PackedVector2Array([c + Vector2(0.0, -k), c + Vector2(k, k * 0.8), c + Vector2(-k, k * 0.8), c + Vector2(0.0, -k)]), col, 2.5, true)
		"blocked":
			for f: float in [-0.5, 0.0, 0.5]:
				draw_line(c + Vector2(-k + f * k * 2.0, k), c + Vector2(k + f * k * 2.0, -k), col, 2.0, true)
