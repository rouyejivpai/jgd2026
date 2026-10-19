class_name TutorialOverlay
extends Control
## 第五阶段（2026-10-17 会议）统一强制引导的表现层：全屏压暗 + 高亮挖空（金边）+ 指向箭头 + 分步说明框。
## 输入：block = true 时只有高亮处可点（_has_point 在高亮外返回 true 吞掉点击，高亮内放行给下面的界面 / 地图）；
## block = false 时整层放行，只有说明框可点。样式参数来自 data/teaching.json 的 style（TeachingDef.DEFAULT_STYLE）。
## 只负责画与收输入；步骤推进、目标定位由 TutorialDirector 负责。
## 2026-10-19 哥特换皮：布局 data/ui_layout/tutorial.json 存在时，说明框 / 文字 / 按钮用其主题，高亮框画细银线 + 四角角饰，
## 箭头画银色长矛切图（按方向旋转）；布局缺失时退回金边 + 三角箭头。

signal next_pressed()
signal skip_pressed()
signal back_pressed()                     ## 配置器预览：返回配置器

const MAX_HOLES: int = 12
const PANEL_PAD: int = 16
const SKIN: String = "tutorial"

var style: Dictionary = TeachingDef.DEFAULT_STYLE.duplicate()
var holes: Array[Rect2] = []              ## 屏幕矩形（已含留白）；第一个为箭头指向的目标
var block: bool = true
var arrow: String = "auto"
var panel_side: String = "auto"
var _deco: Control                       ## 压暗（高亮处挖空）+ 金边 + 箭头
var _panel: PanelContainer
var _title: Label
var _body: Label
var _step: Label
var _next: Button
var _skip: Button
var _back: Button
var _time: float = 0.0
var _corner: Texture2D = null             ## 哥特：高亮框角饰（左上角，其余镜像）
var _arrow_tex: Texture2D = null          ## 哥特：箭头切图（朝下）


func _ready() -> void:
	name = "TutorialOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_deco = Control.new()
	_deco.name = "Deco"
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var m := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, PANEL_PAD)
	_panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	col.add_child(_title)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	_step = Label.new()
	_step.name = "StepLabel"
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_step)
	_back = _button("BackButton", "ui.tutorial_back", back_pressed)
	foot.add_child(_back)
	_skip = _button("SkipButton", "ui.tutorial_skip", skip_pressed)
	foot.add_child(_skip)
	_next = _button("NextButton", "ui.tutorial_next", next_pressed)
	foot.add_child(_next)
	_back.visible = false
	_apply_skin(m)
	visible = false


## 哥特换皮：主题、说明框底板与内边距、文字与按钮的主题变体、角饰 / 箭头贴图
func _apply_skin(m: MarginContainer) -> void:
	if UiKit.ui_layout(SKIN).is_empty():
		return
	theme = UiKit.ui_theme(SKIN)
	_panel.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "panel").get("theme_type", "")))
	var pad: Array = (UiKit.layout_element(SKIN, "panel").get("data", {}) as Dictionary).get("pad", [PANEL_PAD, PANEL_PAD, PANEL_PAD, PANEL_PAD]) as Array
	for i: int in 4:
		m.add_theme_constant_override("margin_" + ["left", "top", "right", "bottom"][i], int(pad[i]))
	for pair: Array in [[_title, "title"], [_body, "body"], [_step, "step"], [_next, "btn_next"], [_skip, "btn_skip"], [_back, "btn_back"]]:
		var c: Control = pair[0] as Control
		var e: Dictionary = UiKit.layout_element(SKIN, str(pair[1]))
		c.theme_type_variation = StringName(str(e.get("theme_type", "")))
		if c is Button:
			c.custom_minimum_size = UiKit.layout_rect(SKIN, str(pair[1]), UiKit.design_size(SKIN)).size
	_title.remove_theme_color_override("font_color")
	_step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_corner = Art.texture(str(UiKit.layout_element(SKIN, "corner").get("file", "")))
	_arrow_tex = Art.texture(str(UiKit.layout_element(SKIN, "arrow").get("file", "")))


func _button(n: String, key: String, sig: Signal) -> Button:
	var b := Button.new()
	b.name = n
	b.text = DataRegistry.get_string(key)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: sig.emit())
	return b


func set_style(s: Dictionary) -> void:
	for k: String in s.keys():
		style[k] = s[k]
	var hd: Dictionary = UiKit.layout_element(SKIN, "highlight").get("data", {}) as Dictionary     # 哥特：高亮线色 / 线宽取布局
	if hd.has("color"):
		style["highlight_color"] = hd["color"]
		style["highlight_width"] = hd.get("width", style["highlight_width"])
	_panel.custom_minimum_size = Vector2(float(style["panel_width"]), 0.0)
	_body.custom_minimum_size = Vector2(float(style["panel_width"]) - PANEL_PAD * 2.0, 0.0)   # 换行标签先定宽，高度才对
	_deco.queue_redraw()


## 显示一步。rects 为目标的屏幕矩形（未加留白），空 = 只有说明框；tap = 点屏幕任意处继续（步骤计数旁加提示）
func show_step(title: String, text: String, step_n: int, total: int, show_next: bool, p_block: bool, p_arrow: String, p_panel: String, tap: bool = false) -> void:
	_title.text = title
	_title.visible = title != ""
	_body.text = text
	_step.text = DataRegistry.get_string("ui.tutorial_step").format({ "n": step_n, "total": total })
	if tap:
		_step.text += DataRegistry.get_string("ui.tutorial_tap")
	_next.visible = show_next
	block = p_block
	arrow = p_arrow
	panel_side = p_panel
	visible = true
	_layout_panel()
	UiKit.slide_in.call_deferred([_panel])     # 2026-10-19：每一步的说明框缓动滑入（等本帧高亮 / 摆放定好再取位置）


func set_back_visible(on: bool) -> void:
	_back.visible = on


func set_targets(rects: Array[Rect2]) -> void:
	var pad: float = float(style["hole_pad"])
	var out: Array[Rect2] = []
	for r: Rect2 in rects:
		if r.size.x > 0.0 or r.size.y > 0.0:
			out.append(r.grow(pad))
	if out.size() > MAX_HOLES:
		out.resize(MAX_HOLES)
	if out == holes:
		return
	holes = out
	_layout_panel()
	_deco.queue_redraw()


func hide_overlay() -> void:
	visible = false


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


## 高亮外是否吞掉点击：block 时高亮外 = 本层（吞掉），高亮内 = 放行；不 block 时整层放行（说明框是子节点，照常可点）
func _has_point(point: Vector2) -> bool:
	if not visible or not block:
		return false
	for r: Rect2 in holes:
		if r.has_point(point):
			return false
	return true


func in_hole(point: Vector2) -> bool:
	for r: Rect2 in holes:
		if r.has_point(point):
			return true
	return false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if UiKit.motion_enabled and not holes.is_empty() and arrow != "none":
		_deco.queue_redraw()


## 屏幕减去高亮处 = 若干矩形：按全部高亮的边把屏幕切成网格，不落在任何高亮内的格子即压暗区域
static func dim_rects(screen: Rect2, hole_rects: Array[Rect2]) -> Array[Rect2]:
	var xs: Array[float] = [screen.position.x, screen.end.x]
	var ys: Array[float] = [screen.position.y, screen.end.y]
	for h: Rect2 in hole_rects:
		var c: Rect2 = h.intersection(screen)
		if c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		xs.append_array([c.position.x, c.end.x])
		ys.append_array([c.position.y, c.end.y])
	xs.sort()
	ys.sort()
	var out: Array[Rect2] = []
	for j: int in ys.size() - 1:
		for i: int in xs.size() - 1:
			var cell := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var mid: Vector2 = cell.get_center()
			if not hole_rects.any(func(h: Rect2) -> bool: return h.has_point(mid)):
				out.append(cell)
	return out


func _draw_deco() -> void:
	var dim := Color(str(style["dim_color"]))
	for r: Rect2 in dim_rects(Rect2(Vector2.ZERO, get_viewport_rect().size), holes):
		_deco.draw_rect(r, dim)
	var col := Color(str(style["highlight_color"]))
	var w: float = float(style["highlight_width"])
	for r: Rect2 in holes:
		_deco.draw_rect(r, col, false, w)
		if _corner != null:
			_draw_corners(r)
	if holes.is_empty() or arrow == "none":
		return
	var t: Rect2 = holes[0]
	var side: String = _arrow_side(t)
	var arrow_len: float = float(style["arrow_size"])
	var bob: float = float(style["arrow_bob"]) * sin(_time * TAU * float(style["arrow_bob_hz"])) if UiKit.motion_enabled else 0.0
	var gap: float = float(style["arrow_gap"]) + bob
	var dir := Vector2.ZERO
	var tip := Vector2.ZERO
	match side:
		"up":       # 箭头在目标下方，朝上指
			dir = Vector2.UP
			tip = Vector2(t.get_center().x, t.end.y + gap)
		"down":
			dir = Vector2.DOWN
			tip = Vector2(t.get_center().x, t.position.y - gap)
		"left":
			dir = Vector2.LEFT
			tip = Vector2(t.end.x + gap, t.get_center().y)
		_:
			dir = Vector2.RIGHT
			tip = Vector2(t.position.x - gap, t.get_center().y)
	if _arrow_tex != null:                     # 哥特：长矛切图朝下、尖端在底边中点 → 旋转到 dir，尖端对准 tip
		var sz: Vector2 = _arrow_tex.get_size()
		_deco.draw_set_transform(tip, Vector2.DOWN.angle_to(dir), Vector2.ONE)
		_deco.draw_texture_rect(_arrow_tex, Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y), false)
		_deco.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var back: Vector2 = tip - dir * arrow_len
	var n: Vector2 = Vector2(-dir.y, dir.x) * arrow_len * 0.55
	_deco.draw_colored_polygon(PackedVector2Array([tip, back + n, back - n]), col)
	_deco.draw_line(back, back - dir * arrow_len * 1.1, col, w * 2.0)


## 高亮框四角角饰：切图为左上角，pivot（两边交点）对准框角，其余三角水平 / 竖直镜像
func _draw_corners(r: Rect2) -> void:
	var pv: Array = (UiKit.layout_element(SKIN, "corner").get("data", {}) as Dictionary).get("pivot", [0, 0]) as Array
	var pivot := Vector2(float(pv[0]), float(pv[1]))
	var sz: Vector2 = _corner.get_size()
	for c: Array in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		_deco.draw_set_transform(c[0] as Vector2, 0.0, c[1] as Vector2)
		_deco.draw_texture_rect(_corner, Rect2(-pivot, sz), false)
	_deco.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 箭头方向：指定方向直接用；auto = 目标在屏幕下半 → 从上往下指（箭头在目标上方），否则从下往上指
func _arrow_side(t: Rect2) -> String:
	if arrow != "auto":
		return arrow
	var vp: Vector2 = get_viewport_rect().size
	if t.size.y > vp.y * 0.6:
		return "right" if t.get_center().x > vp.x * 0.5 else "left"
	return "down" if t.get_center().y > vp.y * 0.5 else "up"


## 说明框位置：指定方位贴屏幕边；auto = 先试第一个高亮的对侧，再依次试 上 / 下 / 右 / 左 / 居中 / 四角，取第一个不压住任何高亮的位置
func _layout_panel() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	_panel.size = Vector2.ZERO
	var sz: Vector2 = _panel.get_combined_minimum_size()
	sz.x = maxf(sz.x, float(style["panel_width"]))
	var side: String = panel_side
	var pos: Vector2 = _panel_pos(side, sz, vp)
	if side == "auto":
		var first: String = "center"
		if not holes.is_empty():
			first = "top" if holes[0].get_center().y > vp.y * 0.5 else "bottom"
			if holes[0].size.y > vp.y * 0.6:
				first = "left" if holes[0].get_center().x > vp.x * 0.5 else "right"
		pos = _panel_pos(first, sz, vp)
		for cand: String in [first, "top", "bottom", "right", "left", "center", "top_left", "top_right", "bottom_left", "bottom_right"]:
			var p: Vector2 = _panel_pos(cand, sz, vp)
			var r := Rect2(p, sz).grow(float(style["hole_pad"]))
			if not holes.any(func(h: Rect2) -> bool: return h.intersects(r)):
				pos = p
				break
	_panel.position = pos
	_panel.size = sz


func _panel_pos(side: String, sz: Vector2, vp: Vector2) -> Vector2:
	var margin: float = float(style["panel_margin"])
	var cx: float = (vp.x - sz.x) * 0.5
	var cy: float = (vp.y - sz.y) * 0.5
	var top: float = margin + vp.y * 0.12          # 让出顶栏
	var bottom: float = vp.y - sz.y - margin - vp.y * 0.18   # 让出底栏
	match side:
		"left":
			return Vector2(margin, cy)
		"right":
			return Vector2(vp.x - sz.x - margin, cy)
		"top":
			return Vector2(cx, top)
		"bottom":
			return Vector2(cx, bottom)
		"top_left":
			return Vector2(margin, top)
		"top_right":
			return Vector2(vp.x - sz.x - margin, top)
		"bottom_left":
			return Vector2(margin, bottom)
		"bottom_right":
			return Vector2(vp.x - sz.x - margin, bottom)
	return Vector2(cx, cy)
