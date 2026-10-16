extends Control
## 己方单位详情（01 §9 unit_panel；第四阶段按侧栏批准整图 assets/ui/side_detail/design.png 换皮，位置见 DetailKit / 布局 side_detail 的 det_*）：
## 头部：圆形头像（金环）、形态名、描述、「形态 N ＋ 指令 M」（free 关，10 §5.5）；右上「移除」（仅部署阶段已放置，10 §4；说明小字改为悬停提示）。
## 属性行：六项属性（3 × 2）；其下一行优先级说明（越靠上越高、「覆盖」）。中部（只有这里滚动）：指令列表（RuleEditor）、信标列表与「复制预设路线为我的信标」。
## 底部：「添加指令」与「信标」（进入信标模式，第四阶段）两个按钮，再下一行信标摘要 / 战斗中不可编辑的说明。
## 框体与「关闭」由 HUD 的 SidePanel 负责；移除后收起（BattleRoot 发 unit_selected(-1)）。

const RULE_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/rule_editor.tscn")
const STAT_KEYS: Array[String] = DetailKit.STAT_KEYS

var controller: BattleController = null
var level: LevelDefinition = null
var slot_id: String = ""
var _portrait: TextureRect
var _name: Label
var _desc: Label
var _remove_button: Button
var _cost_label: Label
var _stats: Array[Label] = []
var _editor: RuleEditor
var _beacon_list: VBoxContainer
var _beacon_hint: Label
var _route_row: HBoxContainer
var _route_pick: OptionButton
var _copy_button: Button
var _footer: Label
var _beacon_button: Button
var _beacon_nodes: Array[Control] = []   ## 信标区各件（行为列表打开时隐藏，批准整图 ui_15）

signal beacon_mode_requested(slot_id: String)   ## 「信标」按钮：HUD 进入该单位的信标模式


func setup(p_controller: BattleController, p_level: LevelDefinition) -> void:
	controller = p_controller
	level = p_level
	size = DetailKit.rel("det_panel").size          # 位置与尺寸由 HUD 摆放（框体内左上对齐）
	mouse_filter = Control.MOUSE_FILTER_PASS
	_portrait = DetailKit.portrait(self)
	_name = DetailKit.label(self, "det_title")
	_desc = DetailKit.label(self, "det_desc")
	_cost_label = DetailKit.label(self, "det_cost")
	_remove_button = UiKit.node_for(UiKit.layout_element(DetailKit.SKIN, "det_remove")) as Button
	_remove_button.text = DataRegistry.get_string("ui.remove_unit")
	_remove_button.focus_mode = Control.FOCUS_NONE
	_remove_button.pressed.connect(_on_remove_pressed)
	_remove_button.tooltip_text = DataRegistry.get_string("ui.remove_hint")      # 侧栏头部没有空位放说明小字：改为悬停提示
	DetailKit.place(self, _remove_button, DetailKit.rel("det_remove"))
	ScrollText.wrap(_name, ScrollText.Mode.AUTO)
	ScrollText.wrap(_cost_label, ScrollText.Mode.AUTO)
	_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_desc.clip_text = false
	ScrollText.wrap(_desc, ScrollText.Mode.MANUAL)
	_stats = DetailKit.stats(self)
	var note: Label = DetailKit.label(self, "det_note", DataRegistry.get_string("ui.rule_priority_note_side"))
	ScrollText.wrap(note, ScrollText.Mode.AUTO)
	var body: VBoxContainer = DetailKit.scroll_body(self)
	body.add_theme_constant_override("separation", 12)
	_editor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
	body.add_child(_editor)
	_editor.setup(controller, level)
	_build_beacon_section(body)
	_editor.picker_toggled.connect(func(open: bool) -> void:
		for c: Control in _beacon_nodes:
			c.visible = not open
		_route_row.visible = not open and not level.routes.is_empty()
		if not open:
			_refresh_beacons())
	var add: Button = _editor.take_add_button()
	add.text = DataRegistry.get_string("ui.add_action_button")       # 侧栏整图：按钮带「＋」（行为列表标题仍是「添加指令」）
	DetailKit.place(self, add, DetailKit.rel("det_add"))
	_beacon_button = UiKit.node_for(UiKit.layout_element(DetailKit.SKIN, "det_beacon_btn")) as Button
	_beacon_button.name = "BeaconModeButton"
	_beacon_button.text = DataRegistry.get_string("ui.beacon_mode_button")
	_beacon_button.tooltip_text = DataRegistry.get_string("ui.beacon_mode_button_tip")
	_beacon_button.focus_mode = Control.FOCUS_NONE
	_beacon_button.pressed.connect(func() -> void: beacon_mode_requested.emit(slot_id))
	DetailKit.place(self, _beacon_button, DetailKit.rel("det_beacon_btn"))
	DetailKit.footer_line(self)
	DetailKit.footer_tab(self)
	_footer = DetailKit.label(self, "det_beacons")
	ScrollText.wrap(_footer, ScrollText.Mode.AUTO)
	EventBus.beacons_changed.connect(func(_id: int) -> void: _refresh_beacons())
	EventBus.battle_phase_changed.connect(func(_p: int) -> void:
		_refresh_beacons()
		_refresh_remove())
	EventBus.deployment_changed.connect(_refresh_remove)
	EventBus.rules_changed.connect(func(_id: int) -> void:
		_refresh_cost()
		_refresh_footer())


func _build_beacon_section(body: VBoxContainer) -> void:
	var title: Label = DetailKit.section_title(body, DataRegistry.get_string("ui.beacons"))
	_beacon_hint = DetailKit.section_text(body, DataRegistry.get_string("ui.beacon_hint"))
	_beacon_nodes.append(title.get_parent() as Control)
	_beacon_nodes.append(_beacon_hint.get_parent() as Control)
	_beacon_list = VBoxContainer.new()
	_beacon_list.add_theme_constant_override("separation", 6)
	body.add_child(_beacon_list)
	_route_row = HBoxContainer.new()
	_route_row.add_theme_constant_override("separation", 8)
	body.add_child(_route_row)
	var lbl: Label = DetailKit.section_text(_route_row, DataRegistry.get_string("ui.copy_route_label"))
	lbl.custom_minimum_size = Vector2.ZERO
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_route_pick = OptionButton.new()
	_route_pick.theme_type_variation = DetailKit.tt("det_p1")
	_route_pick.add_theme_icon_override("arrow", UiKit.transparent_texture(Vector2i.ONE))
	_route_pick.custom_minimum_size = DetailKit.rel("det_p1").size
	_route_pick.fit_to_longest_item = false
	_route_pick.clip_text = true
	var items: Array = []
	for rid: String in level.routes.keys():
		items.append([(level.routes[rid] as RouteDef).display_name, rid])
	UiKit.fill_option(_route_pick, items, "")
	_route_row.add_child(_route_pick)
	_copy_button = Button.new()
	_copy_button.text = DataRegistry.get_string("ui.copy_route")
	_copy_button.theme_type_variation = DetailKit.tt("det_remove")
	_copy_button.custom_minimum_size = Vector2(DetailKit.rel("det_remove").size.x * 1.6, DetailKit.rel("det_remove").size.y)
	_copy_button.clip_text = true
	_copy_button.focus_mode = Control.FOCUS_NONE
	_copy_button.pressed.connect(_on_copy_route)
	_route_row.add_child(_copy_button)
	_route_row.visible = not level.routes.is_empty()
	_beacon_nodes.append(_beacon_list)


func _refresh_beacons() -> void:
	if _beacon_list == null or slot_id == "":
		return
	UiKit.clear(_beacon_list)
	var editable: bool = controller.can_edit_beacons(slot_id)
	var beacons: Array[Dictionary] = controller.get_beacons(slot_id)
	if beacons.is_empty():
		DetailKit.section_text(_beacon_list, DataRegistry.get_string("ui.beacon_none"))
	for b: Dictionary in beacons:
		var row := HBoxContainer.new()
		_beacon_list.add_child(row)
		var cell: Vector2i = b["cell"] as Vector2i
		var l: Label = DetailKit.section_text(row, DataRegistry.get_string("ui.beacon_cell").format({ "id": str(b["id"]), "x": cell.x, "y": cell.y }))
		l.custom_minimum_size = Vector2.ZERO
		(l.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var del := Button.new()
		del.text = DataRegistry.get_string("ui.delete_rule")
		del.theme_type_variation = DetailKit.tt("det_delete")
		del.custom_minimum_size = DetailKit.rel("det_delete").size
		del.focus_mode = Control.FOCUS_NONE
		del.disabled = not editable
		var bid: String = str(b["id"])
		del.pressed.connect(func() -> void: controller.remove_beacon(slot_id, bid))
		row.add_child(del)
	_beacon_hint.visible = editable
	_beacon_button.visible = editable
	_copy_button.disabled = not editable or _route_pick.item_count == 0
	_route_pick.disabled = not editable
	_refresh_footer()


## 底部一行：可编辑时为信标摘要；战斗中为「战斗中无法编辑指令」（批准整图 ui_13）
func _refresh_footer() -> void:
	if _footer == null or slot_id == "":
		return
	if not controller.can_edit_rules(slot_id):
		_footer.text = DataRegistry.get_string("ui.rule_editing_locked")
		return
	var n: int = controller.get_beacons(slot_id).size()
	var mode: int = controller.beacon_follow_mode(slot_id)
	if n == 0:
		_footer.text = DataRegistry.get_string("ui.beacon_footer_none")
	elif mode < 0:
		_footer.text = DataRegistry.get_string("ui.beacon_footer_n").format({ "n": n })
	else:
		_footer.text = DataRegistry.get_string("ui.beacon_footer_mode").format({ "n": n, "mode": RuleText.beacon_mode_name(mode) })


func _on_copy_route() -> void:
	if _route_pick.selected < 0:
		return
	var rid: String = UiKit.option_value(_route_pick, _route_pick.selected)
	if controller.copy_route_to_beacons(slot_id, rid):
		EventBus.toast.emit(DataRegistry.get_string("ui.copy_route_done").format({ "route": (level.routes[rid] as RouteDef).display_name }))


func show_slot(p_slot_id: String) -> void:
	slot_id = p_slot_id
	visible = slot_id != ""
	if slot_id == "":
		return
	var udef: UnitDefinition = DataRegistry.get_unit(controller.form_of(slot_id))
	_name.text = controller.label_of(slot_id)
	_desc.text = udef.description
	UiKit.set_portrait(_portrait, str(udef.visuals.get("portrait", "")), Palette.BONE)
	_editor.show_slot(slot_id)
	_update_stats()
	_refresh_beacons()
	_refresh_remove()
	_refresh_cost()


## 10 §5.5 Cost 拆分：形态 Cost ＋ 指令 Cost（编辑指令时实时刷新；只在按预算出场的 free 关显示）
func _refresh_cost() -> void:
	if _cost_label == null or slot_id == "":
		return
	_cost_label.visible = level.is_free()
	_cost_label.text = DataRegistry.get_string("ui.cost_breakdown").format({
		"form": controller.cost_of(controller.form_of(slot_id)), "commands": controller.command_cost(slot_id) })


## 「移除」只在部署阶段、该单位已放置时可见
func _refresh_remove() -> void:
	if _remove_button == null:
		return
	var can: bool = slot_id != "" and controller.phase == SimTypes.Phase.DEPLOY and controller.placements.has(slot_id)
	_remove_button.visible = can
	_refresh_footer()


func _on_remove_pressed() -> void:
	controller.remove_unit(slot_id)     # 音效与收起侧栏由 BattleRoot 的 deployment_changed 处理


func _process(_delta: float) -> void:
	if visible and slot_id != "":
		_update_stats()


func _update_stats() -> void:
	var udef: UnitDefinition = DataRegistry.get_unit(controller.form_of(slot_id))
	if udef == null:
		return
	var u: SimUnit = controller.world.get_unit(controller.unit_id_of_slot(slot_id)) if controller.world != null else null
	var values: Array[String] = RuleText.stat_values(u, udef)
	for i: int in _stats.size():
		_stats[i].text = values[i]


## 侧栏比设计高 extra 像素（视口高于 1080）：滚动区加高、底部件下移
func stretch(extra: float) -> void:
	DetailKit.stretch(self, extra)
