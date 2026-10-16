class_name ObjectivePanel
extends VBoxContainer
## 任务面板（01 §9 objective_panel）：胜利/失败条件逐条列出、进度（剩余时间、威胁已清除）、关键对象生命。

var controller: BattleController = null
var level: LevelDefinition = null
var _progress: Label


const SKIN: String = "battle_hud"


func setup(p_controller: BattleController, p_level: LevelDefinition) -> void:
	controller = p_controller
	level = p_level
	if not UiKit.ui_layout(SKIN).is_empty():
		_build_skinned()
		return
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label(level.objective_text, "TitleLabel", true))
	add_child(UiKit.label(DataRegistry.get_string("ui.objective_win_header"), ""))
	for o: ObjectiveDef in level.win:
		var l: Label = UiKit.label("· " + RuleText.objective_sentence(o, level), "", true)
		l.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
		add_child(l)
	add_child(UiKit.label(DataRegistry.get_string("ui.objective_lose_header"), ""))
	for o: ObjectiveDef in level.lose:
		var l: Label = UiKit.label("· " + RuleText.objective_sentence(o, level), "", true)
		l.add_theme_color_override("font_color", Palette.WARN_RED)
		add_child(l)
	_progress = UiKit.label("", "", true)
	add_child(_progress)


## P6 批准整图 ui_06 的版式：任务句（金）→ 胜利条件标题 → 每条一个圆角框 → 失败条件标题（红）→ 每条一个框 → 进度；
## 行距、框高、框内文字缩进全部取自布局（obj_text / obj_win_header / obj_box / obj_box_text / obj_lose_header / obj_box2）
func _build_skinned() -> void:
	add_theme_constant_override("separation", 0)
	var d := UiKit.design_size(SKIN)
	var r := func(id: String) -> Rect2: return UiKit.layout_rect(SKIN, id, d)
	var text: Rect2 = r.call("obj_text")
	var win_h: Rect2 = r.call("obj_win_header")
	var box: Rect2 = r.call("obj_box")
	var box_text: Rect2 = r.call("obj_box_text")
	var lose_h: Rect2 = r.call("obj_lose_header")
	var box_gap: float = float(((UiKit.layout_element(SKIN, "obj_box").get("data", {}) as Dictionary).get("box_gap_ref", 0.0))) * d.y / 941.0
	var t: Label = _skin_label(level.objective_text, "obj_text", true)
	add_child(t)
	_gap(win_h.position.y - text.end.y)
	add_child(_indented(_skin_label(DataRegistry.get_string("ui.objective_win_header"), "obj_win_header", false), win_h.position.x - text.position.x))
	_gap(box.position.y - win_h.end.y)
	_boxes(level.win, box, box_text, box_gap)
	_gap(lose_h.position.y - box.end.y)
	add_child(_indented(_skin_label(DataRegistry.get_string("ui.objective_lose_header"), "obj_lose_header", false), lose_h.position.x - text.position.x))
	_gap(box.position.y - win_h.end.y)
	_boxes(level.lose, box, box_text, box_gap)
	_progress = _skin_label("", "obj_box_text", true)
	add_child(_progress)


func _skin_label(text: String, id: String, wrap_lines: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	if wrap_lines:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	return l


## 标题各自的左缩进（整图里两行标题的字形左缘略有不同）
func _indented(c: Control, dx: float) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(round(dx)))
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_child(c)
	return m


func _gap(h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, maxf(h, 0.0))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(g)


## 每条条件一个圆角框（obj_box 样式，最小高 = 整图框高），框内文字按整图缩进、竖直居中，长句换行
func _boxes(list: Array[ObjectiveDef], box: Rect2, box_text: Rect2, gap: float) -> void:
	for i: int in list.size():
		if i > 0:
			_gap(gap)
		var panel := PanelContainer.new()
		panel.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "obj_box").get("theme_type", "")))
		panel.custom_minimum_size = Vector2(0.0, box.size.y)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", int(box_text.position.x - box.position.x))
		m.add_theme_constant_override("margin_right", int(box_text.position.x - box.position.x))
		m.mouse_filter = Control.MOUSE_FILTER_PASS
		var l: Label = _skin_label(RuleText.objective_sentence(list[i], level), "obj_box_text", true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.add_child(l)
		panel.add_child(m)
		add_child(panel)


func _process(_delta: float) -> void:
	if controller == null or controller.world == null:
		return
	_progress.text = progress_text(controller.world, level)


## 生存目标的剩余秒数；无生存目标返回 -1
static func survive_time_left(world: SimWorld, p_level: LevelDefinition) -> float:
	for o: ObjectiveDef in p_level.win:
		if o.type == SimTypes.ObjectiveType.SURVIVE:
			return maxf(0.0, o.seconds - world.clock.time)
	return -1.0


## 进度文案（任务面板与顶栏共用）：剩余时间 / 威胁已清除 / 保护对象生命
static func progress_text(world: SimWorld, p_level: LevelDefinition, include_time: bool = true) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for o: ObjectiveDef in p_level.win:
		if o.type == SimTypes.ObjectiveType.SURVIVE:
			if include_time:
				lines.append(DataRegistry.get_string("ui.time_left").format({ "seconds": "%.1f" % maxf(0.0, o.seconds - world.clock.time) }))
			var p: SimUnit = world.get_spawn(o.target)
			if p != null:
				lines.append(DataRegistry.get_string("ui.target_hp").format({
					"name": RuleText.spawn_name(p_level, o.target), "hp": RuleText.num(maxf(p.hp, 0.0)), "max": RuleText.num(p.max_hp) }))
			if world.clock.steps > 0 and ObjectiveSystem.enemies_cleared(world):
				lines.append(DataRegistry.get_string("ui.threat_cleared"))
	return "\n".join(lines)
