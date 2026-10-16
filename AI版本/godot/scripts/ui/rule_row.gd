class_name RuleRow
extends PanelContainer
## 指令行（10 §5.3，行为在上、条件在下）；第四阶段按侧栏批准整图（assets/ui/side_detail/design.png）换皮（布局 side_detail 的 det_* 元素，位置相对 det_row1）：
##   [⠿] 优先级 N  [☐] 覆盖                                   [删除]
##   行为 [行为 ▾] [参数一 ▾] [参数二 ▾]
##   条件一 [▾ 条件] [参数 ▾] 单位
##                 ───────── ∧ / ∨ ─────────           ← 与 / 或切换（10 §5.3：仅两条件时可切换，分隔线恒在）
##                 条件二 [▾ 条件]                      ← 条件二默认「无」，选了才存在
##                 运行中：为何不成立 / 等待剩余
## 参数：需要目标 = 目标选择 / 目标类型；沿信标 = 模式 / 起点；沿路线 = 路线（占两格）；等待 = 「持续时间 [秒数] 秒」（整图第二行版式）。
## 条件带参数（生命低于 %、目标距离、到达信标）时下拉变窄，参数在右（整图第二行版式）。
## 无启用勾选（10 §5.2：UI 写出 enabled 恒为 true）。target_distance 需要目标而行为无目标时，目标选择放在行为行的参数格。
## 敌人只读面板同布局，条件可多于两条，按条件行距向下排、行高随之增加。运行中当前生效行金边高亮；拖拽排序。

const HANDLE_GLYPH: String = "≡"
const NONE_KEY: String = ""              ## 条件二「无」
const UI_MAX_CONDITIONS: int = 2         ## 10 §5.2：玩家编辑的条件 ≤ 2
const OPTION_MIN_WIDTH: float = 64.0     ## 下拉不按最长项撑宽（侧栏固定 520，08 ⑥），文字过长时省略
const SKIN: String = DetailKit.SKIN

var editor: RuleEditor = null
var index: int = 0
var rule: RuleDef = null

var _action: OptionButton
var _selector: OptionButton
var _filter: OptionButton
var _mode: OptionButton
var _from: OptionButton
var _seconds: SpinBox
var _route: OptionButton
var _override: TextureButton            ## 第四阶段「覆盖」勾选（条件成立时无视上方非覆盖指令的优先级）
var _delete: Button
var _logic: Button                       ## 与 / 或切换
var _cond_options: Array[OptionButton] = []   ## 每个条件行的类型下拉（条件一、条件二…）
var _controls: Array[Control] = []       ## 编辑控件（只读 / 运行中统一禁用）
var _sentence: Label
var _why: Button
var _reason: Label
var _active: bool = false
var _fail_reason: int = -1
var _note: String = ""
var _body: Control                       ## 行内容（绝对定位）
var _highlight: Panel                    ## 运行中生效行的金边
var _content_h: float = 0.0              ## 条件区底（不含运行原因行）


## 布局元素相对行框（det_row1；row2 版式取自 det_row2）的矩形，设计像素
static func rel(id: String, row_id: String = "det_row1") -> Rect2:
	var d: Vector2 = UiKit.design_size(SKIN)
	var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
	var r: Rect2 = UiKit.layout_text_rect(SKIN, id, d) if text else UiKit.layout_rect(SKIN, id, d)
	return Rect2(r.position - UiKit.layout_rect(SKIN, row_id, d).position, r.size)


static func tt(id: String) -> StringName:
	return StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))


func setup(p_editor: RuleEditor, p_index: int, p_rule: RuleDef) -> void:
	editor = p_editor
	index = p_index
	rule = p_rule
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = tt("det_row1")
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_body)
	_highlight = Panel.new()
	var hl := StyleBoxFlat.new()
	hl.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	hl.border_color = Palette.ALCHEMY_GOLD
	hl.set_border_width_all(2)
	hl.set_corner_radius_all(6)
	_highlight.add_theme_stylebox_override("panel", hl)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.visible = false
	_build_action_line()
	var conds: Array[ConditionDef] = rule.conditions
	var shown: int = maxi(conds.size(), 1)
	if not editor.read_only:
		shown = UI_MAX_CONDITIONS          # 玩家行恒显示条件一、条件二（二默认「无」）
	for k: int in shown:
		_build_condition_line(k, conds[k] if k < conds.size() else null)
	_sentence = UiKit.label(RuleText.rule_sentence(rule, editor.level), "", true)
	_sentence.visible = false            # 整图不显示整句（保留供拖拽预览与测试）
	_body.add_child(_sentence)
	_why = Button.new()
	_why.text = DataRegistry.get_string("ui.why_not")
	_why.toggle_mode = true
	_why.flat = true
	_why.toggled.connect(func(on: bool) -> void:
		_reason.visible = on
		_layout_height())
	_body.add_child(_why)
	_reason = Label.new()
	_reason.theme_type_variation = tt("det_c1_label")
	_reason.clip_text = true             # 原因短句一行（换行后的高度要到下一帧才确定，会把行撑高）
	_reason.add_theme_color_override("font_color", Palette.WARN_RED)
	_body.add_child(_reason)
	var c1l: Rect2 = rel("det_c1_label")
	_why.theme_type_variation = tt("det_c1_label")
	_why.size = Vector2(c1l.size.x * 1.6, c1l.size.y)
	_body.add_child(_highlight)
	var editable: bool = editor.editable()
	if _logic != null and bool(_logic.get_meta(&"single", false)):
		_logic.disabled = true
		_logic.add_theme_color_override("font_disabled_color", _logic.get_theme_color("font_color"))
		_controls.erase(_logic)
	_override.visible = not editor.read_only or rule.override        # 敌人只读：只在勾选时显示
	for ctl: Control in _controls:
		if ctl is BaseButton:
			(ctl as BaseButton).disabled = not editable
		elif ctl is SpinBox:
			(ctl as SpinBox).editable = editable
	_apply_runtime()


func _place(c: Control, r: Rect2) -> Control:
	_body.add_child(c)         # 先入树再定尺寸：入树前按默认主题算最小尺寸（下拉高 51），先设尺寸会被撑大且之后不回缩
	c.position = r.position
	c.size = r.size
	return c


func _text(text: String, id: String, r: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = tt(id)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(l, r)
	return l


# ---- 行为行 ----
func _build_action_line() -> void:
	var handle := TextureRect.new()
	handle.texture = load(str(UiKit.layout_element(SKIN, "det_handle").get("file", ""))) as Texture2D
	handle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	handle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.visible = not editor.read_only
	_place(handle, rel("det_handle"))
	_text(DataRegistry.get_string("ui.rule_priority").format({ "n": index + 1 }), "det_prio", rel("det_prio"))
	_override = UiKit.node_for(UiKit.layout_element(SKIN, "det_override")) as TextureButton
	_override.name = "OverrideToggle"
	_override.toggle_mode = true
	_override.set_pressed_no_signal(rule.override)
	_override.tooltip_text = DataRegistry.get_string("ui.rule_override_tip")
	_override.focus_mode = Control.FOCUS_NONE
	_override.toggled.connect(_on_override)
	_place(_override, rel("det_override"))
	_controls.append(_override)
	var ovl: Label = _text(DataRegistry.get_string("ui.rule_override"), "det_override_label", rel("det_override_label"))
	ovl.mouse_filter = Control.MOUSE_FILTER_STOP              # 点文字也能切换
	ovl.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _override.disabled:
			_override.button_pressed = not _override.button_pressed)
	_text(DataRegistry.get_string("ui.rule_action_label"), "det_act_label", rel("det_act_label"))
	var act_key: String = SimTypes.action_to_string(rule.action.type)
	_action = _option(editor.action_items(act_key), act_key, _on_action, "det_action")
	_place(_action, rel("det_action"))
	var t: int = rule.action.type
	if rule.action.needs_target() or (rule.has_condition(SimTypes.ConditionType.TARGET_DISTANCE) and t != SimTypes.ActionType.FOLLOW_BEACONS and t != SimTypes.ActionType.WAIT and t != SimTypes.ActionType.FOLLOW_ROUTE):
		_add_target_options()
	elif t == SimTypes.ActionType.FOLLOW_BEACONS:
		_mode = _option(editor.beacon_mode_items(), SimTypes.beacon_mode_to_string(rule.action.mode), _on_mode, "det_p1")
		_place(_mode, rel("det_p1"))
		_from = _option(editor.beacon_items(rule.action.from), rule.action.from, _on_from, "det_p2")
		_place(_from, rel("det_p2"))
	elif t == SimTypes.ActionType.WAIT:
		_text(DataRegistry.get_string("ui.wait_duration"), "det_wait_label", rel("det_wait_label"))
		_seconds = _spin(SimTypes.WAIT_MIN_SECONDS, SimTypes.WAIT_MAX_SECONDS, SimTypes.WAIT_MIN_SECONDS, "", "det_wait_box")
		_seconds.set_value_no_signal(rule.action.seconds)
		_seconds.value_changed.connect(_on_seconds)
		_place(_seconds, rel("det_wait_box"))
		_text(DataRegistry.get_string("ui.seconds_unit"), "det_wait_unit", rel("det_wait_unit"))
	elif t == SimTypes.ActionType.FOLLOW_ROUTE:
		_route = _option(editor.route_items(), rule.action.route_id, _on_route, "det_p1")
		_place(_route, rel("det_p1").merge(rel("det_p2")))
	_delete = Button.new()
	_delete.text = DataRegistry.get_string("ui.delete_rule")
	_delete.tooltip_text = DataRegistry.get_string("ui.delete_rule_tip")
	_delete.theme_type_variation = tt("det_delete")
	_delete.focus_mode = Control.FOCUS_NONE
	_delete.pressed.connect(func() -> void: editor.delete_rule(index))
	_delete.visible = not editor.read_only and editor.editable()     # 战斗中不可编辑：不显示删除（批准整图 ui_13）
	_place(_delete, rel("det_delete"))
	_controls.append(_delete)


## 目标选择 + 目标类型（参数一 / 参数二格）
func _add_target_options() -> void:
	var sel_key: String = SimTypes.selector_to_string(rule.target.selector) if rule.target != null else ""
	var fil_key: String = SimTypes.filter_to_string(rule.target.filter) if rule.target != null else ""
	_selector = _option(editor.selector_items(sel_key), sel_key, _on_selector, "det_p1")
	_place(_selector, rel("det_p1"))
	_filter = _option(editor.filter_items(fil_key), fil_key, _on_filter, "det_p2")
	_place(_filter, rel("det_p2"))


# ---- 条件行：第 k 条（k ≥ 1 时上方为与 / 或分隔）----
func _build_condition_line(k: int, c: ConditionDef) -> void:
	var pitch: float = rel("det_c2").position.y - rel("det_c1").position.y
	var dy: float = pitch * k
	if k >= 1:
		for lid: String in ["det_logic_line_l", "det_logic_line_r"]:     # 两条件之间的分隔线（1 px，颜色取布局）
			var line := ColorRect.new()
			line.color = Color(str((UiKit.layout_element(SKIN, lid).get("style", {}) as Dictionary).get("bg", "#FFFFFF")))
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_place(line, _shift(rel(lid), dy - pitch))
		var glyph: String = DataRegistry.get_string("ui.logic_or_glyph" if rule.condition_mode == SimTypes.ConditionMode.ANY else "ui.logic_and_glyph")
		if k == 1:
			_logic = Button.new()
			_logic.text = glyph
			_logic.tooltip_text = DataRegistry.get_string("ui.logic_or" if rule.condition_mode == SimTypes.ConditionMode.ANY else "ui.logic_and")
			_logic.theme_type_variation = tt("det_logic")
			_logic.focus_mode = Control.FOCUS_NONE
			_logic.visible = true                                 # 侧栏整图：分隔处恒显示 ∧ / ∨；只有一个条件时不可切换
			_logic.set_meta(&"single", rule.conditions.size() < 2)
			_logic.pressed.connect(_on_logic)
			_place(_logic, _shift(rel("det_logic"), dy - pitch))
			_controls.append(_logic)
		else:
			_text(glyph, "det_logic", _shift(rel("det_logic"), dy - pitch)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title: String = DataRegistry.get_string("ui.condition_n").format({ "n": k + 1 })
	if k == 0:
		title = DataRegistry.get_string("ui.condition_one")
	elif k == 1:
		title = DataRegistry.get_string("ui.condition_two")
	_text(title, "det_c1_label", _shift(rel("det_c1_label"), dy))
	var key: String = SimTypes.condition_to_string(c.type) if c != null else ("always" if k == 0 else NONE_KEY)
	var items: Array = editor.condition_items(key if key != NONE_KEY else "")
	if k >= 1 and not editor.read_only:
		items.push_front([DataRegistry.get_string("ui.condition_none"), NONE_KEY])
	var has_param: bool = c != null and c.type in [SimTypes.ConditionType.SELF_HP_BELOW, SimTypes.ConditionType.TARGET_DISTANCE, SimTypes.ConditionType.AT_BEACON, SimTypes.ConditionType.SIGNAL_IS]
	var opt: OptionButton = _option(items, key, _on_cond.bind(k), "det_c1")
	_place(opt, _shift(rel("det_c1_narrow", "det_row2"), dy, rel("det_c1").position.y) if has_param else _shift(rel("det_c1"), dy))
	_cond_options.append(opt)
	_content_h = maxf(_content_h, opt.position.y + opt.size.y)
	if c == null:
		return
	var prm: Rect2 = _shift(rel("det_cparam", "det_row2"), dy, rel("det_c1").position.y)
	var unit: Rect2 = _shift(rel("det_cunit", "det_row2"), dy, rel("det_c1").position.y)
	match c.type:
		SimTypes.ConditionType.SELF_HP_BELOW:
			var ratio: SpinBox = _spin(1.0, 99.0, 1.0, "", "det_cparam")
			ratio.set_value_no_signal(round(c.ratio * 100.0))
			ratio.value_changed.connect(_on_ratio.bind(k))
			_place(ratio, prm)
			_text("%", "det_cunit", unit)
		SimTypes.ConditionType.TARGET_DISTANCE:
			# 第四阶段（侧栏批准整图）：比较与距离合成一个下拉「< 3」，右侧单位「格」
			var dist: OptionButton = _option(editor.distance_items(c.op, c.value), RuleEditor.distance_key(c.op, c.value), Callable(), "det_cparam")
			dist.item_selected.connect(_on_distance.bind(k, dist))
			_place(dist, prm)
			_text(DataRegistry.get_string("ui.distance_unit"), "det_cunit", unit)
		SimTypes.ConditionType.AT_BEACON:
			var beacon: OptionButton = _option(editor.beacon_items(c.beacon), c.beacon, Callable(), "det_cparam")
			beacon.item_selected.connect(_on_beacon.bind(k, beacon))
			_place(beacon, prm)
		SimTypes.ConditionType.SIGNAL_IS:
			var sig_items: Array = []
			for sig: String in ["red", "yellow", "blue"]:
				sig_items.append([DataRegistry.get_string("names.signals." + sig), sig])
			var sig_opt: OptionButton = _option(sig_items, c.sig, Callable(), "det_cparam")
			sig_opt.item_selected.connect(_on_signal.bind(k, sig_opt))
			_place(sig_opt, prm)


## 第 k 条条件的矩形：从第一条条件的位置下移 dy；row2 版式的元素先对齐到第一条条件的高度（base_y）
func _shift(r: Rect2, dy: float, base_y: float = NAN) -> Rect2:
	if not is_nan(base_y):
		var c1n: Rect2 = rel("det_c1_narrow", "det_row2")
		r.position.y += base_y - c1n.position.y
	return Rect2(r.position + Vector2(0.0, dy), r.size)


func _option(items: Array, current: String, on_selected: Callable, skin_id: String = "") -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.focus_mode = Control.FOCUS_NONE
	if skin_id != "":
		o.theme_type_variation = tt(skin_id)
		o.add_theme_icon_override("arrow", UiKit.transparent_texture(Vector2i.ONE))     # 箭头已画在下拉切片上
	UiKit.fill_option(o, items, current)
	if on_selected.is_valid():
		o.item_selected.connect(on_selected)
	_controls.append(o)
	return o


func _spin(lo: float, hi: float, step: float, suffix: String, skin_id: String = "") -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.suffix = suffix
	if skin_id != "":         # 数值框按整图画成下拉样式：输入框用下拉切片作底（右侧箭头在切片上），上下调节按钮透明但仍可点
		var le: LineEdit = sb.get_line_edit()
		var ttype: StringName = tt(skin_id)
		var th: Theme = UiKit.ui_theme(SKIN)
		for st: String in ["normal", "focus", "read_only"]:
			le.add_theme_stylebox_override(st, th.get_stylebox("normal", ttype))
		le.add_theme_font_override("font", th.get_font("font", ttype))
		le.add_theme_font_size_override("font_size", th.get_font_size("font_size", ttype))
		le.add_theme_color_override("font_color", th.get_color("font_color", ttype))
		sb.add_theme_icon_override("updown", UiKit.transparent_texture(Vector2i(1, 1)))   # 不额外占宽（框宽 = 布局）；改值用滚轮或输入
		le.expand_to_text_length = false
		le.custom_minimum_size = Vector2.ZERO
		le.add_theme_constant_override("minimum_character_width", 0)       # 否则最小宽 = 4 个字 + 边距，会把框撑宽
	_controls.append(sb)
	return sb


## 运行中状态：active = 当前生效；fail_reason ≥ 0 = 本步未成立的原因码；note = 生效行的附加说明（等待剩余秒数）
func set_runtime(active: bool, fail_reason: int, note: String = "") -> void:
	if active == _active and fail_reason == _fail_reason and note == _note:
		return
	_active = active
	_fail_reason = fail_reason
	_note = note
	_apply_runtime()


func _apply_runtime() -> void:
	_highlight.visible = _active
	_why.visible = _fail_reason >= 0
	if _fail_reason >= 0:
		_reason.text = RuleText.reason_text(_fail_reason)
		_reason.add_theme_color_override("font_color", Palette.WARN_RED)
	elif _note != "":
		_reason.text = _note
		_reason.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
		_reason.visible = true
	else:
		_why.button_pressed = false
		_reason.visible = false
	_layout_height()


## 行高 = 整图行框高（条件更多或显示运行原因时加高）
func _layout_height() -> void:
	var pad: float = rel("det_row1").size.y - rel("det_c2").end.y          # 最后一条条件到行框底的边距（整图）
	var h: float = maxf(rel("det_row1").size.y, _content_h + pad)
	if _why.visible or _reason.visible:            # 运行原因 / 等待剩余：条件区下方一行
		_why.position = Vector2(rel("det_c1_label").position.x, _content_h + 6.0)
		_reason.position = Vector2(_why.position.x + (_why.size.x if _why.visible else 0.0), _why.position.y)
		_reason.custom_minimum_size = Vector2(rel("det_delete").end.x - _reason.position.x, 0.0)     # 先定宽，换行后的高度才对
		_reason.size = Vector2(_reason.custom_minimum_size.x, 0.0)
		h = maxf(h, _reason.position.y + maxf(_reason.get_combined_minimum_size().y, _why.size.y) + pad * 0.6)
	_body.custom_minimum_size = Vector2(rel("det_row1").size.x, h)
	var inset: float = rel("det_action").position.y * 0.75      # 金边贴着切片的可见边框（切片四周有透明留白）
	_highlight.position = Vector2(inset, inset)
	_highlight.size = _body.custom_minimum_size - Vector2(inset, inset) * 2.0


# ---- 写回：克隆 → 修改 → 规整 → 提交 ----
func _commit(r: RuleDef) -> void:
	_normalize(r)
	editor.update_rule(index, r)


## 少于两条件时 condition_mode 写 all（10 §5.2）；需要目标而缺失时补默认目标；行为与条件都不需要目标时去掉目标
func _normalize(r: RuleDef) -> void:
	if r.conditions.size() < UI_MAX_CONDITIONS:
		r.condition_mode = SimTypes.ConditionMode.ALL
	var needs: bool = r.action.needs_target() or r.has_condition(SimTypes.ConditionType.TARGET_DISTANCE)
	if needs and r.target == null:
		r.target = editor.default_target()
	elif not needs:
		r.target = null


func _on_action(i: int) -> void:
	var r: RuleDef = rule.clone()
	r.action = editor.default_action(SimTypes.parse_action(UiKit.option_value(_action, i)))
	_commit(r)


## 条件 k 改选：条件一选「始终」= 无条件（有条件二时保留为 always 占位）；条件二选「无」= 删除第二条件
func _on_cond(i: int, k: int) -> void:
	var r: RuleDef = rule.clone()
	var key: String = UiKit.option_value(_cond_options[k], i)
	if k == 0:
		var t: int = SimTypes.parse_condition(key)
		if r.conditions.is_empty():
			if t != SimTypes.ConditionType.ALWAYS:
				r.conditions.append(editor.default_condition(t))
		else:
			r.conditions[0] = editor.default_condition(t)
			if t == SimTypes.ConditionType.ALWAYS and r.conditions.size() == 1:
				r.conditions.clear()
	elif key == NONE_KEY:
		if r.conditions.size() > k:
			r.conditions.remove_at(k)
		if r.conditions.size() == 1 and r.conditions[0].type == SimTypes.ConditionType.ALWAYS:
			r.conditions.clear()
	else:
		var c: ConditionDef = editor.default_condition(SimTypes.parse_condition(key))
		if r.conditions.is_empty():
			r.conditions.append(editor.default_condition(SimTypes.ConditionType.ALWAYS))
		if r.conditions.size() > k:
			r.conditions[k] = c
		else:
			r.conditions.append(c)
	_commit(r)


func _on_override(on: bool) -> void:
	var r: RuleDef = rule.clone()
	r.override = on
	_commit(r)


func _on_logic() -> void:
	var r: RuleDef = rule.clone()
	r.condition_mode = SimTypes.ConditionMode.ALL if r.condition_mode == SimTypes.ConditionMode.ANY else SimTypes.ConditionMode.ANY
	_commit(r)


func _on_ratio(v: float, k: int) -> void:
	var r: RuleDef = rule.clone()
	r.conditions[k].ratio = v / 100.0
	_commit(r)


func _on_distance(i: int, k: int, opt: OptionButton) -> void:
	var parts: PackedStringArray = UiKit.option_value(opt, i).split("|")
	var r: RuleDef = rule.clone()
	r.conditions[k].op = parts[0]
	r.conditions[k].value = float(parts[1])
	_commit(r)


func _on_beacon(i: int, k: int, opt: OptionButton) -> void:
	var r: RuleDef = rule.clone()
	r.conditions[k].beacon = UiKit.option_value(opt, i)
	_commit(r)


func _on_signal(i: int, k: int, opt: OptionButton) -> void:
	var r: RuleDef = rule.clone()
	r.conditions[k].sig = UiKit.option_value(opt, i)
	_commit(r)


func _on_selector(i: int) -> void:
	var r: RuleDef = rule.clone()
	if r.target == null:
		r.target = editor.default_target()
	r.target.selector = SimTypes.parse_selector(UiKit.option_value(_selector, i))
	_commit(r)


func _on_filter(i: int) -> void:
	var r: RuleDef = rule.clone()
	if r.target == null:
		r.target = editor.default_target()
	r.target.filter = SimTypes.parse_filter(UiKit.option_value(_filter, i))
	_commit(r)


func _on_mode(i: int) -> void:
	var r: RuleDef = rule.clone()
	r.action.mode = SimTypes.parse_beacon_mode(UiKit.option_value(_mode, i))
	_commit(r)


func _on_from(i: int) -> void:
	var r: RuleDef = rule.clone()
	r.action.from = UiKit.option_value(_from, i)
	_commit(r)


func _on_seconds(v: float) -> void:
	var r: RuleDef = rule.clone()
	r.action.seconds = v
	_commit(r)


func _on_route(i: int) -> void:
	var r: RuleDef = rule.clone()
	r.action.route_id = UiKit.option_value(_route, i)
	_commit(r)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not editor.editable() or editor.read_only:
		return null
	var preview: Label = UiKit.label(_sentence.text)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.7)
	set_drag_preview(preview)
	return { "rule_from": index, "editor": editor.get_instance_id() }


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var d: Dictionary = data as Dictionary
	return d.has("rule_from") and int(d.get("editor", 0)) == editor.get_instance_id() and editor.editable()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	editor.move_rule(int((data as Dictionary)["rule_from"]), index)
