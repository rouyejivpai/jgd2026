extends Control
## 关卡编辑器场景：左工具栏 / 中地图视图 / 右属性面板。
## 详细设计：[docs/design/07-关卡编辑器.md](../../docs/design/07-关卡编辑器.md) 1.3 / 4.1-4.4
##
## 【职责】把「改数据 → 压撤销栈 → 同步目标区 → 刷新视图与面板」这一串副作用
## 集中在一处。子控件（map_view / inspector）**只发信号**，不碰 EditorSession。
##
## 【布局】锚点 + 容器，不写绝对像素坐标（本工程硬规矩）。
## 左 260 / 右 340 固定，中间自适应 —— 1920 宽下三栏不重叠。

const EditorSessionScript := preload("res://src/editor/editor_session.gd")
const MapViewScript := preload("res://src/editor/map_view.gd")
const InspectorScript := preload("res://src/editor/inspector_panel.gd")
const LevelLoaderScript := preload("res://src/core/level/level_loader.gd")
const DataLoaderScript := preload("res://src/core/data/data_loader.gd")
const LevelDataScript := preload("res://src/core/level/level_data.gd")
const ConditionScript := preload("res://src/core/rule/condition.gd")

const LEFT_W := 260
const RIGHT_W := 340
const LEVEL_SELECT_SCENE := "res://src/ui/level_select.tscn"

## 打开哪一关（由选关界面或主菜单传入）
var level_id := "tutorial_01"

var session = null
var map_view: Control = null
var inspector: Control = null
var toolbar_box: VBoxContainer = null
var status_label: Label = null

var _loader = null
var _data = null
var _tool_buttons: Array = []


func _ready() -> void:
	_data = DataLoaderScript.new()
	_data.call("load_all")
	_loader = LevelLoaderScript.new()
	_build_ui()
	_open_level(level_id)


func load_level_id(id: String) -> void:
	level_id = id
	if is_inside_tree() and session != null:
		_open_level(id)


# ---------------------------------------------------------------------------
# 布局
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	# ---- 左：工具栏 ----
	var left := PanelContainer.new()
	left.name = "LeftBar"
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.11, 0.12, 0.16, 1.0)
	lsb.border_color = Color(0.26, 0.30, 0.38)
	lsb.border_width_right = 2
	lsb.content_margin_left = 12
	lsb.content_margin_right = 12
	lsb.content_margin_top = 12
	lsb.content_margin_bottom = 12
	left.add_theme_stylebox_override("panel", lsb)
	row.add_child(left)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)

	toolbar_box = VBoxContainer.new()
	toolbar_box.name = "Tools"
	toolbar_box.add_theme_constant_override("separation", 6)
	toolbar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(toolbar_box)
	_build_toolbar()

	# ---- 中：地图视图 ----
	var center := MarginContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.clip_contents = true
	row.add_child(center)

	map_view = MapViewScript.new()
	center.add_child(map_view)
	map_view.connect("tile_pressed", _on_tile_pressed)
	map_view.connect("tile_dragged", _on_tile_dragged)
	map_view.connect("drag_finished", _on_drag_finished)

	# ---- 右：属性面板 ----
	var right := MarginContainer.new()
	right.name = "RightBar"
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	row.add_child(right)

	inspector = InspectorScript.new()
	inspector.set("unit_type_ids", _data.call("unit_type_ids"))
	inspector.set("unit_type_names", _unit_type_names())
	right.add_child(inspector)
	inspector.connect("field_changed", _on_field_changed)
	inspector.connect("condition_added", _on_condition_added)
	inspector.connect("condition_removed", _on_condition_removed)
	inspector.connect("condition_type_changed", _on_condition_type_changed)
	inspector.connect("condition_param_changed", _on_condition_param_changed)

	# ---- 顶部状态条 ----
	# 【不能占满整宽】它是 TOP_WIDE 的浮层，占满就会**盖住左右两栏的标题**
	# （实测左栏「工具」、右栏「关卡全局」都被压掉一半）。
	# 用左右偏移把它限制在中栏范围内。
	var top := MarginContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = LEFT_W
	top.offset_right = -RIGHT_W
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("margin_top", 0)
	add_child(top)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	status_label.add_theme_stylebox_override("normal",
		_make_status_style())
	top.add_child(status_label)


func _make_status_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.13, 0.92)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _build_toolbar() -> void:
	_add_section("工具")
	_tool_buttons.clear()
	# 工具顺序与详设 1.3 的列表一致
	for spec in [[EditorSessionScript.TOOL_PAINT_EMPTY, "刷空地"],
			[EditorSessionScript.TOOL_PAINT_WALL, "刷障碍"],
			[EditorSessionScript.TOOL_PAINT_GOAL, "刷目标区"],
			[EditorSessionScript.TOOL_PLACE_UNIT, "放单位"],
			[EditorSessionScript.TOOL_ERASE, "擦除"],
			[EditorSessionScript.TOOL_SELECT, "选择/查看"]]:
		var b := Button.new()
		b.name = "Tool_%d" % int(spec[0])
		b.text = str(spec[1])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_on_tool_selected.bind(int(spec[0])))
		toolbar_box.add_child(b)
		_tool_buttons.append(b)

	_add_section("放单位时用")
	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 6)
	toolbar_box.add_child(team_row)
	for spec2 in [["ally", "我方"], ["enemy", "敌方"]]:
		var tb := Button.new()
		tb.name = "Team_" + str(spec2[0])
		tb.text = str(spec2[1])
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(0, 34)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(_on_team_selected.bind(str(spec2[0])))
		team_row.add_child(tb)

	var type_ob := OptionButton.new()
	type_ob.name = "UnitType"
	type_ob.clip_text = true
	# 【显示中文名、元数据存 id】这是"放单位时用"的类型选择。
	# 我之前只改了右侧属性面板的下拉框，**漏了左栏这一个** ——
	# 于是界面上仍能看到 `basic_enemy` 这种内部标识（用户要求"枚举选项框用中文"）。
	# 教训：界面上的**每一个**枚举控件都要一起改，改完要**扫一遍所有 add_item**。
	var names := _unit_type_names()
	for t in (_data.call("unit_type_ids") as Array):
		var tid := str(t)
		type_ob.add_item(str(names.get(tid, tid)))
		type_ob.set_item_metadata(type_ob.item_count - 1, tid)
	type_ob.item_selected.connect(func(i: int) -> void:
		if session != null:
			session.set("selected_unit_type", str(type_ob.get_item_metadata(i))))
	toolbar_box.add_child(type_ob)

	# 【左上角第一区：关卡】用户实测反馈"编辑器不知道怎么打开某一关" ——
	# 原来编辑器**启动就自动打开第一关**，界面上只有「新建关卡」和「返回选关」，
	# **没有"打开某一关"的路**。打开与新建都属"关卡级"操作，放一起。
	_add_section("关卡")
	_add_action("打开关卡…", _do_open_level_menu, "BtnOpenLevel")
	_add_action("新建关卡", _do_new_level, "BtnNew")

	_add_section("操作")
	_add_action("关卡全局设置", _do_show_global, "BtnGlobal")
	_add_action("撤销（Ctrl+Z）", _do_undo, "BtnUndo")
	_add_action("重做（Ctrl+Y）", _do_redo, "BtnRedo")
	_add_action("保存", _do_save, "BtnSave")
	_add_action("一键试玩", _do_playtest, "BtnPlaytest")
	_add_action("返回选关", _do_back, "BtnBack")

	_add_section("视图")
	_add_action("看全地图", func() -> void: map_view.call("fit_to_view"), "BtnFit")
	_add_note("滚轮缩放 · 中键拖动平移")


## 单位类型 id → 中文显示名（来自 units.json 的 `name`）。
## 属性面板拿它当下拉框标签，**数据里存的仍是 id**。
func _unit_type_names() -> Dictionary:
	if _data == null:
		return {}
	return _data.call("unit_display_names")


## 「关卡全局设置」按钮：清空选中，让右侧属性面板回到**关卡全局**视图。
##
## 【为什么要一个按钮】属性面板是"跟着选中走的"：一旦点了格子或单位，
## 全局设置（id / 名称 / 信标配额 / 信号数 / 地图尺寸 / 介绍 / 胜负条件）
## 就从面板上消失了，而**没有任何可见入口能回去** ——
## 原来的做法是"点地图上的空地"，但地图上到处都是格子，
## 玩家很难想到"点空白处等于回到全局"（用户实测反馈要求加按钮）。
func _do_show_global() -> void:
	if session == null:
		return
	session.set("selection", {})
	inspector.call("refresh")
	_set_status("已切到「关卡全局设置」", false)


## 「打开关卡」列表的内容：**关卡名称 + id**。
##
## 【为什么单独抽一个函数】用例要能断言"列表项显示的是**名称**而不是 id"，
## 而菜单是临时 UI 对象。把"列表内容从哪来"抽出来，菜单与用例就不会各写一套、
## 慢慢漂移。
func level_menu_entries() -> Array:
	var out: Array = []
	for id in (_loader.call("list_level_ids") as Array):
		var res: Dictionary = _loader.call("load_level", str(id), _data.call("unit_type_ids"))
		var nm := str(id)
		if bool(res.get("ok")):
			nm = str((res.get("level") as RefCounted).get("name"))
		out.append({"id": str(id), "name": nm})
	return out


## 弹出「打开关卡」菜单（左栏「打开关卡…」按钮）。
##
## 列表项显示关卡的**名称**（如「第一关 · 初识信标」）而不是 id —— 玩家认的是名字。
## 元数据里存的仍是 id，选中后按 id 打开。
func _do_open_level_menu() -> void:
	var entries := level_menu_entries()
	if entries.is_empty():
		_set_status("没有可打开的关卡（manifest 为空？）", true)
		return
	var menu := PopupMenu.new()
	menu.name = "OpenLevelMenu"
	for e in entries:
		var d: Dictionary = e
		menu.add_item(str(d.get("name")))
		menu.set_item_metadata(menu.item_count - 1, str(d.get("id")))
	menu.id_pressed.connect(func(idx: int) -> void:
		var want := str(menu.get_item_metadata(idx))
		menu.queue_free()
		request_open_level(want))
	# 关掉菜单（按 ESC / 点别处）也要释放，否则会越堆越多
	menu.popup_hide.connect(func() -> void:
		if is_instance_valid(menu):
			menu.queue_free())
	add_child(menu)
	# 弹在按钮下方；拿不到按钮就居中
	var btn := toolbar_box.get_node_or_null("BtnOpenLevel") as Control
	if btn != null:
		menu.position = Vector2i(int(btn.global_position.x),
			int(btn.global_position.y + btn.size.y))
	menu.popup()


## 请求打开某一关 —— **有未保存改动时先确认**。
##
## 【为什么必须问一句】打开另一关会把当前 session 整个换掉，
## 未保存的编辑**直接消失**。这个环境里保存又常常失败（见开发进度第 13 轮），
## 所以"默默丢掉"的代价可能很大。宁可多一次确认。
func request_open_level(id: String) -> void:
	if session != null and bool(session.get("dirty")):
		var dlg := ConfirmationDialog.new()
		dlg.name = "UnsavedConfirm"
		dlg.title = "有未保存的改动"
		dlg.dialog_text = "当前关卡有未保存的改动，打开「%s」会丢掉它们。仍要打开吗？" % id
		dlg.ok_button_text = "放弃改动并打开"
		dlg.cancel_button_text = "取消"
		add_child(dlg)
		dlg.confirmed.connect(func() -> void:
			dlg.queue_free()
			_open_level_confirmed(id))
		dlg.canceled.connect(func() -> void:
			if is_instance_valid(dlg):
				dlg.queue_free())
		dlg.popup_centered()
		return
	_open_level_confirmed(id)


## 真的打开（已确认 / 本来就不脏）
func _open_level_confirmed(id: String) -> void:
	level_id = id
	_open_level(id)


func _add_section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	toolbar_box.add_child(l)


func _add_action(text: String, handler: Callable, btn_name: String) -> Button:
	var b := Button.new()
	b.name = btn_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(handler)
	toolbar_box.add_child(b)
	return b


func _add_note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.60, 0.64, 0.72))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toolbar_box.add_child(l)


# ---------------------------------------------------------------------------
# 关卡装配
# ---------------------------------------------------------------------------

func _open_level(id: String) -> void:
	var res: Dictionary = _loader.call("load_level", id, _data.call("unit_type_ids"))
	if not bool(res.get("ok")):
		_set_status("打开关卡失败：%s" % str(res.get("errors")), true)
		return
	var lv = res.get("level")
	session = EditorSessionScript.new()
	session.call("setup", lv, str(res.get("path")))
	map_view.set("session", session)
	inspector.set("session", session)
	inspector.set("unit_type_ids", _data.call("unit_type_ids"))
	inspector.set("unit_type_names", _unit_type_names())
	map_view.call("fit_to_view")
	_sync_tool_buttons()
	inspector.call("refresh")
	_set_status("已打开 %s（%d×%d，%d 个单位）" % [
		id, int(session.call("map_width")), int(session.call("map_height")),
		int(session.call("unit_count"))], false)


## `res://` 是否可写。用「尝试在 res:// 下创建临时文件」来判断，
## 比看 OS.has_feature("editor") 更可靠（导出版与调试版都可能被系统权限拦住）。
##
## 【注意】这里**只做探测、不存进 session** —— EditorSession 没有这个属性，
## 而 `Object.set()` 对不存在的属性是静默失败（本工程踩过）。
## 保存流程本来就是"先试 res://、失败回退 user://"，不需要一个额外标志位。
func _can_write_res() -> bool:
	var probe := "res://data/levels/.__write_probe"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("1")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	return true


# ---------------------------------------------------------------------------
# 编辑操作：数据改动 + 压栈 + 同步 + 刷新，都走这里
# ---------------------------------------------------------------------------

func _on_tool_selected(tool: int) -> void:
	if session == null:
		return
	session.set("active_tool", tool)
	_sync_tool_buttons()


func _on_team_selected(team: String) -> void:
	if session == null:
		return
	session.set("selected_team", team)
	_sync_tool_buttons()


func _sync_tool_buttons() -> void:
	if session == null:
		return
	for b in _tool_buttons:
		var t := int(str((b as Button).name).substr(5))
		(b as Button).button_pressed = (t == int(session.get("active_tool")))
	for team in ["ally", "enemy"]:
		var tb := toolbar_box.find_child("Team_" + team, true, false)
		if tb is Button:
			(tb as Button).button_pressed = (team == str(session.get("selected_team")))


func _on_tile_pressed(x: int, y: int, button: int) -> void:
	if session == null:
		return
	# 一次拖拽算一次撤销事务（详设 07 的 3.2「粒度」）
	session.call("begin_transaction")
	_apply_at(x, y, button, true)


func _on_tile_dragged(x: int, y: int) -> void:
	if session == null:
		return
	_apply_at(x, y, MOUSE_BUTTON_LEFT, false)


func _on_drag_finished() -> void:
	if session == null:
		return
	session.call("end_transaction")
	inspector.call("refresh")


## 在某格应用当前工具。`select_only` 为真时（第一次按下）总是更新选中。
func _apply_at(x: int, y: int, button: int, select_only: bool) -> void:
	if not bool(map_view.call("in_bounds", x, y)):
		return
	var tool := int(session.get("active_tool"))
	var right_click := button == MOUSE_BUTTON_RIGHT

	if right_click:
		session.call("erase_at", x, y)          # 右键 = 擦除（详设 07 的 4.1）
	else:
		match tool:
			EditorSessionScript.TOOL_PAINT_EMPTY:
				session.call("set_tile", x, y, EditorSessionScript.TILE_EMPTY)
			EditorSessionScript.TOOL_PAINT_WALL:
				session.call("set_tile", x, y, EditorSessionScript.TILE_WALL)
			EditorSessionScript.TOOL_PAINT_GOAL:
				session.call("set_tile", x, y, EditorSessionScript.TILE_GOAL)
			EditorSessionScript.TOOL_PLACE_UNIT:
				session.call("place_unit", x, y, str(session.get("selected_unit_type")),
					str(session.get("selected_team")))
			EditorSessionScript.TOOL_ERASE:
				session.call("erase_at", x, y)
			_:
				pass

	# 选中：选择工具总更新；其它工具也顺手把"刚点的东西"选中，方便右侧面板跟着变
	var u = _unit_at(x, y)
	if u != null:
		session.set("selection", {"kind": "unit", "x": x, "y": y})
	else:
		session.set("selection", {"kind": "tile", "x": x, "y": y})
	_refresh_after_edit()


func _refresh_after_edit() -> void:
	map_view.call("queue_redraw")
	inspector.call("refresh")
	var err := str(session.get("last_error"))
	if not err.is_empty():
		_set_status(err, true)
		session.set("last_error", "")
	elif bool(session.get("dirty")):
		_set_status("有未保存改动", false)


func _unit_at(x: int, y: int):
	var units: Array = session.get("level_data").get("units")
	for u in units:
		var p: Array = (u as Dictionary).get("pos", [0, 0])
		if int(p[0]) == x and int(p[1]) == y:
			return u
	return null


# ---------------------------------------------------------------------------
# 右侧面板的回调
# ---------------------------------------------------------------------------

func _on_field_changed(key: String, value) -> void:
	if session == null:
		return
	var lv = session.get("level_data")
	var sel: Dictionary = session.get("selection")
	var x := int(sel.get("x", 0))
	var y := int(sel.get("y", 0))
	session.call("begin_transaction")
	var handled := true
	match key:
		"id":
			lv.set("id", str(value))
		"name":
			lv.set("name", str(value))
		"beacon_quota":
			session.call("set_beacon_quota", int(value))
		"signal_count":
			session.call("set_signal_count", int(value))
		"time_limit":
			lv.set("time_limit", float(value))
		"map_width":
			session.call("resize_map", int(value), int(session.call("map_height")))
		"map_height":
			session.call("resize_map", int(session.call("map_width")), int(value))
		"intro_title":
			var it: Dictionary = lv.get("intro")
			it["title"] = str(value)
		"intro_tips":
			var it2: Dictionary = lv.get("intro")
			it2["tips"] = _nonempty_lines(str(value))
		"win_logic":
			session.call("set_win_logic", str(value))
		"lose_logic":
			session.call("set_lose_logic", str(value))
		"type":
			session.call("set_unit_type", x, y, str(value))
		"team":
			_set_unit_field(x, y, "team", str(value))
		"pos_x":
			_set_unit_field(x, y, "pos", [int(value), int(sel.get("y", 0))])
		"pos_y":
			_set_unit_field(x, y, "pos", [int(sel.get("x", 0)), int(value)])
		"is_primary_target":
			_set_unit_field(x, y, "is_primary_target", bool(value))
		"ov_max_hp", "ov_move_speed", "ov_range":
			_set_override(x, y, key.substr(3), float(value))
		"clear_overrides":
			session.call("set_unit_overrides", x, y, {})
		"place_unit_here":
			var d: Dictionary = value
			session.call("place_unit", int(d.get("x", 0)), int(d.get("y", 0)),
				str(session.get("selected_unit_type")), str(d.get("team", "ally")))
		_:
			handled = false
	session.call("end_transaction")
	if handled:
		_refresh_after_edit()


func _nonempty_lines(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		var s := str(line).strip_edges()
		if not s.is_empty():
			out.append(s)
	return out


func _set_unit_field(x: int, y: int, field: String, value) -> void:
	var u = _unit_at(x, y)
	if u == null:
		return
	(u as Dictionary)[field] = value
	session.set("dirty", true)


func _set_override(x: int, y: int, field: String, value: float) -> void:
	var u = _unit_at(x, y)
	if u == null:
		return
	var ov: Dictionary = (u as Dictionary).get("overrides", {})
	# 0 视为"该项不覆盖"，与面板上的留空一致
	if is_zero_approx(value):
		ov.erase(field)
	else:
		ov[field] = value
	session.call("set_unit_overrides", x, y, ov)


## 加一条条件：类型取该组允许的第一种，参数按 schema 的默认值填。
##
## 【FR-EDIT-04/05 要求"可增删条件并配置参数"】默认类型只是起点，
## 加完可以在面板上换类型、改参数（比如把失败条件配成「超时 30 秒」）。
func _on_condition_added(which: String) -> void:
	if session == null:
		return
	var types: Array = LevelDataScript.condition_types(which)
	if types.is_empty():
		_set_status("这一类没有可用的条件类型", true)
		return
	var cond: Dictionary = LevelDataScript.make_default_condition(str(types[0]))
	session.call("begin_transaction")
	session.call("add_condition", which, cond)
	session.call("end_transaction")
	inspector.call("refresh")
	_set_status("已加条件 %s（可换类型、改参数）" % str(types[0]), false)


## 换条件的类型 → 参数回到该类型的 schema 默认值
func _on_condition_type_changed(which: String, index: int, new_type: String) -> void:
	if session == null:
		return
	var block: Dictionary = session.get("level_data").get(which)
	var conds: Array = block.get("conditions", [])
	if index < 0 or index >= conds.size():
		return
	session.call("begin_transaction")
	# 整条替换：旧类型的残留参数留着会让校验器报"多余的键"
	conds[index] = LevelDataScript.make_default_condition(new_type)
	session.call("end_transaction")
	# 【这里**不能**调 _sync_goal_area()】它会在"没有 auto_area 条件"时**追加**一条
	# `reach_position`。手写关卡本来就没有这个标记，于是每换一次类型就多出一条
	# 重复的胜利条件（截图里看到两条 reach_position 才发现的）。
	# 换类型与目标区同步无关 —— 目标区只由「刷目标区」工具驱动（详设 07 的 4.1）。
	inspector.call("refresh")
	_set_status("条件类型改为 %s" % new_type, false)


## 改条件参数
func _on_condition_param_changed(which: String, index: int, key: String, value) -> void:
	if session == null:
		return
	var block: Dictionary = session.get("level_data").get(which)
	var conds: Array = block.get("conditions", [])
	if index < 0 or index >= conds.size():
		return
	session.call("begin_transaction")
	(conds[index] as Dictionary)[key] = value
	session.call("end_transaction")
	_set_status("条件参数 %s = %s" % [key, str(value)], false)


func _on_condition_removed(which: String, index: int) -> void:
	if session == null:
		return
	session.call("begin_transaction")
	session.call("remove_condition", which, index)
	session.call("end_transaction")
	inspector.call("refresh")


# ---------------------------------------------------------------------------
# 工具栏动作
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 新建关卡（FR-TEST-05 的第一步）
# ---------------------------------------------------------------------------

## 造一份**最小的、一定合法**的空白关卡数据。
##
## 【为什么默认用 annihilate / all_allies_dead】这两个条件**不需要参数**，
## 所以空白地图也必然通过 `validate()` —— 「新建出来就是非法关卡」是最糟的体验。
## 需要"走到某处"的关卡，作者刷目标区即可（会自动同步进条件）。
func new_level_dict() -> Dictionary:
	var w := 7
	var h := 7
	var tiles: Array = []
	for _j in h:
		var row: Array = []
		for _i in w:
			row.append(0)
		tiles.append(row)
	var types: Array = _data.call("unit_type_ids")
	var first_type := str(types[0]) if not types.is_empty() else "standard"
	return {
		"version": 1,
		"id": _next_free_level_id(),
		"name": "新关卡",
		"order": _next_order(),
		"map": {"width": w, "height": h, "tiles": tiles},
		"units": [{"team": "ally", "type": first_type, "pos": [1, 1], "overrides": {}}],
		"beacon_quota": 4,
		"signal_count": 1,
		"time_limit": 0,
		"win": {"logic": "any", "conditions": [{"type": "annihilate"}]},
		"lose": {"logic": "any", "conditions": [{"type": "all_allies_dead"}]},
		"intro": {"title": "新关卡", "tips": []},
		"tags": [],
	}


## 找一个**不与现有三关冲突**的新 id。
## 不这样做的话，新建关卡会默认叫 `tutorial_01`，一保存就覆盖真实关卡。
func _next_free_level_id() -> String:
	var used: Array = _loader.call("list_level_ids")
	var n := 1
	while true:
		var cand := "new_level_%d" % n
		if not used.has(cand):
			return cand
		n += 1
	return "new_level_x"


## 新关卡默认排在最后（详设 07 的 4.2：新关卡默认排在末尾）
func _next_order() -> int:
	var mx := 0
	for id in (_loader.call("list_level_ids") as Array):
		var res: Dictionary = _loader.call("load_level", str(id), _data.call("unit_type_ids"))
		if bool(res.get("ok")):
			mx = maxi(mx, int((res.get("level") as RefCounted).get("order")))
	return mx + 1


func _do_new_level() -> void:
	var d := new_level_dict()
	var lv: RefCounted = LevelDataScript.from_dict(d)
	var errs: Array = lv.call("validate", _data.call("unit_type_ids"))
	if not errs.is_empty():
		# 造出来的默认数据都不过校验，那是编辑器自己的 bug，必须显式喊出来
		_set_status("新建失败（默认数据不合法）：%s" % str(errs), true)
		return
	session = EditorSessionScript.new()
	session.call("setup", lv, "")
	# 【必须是 dirty】新关卡还没落盘。不置 dirty 的话「一键试玩」会跳过保存，
	# 而玩法场景是**按 id 从磁盘载入**的 → 载入一个不存在的文件 → 试玩直接失败。
	session.set("dirty", true)
	map_view.set("session", session)
	inspector.set("session", session)
	map_view.call("fit_to_view")
	_sync_tool_buttons()
	inspector.call("refresh")
	_set_status("已新建关卡 %s（尚未保存）" % str(lv.get("id")), false)


func _do_undo() -> void:
	if session != null and bool(session.call("undo")):
		map_view.call("queue_redraw")
		inspector.call("refresh")
		_set_status("已撤销", false)


func _do_redo() -> void:
	if session != null and bool(session.call("redo")):
		map_view.call("queue_redraw")
		inspector.call("refresh")
		_set_status("已重做", false)


func _do_save() -> void:
	if session == null:
		return
	var errs: Array = session.call("validate_before_save", _data.call("unit_type_ids"))
	if not errs.is_empty():
		_set_status("保存失败：%s" % str(errs), true)
		return
	# 【写盘策略】先试 res://，失败回退 user://（详设 07 的 4.4）
	var lv = session.get("level_data")
	var id := str(lv.get("id"))
	var json: String = session.call("to_json_string")
	var res_path := "res://data/levels/%s.json" % id
	var written := _write_text(res_path, json)
	var shown := res_path
	if not written:
		var user_path := "user://levels/%s.json" % id
		DirAccess.make_dir_recursive_absolute(user_path.get_base_dir())
		if _write_text(user_path, json):
			written = true
			shown = user_path
	if not written:
		_set_status("保存失败：res:// 与 user:// 都写不进去", true)
		return
	_update_manifest(id)
	session.call("mark_saved", shown)
	_set_status("已保存到 %s" % shown, false)


func _write_text(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


## 新关卡追加到 manifest 末尾；已在清单里的不改顺序（详设 07 的 2.3）
func _update_manifest(id: String) -> void:
	var path := "res://data/levels/manifest.json"
	if not FileAccess.file_exists(path):
		path = "user://levels/manifest.json"
	var d: Dictionary = {"version": 1, "levels": []}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
		if parsed is Dictionary:
			d = parsed
	var levels: Array = d.get("levels", [])
	if not levels.has(id):
		levels.append(id)
		d["levels"] = levels
		_write_text(path, JSON.stringify(d, "  "))


## 试玩前的决策：能试玩则返回关卡 id，否则返回空串。
##
## 【为什么要拆出来】`_do_playtest` 会**替换当前场景**（`get_tree().current_scene`），
## 在自动化用例里调它等于把测试自己拆掉。把"该不该试玩、试玩哪一关"这个**决策**
## 拆成纯函数，就能无副作用地验；换场景那一步留给真实运行。
func _playtest_target_id() -> String:
	if session == null:
		return ""
	# 试玩必须跑在真实文件上（详设 07 的 4.3）：有未保存改动就先存
	if bool(session.get("dirty")):
		_do_save()
		if bool(session.get("dirty")):
			return ""              # 保存失败就别试玩了
	var errs: Array = session.call("validate_before_save", _data.call("unit_type_ids"))
	if not errs.is_empty():
		_set_status("试玩失败：关卡数据不合法 %s" % str(errs), true)
		return ""
	return str(session.get("level_data").get("id"))


func _do_playtest() -> void:
	var id := _playtest_target_id()
	if id.is_empty():
		return
	var packed: PackedScene = load("res://src/play/play_scene.tscn")
	if packed == null:
		_set_status("试玩失败：找不到玩法场景", true)
		return
	var ps = packed.instantiate()
	ps.call("load_level_id", id)
	var root := get_tree().root
	var old := get_tree().current_scene
	root.add_child(ps)
	get_tree().current_scene = ps
	if old != null and old != ps:
		old.queue_free()


func _do_back() -> void:
	if has_node("/root/SceneLoader"):
		get_node("/root/SceneLoader").call("goto", LEVEL_SELECT_SCENE)


func _set_status(text: String, is_error: bool) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override("font_color",
		Color(1.0, 0.75, 0.55) if is_error else Color(0.85, 0.88, 0.95))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k := event as InputEventKey
		if k.ctrl_pressed and k.keycode == KEY_Z:
			_do_undo()
			get_viewport().set_input_as_handled()
		elif k.ctrl_pressed and k.keycode == KEY_Y:
			_do_redo()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE:
			_do_back()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_F and not k.ctrl_pressed:
			map_view.call("fit_to_view")
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_F1 and not k.ctrl_pressed:
			# FR-EDIT-01 的另一半：F1 在编辑器里 = 回到玩法（开关式切换）
			_do_playtest()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 测试/断言用
# ---------------------------------------------------------------------------

func status_text() -> String:
	return status_label.text if status_label != null else ""


func tool_button_names() -> Array:
	var out: Array = []
	for b in _tool_buttons:
		out.append(str((b as Button).name))
	return out


func press_tool(tool: int) -> bool:
	var b := toolbar_box.find_child("Tool_%d" % tool, true, false)
	if b == null:
		return false
	(b as Button).emit_signal("pressed")
	return true


func press_button(btn_name: String) -> bool:
	var b := toolbar_box.find_child(btn_name, true, false)
	if b == null:
		return false
	(b as Button).emit_signal("pressed")
	return true


func main_rects() -> Dictionary:
	return {
		"left": (get_node("Row/LeftBar") as Control).get_global_rect(),
		"center": (get_node("Row/Center") as Control).get_global_rect(),
		"right": (get_node("Row/RightBar") as Control).get_global_rect(),
	}
