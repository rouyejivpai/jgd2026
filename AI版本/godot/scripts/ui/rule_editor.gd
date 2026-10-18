class_name RuleEditor
extends VBoxContainer
## 指令列表（01 §9；第三阶段 10 §5 重构）：顶部 = 最高优先级；拖拽排序；删除；部署阶段可编辑，运行中禁用编辑并显示当前生效行与未成立原因。
## 10 §5.4 添加流程：「添加指令」→ 行为列表（P6 批准整图 ui_15：在详情中部替换指令列表显示，每个行为一行、带图标，末尾「取消」）（commands.actions 中 player ∧ 已解锁 ∧ 本关 allowed ∧ 形态可用）→ 选中即在末尾新增一行：
## 条件「始终」，目标选择 / 目标类型 / 信标模式 / 起点取各自列表首个可用项，等待秒数取 WAIT_MIN_SECONDS。不再有预组合指令。
## 下拉选项一律来自 data/commands.json（数组顺序 = 菜单顺序 = 默认项）；当前值即使不合法也保留在下拉里，便于看出问题。
## 07 §2：敌人面板复用本组件（read_only = true，show_enemy）：同样的行布局、整句、运行中高亮与"为何不成立"，只禁用编辑。
## 第五阶段（2026-10-17 会议）：玩家单位的指令分「攻击策略」「移动策略」两组显示（同一列表按行为分组，组内顺序 = 优先级），
## 每组标题带条数（上限 commands.json group_limits）、各自的「＋ 攻击指令 / ＋ 移动指令」；拖拽只在组内排序。
## UI 暂用简单分区 + 侧栏滚动，正式版式待拼 UI。敌人（旧单列表口径）仍显示为一个列表。

const RULE_ROW_SCENE: PackedScene = preload("res://scenes/ui/rule_row.tscn")
const BEACON_MODES: Array[String] = ["once", "loop", "pingpong"]

var controller: BattleController = null
var level: LevelDefinition = null
var slot_id: String = ""
var read_only: bool = false              ## 只读（敌人面板）
var enemy_id: int = -1                   ## read_only 时显示的模拟单位 id
var _rows: Array[RuleRow] = []
var _note: Label
var _lock_note: Label
var _list: VBoxContainer                 ## 指令区（两组分区；打开行为列表时隐藏）
var _add: Button
var _picker: VBoxContainer               ## 「添加指令」行为列表（打开时隐藏指令列表）
var _menu_actions: Array[String] = []    ## 「添加指令」弹出列表中的行为 id（菜单顺序）
var _picker_group: int = -1              ## 行为列表只列某组（-1 = 两组都列）
var _sections: Dictionary = {}           ## 第五阶段：SimTypes.RuleGroup -> { "title": Label, "note": Label, "list": VBoxContainer, "add": Button }
var _row_gap: int = 8
var _dirty: bool = false

signal picker_toggled(open: bool)        ## 行为列表开 / 关（详情据此隐藏信标区）


func setup(p_controller: BattleController, p_level: LevelDefinition) -> void:
	controller = p_controller
	level = p_level
	add_theme_constant_override("separation", 8)
	_note = UiKit.label(DataRegistry.get_string("ui.rule_priority_note"), "SmallLabel")
	_note.visible = false                # P6：整图不显示（优先级由「优先级 N」标出）
	add_child(_note)
	_lock_note = UiKit.label(DataRegistry.get_string("ui.rule_editing_locked"), "SmallLabel")
	_lock_note.add_theme_color_override("font_color", Palette.WARN_RED)
	add_child(_lock_note)
	_list = VBoxContainer.new()
	_list.name = "RuleGroups"
	var d: Vector2 = UiKit.design_size(DetailKit.SKIN)         # 行距：批准整图两行指令框的间距
	_row_gap = int(round(UiKit.layout_rect(DetailKit.SKIN, "det_row2", d).position.y - UiKit.layout_rect(DetailKit.SKIN, "det_row1", d).end.y))
	_list.add_theme_constant_override("separation", _row_gap)
	add_child(_list)
	_build_sections()
	_add = Button.new()
	_add.text = DataRegistry.get_string("ui.add_action")
	_add.flat = false
	_add.theme_type_variation = StringName(str(UiKit.layout_element(DetailKit.SKIN, "det_add").get("theme_type", "")))
	_add.focus_mode = Control.FOCUS_NONE
	_add.pressed.connect(toggle_picker)
	add_child(_add)
	_picker = VBoxContainer.new()
	_picker.name = "ActionPicker"
	var pm := MarginContainer.new()          # 左右缩进与指令行拖拽柄对齐（DetailKit.inset）
	pm.name = "PickerMargin"
	pm.add_theme_constant_override("margin_left", int(DetailKit.inset()))
	pm.add_theme_constant_override("margin_right", int(DetailKit.inset()))
	pm.add_theme_constant_override("margin_top", int(DetailKit.rel("det_handle").position.y - DetailKit.rel("det_row1").position.y - 8.0))
	pm.visible = false
	pm.add_child(_picker)
	add_child(pm)
	EventBus.rules_changed.connect(func(_id: int) -> void: _mark_dirty())
	EventBus.beacons_changed.connect(func(_id: int) -> void: _mark_dirty())
	EventBus.battle_phase_changed.connect(func(_p: int) -> void: _mark_dirty())


## 详情弹窗把「添加指令」放在底部（批准整图）：从本组件取出按钮交给调用方摆放（行为列表与可用状态仍由本组件维护）
func take_add_button() -> Button:
	_add.get_parent().remove_child(_add)
	return _add


func show_slot(p_slot_id: String) -> void:
	slot_id = p_slot_id
	_mark_dirty()


## 只读显示某个模拟单位（敌人 / 中立）的指令
func show_enemy(unit_id: int) -> void:
	read_only = true
	enemy_id = unit_id
	slot_id = ""
	_mark_dirty()


func editable() -> bool:
	return not read_only and slot_id != "" and controller.can_edit_rules(slot_id)


func _enemy() -> SimUnit:
	return controller.world.get_unit(enemy_id) if read_only and controller.world != null else null


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_rebuild.call_deferred()


## 第五阶段：两组分区（攻击在上、移动在下），每组 = 标题（组名 + 条数）+ 说明 + 指令行 + 本组添加按钮
func _build_sections() -> void:
	for g: int in [SimTypes.RuleGroup.ATTACK, SimTypes.RuleGroup.MOVE]:
		var box := VBoxContainer.new()
		box.name = "Group_" + SimTypes.group_to_string(g)
		box.add_theme_constant_override("separation", _row_gap)
		var title := Label.new()
		title.name = "Title"
		title.theme_type_variation = StringName(str(UiKit.layout_element(DetailKit.SKIN, "det_prio").get("theme_type", "")))
		box.add_child(title)
		var note: Label = UiKit.label(DataRegistry.get_string("ui.rule_group_note_" + SimTypes.group_to_string(g)), "SmallLabel", true)
		note.name = "Note"
		box.add_child(note)
		var list := VBoxContainer.new()
		list.name = "Rows"
		list.add_theme_constant_override("separation", _row_gap)
		box.add_child(list)
		var add := Button.new()
		add.name = "Add"
		add.text = DataRegistry.get_string("ui.add_rule_" + SimTypes.group_to_string(g))
		add.theme_type_variation = StringName(str(UiKit.layout_element(DetailKit.SKIN, "det_add").get("theme_type", "")))
		add.focus_mode = Control.FOCUS_NONE
		add.pressed.connect(open_picker.bind(g))
		box.add_child(add)
		_list.add_child(box)
		_sections[g] = { "box": box, "title": title, "note": note, "list": list, "add": add }


func _rebuild() -> void:
	_dirty = false
	for g: Variant in _sections.keys():
		UiKit.clear((_sections[g] as Dictionary)["list"] as VBoxContainer)
	_rows.clear()
	_lock_note.text = DataRegistry.get_string("ui.enemy_rules_readonly" if read_only else "ui.rule_editing_locked")
	_add.visible = not read_only
	var rules: Array[RuleDef] = []
	if read_only:
		var e: SimUnit = _enemy()
		if e == null:
			return
		rules = e.rules
	elif slot_id == "":
		return
	else:
		rules = controller.get_rules(slot_id)
	var grouped: bool = not read_only or (_enemy() != null and _enemy().dual_rules)
	for g: int in [SimTypes.RuleGroup.ATTACK, SimTypes.RuleGroup.MOVE]:
		var sec: Dictionary = _sections[g] as Dictionary
		var idx: Array[int] = RuleDef.group_indices(rules, g)
		if not grouped:                   # 旧单列表口径（敌人）：全部指令放在第一个分区，不显示组标题
			idx.clear()
			if g == SimTypes.RuleGroup.ATTACK:
				for i: int in rules.size():
					idx.append(i)
		for k: int in idx.size():
			var row: RuleRow = RULE_ROW_SCENE.instantiate() as RuleRow
			row.order = k
			(sec["list"] as VBoxContainer).add_child(row)
			row.setup(self, idx[k], rules[idx[k]])
			_rows.append(row)
		var limit: int = DataRegistry.get_commands().group_limit(g)
		(sec["title"] as Label).text = DataRegistry.get_string("ui.rule_group_title").format({ "group": RuleText.group_name(g), "n": idx.size(), "max": limit })
		(sec["title"] as Label).visible = grouped
		(sec["note"] as Label).visible = grouped and editable()
		(sec["box"] as Control).visible = grouped or g == SimTypes.RuleGroup.ATTACK
		var add: Button = sec["add"] as Button
		add.visible = grouped and editable()
		add.disabled = idx.size() >= limit or not _group_has_actions(g)
		add.tooltip_text = DataRegistry.get_string("ui.rule_group_full").format({ "max": limit }) if idx.size() >= limit else ""
	_lock_note.visible = false            # P6：不可编辑的说明在详情底部一行（UnitPanel）
	_add.disabled = not editable()
	_add.visible = not read_only and editable()          # 战斗中底部只留「战斗中无法编辑指令」（批准整图 ui_13）
	_fill_add_menu()


## 第五阶段：该组还能否添加（条数未满）
func group_full(g: int) -> bool:
	if slot_id == "" or controller == null:
		return false
	return RuleDef.group_indices(controller.get_rules(slot_id), g).size() >= DataRegistry.get_commands().group_limit(g)


func _group_has_actions(g: int) -> bool:
	for key: String in DataRegistry.get_commands().ids("actions"):
		if SimTypes.action_group(SimTypes.parse_action(key)) == g and action_available(key):
			return true
	return false


func _process(_delta: float) -> void:
	if controller == null or controller.world == null or (slot_id == "" and not read_only):
		return
	var running: bool = controller.phase != SimTypes.Phase.DEPLOY
	var u: SimUnit = _enemy() if read_only else controller.world.get_unit(controller.unit_id_of_slot(slot_id))
	for row: RuleRow in _rows:
		if running and u != null and u.alive:
			var active: bool = u.is_rule_active(row.index)
			var note: String = ""
			if active and u.wait_remaining() >= 0.0:
				note = DataRegistry.get_string("ui.wait_remaining").format({ "seconds": "%.1f" % u.wait_remaining() })
			row.set_runtime(active, int(u.rule_fail_reasons.get(row.index, -1)), note)
		else:
			row.set_runtime(false, -1)


# ---- 编辑 ----
func update_rule(i: int, r: RuleDef) -> void:
	var rules: Array[RuleDef] = RuleDef.clone_array(controller.get_rules(slot_id))
	r.enabled = true                     # 10 §5.2：UI 写出恒为 true
	rules[i] = r
	controller.set_rules(slot_id, rules)


func move_rule(from: int, to: int) -> void:
	if from == to:
		return
	var rules: Array[RuleDef] = RuleDef.clone_array(controller.get_rules(slot_id))
	var r: RuleDef = rules[from]
	rules.remove_at(from)
	rules.insert(clampi(to, 0, rules.size()), r)
	controller.set_rules(slot_id, rules)


## 删除第 i 条（A01）；删到空列表允许开始，校验给出 EMPTY_RULES 提醒
func delete_rule(i: int) -> void:
	var rules: Array[RuleDef] = RuleDef.clone_array(controller.get_rules(slot_id))
	if i < 0 or i >= rules.size():
		return
	rules.remove_at(i)
	controller.set_rules(slot_id, rules)


## 10 §5.4：新指令插在列表末尾（Q-018 裁决）= 所在组的末尾；第五阶段：该组已满时不添加
func _on_add_action(id: int) -> void:
	close_picker()
	if id < 0 or id >= _menu_actions.size() or not editable():
		return
	var key: String = _menu_actions[id]
	if group_full(SimTypes.action_group(SimTypes.parse_action(key))):
		return
	var rules: Array[RuleDef] = RuleDef.clone_array(controller.get_rules(slot_id))
	rules.append(new_rule(key))
	controller.set_rules(slot_id, rules)


## 新增一行：选中的行为（参数取默认），条件「始终」（空条件列表），需要目标时目标选择 / 目标类型取首个可用项
func new_rule(action_key: String) -> RuleDef:
	var r := RuleDef.new()
	r.enabled = true
	r.condition_mode = SimTypes.ConditionMode.ALL
	r.action = default_action(SimTypes.parse_action(action_key))
	if r.action.needs_target():
		r.target = chase_target() if r.action.type == SimTypes.ActionType.CHASE else default_target()
	return r


## 追击的默认目标：最近（2026-10-18 起可在追击行改选目标）
static func chase_target() -> TargetDef:
	return TargetDef.create(SimTypes.Selector.NEAREST, SimTypes.TargetFilter.ANY)


## 行为列表的按钮（菜单顺序 = _menu_actions；末尾「取消」）。样式：每行一个平面按钮，底色 / 边框色 / 图标取自布局 det_pick（批准整图 ui_15）
func _fill_add_menu() -> void:
	UiKit.clear(_picker)
	_menu_actions = menu_actions()
	var e: Dictionary = UiKit.layout_element(DetailKit.SKIN, "det_pick")
	var data: Dictionary = e.get("data", {}) as Dictionary
	var colors: Dictionary = data.get("colors", {}) as Dictionary
	var icons: Dictionary = data.get("icons", {}) as Dictionary
	var k: float = UiKit.design_size(DetailKit.SKIN).y / 1080.0
	_picker.add_theme_constant_override("separation", int(float(data.get("row_gap", 8)) * k))
	var title := Label.new()
	title.text = DataRegistry.get_string("ui.add_action") if _picker_group < 0 else DataRegistry.get_string("ui.add_action_group").format({ "group": RuleText.group_name(_picker_group) })
	title.theme_type_variation = StringName(str(UiKit.layout_element(DetailKit.SKIN, "det_prio").get("theme_type", "")))
	_picker.add_child(title)
	for i: int in _menu_actions.size() + 1:
		var key: String = _menu_actions[i] if i < _menu_actions.size() else "cancel"
		var b := Button.new()
		b.text = RuleText.action_name(SimTypes.parse_action(key)) if key != "cancel" else DataRegistry.get_string("ui.cancel")
		b.theme_type_variation = StringName(str(UiKit.layout_element(DetailKit.SKIN, "det_delete").get("theme_type", "")))
		var c: Array = colors.get(key, ["#2B153A", "#DAC9B3"]) as Array
		for st: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(str(c[0])).lightened(0.12 if st == "hover" else 0.0).darkened(0.18 if st.contains("pressed") else 0.0)
			sb.border_color = Color(str(c[1]))
			sb.set_border_width_all(int(round(float(data.get("border_width", 1.5)))))
			sb.set_corner_radius_all(6)
			b.add_theme_stylebox_override(st, sb)
		b.custom_minimum_size = Vector2(0.0, float(data.get("row_h", 44)) * k)
		b.focus_mode = Control.FOCUS_NONE
		if icons.has(key):
			b.icon = Art.texture(str(icons[key]))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", int(28.0 * k))
		b.pressed.connect(_on_add_action.bind(i) if key != "cancel" else close_picker)
		if key != "cancel" and group_full(SimTypes.action_group(SimTypes.parse_action(key))):
			b.disabled = true             # 第五阶段：该组已满
			b.tooltip_text = DataRegistry.get_string("ui.rule_group_full").format({ "max": DataRegistry.get_commands().group_limit(SimTypes.action_group(SimTypes.parse_action(key))) })
		_picker.add_child(b)


## 打开 / 关闭行为列表（打开时隐藏指令列表与「添加指令」本身的作用区）
func toggle_picker() -> void:
	if picker_open():
		close_picker()
	else:
		open_picker(-1)


## 第五阶段：打开只列某组行为的列表（-1 = 两组）
func open_picker(group: int) -> void:
	if not editable():
		return
	_picker_group = group
	_fill_add_menu()
	(_picker.get_parent() as Control).visible = true
	_list.visible = false
	picker_toggled.emit(true)


func close_picker() -> void:
	var was: bool = (_picker.get_parent() as Control).visible
	(_picker.get_parent() as Control).visible = false
	_picker_group = -1
	_list.visible = true
	if was:
		picker_toggled.emit(false)


func picker_open() -> bool:
	return (_picker.get_parent() as Control).visible


## 「添加指令」列表：commands.actions 中 player ∧ 已解锁 ∧ 本关 allowed ∧ 形态可用，按目录顺序（第五阶段：可只列某组）
func menu_actions() -> Array[String]:
	var out: Array[String] = []
	for key: String in DataRegistry.get_commands().ids("actions"):
		if action_available(key) and (_picker_group < 0 or SimTypes.action_group(SimTypes.parse_action(key)) == _picker_group):
			out.append(key)
	return out


func _unit_def() -> UnitDefinition:
	return DataRegistry.get_unit(controller.form_of(slot_id)) if slot_id != "" else null


func _unlocked_presets() -> Array:
	return GameState.unlocks.get("presets", []) as Array


# ---- 可用性：目录解锁键 ∩ 本关 allowed ∩ 类型解锁（∩ 形态可用行为）；信标 / 到点 / 等待不受 allowed 限制（Q-047）----
func action_available(key: String) -> bool:
	var cat: CommandCatalog = DataRegistry.get_commands()
	if not cat.is_player(key) or not cat.unlocked("actions", key, _unlocked_presets()):
		return false
	var t: int = SimTypes.parse_action(key)
	if not DeploymentValidator.action_gated(t):
		return true
	var udef: UnitDefinition = _unit_def()
	return level.allowed_actions.has(t) and DeploymentValidator.action_unlocked(GameState.unlocks.get("actions", []) as Array, key) \
		and (udef == null or udef.allowed_actions.has(t))


func condition_available(key: String) -> bool:
	if not DataRegistry.get_commands().unlocked("conditions", key, _unlocked_presets()):
		return false
	var t: int = SimTypes.parse_condition(key)
	return not DeploymentValidator.condition_gated(t) or (level.allowed_conditions.has(t) and GameState.is_unlocked("conditions", key))


func selector_available(key: String) -> bool:
	var cat: CommandCatalog = DataRegistry.get_commands()
	return cat.is_player_selector(key) and cat.unlocked("selectors", key, _unlocked_presets()) \
		and level.allowed_selectors.has(SimTypes.parse_selector(key)) and GameState.is_unlocked("selectors", key)


func filter_available(key: String) -> bool:
	return DataRegistry.get_commands().unlocked("filters", key, _unlocked_presets())


# ---- 下拉选项（[[显示文本, 值], ...]）；当前值即使不合法也保留 ----
## 第五阶段：行为下拉只列与当前行为同组的行为（换行为不跨组）；当前为旧数据的「追击并攻击」时不限组
func action_items(current: String) -> Array:
	var items: Array = []
	var cur_t: int = SimTypes.parse_action(current)
	for key: String in DataRegistry.get_commands().ids("actions"):
		var t: int = SimTypes.parse_action(key)
		if not read_only and cur_t >= 0 and cur_t != SimTypes.ActionType.CHASE_ATTACK and SimTypes.action_group(t) != SimTypes.action_group(cur_t):
			continue
		if key == current or action_available(key):
			items.append([RuleText.action_name(t), key])
	if current != "" and not _has_value(items, current):
		items.append([RuleText.action_name(SimTypes.parse_action(current)), current])
	return items


func condition_items(current: String) -> Array:
	var items: Array = []
	for key: String in DataRegistry.get_commands().ids("conditions"):
		if key == current or condition_available(key):
			items.append([RuleText.condition_name(SimTypes.parse_condition(key)), key])
	if current != "" and not _has_value(items, current):
		items.append([RuleText.condition_name(SimTypes.parse_condition(current)), current])
	return items


func selector_items(current: String) -> Array:
	var items: Array = []
	for key: String in DataRegistry.get_commands().ids("selectors"):
		if key == current or selector_available(key):
			items.append([RuleText.selector_name(SimTypes.parse_selector(key)), key])
	if current != "" and not _has_value(items, current):
		items.append([RuleText.selector_name(SimTypes.parse_selector(current)), current])
	return items


func filter_items(current: String) -> Array:
	var items: Array = []
	for key: String in DataRegistry.get_commands().ids("filters"):
		if key == current or filter_available(key):
			items.append([RuleText.filter_name(SimTypes.parse_filter(key)), key])
	if current != "" and not _has_value(items, current):
		items.append([RuleText.filter_name(SimTypes.parse_filter(current)), current])
	return items


static func _has_value(items: Array, value: String) -> bool:
	return items.any(func(it: Array) -> bool: return str(it[1]) == value)


func route_items() -> Array:
	var items: Array = [[DataRegistry.get_string("ui.route_none"), ""]]
	for rid: String in level.routes.keys():
		items.append([(level.routes[rid] as RouteDef).display_name, rid])
	return items


## 信标下拉：本单位现有信标编号；当前值即使已删除也保留（便于看出失效）
func beacon_items(current: String) -> Array:
	var items: Array = []
	for b: Dictionary in controller.get_beacons(slot_id):
		items.append([str(b["id"]), str(b["id"])])
	if current != "" and not _has_value(items, current):
		items.append([current, current])
	return items


## 目标距离下拉（第四阶段，比较与距离合成一项）：「< N」「> N」，N 取 DISTANCE_STEPS；当前值不在其中时也保留
const DISTANCE_STEPS: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 8.0, 10.0]


static func distance_key(op: String, value: float) -> String:
	return "%s|%s" % [op, str(value)]


static func distance_label(op: String, value: float) -> String:
	return "%s %s" % [op, str(snappedf(value, 0.01)).trim_suffix(".0")]


func distance_items(current_op: String, current_value: float) -> Array:
	var items: Array = []
	for op: String in ["<", ">"]:
		for v: float in DISTANCE_STEPS:
			items.append([distance_label(op, v), distance_key(op, v)])
	if not _has_value(items, distance_key(current_op, current_value)):
		items.append([distance_label(current_op, current_value), distance_key(current_op, current_value)])
	return items


func beacon_mode_items() -> Array:
	var items: Array = []
	for key: String in BEACON_MODES:
		items.append([RuleText.beacon_mode_name(SimTypes.parse_beacon_mode(key)), key])
	return items


## 第一枚信标的编号（没有信标时为 "1"，10 §6.3）
func first_beacon() -> String:
	var bs: Array[Dictionary] = controller.get_beacons(slot_id)
	return str(bs[0]["id"]) if not bs.is_empty() else "1"


## 新行为：参数取 commands.json defaults；follow_beacons 模式取列表首项、起点取本单位第一枚信标；wait 秒数取 WAIT_MIN_SECONDS（10 §5.4）
func default_action(t: int) -> ActionDef:
	var key: String = SimTypes.action_to_string(t)
	var d: Dictionary = DataRegistry.get_commands().defaults("actions", key)
	d["type"] = key
	if t == SimTypes.ActionType.FOLLOW_ROUTE:
		d["route_id"] = str(d.get("route_id", default_route()))
	elif t == SimTypes.ActionType.FOLLOW_BEACONS:
		d["mode"] = str(d.get("mode", BEACON_MODES[0]))
		d["from"] = first_beacon()
	elif t == SimTypes.ActionType.WAIT:
		d["seconds"] = float(d.get("seconds", SimTypes.WAIT_MIN_SECONDS))
	return ActionDef.from_dict(d, "commands.json:" + key)


func default_route() -> String:
	return str(level.routes.keys()[0]) if not level.routes.is_empty() else ""


## 新目标：目标选择与目标类型各取首个可用项
func default_target() -> TargetDef:
	var sel: Array = selector_items("")
	var fil: Array = filter_items("")
	var sel_key: String = str((sel[0] as Array)[1]) if not sel.is_empty() else DataRegistry.get_commands().ids("selectors")[0]
	var fil_key: String = str((fil[0] as Array)[1]) if not fil.is_empty() else DataRegistry.get_commands().ids("filters")[0]
	return TargetDef.create(SimTypes.parse_selector(sel_key), SimTypes.parse_filter(fil_key))


## 新条件：参数取 commands.json defaults；at_beacon 指向本单位第一枚信标
func default_condition(t: int) -> ConditionDef:
	var key: String = SimTypes.condition_to_string(t)
	var d: Dictionary = DataRegistry.get_commands().defaults("conditions", key)
	d["type"] = key
	if t == SimTypes.ConditionType.AT_BEACON:
		d["beacon"] = first_beacon()
	return ConditionDef.from_dict(d, "commands.json:" + key)
