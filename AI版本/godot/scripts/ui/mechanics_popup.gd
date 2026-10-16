extends Control
## 通用规则说明（01 §9 mechanics_popup），文案来自 strings.json["mechanics"]；顶部另列本关机制提示（关卡 briefing.mechanic_hint，07 §10.2）。
## 第三阶段 P6 按批准整图 ui_07 换皮：modal_panel 框体、标题、「关闭」、分隔线；本关要点（金字，超出时上下滚动）；
## 每条规则一个圆角框（最小高 = 整图框高，文字竖直居中、超长换行），规则区上下滚动并显示滚动条（scroll_track / scroll_thumb 切片）。
## 位置全部取自 data/ui_layout/battle_hud.json 的 mech_* 元素（相对框体）；框体本身由 HUD 摆放（UiKit.layout_rect("mech_panel")）。

const SKIN: String = "battle_hud"

var _level_hint: Label
var _hint_scroll: ScrollText
var _body_scroll: ScrollText


func _ready() -> void:
	theme = UiKit.ui_theme(SKIN)            # 先设主题：子节点的最小尺寸按换皮样式计算（HUD 的主题此时还没设）
	var d: Vector2 = UiKit.design_size(SKIN)
	var panel: Rect2 = UiKit.layout_rect(SKIN, "mech_panel", d)
	var rel := func(id: String, text_rect: bool = false) -> Rect2:
		var r: Rect2 = UiKit.layout_text_rect(SKIN, id, d) if text_rect else UiKit.layout_rect(SKIN, id, d)
		return Rect2(r.position - panel.position, r.size)
	size = panel.size
	var bg: Control = UiKit.node_for(UiKit.layout_element(SKIN, "mech_panel"))
	bg.name = "Skin_mech_panel"
	_add(bg, Rect2(Vector2.ZERO, panel.size))
	var title: Label = _label(DataRegistry.get_string("ui.mechanics"), "mech_title", false)
	title.clip_text = true
	_add(title, rel.call("mech_title", true))
	ScrollText.wrap(title, ScrollText.Mode.AUTO)
	var close: Button = UiKit.node_for(UiKit.layout_element(SKIN, "mech_close")) as Button
	close.name = "PopupClose"
	close.text = DataRegistry.get_string("ui.close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	_add(close, rel.call("mech_close"))
	var sep: Control = UiKit.node_for(UiKit.layout_element(SKIN, "mech_sep"))
	_add(sep, rel.call("mech_sep"))
	# 本关要点：从 hint 顶到第一个框顶（扣掉整图里第二行到框的间距），超出时滚动
	var hint: Rect2 = rel.call("mech_hint", true)
	var box: Rect2 = rel.call("mech_box")
	var box2: Rect2 = rel.call("mech_box2")
	var box_text: Rect2 = rel.call("mech_box_text", true)
	_level_hint = _label("", "mech_hint", true)
	_level_hint.visible = false
	var hint_h: float = box.position.y - hint.position.y - hint.size.y * 0.5          # 到第一个框顶，留半行间距
	_add(_level_hint, Rect2(hint.position, Vector2(hint.size.x, box.position.y - hint.position.y)))
	_hint_scroll = ScrollText.wrap(_level_hint, ScrollText.Mode.MANUAL, Rect2(hint.position, Vector2(hint.size.x, hint_h)))
	# 规则：每条一个框
	var list := VBoxContainer.new()
	list.name = "RuleList"
	list.add_theme_constant_override("separation", int(round(box2.position.y - box.end.y)))
	var lines: Array[String] = DataRegistry.get_string_list("mechanics")
	for line: String in lines:
		var p := PanelContainer.new()
		p.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "mech_box").get("theme_type", "")))
		p.custom_minimum_size = Vector2(box.size.x, box.size.y)
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var m := MarginContainer.new()
		var inset: int = int(round(box_text.position.x - box.position.x))
		m.add_theme_constant_override("margin_left", inset)
		m.add_theme_constant_override("margin_right", inset)
		m.mouse_filter = Control.MOUSE_FILTER_PASS
		var l: Label = _label(line, "mech_box_text", true)
		l.custom_minimum_size = Vector2(box.size.x - inset * 2, 0.0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.add_child(l)
		p.add_child(m)
		list.add_child(p)
	var track_r: Rect2 = rel.call("mech_track")
	var body := Rect2(box.position, Vector2(box.size.x, track_r.end.y - box.position.y))
	_add(list, body)
	_body_scroll = ScrollText.wrap_box(list, ScrollText.Mode.MANUAL, body)
	var track: Control = UiKit.node_for(UiKit.layout_element(SKIN, "mech_track"))
	_add(track, track_r)
	var thumb: Control = UiKit.node_for(UiKit.layout_element(SKIN, "mech_thumb"))
	_add(thumb, rel.call("mech_thumb"))
	_body_scroll.attach_scrollbar(track, thumb)
	visible = false


func _add(c: Control, r: Rect2) -> void:
	add_child(c)
	c.position = r.position
	c.size = r.size


func _label(text: String, id: String, wrap_lines: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	if wrap_lines:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	return l


func set_level_hint(text: String) -> void:
	_level_hint.text = DataRegistry.get_string("ui.level_mechanic").format({ "text": text })
	_level_hint.visible = text != ""
