extends Node2D
## 部署区（01 §8 DeployZone，己方出生点）：2026-10-18 起按特殊地块画——格内不填色，部署格整体画金色发光边线
## （GlowLines，芯线不透明、线端越出后淡出，光晕随时间呼吸）+ 每格一个半透明金色出生点标志（tile_marks/spawn）；拖拽悬停时合法格金色、非法格红色发光框；放下非法时该格红闪（10 §4）。仅 DEPLOY 阶段可见。

const PULSE_SPEED: float = 2.0
## 金色提亮（>1），与底格线同理抵消 CanvasModulate 压暗，出生点不被骨白格线盖住
const SPAWN_COLOR: Color = Color(1.42, 1.15, 0.52, 1.0)
const FLASH_SECONDS: float = 0.4

var level: LevelDefinition = null
var hover_cell: Vector2i = Vector2i(-1, -1)
var hover_legal: bool = false
var hover_ghost: Texture2D = null        ## 第四阶段：拖动部署时吸附到悬停格的单位虚影
const GHOST_ALPHA: float = 0.75
var _flash_tween: Tween = null
var _cells: Dictionary = {}              ## 部署格集合
var _time: float = 0.0
var _mark: Texture2D = null
var _goal_mark: Texture2D = null
var _goal: Array[Vector2i] = []          ## 与部署格重叠的胜利目标格不画出生点标志（目标区画在最上）


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	for c: Node in get_children():
		c.queue_free()
	_cells = GlowLines.cell_set(level.deploy_cells)
	_mark = GlowLines.mark_texture("spawn")
	_goal_mark = GlowLines.mark_texture("goal")
	_goal = GridOverlay.goal_cells(level)
	queue_redraw()


func _process(delta: float) -> void:
	if level == null or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func set_hover(cell: Vector2i, legal: bool, ghost: Texture2D = null) -> void:
	if cell == hover_cell and legal == hover_legal and ghost == hover_ghost:
		return
	hover_cell = cell
	hover_legal = legal
	hover_ghost = ghost
	queue_redraw()


## 红闪进行中不清除（拖拽结束通知晚于放下）
func clear_hover() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		return
	set_hover(Vector2i(-1, -1), false)


## 10 §4：放下到非法格后该格红色停留 FLASH_SECONDS 再消失
func flash(cell: Vector2i) -> void:
	set_hover(cell, false)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(FLASH_SECONDS)
	_flash_tween.tween_callback(func() -> void: set_hover(Vector2i(-1, -1), false))


func _draw() -> void:
	if level == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * PULSE_SPEED * PI)
	GlowLines.draw_cells(self, _cells, level.height, SPAWN_COLOR, 1.2 + 1.2 * pulse, true, 0.3, GlowLines.CORE_WIDTH * 1.4)
	if _mark != null:
		for cell: Vector2i in level.deploy_cells:
			if not _goal.has(cell):
				GlowLines.draw_mark(self, _mark, cell, level.height, SPAWN_COLOR)
	GridOverlay.draw_goal_zones(self, level, _goal_mark)
	if hover_cell.x < 0 or not level.in_bounds(hover_cell):
		return
	var t: float = float(SimTypes.TILE_SIZE)
	var hr := Rect2(SimTypes.sim_to_screen(Vector2(hover_cell.x, hover_cell.y + 1), level.height), Vector2(t, t))
	var hc: Color = SPAWN_COLOR * 1.25 if hover_legal else Color(1.6, 0.45, 0.38)
	GlowLines.draw_cells(self, { hover_cell: true }, level.height, Color(hc, 1.0), 2.6, true, 0.0, GlowLines.CORE_WIDTH * 2.0)
	if hover_ghost != null:              # 虚影：脚底对齐格中心（与 RosterCard 拖拽虚影同尺寸、同脚底比例）
		var h: float = t * RosterCard.PREVIEW_HEIGHT_CELLS
		var w: float = h * hover_ghost.get_size().x / maxf(hover_ghost.get_size().y, 1.0)
		var feet: Vector2 = hr.get_center()
		var tint: Color = RosterCard.PREVIEW_TINT_LEGAL if hover_legal else RosterCard.PREVIEW_TINT_ILLEGAL
		draw_texture_rect(hover_ghost, Rect2(feet - Vector2(w * 0.5, h * RosterCard.SPRITE_FEET_RATIO), Vector2(w, h)), false, Color(tint, GHOST_ALPHA))
