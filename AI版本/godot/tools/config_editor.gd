extends Control
## 第五阶段（2026-10-17 会议）关卡与教学配置器（开发工具，不进导出包）：统一编辑 data/teaching.json。
## 打开：主菜单按 F10，或命令行 `Godot --path . -- --config-editor`。
## 左侧选关卡（顺序 = 现有关卡编号），右侧四页：
##   关卡配置：出场 / 部署区 / 胜负数值 / 敌方与预置单位 / 关卡加成（tools/config_level_page.gd）；「试玩本关」用未保存的配置进入该关
##   引导步骤：步骤增删 / 排序、文字、推进方式、高亮目标；「拾取」进入该关点选界面元素或地块；「预览」带当前未保存的步骤进入该关
##   解锁表：本关 allowed（行为 / 条件 / 目标选择）与通关奖励解锁；覆盖写入 teaching.json，可一键恢复关卡原值；全部关卡总览，可导出 Markdown
##   提示文案：机制提示（briefing.mechanic_hint）与四层提示，可用关卡原文
## 「保存」写 teaching.json 并重新加载全部数据校验；第七关数据冻结，只能配置引导。UI 为开发工具用默认主题，文案直接写在本工具里（不进游戏）。
## 配置包（数值策划 → 程序）：「导出配置包」把当前 teaching.json 内容（须校验通过）连同备注写成 ../exports/关卡配置包_<时间>.json；
## 「导入配置包」读包 → 校验 → 列出各关改动 → 确认后备份现有 teaching.json（../exports/备份/）、写入、重新加载，并在 docs/CHANGELOG.md 记一行。

const TEACHING_PATH: String = "res://data/teaching.json"
const LEVEL_DIR: String = "res://data/levels/"
const UNLOCK_TABLE_PATH: String = "../docs/15_指令解锁表.md"
const ADVANCE_LABELS: Dictionary = { "next": "下一步按钮", "click": "点击高亮处", "tap": "点击任意处", "event": "等待事件" }
const EVENT_LABELS: Dictionary = { "deployed": "放下单位", "ally_selected": "选中己方", "enemy_selected": "选中敌人", "beacon_placed": "放置信标",
	"beacon_mode": "进入信标模式", "rules_changed": "修改指令", "battle_started": "开始战斗", "drag_started": "开始拖动出场卡", "beacon_mode_exit": "退出信标模式" }
const BLOCK_LABELS: Array[String] = ["自动", "只放行高亮处", "不拦截"]
const KIND_LABELS: Dictionary = { "ui": "界面元素", "cell": "地块", "cells": "多个地块", "deploy_zone": "部署区", "unit": "预置单位", "ally": "第一名己方",
	"blocked": "全部障碍格", "ring": "视野 / 射程圈", "none": "无高亮" }
const RING_LABELS: Dictionary = { "vision": "视野圈", "attack": "射程圈" }
const REWARD_KEYS: Array[String] = ["unlock_actions", "unlock_conditions", "unlock_selectors", "unlock_forms", "unlock_presets"]
const LEVEL_PAGE: GDScript = preload("res://tools/config_level_page.gd")
const PACK_FORMAT: String = "rengong-shenling-level-config"
const PACK_VERSION: int = 1
const EXPORT_DIR: String = "../exports"

var teaching_path: String = TEACHING_PATH   ## 测试可改到 user://
var export_dir: String = ""                 ## 配置包导出目录（绝对路径；空 = 项目旁的 exports/）
var backup_dir: String = ""                 ## 导入前备份目录（空 = exports/备份/）
var changelog_path: String = ""             ## 导入后追加记录的文件（空 = docs/CHANGELOG.md；测试可指向临时文件）
var doc: Dictionary = {}
var level_ids: Array[String] = []
var raw_levels: Dictionary = {}           ## level_id -> 关卡 JSON 原值（不含覆盖）
var cur_level: String = ""
var cur_step: int = -1
var cur_target: int = -1
var dirty: bool = false
var _filling: bool = false                ## 回填控件时不触发写回

var _status: Label
var _levels: ItemList
var _tabs: TabContainer
var _level_page: ScrollContainer
var _pack_note: LineEdit
var _import_dialog: FileDialog
var _confirm: ConfirmationDialog
var _pending_pack: Dictionary = {}
# 引导页
var _test: CheckBox
var _steps: ItemList
var _form: VBoxContainer
var _f_title: LineEdit
var _f_text: TextEdit
var _f_advance: OptionButton
var _f_event: OptionButton
var _f_block: OptionButton
var _f_arrow: OptionButton
var _f_panel: OptionButton
var _f_phase: OptionButton
var _f_after: SpinBox
var _f_count: SpinBox
var _f_deselect: CheckBox
var _targets: ItemList
var _t_node: LineEdit
var _t_zoom: SpinBox
var _t_cells: LineEdit
var _t_spawn: OptionButton
var _t_ring: OptionButton
var _t_ring_of: OptionButton
# 解锁页
var _unlock_note: Label
var _unlock_boxes: Dictionary = {}        ## "allowed.actions" / "rewards.unlock_actions" … -> { id: CheckBox }
var _unlock_overview: TextEdit
# 提示页
var _mech_custom: CheckBox
var _mech_text: TextEdit
var _hints_custom: CheckBox
var _hint_texts: Array[TextEdit] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if DataRegistry.preview_active:          # 从「试玩本关」回来：还原被临时替换的关卡定义
		DataRegistry.load_all()
	level_ids = DataRegistry.get_level_list()
	for lid: String in level_ids:
		raw_levels[lid] = _read_json(LEVEL_DIR + lid + ".json")
	var st: Dictionary = GameState.config_editor_state
	doc = (st["doc"] as Dictionary).duplicate(true) if st.get("doc", null) is Dictionary else _read_json(teaching_path)
	dirty = bool(st.get("dirty", false))
	if not doc.get("levels", null) is Dictionary:
		doc["levels"] = {}
	_build()
	var sel: String = str(st.get("level", level_ids[0] if not level_ids.is_empty() else ""))
	_select_level(sel)
	_tabs.current_tab = int(st.get("tab", 0))
	cur_step = int(st.get("step", -1))
	_refresh_steps()
	_apply_pick_result(st)
	GameState.config_editor_state = {}
	_set_status("已载入 teaching.json" + ("（有未保存的修改）" if dirty else ""))


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v as Dictionary if v is Dictionary else {}


# ---- 搭界面 ----
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 12)
	add_child(outer)
	var col := VBoxContainer.new()
	outer.add_child(col)
	var bar := HBoxContainer.new()
	col.add_child(bar)
	var title := Label.new()
	title.text = "关卡与教学配置器（data/teaching.json）"
	bar.add_child(title)
	_pack_note = LineEdit.new()
	_pack_note.placeholder_text = "配置包备注（作者 / 改了什么）"
	_pack_note.custom_minimum_size = Vector2(260, 0)
	bar.add_child(_pack_note)
	bar.add_child(_btn("导出配置包", func() -> void: export_pack()))
	bar.add_child(_btn("导入配置包", open_import_dialog))
	bar.add_child(_btn("打开导出文件夹", func() -> void:
		DirAccess.make_dir_recursive_absolute(export_dir_abs())
		OS.shell_open(export_dir_abs())))
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status)
	bar.add_child(_btn("校验", validate_doc))
	bar.add_child(_btn("保存", save_doc))
	bar.add_child(_btn("重新载入", _reload))
	bar.add_child(_btn("返回主菜单", func() -> void: SceneRouter.goto_main_menu()))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(split)
	_levels = ItemList.new()
	_levels.custom_minimum_size = Vector2(300, 0)
	_levels.item_selected.connect(func(i: int) -> void: _select_level(level_ids[i]))
	split.add_child(_levels)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_tabs)
	_level_page = LEVEL_PAGE.new() as ScrollContainer
	_level_page.call("setup", self)
	_tabs.add_child(_level_page)
	_build_tutorial_tab()
	_build_unlock_tab()
	_build_hint_tab()
	_fill_level_list()
	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.filters = PackedStringArray(["*.json ; 关卡配置包"])
	_import_dialog.title = "选择关卡配置包"
	_import_dialog.size = Vector2i(1100, 700)
	_import_dialog.file_selected.connect(_on_pack_selected)
	add_child(_import_dialog)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "导入关卡配置包"
	_confirm.ok_button_text = "确认导入"
	_confirm.size = Vector2i(900, 600)
	_confirm.confirmed.connect(func() -> void: apply_pack(_pending_pack))
	add_child(_confirm)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _option(items: Array, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it: Variant in items:
		var pair: Array = it as Array
		o.add_item(str(pair[0]))
		o.set_item_metadata(o.item_count - 1, pair[1])
	o.item_selected.connect(func(_i: int) -> void: cb.call())
	return o


static func _pairs(labels: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in labels.keys():
		out.append([str(labels[k]), str(k)])
	return out


static func _plain(values: Array[String]) -> Array:
	var out: Array = []
	for v: String in values:
		out.append([v, v])
	return out


func _row(parent: Control, label: String, ctl: Control) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctl)
	parent.add_child(h)
	return ctl


func _build_tutorial_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "引导步骤"
	_tabs.add_child(page)
	var top := HBoxContainer.new()
	page.add_child(top)
	_test = CheckBox.new()
	_test.text = "测试内容（标题前加「【测试】」）"
	_test.toggled.connect(func(on: bool) -> void:
		if _filling or cur_level == "":
			return
		if on:
			_entry(true)["test"] = true
		else:
			_entry(true).erase("test")
		_changed())
	top.add_child(_test)
	top.add_child(_btn("预览本关引导", preview_level))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	split.add_child(left)
	_steps = ItemList.new()
	_steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_steps.item_selected.connect(func(i: int) -> void:
		cur_step = i
		cur_target = 0
		_fill_step_form())
	left.add_child(_steps)
	var sb := HBoxContainer.new()
	left.add_child(sb)
	sb.add_child(_btn("新增", add_step))
	sb.add_child(_btn("复制", func() -> void: _dup_step()))
	sb.add_child(_btn("删除", delete_step))
	sb.add_child(_btn("上移", func() -> void: move_step(-1)))
	sb.add_child(_btn("下移", func() -> void: move_step(1)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	_f_title = _row(_form, "标题", LineEdit.new()) as LineEdit
	_f_title.text_changed.connect(func(_t: String) -> void: _write_step())
	_f_text = _row(_form, "说明文字", TextEdit.new()) as TextEdit
	_f_text.custom_minimum_size = Vector2(0, 90)
	_f_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_f_text.text_changed.connect(_write_step)
	_f_advance = _row(_form, "推进方式", _option(_pairs(ADVANCE_LABELS), _write_step)) as OptionButton
	_f_event = _row(_form, "等待的事件", _option(_pairs(EVENT_LABELS), _write_step)) as OptionButton
	_f_count = _row(_form, "累计数量（放下单位 / 放置信标）", SpinBox.new()) as SpinBox
	_f_count.min_value = 1.0
	_f_count.max_value = 99.0
	_f_count.value_changed.connect(func(_v: float) -> void: _write_step())
	_f_block = _row(_form, "点击限制", _option(_plain(BLOCK_LABELS), _write_step)) as OptionButton
	_f_arrow = _row(_form, "箭头", _option(_plain(TeachingDef.ARROWS), _write_step)) as OptionButton
	_f_panel = _row(_form, "说明框位置", _option(_plain(TeachingDef.PANELS), _write_step)) as OptionButton
	_f_phase = _row(_form, "出现阶段", _option([["部署阶段", "deploy"], ["战斗中（暂停战斗）", "running"]], _write_step)) as OptionButton
	_f_after = _row(_form, "战斗第几秒出现", SpinBox.new()) as SpinBox
	_f_after.max_value = 600.0
	_f_after.step = 0.5
	_f_after.value_changed.connect(func(_v: float) -> void: _write_step())
	_f_deselect = _row(_form, "收起侧栏", CheckBox.new()) as CheckBox
	_f_deselect.text = "出现时取消选中单位（露出被侧栏盖住的「开始」）"
	_f_deselect.toggled.connect(func(_on: bool) -> void: _write_step())
	var tl := Label.new()
	tl.text = "高亮目标（第一个 = 箭头指向）"
	_form.add_child(tl)
	_targets = ItemList.new()
	_targets.custom_minimum_size = Vector2(0, 110)
	_targets.item_selected.connect(func(i: int) -> void:
		cur_target = i
		_fill_target_fields())
	_form.add_child(_targets)
	var kinds := HBoxContainer.new()
	_form.add_child(kinds)
	for k: String in ["ui", "cell", "cells", "deploy_zone", "unit", "ally", "blocked", "ring", "none"]:
		kinds.add_child(_btn("+" + str(KIND_LABELS[k]), add_target.bind(k)))
	_t_node = _row(_form, "界面元素名", LineEdit.new()) as LineEdit
	_t_node.placeholder_text = "如 StartButton / Card_striker / BudgetBox / BeaconModeButton / Group_attack/RuleSelector / Beacon_beacon_done"
	_t_node.text_changed.connect(func(_t: String) -> void: _write_target())
	_t_zoom = _row(_form, "放大倍数（1 = 不放大）", SpinBox.new()) as SpinBox
	_t_zoom.min_value = 0.5
	_t_zoom.max_value = 2.0
	_t_zoom.step = 0.05
	_t_zoom.value_changed.connect(func(_v: float) -> void: _write_target())
	_t_cells = _row(_form, "地块 x,y; x,y", LineEdit.new()) as LineEdit
	_t_cells.text_changed.connect(func(_t: String) -> void: _write_target())
	_t_spawn = _row(_form, "预置单位", _option([], _write_target)) as OptionButton
	_t_ring = _row(_form, "圆环", _option(_pairs(RING_LABELS), _write_target)) as OptionButton
	_t_ring_of = _row(_form, "圆环所属", _option([], _write_target)) as OptionButton
	var tb := HBoxContainer.new()
	_form.add_child(tb)
	tb.add_child(_btn("拾取目标（进入该关点选）", pick_target))
	tb.add_child(_btn("删除目标", delete_target))
	tb.add_child(_btn("目标上移", func() -> void: move_target(-1)))


func _build_unlock_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "解锁表"
	_tabs.add_child(page)
	var top := HBoxContainer.new()
	page.add_child(top)
	_unlock_note = Label.new()
	_unlock_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_unlock_note)
	top.add_child(_btn("恢复本关原值", reset_unlock_override))
	top.add_child(_btn("导出解锁表（Markdown）", export_unlock_table))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var cat: CommandCatalog = DataRegistry.get_commands()
	var forms: Array[String] = []
	for uid: String in DataRegistry.get_units().keys():
		if (DataRegistry.get_unit(uid) as UnitDefinition).cost > 0:
			forms.append(uid)
	var groups: Array = [
		["allowed.actions", "本关可用行为", cat.ids("actions"), "actions"], ["allowed.conditions", "本关可用条件", cat.ids("conditions"), "conditions"],
		["allowed.selectors", "本关可用目标选择", cat.ids("selectors"), "selectors"],
		["rewards.unlock_actions", "通关解锁 · 行为", cat.ids("actions"), "actions"], ["rewards.unlock_conditions", "通关解锁 · 条件", cat.ids("conditions"), "conditions"],
		["rewards.unlock_selectors", "通关解锁 · 目标选择", cat.ids("selectors"), "selectors"], ["rewards.unlock_forms", "通关解锁 · 形态", forms, "forms"],
		["rewards.unlock_presets", "通关解锁 · 解锁键（preset.*）", cat.unlock_keys(), "presets"],
	]
	for g: Variant in groups:
		var ga: Array = g as Array
		var l := Label.new()
		l.text = str(ga[1])
		body.add_child(l)
		var flow := HFlowContainer.new()
		body.add_child(flow)
		var boxes: Dictionary = {}
		for id: String in ga[2] as Array:
			var cb := CheckBox.new()
			cb.text = _id_label(str(ga[3]), id)
			cb.toggled.connect(func(_on: bool) -> void: _write_unlock(str(ga[0])))
			flow.add_child(cb)
			boxes[id] = cb
		_unlock_boxes[str(ga[0])] = boxes
	var ol := Label.new()
	ol.text = "全部关卡总览（生效值；* = teaching.json 覆盖）"
	body.add_child(ol)
	_unlock_overview = TextEdit.new()
	_unlock_overview.editable = false
	_unlock_overview.custom_minimum_size = Vector2(0, 360)
	body.add_child(_unlock_overview)


func _build_hint_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "提示文案"
	_tabs.add_child(page)
	_mech_custom = CheckBox.new()
	_mech_custom.text = "自定义机制提示（不勾 = 用关卡原文）"
	_mech_custom.toggled.connect(func(_on: bool) -> void: _write_hints())
	page.add_child(_mech_custom)
	_mech_text = TextEdit.new()
	_mech_text.custom_minimum_size = Vector2(0, 80)
	_mech_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_mech_text.text_changed.connect(_write_hints)
	page.add_child(_mech_text)
	_hints_custom = CheckBox.new()
	_hints_custom.text = "自定义四层提示（不勾 = 用关卡原文）"
	_hints_custom.toggled.connect(func(_on: bool) -> void: _write_hints())
	page.add_child(_hints_custom)
	for i: int in 4:
		var t := TextEdit.new()
		t.custom_minimum_size = Vector2(0, 70)
		t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		t.text_changed.connect(_write_hints)
		page.add_child(t)
		_hint_texts.append(t)


func _id_label(kind: String, id: String) -> String:
	var cat: CommandCatalog = DataRegistry.get_commands()
	match kind:
		"actions":
			return "%s %s%s" % [DataRegistry.get_string("names.actions." + id), id, "" if cat.is_player(id) else "（仅敌人/旧数据）"]
		"conditions":
			return "%s %s" % [DataRegistry.get_string("names.conditions." + id), id]
		"selectors":
			return "%s %s%s" % [DataRegistry.get_string("names.selectors." + id), id, "" if cat.is_player_selector(id) else "（仅敌人/旧数据）"]
		"forms":
			return "%s %s" % [(DataRegistry.get_unit(id) as UnitDefinition).display_name, id]
	return id


# ---- 关卡 ----
func _fill_level_list() -> void:
	_levels.clear()
	for lid: String in level_ids:
		var L: LevelDefinition = DataRegistry.get_level(lid)
		var e: Dictionary = _entry(false, lid)
		var tags: PackedStringArray = PackedStringArray()
		if not (((e.get("tutorial", {}) as Dictionary).get("steps", []) as Array).is_empty()):
			tags.append("引导")
		for k: String in TeachingDef.OVERRIDE_KEYS:
			if e.has(k):
				tags.append("覆盖")
				break
		if bool(e.get("test", false)):
			tags.append("测试")
		_levels.add_item("第%d关 %s  %s%s" % [L.display_index, L.title, lid, ("  [" + "·".join(tags) + "]") if not tags.is_empty() else ""])


func _select_level(lid: String) -> void:
	if not level_ids.has(lid):
		return
	cur_level = lid
	_levels.select(level_ids.find(lid))
	cur_step = 0 if not _steps_of().is_empty() else -1
	cur_target = 0
	_filling = true
	_test.button_pressed = bool(_entry(false).get("test", false))
	_t_spawn.clear()
	_t_ring_of.clear()
	_t_ring_of.add_item("第一名己方")
	_t_ring_of.set_item_metadata(0, "")
	for s: Variant in (raw_levels[lid] as Dictionary).get("initial_units", []) as Array:
		var sid: String = str((s as Dictionary).get("id", ""))
		for o: OptionButton in [_t_spawn, _t_ring_of]:
			o.add_item("%s（%s）" % [sid, str((s as Dictionary).get("unit", ""))])
			o.set_item_metadata(o.item_count - 1, sid)
	_filling = false
	_refresh_steps()
	_fill_unlocks()
	_fill_hints()
	_level_page.call("fill", lid)


## teaching.json 中本关条目；create = 没有时新建
func _entry(create: bool, lid: String = "") -> Dictionary:
	var id: String = lid if lid != "" else cur_level
	var levels: Dictionary = doc["levels"] as Dictionary
	if not levels.has(id):
		if not create:
			return {}
		levels[id] = {}
	return levels[id] as Dictionary


func _steps_of(create: bool = false) -> Array:
	var e: Dictionary = _entry(create)
	if e.is_empty() and not create:
		return []
	if not e.get("tutorial", null) is Dictionary:
		if not create:
			return []
		e["tutorial"] = { "steps": [] }
	var t: Dictionary = e["tutorial"] as Dictionary
	if not t.get("steps", null) is Array:
		t["steps"] = []
	return t["steps"] as Array


func _changed() -> void:
	dirty = true
	_set_status("有未保存的修改")
	_fill_level_list()
	_levels.select(level_ids.find(cur_level))


func _set_status(t: String) -> void:
	_status.text = t


# ---- 引导步骤 ----
func _refresh_steps() -> void:
	_steps.clear()
	var steps: Array = _steps_of()
	for i: int in steps.size():
		var s: Dictionary = steps[i] as Dictionary
		_steps.add_item("%d. %s  [%s]" % [i + 1, str(s.get("title", "")) if str(s.get("title", "")) != "" else str(s.get("text", "")).left(16), str(ADVANCE_LABELS.get(str(s.get("advance", "next")), ""))])
	cur_step = clampi(cur_step, -1, steps.size() - 1)
	if cur_step >= 0:
		_steps.select(cur_step)
	_fill_step_form()


func _step() -> Dictionary:
	var steps: Array = _steps_of()
	return steps[cur_step] as Dictionary if cur_step >= 0 and cur_step < steps.size() else {}


func add_step() -> void:
	var steps: Array = _steps_of(true)
	steps.insert(cur_step + 1, { "title": "", "text": "新步骤说明", "targets": [], "advance": "next" })
	cur_step += 1
	_refresh_steps()
	_changed()


func _dup_step() -> void:
	var s: Dictionary = _step()
	if s.is_empty():
		return
	_steps_of(true).insert(cur_step + 1, s.duplicate(true))
	cur_step += 1
	_refresh_steps()
	_changed()


func delete_step() -> void:
	var steps: Array = _steps_of()
	if cur_step < 0 or cur_step >= steps.size():
		return
	steps.remove_at(cur_step)
	cur_step = mini(cur_step, steps.size() - 1)
	_refresh_steps()
	_changed()


func move_step(d: int) -> void:
	var steps: Array = _steps_of()
	var to: int = cur_step + d
	if cur_step < 0 or to < 0 or to >= steps.size():
		return
	var s: Variant = steps[cur_step]
	steps.remove_at(cur_step)
	steps.insert(to, s)
	cur_step = to
	_refresh_steps()
	_changed()


static func _select_meta(o: OptionButton, value: String) -> void:
	for i: int in o.item_count:
		if str(o.get_item_metadata(i)) == value:
			o.select(i)
			return


static func _meta(o: OptionButton) -> String:
	return str(o.get_item_metadata(o.selected)) if o.selected >= 0 else ""


func _fill_step_form() -> void:
	var s: Dictionary = _step()
	_form.visible = not s.is_empty()
	if s.is_empty():
		return
	_filling = true
	_f_title.text = str(s.get("title", ""))
	_f_text.text = str(s.get("text", ""))
	_select_meta(_f_advance, str(s.get("advance", "next")))
	_select_meta(_f_event, str(s.get("event", "deployed")))
	_f_block.select(0 if not s.has("block") else (1 if bool(s["block"]) else 2))
	_select_meta(_f_arrow, str(s.get("arrow", "auto")))
	_select_meta(_f_panel, str(s.get("panel", "auto")))
	_select_meta(_f_phase, str(s.get("phase", "deploy")))
	_f_after.value = float(s.get("after", 0.0))
	_f_count.value = float(s.get("count", 1))
	_f_deselect.button_pressed = bool(s.get("deselect", false))
	_f_event.disabled = str(s.get("advance", "next")) != "event"
	_f_count.editable = _counted_event(s)
	_filling = false
	_refresh_targets()


func _write_step() -> void:
	if _filling:
		return
	var s: Dictionary = _step()
	if s.is_empty():
		return
	s["title"] = _f_title.text
	s["text"] = _f_text.text
	s["advance"] = _meta(_f_advance)
	if s["advance"] == "event":
		s["event"] = _meta(_f_event)
	else:
		s.erase("event")
	match _f_block.selected:
		1:
			s["block"] = true
		2:
			s["block"] = false
		_:
			s.erase("block")
	for key: String in ["arrow", "panel", "phase"]:
		var o: OptionButton = { "arrow": _f_arrow, "panel": _f_panel, "phase": _f_phase }[key] as OptionButton
		var v: String = _meta(o)
		if v == ("deploy" if key == "phase" else "auto"):
			s.erase(key)
		else:
			s[key] = v
	if _f_after.value > 0.0:
		s["after"] = _f_after.value
	else:
		s.erase("after")
	if _f_deselect.button_pressed:
		s["deselect"] = true
	else:
		s.erase("deselect")
	if _counted_event(s) and int(_f_count.value) > 1:
		s["count"] = int(_f_count.value)
	else:
		s.erase("count")
	_f_event.disabled = s["advance"] != "event"
	_f_count.editable = _counted_event(s)
	var keep: int = cur_step
	_changed()
	_steps.set_item_text(keep, "%d. %s  [%s]" % [keep + 1, str(s["title"]) if str(s["title"]) != "" else str(s["text"]).left(16), str(ADVANCE_LABELS.get(str(s["advance"]), ""))])


static func _counted_event(s: Dictionary) -> bool:
	return str(s.get("advance", "")) == "event" and TeachingDef.COUNTED_EVENTS.has(str(s.get("event", "")))


# ---- 目标 ----
func _targets_of() -> Array:
	var s: Dictionary = _step()
	if s.is_empty():
		return []
	if not s.get("targets", null) is Array:
		s["targets"] = []
	return s["targets"] as Array


static func target_label(t: Dictionary) -> String:
	var k: String = str(t.get("kind", ""))
	var detail: String = ""
	match k:
		"ui":
			detail = str(t.get("node", ""))
			if float(t.get("zoom", 1.0)) != 1.0:
				detail += " ×%s" % str(t["zoom"])
		"ring":
			detail = "%s %s" % [str(RING_LABELS.get(str(t.get("ring", "vision")), "")), str(t.get("spawn", "")) if str(t.get("spawn", "")) != "" else "第一名己方"]
		"cell":
			detail = str(t.get("cell", []))
		"cells":
			detail = str(t.get("cells", []))
		"unit":
			detail = str(t.get("spawn", ""))
	return "%s %s" % [str(KIND_LABELS.get(k, k)), detail]


func _refresh_targets() -> void:
	_targets.clear()
	var ts: Array = _targets_of()
	for t: Variant in ts:
		_targets.add_item(target_label(t as Dictionary))
	cur_target = clampi(cur_target, -1, ts.size() - 1)
	if cur_target >= 0:
		_targets.select(cur_target)
	_fill_target_fields()


func _target() -> Dictionary:
	var ts: Array = _targets_of()
	return ts[cur_target] as Dictionary if cur_target >= 0 and cur_target < ts.size() else {}


func _fill_target_fields() -> void:
	var t: Dictionary = _target()
	var k: String = str(t.get("kind", ""))
	_filling = true
	_t_node.editable = k == "ui"
	_t_node.text = str(t.get("node", ""))
	_t_zoom.editable = k == "ui"
	_t_zoom.value = float(t.get("zoom", 1.0))
	_t_ring.disabled = k != "ring"
	_select_meta(_t_ring, str(t.get("ring", "vision")))
	_t_ring_of.disabled = k != "ring"
	_select_meta(_t_ring_of, str(t.get("spawn", "")) if k == "ring" else "")
	_t_cells.editable = k == "cell" or k == "cells"
	_t_cells.text = cells_to_text([t["cell"]] if k == "cell" and t.has("cell") else (t.get("cells", []) as Array if k == "cells" else []))
	_t_spawn.disabled = k != "unit"
	_select_meta(_t_spawn, str(t.get("spawn", "")))
	_filling = false


static func cells_to_text(cells: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Variant in cells:
		var a: Array = c as Array
		if a.size() == 2:
			parts.append("%d,%d" % [int(a[0]), int(a[1])])
	return "; ".join(parts)


static func text_to_cells(text: String) -> Array:
	var out: Array = []
	for part: String in text.split(";", false):
		var xy: PackedStringArray = part.strip_edges().split(",", false)
		if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
			out.append([int(xy[0]), int(xy[1])])
	return out


func add_target(kind: String) -> void:
	if _step().is_empty():
		return
	var t: Dictionary = { "kind": kind }
	match kind:
		"ui":
			t["node"] = "StartButton"
		"cell":
			t["cell"] = [0, 0]
		"cells":
			t["cells"] = [[0, 0]]
		"unit":
			t["spawn"] = _meta(_t_spawn) if _t_spawn.item_count > 0 else ""
		"ring":
			t["ring"] = "vision"
	var ts: Array = _targets_of()
	ts.append(t)
	cur_target = ts.size() - 1
	_refresh_targets()
	_changed()


func _write_target() -> void:
	if _filling:
		return
	var t: Dictionary = _target()
	if t.is_empty():
		return
	match str(t["kind"]):
		"ui":
			t["node"] = _t_node.text.strip_edges()
			if is_equal_approx(_t_zoom.value, 1.0):
				t.erase("zoom")
			else:
				t["zoom"] = _t_zoom.value
		"ring":
			t["ring"] = _meta(_t_ring)
			if _meta(_t_ring_of) == "":
				t.erase("spawn")
			else:
				t["spawn"] = _meta(_t_ring_of)
		"cell":
			var cs: Array = text_to_cells(_t_cells.text)
			if not cs.is_empty():
				t["cell"] = cs[0]
		"cells":
			t["cells"] = text_to_cells(_t_cells.text)
		"unit":
			t["spawn"] = _meta(_t_spawn)
	_targets.set_item_text(cur_target, target_label(t))
	_changed()


func delete_target() -> void:
	var ts: Array = _targets_of()
	if cur_target < 0 or cur_target >= ts.size():
		return
	ts.remove_at(cur_target)
	cur_target = mini(cur_target, ts.size() - 1)
	_refresh_targets()
	_changed()


func move_target(d: int) -> void:
	var ts: Array = _targets_of()
	var to: int = cur_target + d
	if cur_target < 0 or to < 0 or to >= ts.size():
		return
	var t: Variant = ts[cur_target]
	ts.remove_at(cur_target)
	ts.insert(to, t)
	cur_target = to
	_refresh_targets()
	_changed()


# ---- 拾取 / 预览（进入战斗场景，返回时恢复未保存的编辑）----
func _stash(extra: Dictionary = {}) -> void:
	var st: Dictionary = { "doc": doc.duplicate(true), "dirty": dirty, "level": cur_level, "tab": _tabs.current_tab, "step": cur_step }
	st.merge(extra, true)
	GameState.config_editor_state = st


func pick_target() -> void:
	if _step().is_empty():
		_set_status("先选一个步骤")
		return
	_stash({ "pick_step": cur_step, "pick_target": cur_target })
	GameState.tutorial_pick = { "active": true, "level_id": cur_level }
	GameState.tutorial_pick_result = {}
	SceneRouter.goto_battle(cur_level)


## 拾取返回：替换选中的目标（没有选中则追加）
func _apply_pick_result(st: Dictionary) -> void:
	var res: Dictionary = GameState.tutorial_pick_result
	GameState.tutorial_pick_result = {}
	GameState.tutorial_pick = {}
	if res.is_empty() or not st.has("pick_step"):
		return
	cur_step = int(st["pick_step"])
	_refresh_steps()
	var ts: Array = _targets_of()
	var ti: int = int(st.get("pick_target", -1))
	if ti >= 0 and ti < ts.size():
		ts[ti] = res.duplicate(true)
	else:
		ts.append(res.duplicate(true))
		ti = ts.size() - 1
	cur_target = ti
	_refresh_targets()
	_changed()
	_set_status("已拾取：" + target_label(res))


## 关卡配置页「试玩本关」：用本关未保存的覆盖项临时替换关卡定义后进入（不出现引导；回到配置器时还原）
func play_level() -> bool:
	if cur_level == "":
		return false
	var msgs: Array[String] = DataRegistry.preview_level(cur_level, _clean(_entry(false)) as Dictionary)
	if not msgs.is_empty():
		_set_status("本关配置有问题，不能试玩：%s" % msgs[0])
		return false
	_stash()
	GameState.tutorial_preview = { "level_id": cur_level, "steps": [] }
	SceneRouter.goto_battle(cur_level)
	return true


func preview_level() -> void:
	if cur_level == "":
		return
	_stash()
	GameState.tutorial_preview = { "level_id": cur_level, "steps": _steps_of().duplicate(true), "test": bool(_entry(false).get("test", false)) }
	SceneRouter.goto_battle(cur_level)


# ---- 解锁表 ----
func _effective(lid: String, section: String) -> Dictionary:
	var raw: Dictionary = ((raw_levels[lid] as Dictionary).get(section, {}) as Dictionary).duplicate(true)
	var ov: Variant = _entry(false, lid).get(section, null)
	if ov is Dictionary:
		for k: String in (ov as Dictionary).keys():
			raw[k] = (ov as Dictionary)[k]
	return raw


func _fill_unlocks() -> void:
	if cur_level == "":
		return
	var frozen: bool = cur_level == TeachingDef.FROZEN_LEVEL
	var e: Dictionary = _entry(false)
	_unlock_note.text = "%s：%s" % [cur_level, "第七关数据冻结，只能配置引导" if frozen else ("已有覆盖（teaching.json）" if e.has("allowed") or e.has("rewards") else "关卡原值")]
	_filling = true
	for key: String in _unlock_boxes.keys():
		var section: String = key.get_slice(".", 0)
		var field: String = key.get_slice(".", 1)
		var have: Array = _effective(cur_level, section).get(field, []) as Array
		var boxes: Dictionary = _unlock_boxes[key] as Dictionary
		for id: String in boxes.keys():
			var cb: CheckBox = boxes[id] as CheckBox
			cb.button_pressed = have.has(id)
			cb.disabled = frozen
	_filling = false
	_unlock_overview.text = unlock_table_markdown()


func _write_unlock(key: String) -> void:
	if _filling or cur_level == "" or cur_level == TeachingDef.FROZEN_LEVEL:
		return
	var section: String = key.get_slice(".", 0)
	var field: String = key.get_slice(".", 1)
	var list: Array = []
	var boxes: Dictionary = _unlock_boxes[key] as Dictionary
	for id: String in boxes.keys():
		if (boxes[id] as CheckBox).button_pressed:
			list.append(id)
	var e: Dictionary = _entry(true)
	if not e.get(section, null) is Dictionary:
		e[section] = {}
	(e[section] as Dictionary)[field] = list
	_changed()
	_fill_unlocks()


func reset_unlock_override() -> void:
	var e: Dictionary = _entry(false)
	e.erase("allowed")
	e.erase("rewards")
	_changed()
	_fill_unlocks()


## 指令逐关解锁表（生效值）：每关 可用行为 / 条件 / 目标选择 与 通关解锁
func unlock_table_markdown() -> String:
	var cat: CommandCatalog = DataRegistry.get_commands()
	var universal: PackedStringArray = PackedStringArray()
	for a: String in cat.ids("actions"):
		if cat.is_player(a) and not DeploymentValidator.action_gated(SimTypes.parse_action(a)):
			universal.append(DataRegistry.get_string("names.actions." + a))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("通用指令（每关可用，不受下表限制）：%s；条件「到达信标」同样通用。旧数据的「追击并攻击」按 追击 + 攻击 计；（旧）= 只给敌人 / 旧数据、不进玩家菜单。" % "、".join(universal))
	lines.append("")
	lines.append("| 关卡 | 可用行为（攻击组 / 移动组） | 可用条件 | 可用目标选择 | 通关解锁 | 解锁键 |")
	lines.append("|---|---|---|---|---|---|")
	for lid: String in level_ids:
		var L: LevelDefinition = DataRegistry.get_level(lid)
		var e: Dictionary = _entry(false, lid)
		var al: Dictionary = _effective(lid, "allowed")
		var rw: Dictionary = _effective(lid, "rewards")
		var acts: Array[int] = []
		for a: Variant in al.get("actions", []) as Array:
			acts.append(SimTypes.parse_action(str(a)))
		ActionDef.expand_allowed(acts)
		var atk: PackedStringArray = PackedStringArray()
		var mov: PackedStringArray = PackedStringArray()
		for key: String in cat.ids("actions"):
			var t: int = SimTypes.parse_action(key)
			if not acts.has(t) or not cat.is_player(key) or not DeploymentValidator.action_gated(t):
				continue
			(atk if SimTypes.action_group(t) == SimTypes.RuleGroup.ATTACK else mov).append(DataRegistry.get_string("names.actions." + key))
		var sels: PackedStringArray = PackedStringArray()
		for sid: Variant in al.get("selectors", []) as Array:
			sels.append(DataRegistry.get_string("names.selectors." + str(sid)) + ("" if cat.is_player_selector(str(sid)) else "（旧）"))
		var rewards: PackedStringArray = PackedStringArray()
		for k: String in ["unlock_actions", "unlock_conditions", "unlock_selectors"]:
			rewards.append_array(_names({ "unlock_actions": "actions", "unlock_conditions": "conditions", "unlock_selectors": "selectors" }[k] as String, rw.get(k, []) as Array).split("、", false))
		for f: Variant in rw.get("unlock_forms", []) as Array:
			var ud: UnitDefinition = DataRegistry.get_unit(str(f))
			rewards.append("形态·" + (ud.display_name if ud != null else str(f)))
		lines.append("| %s第%d关 %s（%s） | %s / %s | %s | %s | %s | %s |" % ["*" if e.has("allowed") or e.has("rewards") else "", L.display_index, L.title, lid,
			"、".join(atk) if not atk.is_empty() else "—", "、".join(mov) if not mov.is_empty() else "—",
			_names("conditions", al.get("conditions", []) as Array), "、".join(sels), "、".join(rewards),
			"、".join((rw.get("unlock_presets", []) as Array).map(func(v: Variant) -> String: return str(v).trim_prefix("preset.")))])
	return "
".join(lines)


func _names(kind: String, ids: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for id: Variant in ids:
		out.append(DataRegistry.get_string("names.%s.%s" % [kind, str(id)]))
	return "、".join(out)


func export_unlock_table() -> void:
	var path: String = ProjectSettings.globalize_path("res://").path_join(UNLOCK_TABLE_PATH).simplify_path()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("导出失败：" + path)
		return
	f.store_string("# 指令逐关解锁表（由配置器导出，生效值；* = teaching.json 覆盖）\n\n" + unlock_table_markdown() + "\n")
	f.close()
	_set_status("已导出：" + path)


# ---- 提示文案 ----
func _fill_hints() -> void:
	var e: Dictionary = _entry(false)
	var raw: Dictionary = raw_levels.get(cur_level, {}) as Dictionary
	var frozen: bool = cur_level == TeachingDef.FROZEN_LEVEL
	_filling = true
	_mech_custom.button_pressed = e.has("mechanic_hint")
	_mech_text.text = str(e.get("mechanic_hint", (raw.get("briefing", {}) as Dictionary).get("mechanic_hint", "")))
	_hints_custom.button_pressed = e.has("hints")
	var hints: Array = e.get("hints", raw.get("hints", [])) as Array
	for i: int in 4:
		_hint_texts[i].text = str(hints[i]) if i < hints.size() else ""
		_hint_texts[i].editable = not frozen
	_mech_custom.disabled = frozen
	_hints_custom.disabled = frozen
	_mech_text.editable = not frozen
	_filling = false


func _write_hints() -> void:
	if _filling or cur_level == "" or cur_level == TeachingDef.FROZEN_LEVEL:
		return
	var e: Dictionary = _entry(true)
	if _mech_custom.button_pressed:
		e["mechanic_hint"] = _mech_text.text
	else:
		e.erase("mechanic_hint")
	if _hints_custom.button_pressed:
		var hs: Array = []
		for t: TextEdit in _hint_texts:
			hs.append(t.text)
		e["hints"] = hs
	else:
		e.erase("hints")
	_changed()


# ---- 校验 / 保存 ----
## 只解析当前编辑（不写盘）：引导字段 + 覆盖后的关卡按正式加载口径校验；返回错误信息
func validate_doc() -> Array[String]:
	var msgs: Array[String] = DataRegistry.validate_teaching_doc(_clean(doc) as Dictionary)
	_set_status("校验通过" if msgs.is_empty() else "校验：%d 处问题 —— %s" % [msgs.size(), msgs[0]])
	return msgs


func _level_defs() -> Dictionary:
	var out: Dictionary = {}
	for lid: String in level_ids:
		out[lid] = DataRegistry.get_level(lid)
	return out


## 去掉空条目；整数值写成整数（JSON.stringify 会把 3.0 写成 3.0）
static func _clean(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in (v as Dictionary).keys():
			var val: Variant = _clean((v as Dictionary)[k])
			if k is String and str(k) != "levels" and val is Dictionary and (val as Dictionary).is_empty() and str(k) != "style":
				continue
			d[k] = val
		return d
	if v is Array:
		var a: Array = []
		for x: Variant in v as Array:
			a.append(_clean(x))
		return a
	if v is float and is_equal_approx(float(v), roundf(float(v))) and absf(float(v)) < 1e9:
		return int(roundf(float(v)))
	return v


func save_doc() -> void:
	var msgs: Array[String] = validate_doc()
	if not msgs.is_empty():
		return
	var out: Dictionary = _clean(doc) as Dictionary
	var f: FileAccess = FileAccess.open(teaching_path, FileAccess.WRITE)
	if f == null:
		_set_status("写入失败：" + ProjectSettings.globalize_path(teaching_path))
		return
	f.store_string(JSON.stringify(out, "  ", false) + "\n")
	f.close()
	var ok: bool = DataRegistry.load_all() if teaching_path == TEACHING_PATH else true
	dirty = false
	_fill_level_list()
	_levels.select(level_ids.find(cur_level))
	_set_status("已保存并重新加载数据：" + ("全部校验通过" if ok else "有数据错误，见日志"))


func _reload() -> void:
	doc = _read_json(teaching_path)
	if not doc.get("levels", null) is Dictionary:
		doc["levels"] = {}
	dirty = false
	_fill_level_list()
	_select_level(cur_level)
	_set_status("已重新载入")


# ---- 配置包：导出 / 导入 ----
func export_dir_abs() -> String:
	return export_dir if export_dir != "" else ProjectSettings.globalize_path("res://").path_join(EXPORT_DIR).simplify_path()


func _backup_dir_abs() -> String:
	return backup_dir if backup_dir != "" else export_dir_abs().path_join("备份")


func _changelog_abs() -> String:
	return changelog_path if changelog_path != "" else ProjectSettings.globalize_path("res://").path_join("../docs/CHANGELOG.md").simplify_path()


static func _stamp() -> String:
	return Time.get_datetime_string_from_system(false, true).replace("-", "").replace(":", "").replace(" ", "_")


## 有覆盖或引导的关卡 id（按关卡顺序）
func _configured_levels(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var lv: Dictionary = d.get("levels", {}) as Dictionary
	for lid: String in level_ids:
		if lv.has(lid) and not (lv[lid] as Dictionary).is_empty():
			out.append(lid)
	return out


## 导出：校验通过后把当前编辑（含未保存的修改）写成配置包，返回文件路径（失败 ""）
func export_pack() -> String:
	if not validate_doc().is_empty():
		return ""
	var dir: String = export_dir_abs()
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("关卡配置包_%s.json" % _stamp())
	var clean: Dictionary = _clean(doc) as Dictionary
	var pack: Dictionary = {
		"format": PACK_FORMAT, "version": PACK_VERSION,
		"exported_at": Time.get_datetime_string_from_system(false, true),
		"note": _pack_note.text.strip_edges(),
		"levels": _configured_levels(clean),
		"teaching": clean,
	}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("导出失败：" + path)
		return ""
	f.store_string(JSON.stringify(pack, "  ", false) + "\n")
	f.close()
	_set_status("已导出配置包：" + path)
	return path


func open_import_dialog() -> void:
	_import_dialog.current_dir = export_dir_abs()
	_import_dialog.popup_centered()


func _on_pack_selected(path: String) -> void:
	var pack: Dictionary = read_pack(path)
	if not bool(pack["ok"]):
		_set_status("不能导入：" + str(pack["error"]))
		return
	_pending_pack = pack
	var lines: PackedStringArray = PackedStringArray()
	lines.append("文件：%s" % path.get_file())
	lines.append("导出时间：%s　备注：%s" % [str(pack["exported_at"]), str(pack["note"]) if str(pack["note"]) != "" else "（无）"])
	if dirty:
		lines.append("注意：配置器里未保存的修改会被导入内容替换。")
	lines.append("")
	lines.append("改动：")
	lines.append_array(pack["summary"] as PackedStringArray)
	_confirm.dialog_text = "\n".join(lines)
	_confirm.popup_centered()


## 读配置包：格式检查 + 校验 + 与当前 teaching.json（已保存的）比对。返回 { ok, error, teaching, note, exported_at, summary, path }
func read_pack(path: String) -> Dictionary:
	var out: Dictionary = { "ok": false, "error": "", "teaching": {}, "note": "", "exported_at": "", "summary": PackedStringArray(), "path": path }
	if not FileAccess.file_exists(path):
		out["error"] = "文件不存在"
		return out
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not v is Dictionary or str((v as Dictionary).get("format", "")) != PACK_FORMAT or not (v as Dictionary).get("teaching", null) is Dictionary:
		out["error"] = "不是关卡配置包（format 应为 %s）" % PACK_FORMAT
		return out
	var pack: Dictionary = v as Dictionary
	if int(pack.get("version", 0)) > PACK_VERSION:
		out["error"] = "配置包版本 %d 比配置器新，请先更新工程" % int(pack.get("version", 0))
		return out
	var teaching: Dictionary = pack["teaching"] as Dictionary
	var msgs: Array[String] = DataRegistry.validate_teaching_doc(teaching)
	if not msgs.is_empty():
		out["error"] = "校验未通过（%d 处），第一处：%s" % [msgs.size(), msgs[0]]
		return out
	out["ok"] = true
	out["teaching"] = teaching
	out["note"] = str(pack.get("note", ""))
	out["exported_at"] = str(pack.get("exported_at", ""))
	out["summary"] = diff_summary(_read_json(teaching_path), teaching)
	return out


## 两份 teaching.json 的差异：逐关列出 新增 / 删除 / 修改的字段
func diff_summary(old_doc: Dictionary, new_doc: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var ol: Dictionary = old_doc.get("levels", {}) as Dictionary
	var nl: Dictionary = new_doc.get("levels", {}) as Dictionary
	for lid: String in level_ids:
		var a: Dictionary = _clean(ol.get(lid, {})) as Dictionary
		var b: Dictionary = _clean(nl.get(lid, {})) as Dictionary
		if JSON.stringify(a, "", true) == JSON.stringify(b, "", true):
			continue
		var keys: PackedStringArray = PackedStringArray()
		var all: Array = a.keys()
		for k: Variant in b.keys():
			if not all.has(k):
				all.append(k)
		for k: Variant in all:
			if JSON.stringify(a.get(k, null), "", true) != JSON.stringify(b.get(k, null), "", true):
				keys.append(("+" if not a.has(k) else ("-" if not b.has(k) else "")) + _field_label(str(k)))
		var L: LevelDefinition = DataRegistry.get_level(lid)
		lines.append("· 第%d关 %s（%s）：%s" % [L.display_index, L.title, lid, "、".join(keys)])
	if JSON.stringify(_clean(old_doc.get("style", {})), "", true) != JSON.stringify(_clean(new_doc.get("style", {})), "", true):
		lines.append("· 引导样式（style）")
	if lines.is_empty():
		lines.append("（与当前 teaching.json 相同）")
	return lines


static func _field_label(k: String) -> String:
	var names: Dictionary = { "tutorial": "引导步骤", "test": "测试标记", "allowed": "可用指令", "rewards": "通关解锁", "hints": "四层提示",
		"mechanic_hint": "机制提示", "roster": "出场", "deploy_zone": "部署区", "initial_units": "敌方与预置单位", "objectives": "胜负条件", "modifiers": "关卡加成" }
	return str(names.get(k, k))


## 导入：备份 → 写入 teaching.json → 重新加载 → 记 CHANGELOG。返回是否成功
func apply_pack(pack: Dictionary) -> bool:
	if not bool(pack.get("ok", false)):
		return false
	var bdir: String = _backup_dir_abs()
	DirAccess.make_dir_recursive_absolute(bdir)
	if FileAccess.file_exists(teaching_path):
		var bak: FileAccess = FileAccess.open(bdir.path_join("teaching_导入前_%s.json" % _stamp()), FileAccess.WRITE)
		if bak != null:
			bak.store_string(FileAccess.get_file_as_string(teaching_path))
			bak.close()
	var teaching: Dictionary = _clean(pack["teaching"]) as Dictionary
	var f: FileAccess = FileAccess.open(teaching_path, FileAccess.WRITE)
	if f == null:
		_set_status("写入失败：" + ProjectSettings.globalize_path(teaching_path))
		return false
	f.store_string(JSON.stringify(teaching, "  ", false) + "\n")
	f.close()
	var ok: bool = DataRegistry.load_all() if teaching_path == TEACHING_PATH else true
	doc = teaching.duplicate(true)
	if not doc.get("levels", null) is Dictionary:
		doc["levels"] = {}
	dirty = false
	_append_changelog(pack)
	_fill_level_list()
	_select_level(cur_level)
	_set_status("已导入配置包 %s：%s（已备份原 teaching.json；请运行测试与试玩复核）" % [str(pack["path"]).get_file(), "数据校验通过" if ok else "有数据错误，见日志"])
	return true


func _append_changelog(pack: Dictionary) -> void:
	var path: String = _changelog_abs()
	if not FileAccess.file_exists(path):
		return
	var text: String = FileAccess.get_file_as_string(path).rstrip("\n")
	var summary: String = "；".join(pack["summary"] as PackedStringArray).replace("|", "/")
	text += "\n| %s | data/teaching.json | 导入关卡配置包 `%s`（导出于 %s；备注：%s）：%s | 数值策划配置 | 导入时校验通过；需复跑 GUT / run_playtests |\n" % [
		Time.get_date_string_from_system(), str(pack["path"]).get_file(), str(pack["exported_at"]), str(pack["note"]) if str(pack["note"]) != "" else "无", summary]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
