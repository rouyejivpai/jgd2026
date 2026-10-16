extends Node2D
## 部署区（01 §8 DeployZone）：每个部署格一块 deploy_zone.gdshader（脉动符文格，网格对齐）；
## 拖拽悬停时合法格金色、非法格红色（_draw 叠加）；放下非法时该格红闪（10 §4）。仅 DEPLOY 阶段可见。

const PULSE_SPEED: float = 2.0
const FLASH_SECONDS: float = 0.4

var level: LevelDefinition = null
var hover_cell: Vector2i = Vector2i(-1, -1)
var hover_legal: bool = false
var hover_ghost: Texture2D = null        ## 第四阶段：拖动部署时吸附到悬停格的单位虚影
const GHOST_ALPHA: float = 0.75
var _flash_tween: Tween = null


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	for c: Node in get_children():
		c.queue_free()
	var t: float = float(SimTypes.TILE_SIZE)
	var shader_mat: ShaderMaterial = Art.material("deploy_zone")
	shader_mat.set_shader_parameter("tile_px", t)
	shader_mat.set_shader_parameter("pulse_speed", PULSE_SPEED)
	shader_mat.set_shader_parameter("color", Palette.ALCHEMY_GOLD)
	for cell: Vector2i in level.deploy_cells:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = SimTypes.sim_to_screen(Vector2(cell.x, cell.y + 1), level.height)
		r.size = Vector2(t, t)
		r.material = shader_mat
		r.show_behind_parent = true
		add_child(r)
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
	if level == null or hover_cell.x < 0 or not level.in_bounds(hover_cell):
		return
	var t: float = float(SimTypes.TILE_SIZE)
	var hr := Rect2(SimTypes.sim_to_screen(Vector2(hover_cell.x, hover_cell.y + 1), level.height), Vector2(t, t))
	var hc: Color = Palette.ALCHEMY_GOLD if hover_legal else Palette.WARN_RED
	draw_rect(hr.grow(-2.0), Color(hc, 0.35))
	draw_rect(hr.grow(-2.0), hc, false, 3.0)
	if hover_ghost != null:              # 虚影：脚底对齐格中心（与 RosterCard 拖拽虚影同尺寸、同脚底比例）
		var h: float = t * RosterCard.PREVIEW_HEIGHT_CELLS
		var w: float = h * hover_ghost.get_size().x / maxf(hover_ghost.get_size().y, 1.0)
		var feet: Vector2 = hr.get_center()
		var tint: Color = RosterCard.PREVIEW_TINT_LEGAL if hover_legal else RosterCard.PREVIEW_TINT_ILLEGAL
		draw_texture_rect(hover_ghost, Rect2(feet - Vector2(w * 0.5, h * RosterCard.SPRITE_FEET_RATIO), Vector2(w, h)), false, Color(tint, GHOST_ALPHA))
