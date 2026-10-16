class_name DetailKit
extends RefCounted
## 角色 / 敌人详情的公共件（第四阶段：详情从居中弹窗改为停靠屏幕一侧的侧栏，批准整图 assets/ui/side_detail/design.png，
## 布局 data/ui_layout/side_detail.json 的 det_* 元素，由 tools/make_side_manifest.py 生成）：
## 头像（金环）、标题、描述、六项属性（属性底板 + 图标 + 名称 + 数值）、可滚动的中部区域（带滚动条）、底部说明。
## 位置一律相对详情框体（det_panel），由 UnitPanel / EnemyPanel 调用；框体与「关闭」由 HUD 的 SidePanel 负责（不再有全屏遮罩）。

const SKIN: String = "side_detail"
const STAT_KEYS: Array[String] = ["stat_hp", "stat_attack", "stat_aps", "stat_speed", "stat_vision", "stat_range"]
const STAT_ICONS: Array[String] = ["ui/icons/stat_hp.svg", "ui/icons/stat_attack.svg", "ui/icons/stat_aps.svg", "ui/icons/stat_speed.svg", "ui/icons/stat_vision.svg", "ui/icons/stat_range.svg"]


## 布局元素相对详情框体的矩形（设计像素；文字元素取文字区）
static func rel(id: String) -> Rect2:
	var d: Vector2 = UiKit.design_size(SKIN)
	var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
	var r: Rect2 = UiKit.layout_text_rect(SKIN, id, d) if text else UiKit.layout_rect(SKIN, id, d)
	return Rect2(r.position - UiKit.layout_rect(SKIN, "det_panel", d).position, r.size)


static func tt(id: String) -> StringName:
	return StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))


static func place(parent: Control, c: Control, r: Rect2) -> Control:
	parent.add_child(c)
	c.position = r.position
	c.size = r.size
	return c


static func label(parent: Control, id: String, text: String = "", rect_id: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = tt(id)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = UiKit.text_align(str(UiKit.layout_element(SKIN, id).get("align", "left")))
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(parent, l, rel(rect_id if rect_id != "" else id))
	return l


## 头像（圆形遮罩）+ 侧栏金环切片（画在头像之上）
static func portrait(parent: Control) -> TextureRect:
	var r: Rect2 = rel("det_portrait")
	var p: TextureRect = UiKit.portrait(r.size.y)
	place(parent, p, r)
	if not UiKit.layout_element(SKIN, "det_portrait_ring").is_empty():
		var ring: Control = UiKit.node_for(UiKit.layout_element(SKIN, "det_portrait_ring"))
		ring.name = "Skin_det_portrait_ring"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(parent, ring, rel("det_portrait_ring"))
	return p


## 属性行：底板 + 六组（图标、名称、数值）；返回数值 Label
static func stats(parent: Control) -> Array[Label]:
	var bg: Control = UiKit.node_for(UiKit.layout_element(SKIN, "det_stats"))
	place(parent, bg, rel("det_stats"))
	var values: Array[Label] = []
	for i: int in STAT_KEYS.size():
		var icon := TextureRect.new()
		icon.texture = Art.texture(STAT_ICONS[i])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(parent, icon, rel("det_stat_icon_%d" % i))
		label(parent, "det_stat_name_%d" % i, DataRegistry.get_string("ui." + STAT_KEYS[i]))
		values.append(label(parent, "det_stat_value_%d" % i))
	return values


## 中部滚动区：内容 VBox 包进 ScrollText（滚轮 / 拖动上下滚动）并挂滚动条；返回内容 VBox
static func scroll_body(parent: Control) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.name = "DetailBody"
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	var row: Rect2 = rel("det_row1")         # 滚动区左上 = 第一行指令框（含切片四周透明留白）的左上，宽 = 行宽
	var sc: Rect2 = rel("det_scroll")
	var r := Rect2(row.position, Vector2(row.size.x, sc.end.y - row.position.y))
	place(parent, body, r)
	var st: ScrollText = ScrollText.wrap_box(body, ScrollText.Mode.MANUAL, r)
	var track: Control = UiKit.node_for(UiKit.layout_element(SKIN, "det_track"))
	track.name = "Skin_det_track"
	place(parent, track, rel("det_track"))
	var thumb: Control = UiKit.node_for(UiKit.layout_element(SKIN, "det_thumb"))
	place(parent, thumb, rel("det_thumb"))
	st.attach_scrollbar(track, thumb)
	st.name = "DetailScroll"
	var arrows: Array[Control] = []                   # 滚动条两端 ▲ / ▼（布局有才建；侧栏整图没有画）
	for id: String in ["det_scroll_arrow_up", "det_scroll_arrow_down"]:
		if UiKit.layout_element(SKIN, id).is_empty():
			continue
		var a: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		a.name = "Skin_" + id
		place(parent, a, rel(id))
		arrows.append(a)
	if arrows.size() == 2:
		st.attach_arrows(arrows[0], arrows[1])
	return body


## 指令区与底部按钮之间的金色分隔线（侧栏整图；布局没有时不建）
static func footer_line(parent: Control) -> void:
	if UiKit.layout_element(SKIN, "det_footer_line").is_empty():
		return
	var line: Control = UiKit.node_for(UiKit.layout_element(SKIN, "det_footer_line"))
	line.name = "Skin_det_footer_line"
	place(parent, line, rel("det_footer_line"))


## 侧栏随视口变高时（宽屏外的 16:10 等）：框体比设计高 extra 像素——滚动区与滚动条加高，scroll 以下的底部件下移
static func stretch(parent: Control, extra: float) -> void:
	var prev: float = float(parent.get_meta(&"stretch_extra", 0.0))
	var d: float = extra - prev
	if is_zero_approx(d):
		return
	parent.set_meta(&"stretch_extra", extra)
	var scroll_end: float = rel("det_scroll").end.y
	for c: Node in parent.get_children():
		var ctl: Control = c as Control
		if ctl == null:
			continue
		if ctl.name == "DetailScroll" or ctl.name.begins_with("Skin_det_track"):
			ctl.size.y += d
		elif ctl.position.y >= scroll_end - 1.0:
			ctl.position.y += d


## 底部说明下方的凸出标签（P6 补充素材 #10，整图里框体下沿向下凸出一块，文字在其中）；须在说明文字之前加入（文字画在上面）
static func footer_tab(parent: Control) -> Control:
	if UiKit.layout_element(SKIN, "det_footer_tab").is_empty():
		return null
	var tab: Control = UiKit.node_for(UiKit.layout_element(SKIN, "det_footer_tab"))
	tab.name = "Skin_det_footer_tab"
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(parent, tab, rel("det_footer_tab"))
	return tab


## 中部区域内文字的左缩进：与指令行里拖拽柄的左缘对齐（行框切片四周有透明留白，文字不能贴着滚动区左缘）
static func inset() -> float:
	return rel("det_handle").position.x - rel("det_row1").position.x


static func _indented(body: Control, c: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(inset()))
	m.add_theme_constant_override("margin_right", int(inset()))
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_child(c)
	body.add_child(m)
	return m


## 中部区域里的小节标题（金色，用优先级标题样式）与正文（用描述样式，换行）
static func section_title(body: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = tt("det_prio")
	_indented(body, l)
	return l


static func section_text(body: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = tt("det_desc")
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(rel("det_row1").size.x - inset() * 2.0, 0.0)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	_indented(body, l)
	return l


## 中部区域顶部留白（与指令行框的可见上沿对齐）
static func top_gap(body: Control) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, rel("det_handle").position.y - rel("det_row1").position.y - 8.0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(g)
