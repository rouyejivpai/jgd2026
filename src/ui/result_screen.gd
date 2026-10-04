class_name ResultScreen
extends Control
## 结算界面。详细设计：[docs/design/08-评价与结算.md](../../docs/design/08-评价与结算.md) 4.5
## 与 [10-主界面与HUD](../../docs/design/10-主界面与HUD.md) 4.5
##
## 【边界】**只渲染 `ResultData`，不做任何算术** —— 避免与系统 08 口径分叉
## （详设 10 的 2.3）。分数、分项、明细全部从传入的对象里读。
##
## 【布局】遵守本工程的 UI 约定：锚点 + 容器，不写绝对像素坐标。
##
## 发：`action_selected(id)`，收：PlayScene
## 取值：见下方 ACTION_*

const ResultDataScript := preload("res://src/core/score/result_data.gd")

const ACTION_RETRY := "retry"
const ACTION_NEXT := "next"
const ACTION_SELECT := "select"
const ACTION_EXIT := "exit"

signal action_selected(id: String)

var _root: PanelContainer
var _title: Label
var _total: Label
var _rows: VBoxContainer
var _detail: Label
var _record: Label
var _buttons: HBoxContainer
## 当前是否允许"下一关"（没有下一关时隐藏）
var has_next := true


func _ready() -> void:
	_build_ui()
	visible = false
	_fit_to_viewport()


## 【必须自己撑满视口】本界面挂在 CanvasLayer 下，而实测这种 Control 的尺寸是
## (0,0) —— 于是 `CenterContainer` 在零尺寸矩形里居中，面板会**贴到左上角**，
## 而不是屏幕中央（截图里一眼可见）。抽屉（RulePanel）踩过同一个坑。
## 显式把尺寸设成视口大小即可，并在窗口变化时跟随。
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

	# 半透明遮罩：把注意力集中在结算面板上
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 居中容器：任何窗口尺寸下都居中
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_root = PanelContainer.new()
	_root.name = "Panel"
	_root.custom_minimum_size = Vector2(760, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.16, 0.98)
	sb.border_color = Color(0.32, 0.36, 0.44)
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
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)

	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)

	_total = Label.new()
	_total.name = "Total"
	_total.add_theme_font_size_override("font_size", 30)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_total)

	_record = Label.new()
	_record.name = "Record"
	_record.add_theme_font_size_override("font_size", 20)
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_record.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	col.add_child(_record)

	var sep := HSeparator.new()
	col.add_child(sep)

	# 分项与明细：只读 ResultData，不在这里做算术
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 6)
	col.add_child(_rows)

	_detail = Label.new()
	_detail.name = "Detail"
	_detail.add_theme_font_size_override("font_size", 18)
	_detail.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail)

	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_buttons)

	for spec in [[ACTION_RETRY, "重试"], [ACTION_NEXT, "下一关"],
			[ACTION_SELECT, "返回选关"], [ACTION_EXIT, "回主菜单"]]:
		var b := Button.new()
		b.name = "Btn_" + str(spec[0])
		b.text = str(spec[1])
		b.custom_minimum_size = Vector2(150, 48)
		b.pressed.connect(_on_action.bind(str(spec[0])))
		_buttons.add_child(b)


## 显示一个结算结果。rd 是 ResultData（失败时只含 verdict）。
func show_result(rd) -> void:
	if rd == null:
		return
	var win: bool = int(rd.get("verdict")) == 1
	_title.text = "胜利！" if win else "失败"
	_title.add_theme_color_override("font_color",
		Color(0.55, 0.95, 0.60) if win else Color(1.0, 0.55, 0.55))

	if not bool(rd.get("computed")):
		# 失败不计分（FR-SCORE-06）
		_total.text = "本关未计分"
		_record.text = ""
		_detail.text = "提示：失败时不计算得分、也不写入最佳记录。"
	else:
		_total.text = "总分 %.1f" % float(rd.get("total_score"))
		_detail.text = "明细：条件 %d 个 · 行为 %d 个 · 信标 %d 个 · 用时 %.1f 秒" % [
			int(rd.get("condition_count")), int(rd.get("action_count")),
			int(rd.get("beacon_count")), float(rd.get("elapsed_time"))]
		var best := float(rd.get("best_score"))
		if bool(rd.get("is_new_record")):
			_record.text = "新纪录！历史最佳 %.1f" % best
		elif best >= 0.0:
			_record.text = "历史最佳 %.1f" % best
		else:
			_record.text = ""

	# 分项常驻（即使是 0 也显示，便于玩家看懂计分口径）
	_rebuild_rows(rd)

	var next_btn := _buttons.get_node_or_null("Btn_" + ACTION_NEXT)
	if next_btn != null:
		(next_btn as Button).visible = has_next
	visible = true
	# 默认焦点给"重试"，键盘/手柄能立刻操作
	var retry := _buttons.get_node_or_null("Btn_" + ACTION_RETRY)
	if retry != null:
		(retry as Button).grab_focus()


func _rebuild_rows(rd) -> void:
	for c in _rows.get_children():
		c.queue_free()
	var items := [
		["指令复杂度", float(rd.get("complexity_cost"))],
		["信标成本", float(rd.get("beacon_cost"))],
		["时间成本", float(rd.get("time_cost"))],
	]
	for it in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_l := Label.new()
		name_l.text = str(it[0])
		name_l.add_theme_font_size_override("font_size", 20)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var val_l := Label.new()
		var v := float(it[1])
		val_l.text = "—" if v < 0.0 else "%.1f" % v
		val_l.add_theme_font_size_override("font_size", 20)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_l)
		_rows.add_child(row)


func hide_result() -> void:
	visible = false


func is_showing() -> bool:
	return visible


func _on_action(id: String) -> void:
	action_selected.emit(id)


## 测试用：按名字点某个出口按钮
func press_action(id: String) -> bool:
	var b := _buttons.get_node_or_null("Btn_" + id)
	if b == null:
		return false
	(b as Button).emit_signal("pressed")
	return true


func title_text() -> String:
	return _title.text if _title != null else ""


## 面板矩形（测试与像素断言用来验证"弹窗确实居中"）
func panel_rect() -> Rect2:
	return _root.get_global_rect() if _root != null else Rect2()


func total_text() -> String:
	return _total.text if _total != null else ""
