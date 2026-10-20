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
## 2026-10-20 刻印界面（02.zip F02–F04，参考图 刻印.png）：一条指令 = 一条底纹（F02），上排 [行为][参数一][参数二]｜[条件一][条件二] 五个框
## （F03 / F04：有内容的是亮框、用不到的参数格是暗框带星芒），下排（底纹下半的纹饰里）= 运行原因、「且 / 或」；删除是行为框左边的小图标，不显示「优先级 N」；
## 「行为 / 条件1 / 条件2」列标题画在面板底图上（每行不再带标签），没有拖拽柄（整行可拖）。条件带参数时参数叠在条件框右端（无框）。
## 音效：删除 / 条件二选「无」rule_remove，与 / 或切换 ui_toggle（与 0.9、或 1.1 音高），拖起 ui_drag_pick、放下 ui_drag_drop，
## 拖到别组的行上被拒 ui_error、拖出后没被接收 drag_cancel。运行中生效行高亮切换太频繁，不配音。

const HANDLE_GLYPH: String = "≡"
const NONE_KEY: String = ""              ## 条件二「无」
const UI_MAX_CONDITIONS: int = 2         ## 10 §5.2：玩家编辑的条件 ≤ 2
const OPTION_MIN_WIDTH: float = 64.0     ## 下拉不按最长项撑宽（侧栏固定 520，08 ⑥），文字过长时省略
const SLOT_OFF: Texture2D = preload("res://assets/ui/gothic/cmd_act_off.png")     ## 用不到的参数格（暗框带星芒）
const DELETE_ICON: Texture2D = preload("res://assets/ui/gothic/cmd_delete.png")
const LOGIC_AND: Texture2D = preload("res://assets/ui/gothic/cmd_logic_and.png")     ## 与 / 或标志（韦恩图：交集亮 = 与，并集亮 = 或），摆在条件框之间
const LOGIC_OR: Texture2D = preload("res://assets/ui/gothic/cmd_logic_or.png")
const REASON_EXTRA: float = 20.0         ## 运行中有「为何不成立」/ 等待剩余时，行下方多出的一行
const EXTRA_COND_PITCH: float = 52.0     ## 敌人条件多于两条时，第 3 条起每两条一排的行距
const SKIN: String = DetailKit.SKIN

var editor: RuleEditor = null
var index: int = 0
var order: int = -1                      ## 第五阶段：组内序号（显示「优先级 N」）；-1 = 用列表下标
var rule: RuleDef = null

var _action: OptionButton
var _selector: OptionButton
var _filter: OptionButton
var _mode: OptionButton
var _from: OptionButton
var _seconds: SpinBox
var _route: OptionButton
var _override: TextureButton            ## 第四阶段「覆盖」勾选（条件成立时无视上方非覆盖指令的优先级）；第五阶段起玩家行不显示
var _override_label: Label
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
var _low_dy: float = 0.0                 ## 条件多于两条时下排（优先级 / 逻辑 / 删除）下移的距离
var _dragging: bool = false              ## 从本行拖起的拖拽进行中


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
	var conds: Array[ConditionDef] = rule.conditions
	var shown: int = maxi(conds.size(), 1)
	if not editor.read_only:
		shown = UI_MAX_CONDITIONS          # 玩家行恒显示条件一、条件二（二默认「无」）
	_low_dy = EXTRA_COND_PITCH * ceilf(maxf(shown - UI_MAX_CONDITIONS, 0.0) / 2.0)
	_build_action_line()
	for k: int in shown:
		_build_condition_line(k, conds[k] if k < conds.size() else null)
	if _logic != null:
		_body.move_child(_logic, -1)               # 与 / 或标志压在两个条件框之上
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
	_why.theme_type_variation = tt("det_c1_label")
	_why.add_theme_font_size_override("font_size", 14)
	_reason.add_theme_font_size_override("font_size", 14)
	_why.size = Vector2(74.0, 18.0)
	_body.add_child(_highlight)
	var editable: bool = editor.editable()
	if _logic != null and bool(_logic.get_meta(&"single", false)):
		_logic.disabled = true
		_logic.add_theme_color_override("font_disabled_color", _logic.get_theme_color("font_color"))
		_controls.erase(_logic)
	_override.visible = editor.read_only and rule.override           # 第五阶段：玩家不再有「覆盖」（组内优先级即覆盖）；敌人只读面板只在旧数据勾选时显示
	_override_label.visible = _override.visible
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
	var low := Vector2(0.0, _low_dy)
	_override = UiKit.node_for(UiKit.layout_element(SKIN, "det_override")) as TextureButton
	_override.name = "OverrideToggle"
	_override.toggle_mode = true
	_override.set_pressed_no_signal(rule.override)
	_override.tooltip_text = DataRegistry.get_string("ui.rule_override_tip")
	_override.focus_mode = Control.FOCUS_NONE
	_override.toggled.connect(_on_override)
	_place(_override, _moved(rel("det_override"), low))
	var ovl: Label = _text(DataRegistry.get_string("ui.rule_override"), "det_override_label", _moved(rel("det_override_label"), low))
	_override_label = ovl
	ovl.mouse_filter = Control.MOUSE_FILTER_STOP              # 点文字也能切换
	ovl.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _override.disabled:
			AudioManager.play_sfx("ui_toggle", "UI")        # 代码改 button_pressed 不触发按钮的自动点击音
			_override.button_pressed = not _override.button_pressed)
	var act_key: String = SimTypes.action_to_string(rule.action.type)
	_action = _option(editor.action_items(act_key), act_key, _on_action, "det_action")
	_action.name = "RuleAction"                # 固定名字供引导 / 配置器拾取（如 Group_attack/RuleAction）
	_place(_action, rel("det_action"))
	var t: int = rule.action.type
	var p1_used: bool = true
	var p2_used: bool = true
	if rule.action.needs_target() or (rule.has_condition(SimTypes.ConditionType.TARGET_DISTANCE) and t != SimTypes.ActionType.FOLLOW_BEACONS and t != SimTypes.ActionType.WAIT and t != SimTypes.ActionType.FOLLOW_ROUTE \
			and t != SimTypes.ActionType.IDLE and t != SimTypes.ActionType.HOLD_FIRE and t != SimTypes.ActionType.RETREAT):
		_add_target_options()
	elif t == SimTypes.ActionType.FOLLOW_BEACONS:
		_mode = _option(editor.beacon_mode_items(), SimTypes.beacon_mode_to_string(rule.action.mode), _on_mode, "det_p1")
		_mode.name = "RuleMode"
		_place(_mode, rel("det_p1"))
		_from = _option(editor.beacon_items(rule.action.from), rule.action.from, _on_from, "det_p2")
		_from.name = "RuleFrom"
		_place(_from, rel("det_p2"))
	elif t == SimTypes.ActionType.WAIT:
		# 持续时间：参数一格里一个数值框（后缀「秒」），参数二格暗
		_seconds = _spin(SimTypes.WAIT_MIN_SECONDS, SimTypes.WAIT_MAX_SECONDS, SimTypes.WAIT_MIN_SECONDS, " " + DataRegistry.get_string("ui.seconds_unit"), "det_wait_box")
		_seconds.tooltip_text = DataRegistry.get_string("ui.wait_duration")
		_seconds.set_value_no_signal(rule.action.seconds)
		_seconds.value_changed.connect(_on_seconds)
		_place(_seconds, rel("det_wait_box"))
		p2_used = false
	elif t == SimTypes.ActionType.FOLLOW_ROUTE:
		_route = _option(editor.route_items(), rule.action.route_id, _on_route, "det_p1")
		_place(_route, rel("det_p1").merge(rel("det_p2")))
	else:
		p1_used = false
		p2_used = false
	for pair: Array in [[p1_used, "det_p1"], [p2_used, "det_p2"]]:
		if not bool(pair[0]):
			var off := TextureRect.new()
			off.name = "SlotOff_" + str(pair[1])
			off.texture = SLOT_OFF
			off.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			off.stretch_mode = TextureRect.STRETCH_SCALE
			off.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_place(off, rel(str(pair[1])))
	_delete = Button.new()                           # 刻印界面：删除 = 行为框左边的小图标（不再有「优先级 N」与「删除」字样）
	_delete.icon = DELETE_ICON
	_delete.expand_icon = true
	_delete.tooltip_text = DataRegistry.get_string("ui.delete_rule_tip")
	_delete.flat = true
	var plain := StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		_delete.add_theme_stylebox_override(st, plain)
	_delete.add_theme_color_override("icon_normal_color", Color(0.85, 0.8, 0.8))
	_delete.add_theme_color_override("icon_hover_color", Color(1.25, 1.1, 1.1))
	_delete.add_theme_color_override("icon_pressed_color", Color(1.0, 0.8, 0.8))
	_delete.focus_mode = Control.FOCUS_NONE
	_delete.set_meta(&"sfx_press", "")
	_delete.pressed.connect(func() -> void:
		AudioManager.play_sfx("rule_remove", "UI")
		editor.delete_rule(index))
	_delete.visible = not editor.read_only and editor.editable()     # 战斗中不可编辑：不显示删除（批准整图 ui_13）
	_place(_delete, rel("det_delete"))
	_controls.append(_delete)


static func _moved(r: Rect2, by: Vector2) -> Rect2:
	return Rect2(r.position + by, r.size)


## 目标选择 + 目标类型（参数一 / 参数二格）
func _add_target_options() -> void:
	var sel_key: String = SimTypes.selector_to_string(rule.target.selector) if rule.target != null else ""
	var fil_key: String = SimTypes.filter_to_string(rule.target.filter) if rule.target != null else ""
	_selector = _option(editor.selector_items(sel_key), sel_key, _on_selector, "det_p1")
	_selector.name = "RuleSelector"
	_place(_selector, rel("det_p1"))
	_filter = _option(editor.filter_items(fil_key), fil_key, _on_filter, "det_p2")
	_filter.name = "RuleFilter"
	_place(_filter, rel("det_p2"))


# ---- 条件行：第 k 条（条件一 / 条件二两个框；敌人的第 3 条起每两条一排向下排）----
func _cond_slot(k: int) -> Rect2:
	var base: Rect2 = rel("det_c1") if k % 2 == 0 else rel("det_c2")
	if k >= UI_MAX_CONDITIONS:
		base.position.y += EXTRA_COND_PITCH * float((k - UI_MAX_CONDITIONS) / 2 + 1)
	return base


func _build_condition_line(k: int, c: ConditionDef) -> void:
	var slot: Rect2 = _cond_slot(k)
	if k == 1:
		var glyph: String = DataRegistry.get_string("ui.logic_or_glyph" if rule.condition_mode == SimTypes.ConditionMode.ANY else "ui.logic_and_glyph")
		_logic = Button.new()
		_logic.icon = LOGIC_OR if rule.condition_mode == SimTypes.ConditionMode.ANY else LOGIC_AND
		_logic.expand_icon = true
		_logic.flat = true
		var plain_logic := StyleBoxEmpty.new()
		for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			_logic.add_theme_stylebox_override(st, plain_logic)
		_logic.add_theme_color_override("icon_hover_color", Color(1.2, 1.2, 1.2))
		_logic.focus_mode = Control.FOCUS_NONE
		_logic.visible = true                                 # 条件一 / 条件二之间的与 / 或标志；只有一个条件时变暗、不可切换
		_logic.set_meta(&"single", rule.conditions.size() < 2)
		_logic.set_meta(&"sfx_press", "")                    # 由 _on_logic 按切换后的与 / 或播
		_logic.pressed.connect(_on_logic)
		_place(_logic, rel("det_logic"))
		_controls.append(_logic)
	var key: String = SimTypes.condition_to_string(c.type) if c != null else ("always" if k == 0 else NONE_KEY)
	var items: Array = editor.condition_items(key if key != NONE_KEY else "")
	if k >= 1 and not editor.read_only:
		items.push_front([DataRegistry.get_string("ui.condition_none"), NONE_KEY])
	var has_param: bool = c != null and c.type in [SimTypes.ConditionType.SELF_HP_BELOW, SimTypes.ConditionType.TARGET_DISTANCE, SimTypes.ConditionType.AT_BEACON, SimTypes.ConditionType.SIGNAL_IS]
	var opt: OptionButton = _option(items, key, _on_cond.bind(k), "det_c1_narrow" if has_param else "det_c1")
	opt.name = "RuleCond%d" % (k + 1)
	_place(opt, slot)
	_cond_options.append(opt)
	_content_h = maxf(_content_h, opt.position.y + opt.size.y)
	if c == null:
		return
	# 参数叠在条件框右端（无框，只有字）
	var off: Vector2 = rel("det_cparam").position - rel("det_c1").position
	var prm := Rect2(slot.position + off, rel("det_cparam").size)
	match c.type:
		SimTypes.ConditionType.SELF_HP_BELOW:
			var ratio: SpinBox = _spin(1.0, 99.0, 1.0, "%", "det_cparam", true)
			ratio.set_value_no_signal(round(c.ratio * 100.0))
			ratio.value_changed.connect(_on_ratio.bind(k))
			_place(ratio, prm)
		SimTypes.ConditionType.TARGET_DISTANCE:
			# 比较与距离合成一个下拉「< 3」（单位「格」放在悬停提示里，条件框右端放不下）
			var dist: OptionButton = _option(editor.distance_items(c.op, c.value), RuleEditor.distance_key(c.op, c.value), Callable(), "det_cparam")
			dist.item_selected.connect(_on_distance.bind(k, dist))
			dist.tooltip_text = DataRegistry.get_string("ui.distance_unit")
			_flat_param(dist)
			_place(dist, prm)
		SimTypes.ConditionType.AT_BEACON:
			var beacon: OptionButton = _option(editor.beacon_items(c.beacon), c.beacon, Callable(), "det_cparam")
			beacon.item_selected.connect(_on_beacon.bind(k, beacon))
			_flat_param(beacon)
			_place(beacon, prm)
		SimTypes.ConditionType.SIGNAL_IS:
			var sig_items: Array = []
			for sig: String in ["red", "yellow", "blue"]:
				sig_items.append([DataRegistry.get_string("names.signals." + sig), sig])
			var sig_opt: OptionButton = _option(sig_items, c.sig, Callable(), "det_cparam")
			sig_opt.item_selected.connect(_on_signal.bind(k, sig_opt))
			_flat_param(sig_opt)
			_place(sig_opt, prm)


## 条件参数下拉：去掉框（叠在条件框上），字号与条件框一致
func _flat_param(o: OptionButton) -> void:
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 2.0
	plain.content_margin_right = 2.0
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		o.add_theme_stylebox_override(st, plain)
	o.add_theme_font_size_override("font_size", 18)
	o.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	o.add_theme_color_override("font_hover_color", Palette.ALCHEMY_GOLD.lightened(0.25))
	o.add_theme_color_override("font_pressed_color", Palette.ALCHEMY_GOLD.lightened(0.25))
	o.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _option(items: Array, current: String, on_selected: Callable, skin_id: String = "") -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.focus_mode = Control.FOCUS_NONE
	if skin_id != "":
		o.theme_type_variation = tt(skin_id)
		o.add_theme_icon_override("arrow", UiKit.transparent_texture(Vector2i.ONE))     # 箭头已画在下拉切片上
		o.alignment = HORIZONTAL_ALIGNMENT_CENTER                                        # 刻印界面的框内文字居中
	UiKit.fill_option(o, items, current)
	if on_selected.is_valid():
		o.item_selected.connect(on_selected)
	_controls.append(o)
	return o


func _spin(lo: float, hi: float, step: float, suffix: String, skin_id: String = "", flat: bool = false) -> SpinBox:
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
		if flat:                                                           # 条件参数：无框，叠在条件框右端
			var plain := StyleBoxEmpty.new()
			for st2: String in ["normal", "focus", "read_only"]:
				le.add_theme_stylebox_override(st2, plain)
			le.add_theme_font_size_override("font_size", 18)
			le.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
			le.alignment = HORIZONTAL_ALIGNMENT_CENTER
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


## 行高 = 底纹高（敌人条件多于两条时加高；运行中有原因 / 等待剩余时再加一行）。底纹自带的下沿纹饰画在行框外（expand），相邻指令行靠得很近
func _layout_height() -> void:
	var reason_on: bool = _why.visible or _reason.visible
	var y: float = rel("det_action").end.y + 2.0 + _low_dy
	var x: float = rel("det_action").position.x
	_why.position = Vector2(x, y)
	_reason.position = Vector2(x + (_why.size.x if _why.visible else 0.0), y)
	_reason.size = Vector2(maxf(rel("det_c2").end.x - _reason.position.x, 40.0), 18.0)
	_reason.custom_minimum_size = Vector2.ZERO
	var h: float = rel("det_row1").size.y + _low_dy + (REASON_EXTRA if reason_on else 0.0)
	_body.custom_minimum_size = Vector2(rel("det_row1").size.x, h)
	_highlight.position = Vector2(4.0, 2.0)                  # 金边只框住框行
	_highlight.size = Vector2(_body.custom_minimum_size.x - 8.0, rel("det_action").end.y + _low_dy + 4.0)


# ---- 写回：克隆 → 修改 → 规整 → 提交 ----
func _commit(r: RuleDef) -> void:
	_normalize(r)
	editor.update_rule(index, r)


## 少于两条件时 condition_mode 写 all（10 §5.2）；需要目标而缺失时补默认目标；行为与条件都不需要目标时去掉目标
func _normalize(r: RuleDef) -> void:
	if r.conditions.size() < UI_MAX_CONDITIONS:
		r.condition_mode = SimTypes.ConditionMode.ALL
	var needs: bool = r.action.needs_target() or r.has_condition(SimTypes.ConditionType.TARGET_DISTANCE)
	if r.action.type == SimTypes.ActionType.CHASE and r.target == null:
		r.target = RuleEditor.chase_target()       # 2026-10-18：追击像攻击一样可选目标，默认最近
	elif needs and r.target == null:
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
			AudioManager.play_sfx("rule_remove", "UI")       # AudioManager 见到同帧的具体音就不再叠自动 ui_select
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
	AudioManager.play_sfx("ui_toggle", "UI", 0.0, 1.1 if r.condition_mode == SimTypes.ConditionMode.ANY else 0.9)
	if _logic != null and not editor.read_only:       # 切换提示：从标志上冒出一行字，向上飘并淡出（行随后重建，提示挂在编辑器上）
		editor.show_logic_hint(_logic.get_global_rect().get_center(), DataRegistry.get_string("ui.logic_or_hint" if r.condition_mode == SimTypes.ConditionMode.ANY else "ui.logic_and_hint"))
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
	AudioManager.play_sfx("ui_drag_pick", "UI")
	_dragging = true
	return _drag_payload()


## 从本行拖起、没被接收：落在同编辑器别组的行上 = 被拒（ui_error），否则 = 取消（drag_cancel）
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _dragging:
		return
	_dragging = false
	if get_viewport().gui_is_drag_successful() or editor == null:
		return
	var over: RuleRow = editor.row_at(get_global_mouse_position())
	var rejected: bool = over != null and over != self and SimTypes.action_group(over.rule.action.type) != SimTypes.action_group(rule.action.type)
	AudioManager.play_sfx("ui_error" if rejected else "drag_cancel", "UI")


func _drag_payload() -> Dictionary:
	return { "rule_from": index, "editor": editor.get_instance_id(), "group": SimTypes.action_group(rule.action.type) }


## 第五阶段：只能在同一组内拖动排序
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var d: Dictionary = data as Dictionary
	return d.has("rule_from") and int(d.get("editor", 0)) == editor.get_instance_id() and editor.editable() \
		and int(d.get("group", -1)) == SimTypes.action_group(rule.action.type)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	AudioManager.play_sfx("ui_drag_drop", "UI")
	editor.move_rule(int((data as Dictionary)["rule_from"]), index)
