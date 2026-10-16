extends Control
## 敌人详情（01 §9 enemy_panel；第三阶段 P6 按批准整图换皮，与己方详情同一框体，位置见 DetailKit / 布局 det_*）：
## 头部：圆形头像、名称、说明（敌方单位：「敌方指令只读」等；建筑：描述）；属性行：六项属性。
## 中部（滚动）：运行中当前目标与特性冷却（07 §2）、特性说明（列在规则上方）、公开规则一句话、只读指令列表（RuleEditor read_only）。
## 底部：「敌方指令 · 只读」。也用于查看建筑（如保护对象）。

const RULE_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/rule_editor.tscn")
const STAT_KEYS: Array[String] = DetailKit.STAT_KEYS

var controller: BattleController = null
var level: LevelDefinition = null
var unit_id: int = -1
var _portrait: TextureRect
var _name: Label
var _desc: Label
var _stats: Array[Label] = []
var _public: Label
var _public_title: Label
var _editor: RuleEditor
var _traits: Label
var _runtime: Label
var _footer: Label


func setup(p_controller: BattleController, p_level: LevelDefinition) -> void:
	controller = p_controller
	level = p_level
	size = DetailKit.rel("det_panel").size          # 位置与尺寸由 HUD 摆放（框体内左上对齐）
	mouse_filter = Control.MOUSE_FILTER_PASS
	_portrait = DetailKit.portrait(self)
	_name = DetailKit.label(self, "det_title")
	_desc = DetailKit.label(self, "det_desc")
	ScrollText.wrap(_name, ScrollText.Mode.AUTO)
	_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_desc.clip_text = false
	ScrollText.wrap(_desc, ScrollText.Mode.MANUAL)
	_stats = DetailKit.stats(self)
	var body: VBoxContainer = DetailKit.scroll_body(self)
	body.add_theme_constant_override("separation", 10)
	DetailKit.top_gap(body)
	_runtime = DetailKit.section_text(body, "")
	_runtime.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	DetailKit.section_title(body, DataRegistry.get_string("ui.traits"))
	_traits = DetailKit.section_text(body, "")
	_public_title = DetailKit.section_title(body, DataRegistry.get_string("ui.public_rules"))
	_public = DetailKit.section_text(body, "")
	_editor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
	body.add_child(_editor)
	_editor.setup(controller, level)
	DetailKit.footer_line(self)
	DetailKit.footer_tab(self)
	_footer = DetailKit.label(self, "det_beacons", DataRegistry.get_string("ui.enemy_rules_footer"))
	show_unit(-1)


func show_unit(p_unit_id: int) -> void:
	unit_id = p_unit_id
	var u: SimUnit = _unit()
	visible = u != null
	if u == null:
		return
	_name.text = RuleText.unit_name(u, level)
	UiKit.set_portrait(_portrait, str(u.def.visuals.get("portrait", "")), Palette.FLESH)
	_desc.text = u.def.description
	_public.text = u.def.public_rule_text
	_public.visible = u.def.public_rule_text != ""
	_public_title.visible = _public.visible
	_editor.show_enemy(unit_id)
	var trait_lines: PackedStringArray = PackedStringArray()
	for tid: String in u.def.traits:
		var tdef: TraitDefinition = DataRegistry.get_trait(tid)
		if tdef != null:
			trait_lines.append(tdef.public_text)
	_traits.text = "\n".join(trait_lines) if not trait_lines.is_empty() else DataRegistry.get_string("ui.none")
	_update()


func _unit() -> SimUnit:
	if unit_id < 0 or controller == null or controller.world == null:
		return null
	return controller.world.get_unit(unit_id)


func _process(_delta: float) -> void:
	if visible:
		_update()


func _update() -> void:
	var u: SimUnit = _unit()
	if u == null:
		return
	var values: Array[String] = RuleText.stat_values(u, u.def)
	for i: int in _stats.size():
		_stats[i].text = values[i]
	var running: bool = controller.phase != SimTypes.Phase.DEPLOY and u.alive
	_runtime.visible = running
	if running:
		var target_name: String = RuleText.unit_name(controller.world.get_unit(u.current_target), level) if u.current_target >= 0 else DataRegistry.get_string("ui.none")
		var lines: PackedStringArray = PackedStringArray([RuleText.label_value("ui.current_target", target_name)])
		if u.current_rule < 0:
			lines.append(RuleText.label_value("ui.current_rule", RuleText.state_text(u)))
		for tid: String in u.def.traits:
			var tdef: TraitDefinition = DataRegistry.get_trait(tid)
			if tdef == null:
				continue
			var cd: float = float(u.trait_state.get(tid, tdef.first_delay))
			var trait_name: String = RuleText.s("names.traits." + str(SimTypes.TraitType.keys()[tdef.type]).to_lower())
			if cd > SimTypes.TIME_EPS:
				lines.append(RuleText.s("ui.trait_next").format({ "name": trait_name, "seconds": "%.1f" % cd }))
			else:
				lines.append(RuleText.s("ui.trait_ready").format({ "name": trait_name }))
		_runtime.text = "\n".join(lines)


func stretch(extra: float) -> void:
	DetailKit.stretch(self, extra)
