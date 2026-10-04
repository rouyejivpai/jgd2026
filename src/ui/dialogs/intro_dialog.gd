class_name IntroDialog
extends Control
## 关卡介绍弹窗。详细设计：[docs/design/10-主界面与HUD.md](../../docs/design/10-主界面与HUD.md) 4.3
##
## 进关卡自动弹一次（FR-TUT-03），之后可随时用工具条「关卡介绍」按钮重看。
## 内容来自关卡数据的 `intro` 字段：`{ title, tips[] }`（已在三关 JSON 里写好）。
##
## 【布局】遵守本工程 UI 约定：锚点 + 容器，不写绝对像素坐标。

signal closed

var _root: PanelContainer
var _title: Label
var _tips: VBoxContainer


func _ready() -> void:
	_build_ui()
	visible = false
	_fit_to_viewport()


## 【必须自己撑满视口】同 ResultScreen：挂 CanvasLayer 下的 Control 尺寸实测为
## (0,0)，`CenterContainer` 会把面板摆到左上角而不是居中。
func _fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0 and size != vp:
		size = vp


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_to_viewport()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_root = PanelContainer.new()
	_root.name = "Panel"
	_root.custom_minimum_size = Vector2(820, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.17, 0.98)
	sb.border_color = Color(0.34, 0.38, 0.46)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_root.add_theme_stylebox_override("panel", sb)
	center.add_child(_root)

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 16)
	_root.add_child(col)

	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)

	_tips = VBoxContainer.new()
	_tips.name = "Tips"
	_tips.add_theme_constant_override("separation", 10)
	col.add_child(_tips)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var ok_btn := Button.new()
	ok_btn.name = "OkButton"
	ok_btn.text = "开始编制（Esc 关闭）"
	ok_btn.custom_minimum_size = Vector2(260, 48)
	ok_btn.pressed.connect(_on_ok)
	row.add_child(ok_btn)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_ok()
		get_viewport().set_input_as_handled()


## 用关卡数据的 intro 字段填充并弹出。
## intro 形如 {"title": "...", "tips": ["...", "..."]}
func show_intro(intro: Dictionary) -> void:
	var t := str(intro.get("title", ""))
	_title.text = t if not t.is_empty() else "关卡介绍"

	for c in _tips.get_children():
		# 【必须先 remove_child 再 queue_free】queue_free 是**帧末**执行的，
		# 只调它的话旧条目在本帧仍然是子节点，紧接着遍历子节点就会数到陈旧数据
		# （实测：空 intro 却数出 3 条 tip）。与 BattleMap 清障碍那次是同一个坑。
		_tips.remove_child(c)
		c.queue_free()
	var tips: Array = intro.get("tips", [])
	if tips.is_empty():
		var l := Label.new()
		l.text = "（本关没有介绍文字）"
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
		_tips.add_child(l)
	else:
		for i in tips.size():
			var l := Label.new()
			l.name = "Tip_%d" % i
			# 用「· 」而不是依赖富文本：内容来自数据文件，不做 Markdown 渲染
			l.text = "%d. %s" % [i + 1, str(tips[i])]
			l.add_theme_font_size_override("font_size", 21)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_tips.add_child(l)

	visible = true
	var ok_btn := _root.get_node_or_null("Column/ButtonRow/OkButton")
	if ok_btn == null:
		ok_btn = find_child("OkButton", true, false)
	if ok_btn is Button:
		(ok_btn as Button).grab_focus()


func hide_intro() -> void:
	visible = false


func is_showing() -> bool:
	return visible


func title_text() -> String:
	return _title.text if _title != null else ""


## 面板矩形（测试与像素断言用来验证"弹窗确实居中"）
func panel_rect() -> Rect2:
	return _root.get_global_rect() if _root != null else Rect2()


func tip_count() -> int:
	var n := 0
	for c in _tips.get_children():
		if str(c.name).begins_with("Tip_") and not c.is_queued_for_deletion():
			n += 1
	return n


func press_ok() -> void:
	_on_ok()


func _on_ok() -> void:
	visible = false
	closed.emit()
