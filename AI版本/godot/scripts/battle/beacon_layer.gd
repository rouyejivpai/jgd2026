extends Node2D
## 信标显示（07 §3.1、§6）：选中单位的信标与连线高亮（骨白，线宽 3 px；部署 alpha 0.85、运行 0.45）；
## 其他己方单位的信标为小号浅印记（alpha 0.3）；运行中各单位当前前往的信标闪烁；拖动信标时显示落点（合法金色 / 非法红色）。
## 坐标为 MapLayer 局部（每格 TILE_SIZE），位于受玩法矩形裁剪的 MapLayer 下。只读控制器与模拟数据。

const NAME_FONT: FontFile = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const LINE_PX: float = 3.0
const ALPHA_DEPLOY: float = 0.85
const ALPHA_RUNNING: float = 0.45
const ALPHA_OTHER: float = 0.3
const MARK_RADIUS: float = 0.26           ## 格
const OTHER_RADIUS: float = 0.14
const BLINK_HZ: float = 2.5
const LABEL_PX: int = 22
const NUMBER_RADIUS: float = 0.14        ## 第四阶段单位编号圆牌半径（格）
const NUMBER_MIN_PX: float = 20.0        ## 圆牌最小直径（屏幕像素）

var level: LevelDefinition = null
var controller: BattleController = null
var root: Node2D = null
var _drag_id: String = ""
var _drag_cell: Vector2i = Vector2i(-1, -1)
var _drag_legal: bool = false


func setup(p_level: LevelDefinition, p_controller: BattleController, p_root: Node2D) -> void:
	level = p_level
	controller = p_controller
	root = p_root
	EventBus.beacons_changed.connect(func(_id: int) -> void: queue_redraw())
	EventBus.unit_selected.connect(func(_id: int) -> void: queue_redraw())
	EventBus.deployment_changed.connect(queue_redraw)
	EventBus.battle_phase_changed.connect(func(_p: int) -> void: queue_redraw())
	controller.world_rebuilt.connect(queue_redraw)
	queue_redraw()


func set_drag(beacon_id: String, cell: Vector2i, legal: bool) -> void:
	_drag_id = beacon_id
	_drag_cell = cell
	_drag_legal = legal
	queue_redraw()


func clear_drag() -> void:
	_drag_id = ""
	queue_redraw()


func _process(_delta: float) -> void:
	if controller != null and controller.phase == SimTypes.Phase.RUNNING:
		queue_redraw()     # 闪烁


func _draw() -> void:
	if level == null or controller == null:
		return
	var deploy: bool = controller.phase == SimTypes.Phase.DEPLOY
	var selected_slot: String = controller.slot_of_unit(int(root.get("selected_id")))
	var t: float = float(SimTypes.TILE_SIZE)
	var line_w: float = LINE_PX / maxf(get_global_transform().get_scale().x, 0.01)
	var blink: bool = fmod(Time.get_ticks_msec() * 0.001 * BLINK_HZ, 1.0) < 0.5
	for uid: String in controller.uids():
		var beacons: Array[Dictionary] = _beacons_of(uid, deploy)
		if beacons.is_empty():
			continue
		var target_index: int = -1
		var u: SimUnit = controller.world.get_unit(controller.unit_id_of_slot(uid)) if controller.world != null else null
		if not deploy and u != null and u.alive and u.current_action == SimTypes.ActionType.FOLLOW_BEACONS:
			target_index = u.beacon_index
		var is_sel: bool = uid == selected_slot
		var alpha: float = (ALPHA_DEPLOY if deploy else ALPHA_RUNNING) if is_sel else ALPHA_OTHER
		var c: Color = Color(Palette.BONE, alpha)
		if is_sel:
			for i: int in range(1, beacons.size()):
				draw_line(_px(beacons[i - 1]["cell"] as Vector2i), _px(beacons[i]["cell"] as Vector2i), c, line_w)
		for i: int in beacons.size():
			var p: Vector2 = _px(beacons[i]["cell"] as Vector2i)
			var r: float = (MARK_RADIUS if is_sel else OTHER_RADIUS) * t
			var mc: Color = c
			if i == target_index:
				mc = Color(Palette.ALCHEMY_GOLD, 1.0 if blink else 0.35)
			if is_sel:
				_draw_plate(p, str(beacons[i]["id"]), i == target_index and not blink)
				continue
			draw_circle(p, r, Color(Palette.BG_DEEP, mc.a * 0.6))
			draw_arc(p, r, 0.0, TAU, 32, mc, line_w)
	if deploy:
		_draw_unit_numbers(line_w)
	if _drag_id != "" and level.in_bounds(_drag_cell):
		var dc: Color = Palette.ALCHEMY_GOLD if _drag_legal else Palette.WARN_RED
		draw_arc(_px(_drag_cell), MARK_RADIUS * t, 0.0, TAU, 32, dc, line_w)


## 选中单位的信标 = 数字牌（批准整图 ui_21：深底金边圆角方块 + 金色数字；样式取布局 fx_beacon / fx_beacon_text）；
## 边长 = size_cells 格（不小于 min_px 屏幕像素）；运行中当前前往的信标闪烁（dim = 暗相）
func _draw_plate(p: Vector2, id: String, dim: bool) -> void:
	var e: Dictionary = UiKit.layout_element("battle_hud", "fx_beacon")
	var data: Dictionary = e.get("data", {}) as Dictionary
	var th: Theme = UiKit.ui_theme("battle_hud")
	var k: float = maxf(get_global_transform().get_scale().x, 0.01)
	var side: float = maxf(float(data.get("size_cells", 0.45)) * SimTypes.TILE_SIZE, float(data.get("min_px", 26)) / k)
	var rect := Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side))
	var sb: StyleBox = th.get_stylebox("panel", StringName(str(e.get("theme_type", ""))))
	if sb is StyleBoxFlat:
		var f: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat     # 边框与圆角按屏幕像素，换成本层局部单位
		f.set_border_width_all(maxi(int(round(f.border_width_left / k)), 1))
		f.set_corner_radius_all(int(round(f.corner_radius_top_left / k)))
		sb = f
	draw_style_box(sb, rect)
	var tt: StringName = StringName(str(UiKit.layout_element("battle_hud", "fx_beacon_text").get("theme_type", "")))
	var font: Font = th.get_font("font", tt)
	var ref_side: float = UiKit.layout_rect("battle_hud", "fx_beacon", UiKit.design_size("battle_hud")).size.x
	var fs: int = maxi(int(round(float(th.get_font_size("font_size", tt)) * side / ref_side)), 1)   # 字号随牌子大小（整图牌边长对应布局字号），本层局部单位
	var col: Color = th.get_color("font_color", tt)
	if dim:
		col.a = 0.35
	var w: float = font.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	draw_string(font, p + Vector2(-w * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


## 第四阶段：部署阶段在每个已部署单位所在格左下角画编号圆牌（= 进入信标模式的数字键；信标模式中的单位为金底）
func _draw_unit_numbers(line_w: float) -> void:
	var t: float = float(SimTypes.TILE_SIZE)
	var hud: Node = root.get_node_or_null("UI/HUD") if root != null else null
	var active: String = str(hud.call("beacon_mode_slot")) if hud != null and hud.has_method("beacon_mode_slot") else ""
	var list: Array[String] = controller.deployed_uids()
	var k: float = maxf(get_global_transform().get_scale().x, 0.01)
	var r: float = maxf(NUMBER_RADIUS * t, NUMBER_MIN_PX * 0.5 / k)
	var fs: int = maxi(int(round(r * 1.3)), 1)
	for i: int in list.size():
		var cell: Vector2i = controller.placements[list[i]] as Vector2i
		var c: Vector2 = _px(cell) + Vector2(-0.5 * t + r + 2.0, 0.5 * t - r - 2.0)
		var on: bool = list[i] == active
		draw_circle(c, r, Palette.ALCHEMY_GOLD if on else Color(Palette.BG_DEEP, 0.85))
		draw_arc(c, r, 0.0, TAU, 24, Palette.ALCHEMY_GOLD, line_w)
		var txt: String = str(i + 1)
		var sz: Vector2 = NAME_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		draw_string(NAME_FONT, c + Vector2(-sz.x * 0.5, (NAME_FONT.get_ascent(fs) - NAME_FONT.get_descent(fs)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Palette.BG_DEEP if on else Palette.ALCHEMY_GOLD)


## 部署阶段读控制器配置；运行中读模拟单位（已阵亡的不画）
func _beacons_of(slot_id: String, deploy: bool) -> Array[Dictionary]:
	if deploy:
		return controller.get_beacons(slot_id)
	var u: SimUnit = controller.world.get_unit(controller.unit_id_of_slot(slot_id)) if controller.world != null else null
	var out: Array[Dictionary] = []
	if u != null and u.alive:
		out.assign(u.beacons)
	return out


func _px(cell: Vector2i) -> Vector2:
	return SimTypes.sim_to_screen(SimTypes.cell_center(cell), level.height)
