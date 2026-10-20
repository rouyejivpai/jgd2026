class_name RelicSlot
extends Control
## 遗物栏里的一枚遗物（HUD 左下，见 RelicBar）：金环深底圆盘 + 遗物图标 + 剩余次数小点；
## 未获得 = 剪影 + 锁；本场不可用（其他遗物已启用 / 阶段不对 / 次数用完）= 压暗；冷却 = 扇形遮罩 + 秒数；
## 已启用 = 遗物色呼吸外环；正在点选目标 = 金色亮环。点按 / 拖拽交给 RelicBar（地块遗物可直接拖到地图上，同放置人偶）。
## 音效：不是 BaseButton，悬停 ui_hover 自己播（未获得不响）；拖起 relic_pick，拖出后没被接收 drag_cancel；冷却结束重新可用 relic_ready。

signal pressed_slot(relic_id: String)

const RING_W: float = 4.0

var relic_id: String = ""
var controller: BattleController = null
var armed: bool = false
var _hover: bool = false
var _t: float = 0.0
var _dragging: bool = false              ## 从这枚拖起的 GUI 拖拽进行中
var _was_cooldown: bool = false          ## 上一帧是否在冷却（冷却 → 可用时响 relic_ready）


func setup(id: String, p_controller: BattleController) -> void:
	relic_id = id
	controller = p_controller
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		if owned():
			AudioManager.play_sfx("ui_hover", "UI")
		queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())
	refresh()


func owned() -> bool:
	return GameState.is_unlocked("relics", relic_id)


## 悬停说明：名字 + 描述 + 当前不可用原因（或操作方法）
func refresh() -> void:
	var d: Dictionary = DataRegistry.get_relic(relic_id)
	if not owned():
		var src: LevelDefinition = DataRegistry.relic_source_level(relic_id)
		tooltip_text = DataRegistry.get_string("ui.relic_locked_tip").format({ "level": src.title, "name": str(d.get("name", "")) }) if src != null \
			else DataRegistry.get_string("ui.relic_locked_unknown")
	else:
		tooltip_text = DataRegistry.get_string("ui.relic_tip_state").format({ "name": str(d.get("name", "")), "desc": str(d.get("desc", "")), "state": state_text() })
	queue_redraw()


## 当前状态短句（ui.relic_state_*）
func state_text() -> String:
	if controller == null:
		return ""
	var problem: String = controller.relic_problem(relic_id)
	match problem:
		"":
			return DataRegistry.get_string("ui.relic_state_ready_tile" if str(DataRegistry.get_relic(relic_id).get("kind", "")) == "tile" else "ui.relic_state_ready_target")
		"other_active":
			return DataRegistry.get_string("ui.relic_state_other_active").format({ "name": str(DataRegistry.get_relic(controller.relic_active).get("name", "")) })
		"cooldown":
			return DataRegistry.get_string("ui.relic_state_cooldown").format({ "s": "%.1f" % controller.relic_cooldown_left(relic_id) })
		"locked":
			return ""
	return DataRegistry.get_string("ui.relic_state_" + problem)


func _process(delta: float) -> void:
	_t += delta
	if controller != null:
		var problem: String = controller.relic_problem(relic_id)
		if _was_cooldown and problem == "":
			AudioManager.play_ui("relic_ready")
		_was_cooldown = problem == "cooldown"
	if controller != null and (controller.relic_active == relic_id or armed):
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and Rect2(Vector2.ZERO, size).has_point(mb.position):
		pressed_slot.emit(relic_id)
		accept_event()


## 地块遗物：可用时（或拖动已放下的同一枚，见 MapInput）拖到地图上放置
func _get_drag_data(_at_position: Vector2) -> Variant:
	if controller == null or str(DataRegistry.get_relic(relic_id).get("kind", "")) != "tile" or controller.relic_problem(relic_id) != "":
		return null
	set_drag_preview(make_preview(relic_id, _cell_px()))
	AudioManager.play_sfx("relic_pick", "UI")
	_dragging = true
	return { "relic": relic_id }


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		if not get_viewport().gui_is_drag_successful():
			AudioManager.play_sfx("drag_cancel", "UI")


func _cell_px() -> float:
	var root: Node = controller.get_parent() if controller != null else null
	return float(root.call("cell_screen_px")) if root != null and root.has_method("cell_screen_px") else float(SimTypes.TILE_SIZE)


## 拖拽虚影：遗物图标（一格大），战场内由 RelicLayer 画吸附预览，虚影隐藏（与 RosterCard 同一套 show / tint）
static func make_preview(id: String, cell_px: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Art.texture(str(DataRegistry.get_relic(id).get("icon", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(cell_px, cell_px)
	icon.position = -icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, RosterCard.PREVIEW_ALPHA)
	holder.add_child(icon)
	RosterCard.register_preview(icon)
	return holder


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - RING_W
	var have: bool = owned()
	var problem: String = controller.relic_problem(relic_id) if controller != null else "locked"
	var usable: bool = problem == ""
	var active: bool = controller != null and controller.relic_active == relic_id
	var col: Color = Color(str(DataRegistry.get_relic(relic_id).get("color", "#c9a24a")))
	# 底盘
	draw_circle(c, r, Color(Palette.VIOLET_DEEP, 0.95))
	draw_circle(c, r * 0.82, Color(Palette.BG_DEEP, 0.9))
	if active:
		var glow: float = 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(c, r * 0.82, Color(col, 0.18 + 0.12 * glow))
	# 图标
	var tex: Texture2D = Art.texture(str(DataRegistry.get_relic(relic_id).get("icon", "")))
	if tex != null:
		var side: float = r * 1.55 * (1.06 if (_hover and have) else 1.0)
		var tint: Color = Color.WHITE
		if not have:
			tint = Color(0.0, 0.0, 0.0, 0.75)
		elif not usable and not active and problem != "placed":
			tint = Color(0.55, 0.5, 0.58, 0.7)
		draw_texture_rect(tex, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, tint)
	# 冷却扇形
	if controller != null and problem == "cooldown":
		var d: Dictionary = DataRegistry.get_relic(relic_id)
		var k: float = clampf(controller.relic_cooldown_left(relic_id) / maxf(float(d.get("cooldown", 1.0)), 0.01), 0.0, 1.0)
		var pts := PackedVector2Array([c])
		var seg: int = 32
		for i: int in seg + 1:
			var a: float = -PI * 0.5 + TAU * k * float(i) / float(seg)
			pts.append(c + Vector2(cos(a), sin(a)) * r * 0.82)
		if k > 0.01:
			draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.55))
		var font: Font = get_theme_default_font()
		var s: String = "%d" % ceili(controller.relic_cooldown_left(relic_id))
		var fs: int = int(r * 0.7)
		var sz: Vector2 = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		draw_string_outline(font, c + Vector2(-sz.x * 0.5, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 6, Palette.BG_DEEP)
		draw_string(font, c + Vector2(-sz.x * 0.5, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Palette.BONE)
	# 外环：未获得暗紫；可用金；已启用遗物色呼吸；点选中亮金加粗
	var ring: Color = Palette.VIOLET_MUTE
	var ring_w: float = RING_W
	if armed:
		ring = Palette.ALCHEMY_GOLD.lightened(0.35)
		ring_w = RING_W + 2.0
	elif active:
		ring = col.lerp(Palette.ALCHEMY_GOLD, 0.5 + 0.5 * sin(_t * 3.0))
	elif have and (usable or _hover):
		ring = Palette.ALCHEMY_GOLD
	elif have:
		ring = Palette.ALCHEMY_GOLD.darkened(0.45)
	draw_arc(c, r, 0.0, TAU, 48, ring, ring_w, true)
	draw_arc(c, r * 0.82, 0.0, TAU, 48, Color(ring, 0.45), 1.5, true)
	# 锁
	if not have:
		var lk: Vector2 = c + Vector2(r * 0.55, r * 0.55)
		draw_circle(lk, r * 0.26, Palette.VIOLET_DEEP)
		draw_arc(lk, r * 0.26, 0.0, TAU, 24, Palette.BONE_DIM, 2.0, true)
		draw_rect(Rect2(lk + Vector2(-r * 0.11, -r * 0.03), Vector2(r * 0.22, r * 0.15)), Palette.BONE_DIM)
		draw_arc(lk + Vector2(0.0, -r * 0.03), r * 0.07, PI, TAU, 12, Palette.BONE_DIM, 2.0, true)
		return
	# 剩余次数小点（地块已放下 / 次数用完时为空心）
	if controller != null:
		var total: int = int(DataRegistry.get_relic(relic_id).get("charges", 1))
		var left: int = controller.relic_charges_left(relic_id)
		var pip: float = maxf(r * 0.1, 3.0)
		var gap: float = pip * 2.8
		var y: float = c.y + r + pip * 0.4
		for i: int in total:
			var p := Vector2(c.x + (float(i) - float(total - 1) * 0.5) * gap, y)
			draw_circle(p, pip + 1.5, Palette.BG_DEEP)
			if i < left:
				draw_circle(p, pip, Palette.ALCHEMY_GOLD)
			else:
				draw_arc(p, pip, 0.0, TAU, 12, Palette.ALCHEMY_GOLD.darkened(0.4), 1.5, true)
