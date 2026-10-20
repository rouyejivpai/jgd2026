class_name HintPanel
extends Control
## 分层提示与「推荐阵型」（01 §9 hint_panel、07 §2）：
## - 每次按提示按钮多显示一层（已看层数存档）；
## - 第 4 层看过之后按钮变为「推荐阵型」，按下后列出全部提示并请求确认，确认后由 BattleController
##   用 recommended.units 覆盖部署与指令并校验；"已使用"记入存档，重置不清除。部署阶段与 Boss 换阶段暂停（recommended.phase2）可确认。
## 连点保护（A02）：两次揭示新层之间至少间隔 REVEAL_GUARD_MS，避免一次双击消耗两层提示。
## 第三阶段 P6 按批准整图 ui_08（提示）/ ui_09（推荐阵型确认）换皮：modal_panel 框体、标题、描边「关闭」、分隔线；
## 提示逐条换行、段距取自整图；提示态下方为已看层数圆点（金 = 已看、紫 = 未看）；确认态为分隔线 + 金色确认句 + 「摆放」「取消」。
## 宽与左右取自整图，高度随内容，竖直居中于 HUD 让出的战场带；超出可用高度时提示列表上下滚动。
## 位置全部取自 data/ui_layout/battle_hud.json 的 hint_* / rec_* 元素。
## 音效：揭示新层 hint_open（AudioManager 听 hint_requested）；「摆放」成功 formation_apply、失败 ui_error；「关闭」ui_panel_close、「取消」ui_back。

signal state_changed()                    ## 已看层数 / 推荐阵型可用性变化 → HUD 刷新按钮文字
signal recommended_applied(problems: Array)

const REVEAL_GUARD_MS: int = 350

var level: LevelDefinition = null
var controller: BattleController = null
var _list: VBoxContainer
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _apply_button: Button
var _last_reveal_ms: int = -REVEAL_GUARD_MS
var _dots: HBoxContainer
var _list_scroll: ScrollText
var _skin: Dictionary = {}               ## 元素 id → 节点（标题、关闭、分隔线、确认区各件）

const SKIN: String = "battle_hud"


func setup(p_level: LevelDefinition, p_controller: BattleController) -> void:
	level = p_level
	controller = p_controller
	theme = UiKit.ui_theme(SKIN)
	var bg: Control = UiKit.node_for(UiKit.layout_element(SKIN, "hint_panel"))
	bg.name = "Skin_hint_panel"
	_add("hint_panel", bg)
	var title: Label = _label(DataRegistry.get_string("ui.hint"), "hint_title", false)
	title.clip_text = true
	_add("hint_title", title)
	var close: Button = UiKit.node_for(UiKit.layout_element(SKIN, "hint_close")) as Button
	close.text = DataRegistry.get_string("ui.close")
	close.focus_mode = Control.FOCUS_NONE
	close.set_meta(&"sfx_press", "ui_panel_close")
	close.pressed.connect(close_panel)
	_add("hint_close", close)
	_add("hint_sep", UiKit.node_for(UiKit.layout_element(SKIN, "hint_sep")))
	_list = VBoxContainer.new()
	_list.name = "HintList"
	_list.add_theme_constant_override("separation", int(round(_paragraph_gap())))
	_list.minimum_size_changed.connect(func() -> void: _layout_skin.call_deferred())     # 换行后行高变化时重新量高
	_add("hint_list", _list)
	_dots = HBoxContainer.new()
	_dots.name = "HintDots"
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var on: Rect2 = _r("hint_dot_on")
	_dots.add_theme_constant_override("separation", int(round(_r("hint_dot_off").position.x - on.end.x)))
	_add("hint_dots", _dots)
	_confirm_box = VBoxContainer.new()
	_confirm_box.name = "ConfirmBox"
	_confirm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add("rec_box", _confirm_box)
	_add("rec_sep", UiKit.node_for(UiKit.layout_element(SKIN, "rec_sep")))
	_confirm_label = _label("", "rec_confirm", true)
	_add("rec_confirm", _confirm_label)
	_apply_button = UiKit.node_for(UiKit.layout_element(SKIN, "rec_apply")) as Button
	_apply_button.text = DataRegistry.get_string("ui.recommend_apply")
	_apply_button.focus_mode = Control.FOCUS_NONE
	_apply_button.set_meta(&"sfx_press", "")
	_apply_button.pressed.connect(func() -> void:
		AudioManager.play_sfx("formation_apply" if confirm_recommended() else "ui_error", "UI"))
	_add("rec_apply", _apply_button)
	var cancel: Button = UiKit.node_for(UiKit.layout_element(SKIN, "rec_cancel")) as Button
	cancel.text = DataRegistry.get_string("ui.cancel")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.set_meta(&"sfx_press", "ui_back")
	cancel.pressed.connect(close_panel)
	_add("rec_cancel", cancel)
	ScrollText.wrap(title, ScrollText.Mode.AUTO, Rect2(Vector2.ZERO, Vector2.ONE))
	_skin["hint_title"] = title.get_parent()
	_list_scroll = ScrollText.wrap_box(_list, ScrollText.Mode.MANUAL, Rect2(Vector2.ZERO, Vector2.ONE))
	_skin["hint_list"] = _list_scroll
	_confirm_box.visible = false
	visible = false
	EventBus.battle_phase_changed.connect(func(_p: int) -> void: _refresh_confirm())


## 布局元素在设计坐标下的矩形（文字元素取文字区）
func _r(id: String) -> Rect2:
	var d: Vector2 = UiKit.design_size(SKIN)
	return UiKit.layout_text_rect(SKIN, id, d) if str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style" else UiKit.layout_rect(SKIN, id, d)


func _add(id: String, c: Control) -> void:
	add_child(c)
	_skin[id] = c


func _label(text: String, id: String, wrap_lines: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	if wrap_lines:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(_r("hint_line").size.x, 0.0)
	return l


## 段距 = 整图里第 1、2 条提示的顶差 − 实际一行高（提示态取 ui_08，确认态取 ui_09）；行高按 Godot 实际字体度量
func _paragraph_gap(confirm: bool = false) -> float:
	var a: Rect2 = _r("rec_hint1" if confirm else "hint_line")
	var line_h: float = a.size.y
	if _list != null and _list.get_child_count() > 0:
		var first: Label = _list.get_child(0) as Label
		line_h = first.get_combined_minimum_size().y / maxf(float(first.get_line_count()), 1.0)    # 实际行高（含行距）
	return _r("rec_hint2" if confirm else "hint_line2").position.y - a.position.y - line_h


func _title_label() -> Label:
	return (_skin["hint_title"] as ScrollText).label


func seen() -> int:
	return SaveManager.get_hints_seen(level.id)


## 第 4 层（最后一层）提示看过之后才可用
func recommend_available() -> bool:
	return not level.hints.is_empty() and seen() >= level.hints.size() and not level.recommended_units.is_empty()


## 提示按钮文字（P6 用户 2026-10-06：按钮上只显示「提示」，不显示已看层数）；看完全部提示后为「推荐阵型」
func button_text() -> String:
	if recommend_available():
		return DataRegistry.get_string("ui.recommend_formation")
	return DataRegistry.get_string("ui.hint")


## 提示按钮：未看完则揭示下一层；看完则打开推荐阵型确认
func press() -> void:
	if recommend_available():
		open_recommend()
	else:
		reveal_next()


func reveal_next() -> void:
	var now: int = Time.get_ticks_msec()
	var tier: int = mini(seen() + 1, level.hints.size())
	if tier > seen() and now - _last_reveal_ms >= REVEAL_GUARD_MS:
		_last_reveal_ms = now
		SaveManager.set_hints_seen(level.id, tier)
		if controller != null and controller.persist:
			SaveManager.save()
		EventBus.hint_requested.emit(tier)
		state_changed.emit()
	show_tier(seen())


## 显示前 tier 层（不改变已看层数）
func show_tier(tier: int) -> void:
	UiKit.clear(_list)
	if not _skin.is_empty():
		_title_label().text = DataRegistry.get_string("ui.hint")
	for i: int in mini(tier, level.hints.size()):
		var l: Label = _label("%d. %s" % [i + 1, level.hints[i]], "rec_hint4" if i == 3 else "hint_line", true)    # 第 4 层（推荐部署）金色
		_list.add_child(l)
	UiKit.clear(_dots)
	for i: int in level.hints.size():
		var dot: Control = UiKit.node_for(UiKit.layout_element(SKIN, "hint_dot_on" if i < seen() else "hint_dot_off"))
		dot.custom_minimum_size = _r("hint_dot_on").size
		_dots.add_child(dot)
	_confirm_box.visible = false
	_show()


func open_recommend() -> void:
	show_tier(level.hints.size())
	_confirm_box.visible = true
	_title_label().text = DataRegistry.get_string("ui.recommend_formation")
	_refresh_confirm()


## 确认摆放推荐阵型；不可用或不在部署阶段返回 false
func confirm_recommended() -> bool:
	if not recommend_available() or controller == null or not controller.apply_recommended():
		return false
	SaveManager.set_recommend_used(level.id, true)
	controller.save_config()
	if controller.persist:
		SaveManager.save()
	close_panel()
	state_changed.emit()
	recommended_applied.emit(controller.last_problems)
	return true


func close_panel() -> void:
	_confirm_box.visible = false
	visible = false


func _refresh_confirm() -> void:
	if _confirm_box == null or not _confirm_box.visible:
		return
	var deploy: bool = controller != null and controller.editing()      # 含 Boss 换阶段暂停（摆第二阶段推荐）
	_apply_button.disabled = not deploy
	_confirm_label.text = DataRegistry.get_string("ui.recommend_confirm" if deploy else "ui.recommend_deploy_only")
	if deploy:
		_confirm_label.remove_theme_color_override("font_color")        # 布局字色（整图金色）
	else:
		_confirm_label.add_theme_color_override("font_color", Palette.WARN_RED)
	_layout_skin()


func _show() -> void:
	var was_open: bool = visible
	visible = true
	_layout_skin()
	_layout_skin.call_deferred()        # 换行后的行高下一帧才确定
	if not was_open and not _skin.is_empty():
		UiKit.slide_in.call_deferred([self], Rect2())       # 浮窗：缓动滑入（矩形在下一帧布局后取）


## 高度随内容：顶部（标题 / 关闭 / 分隔线）按整图距上沿；列表；其下为圆点（提示态）或确认区（确认态，按整图距下沿）
func _layout_skin() -> void:
	if _skin.is_empty():
		return
	var panel: Rect2 = _r("hint_panel")
	var rec: Rect2 = _r("rec_panel")
	var line: Rect2 = _r("hint_line")
	var confirm: bool = _confirm_box.visible
	var list_top: float = (_r("rec_hint1").position.y - rec.position.y) if confirm else (line.position.y - panel.position.y)
	_list.add_theme_constant_override("separation", int(round(_paragraph_gap(confirm))))
	_list.size = Vector2(line.size.x, 0.0)
	var list_h: float = 0.0                 # 逐项求和（容器的最小尺寸要到下一帧才按新段距更新）
	for i: int in _list.get_child_count():
		var ch: Control = _list.get_child(i) as Control
		list_h += ceilf(maxf(ch.get_combined_minimum_size().y, ch.size.y)) + (roundf(_paragraph_gap(confirm)) if i > 0 else 0.0)   # 容器按整像素排每项；换行后的实际高
	var tail: float
	if confirm:
		tail = (rec.end.y - _r("rec_sep").position.y) + (_r("rec_sep").position.y - _r("rec_hint4").end.y)
	else:
		var dot: Rect2 = _r("hint_dot_on")
		tail = panel.end.y - dot.position.y + (dot.position.y - _r("hint_line2").end.y - line.size.y)
	var vp: Vector2 = get_viewport_rect().size
	var offset: Vector2 = UiKit.layout_rect(SKIN, "hint_panel", vp).position - panel.position        # 设计 → 视口的平移
	# 最高 = 整图 ui_09 的框高 + 一行（Godot 换行后的行距比整图略大，四层全开时约多 5 px），竖直以整图框体中心居中；更多内容时列表滚动
	var h: float = minf(list_top + list_h + tail, rec.size.y + line.size.y)
	var origin := Vector2(panel.position.x + offset.x, rec.get_center().y + offset.y - h * 0.5)
	UiKit.place(self, Rect2(origin, Vector2(panel.size.x, h)))
	var place := func(id: String, r: Rect2, from_bottom: bool, ref: Rect2) -> void:
		var y: float = h - (ref.end.y - r.position.y) if from_bottom else r.position.y - ref.position.y
		var c: Control = _skin[id] as Control
		c.position = Vector2(r.position.x - panel.position.x, y)
		c.size = r.size
	(_skin["hint_panel"] as Control).position = Vector2.ZERO
	(_skin["hint_panel"] as Control).size = Vector2(panel.size.x, h)
	for id: String in ["hint_title", "hint_close", "hint_sep"]:
		place.call(id, _r(id), false, panel)
	if confirm:            # 确认态：标题 / 关闭 / 分隔线按 ui_09 距上沿（与 ui_08 略有不同）
		place.call("hint_title", _r("rec_title"), false, rec)
	var scroll: ScrollText = _skin["hint_list"] as ScrollText
	scroll.position = Vector2(line.position.x - panel.position.x, list_top)
	scroll.size = Vector2(line.size.x, h - list_top - tail)
	_dots.visible = not confirm and not _dots.get_children().is_empty()
	var dot_r: Rect2 = _r("hint_dot_on")
	_dots.position = Vector2(dot_r.position.x - panel.position.x, h - (panel.end.y - dot_r.position.y))
	_dots.size = Vector2(line.size.x, dot_r.size.y)
	for id: String in ["rec_sep", "rec_confirm", "rec_apply", "rec_cancel"]:
		(_skin[id] as Control).visible = confirm
		place.call(id, _r(id), true, rec)
