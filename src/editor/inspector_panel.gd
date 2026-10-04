class_name EditorInspectorPanel
extends Control
## 编辑器右侧属性面板：按选中对象动态生成字段。
## 详细设计：[docs/design/07-关卡编辑器.md](../../docs/design/07-关卡编辑器.md) 1.3 / 2.1
##
## 【只发信号】面板不直接改 EditorSession —— 「改数据 + 压撤销栈 + 同步目标区 + 刷新」
## 这一串副作用必须集中在一处（编辑器场景），否则很容易漏掉压栈。
##
## 选中对象由 `selection` 决定（EditorSession.selection）：
##   {} → 关卡全局；{kind:"tile", x, y} → 格子；{kind:"unit", x, y} → 单位

signal field_changed(key: String, value)
signal condition_added(which: String)
signal condition_removed(which: String, index: int)
signal logic_changed(which: String, logic: String)
## 改了条件的类型（编辑器要按新类型重置参数并压栈）
signal condition_type_changed(which: String, index: int, new_type: String)
## 改了条件的某个参数
signal condition_param_changed(which: String, index: int, key: String, value)

## 关卡条件 schema 的唯一来源（与 LevelData.validate 同一处知识）
const LevelDataScript := preload("res://src/core/level/level_data.gd")
## 参数控件工厂：与指令面板共用（schema 形态一致）
const RuleFieldFactoryScript := preload("res://src/ui/rule_panel/field_factory.gd")

const C_LABEL := Color(0.80, 0.84, 0.92)
const C_DIM := Color(0.62, 0.66, 0.74)

var session = null
var unit_type_ids: Array = []
## 单位类型 id → 中文显示名（由 editor_scene 从 units.json 灌进来）。
## 【只影响显示】下拉框的 metadata 仍然是 id，写回数据的也是 id。
var unit_type_names: Dictionary = {}

var _title: Label
var _body: VBoxContainer


func _ready() -> void:
	name = "Inspector"
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.16, 1.0)
	sb.border_color = Color(0.26, 0.30, 0.38)
	sb.border_width_left = 2
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	var root := PanelContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", sb)
	add_child(root)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)


## 重建面板内容
func refresh() -> void:
	for c in _body.get_children():
		# remove_child + queue_free：queue_free 帧末才生效，只调它会数到旧节点
		_body.remove_child(c)
		c.queue_free()
	if session == null:
		return
	var sel: Dictionary = session.get("selection")
	var kind := str(sel.get("kind", ""))
	match kind:
		"tile":
			_build_tile(sel)
		"unit":
			_build_unit(sel)
		_:
			_build_global()


# ---------------------------------------------------------------------------

func _add_title(text: String) -> void:
	_title = Label.new()
	_title.name = "Title"
	_title.text = text
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", C_LABEL)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_title)


## 分区小标题。**不要用它改 `_title`** —— 那会覆盖面板主标题。
func _add_section_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.72, 0.80, 0.95))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)


func _add_note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", C_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)


func _add_sep() -> void:
	_body.add_child(HSeparator.new())


## 一行「标签 + 数值输入」
func _add_spin(key: String, label: String, value: float,
		lo: float, hi: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var sb := SpinBox.new()
	sb.name = "F_" + key
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = value
	sb.custom_minimum_size = Vector2(110, 0)
	sb.value_changed.connect(func(v: float) -> void:
		field_changed.emit(key, v))
	row.add_child(sb)
	_body.add_child(row)
	return sb


## 一行「标签 + 文本输入」
func _add_line(key: String, label: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var le := LineEdit.new()
	le.name = "F_" + key
	le.text = value
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(t: String) -> void: field_changed.emit(key, t))
	le.focus_exited.connect(func() -> void: field_changed.emit(key, le.text))
	row.add_child(le)
	_body.add_child(row)
	return le


## 一行「标签 + 下拉」。
##
## 【`labels` 只改显示，不改数据】下拉项的**文字**取 `labels[value]`（缺省用 value 本身），
## 而 `set_item_metadata` 始终存**原始 value** —— 所以玩家看到的是中文，
## 写回关卡数据的仍是 `reach_position` / `ally` 这类 id。
## 两者混起来是这类 UI 最容易出的数据事故，所以这里明确分开。
func _add_option(key: String, label: String, items: Array, current: String,
		labels: Dictionary = {}) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.name = "F_" + key
	ob.clip_text = true
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		var v := str(items[i])
		ob.add_item(str(labels.get(v, v)))
		ob.set_item_metadata(i, v)          # ← 元数据永远是 id
		if v == current:
			ob.selected = i
	ob.item_selected.connect(func(i: int) -> void:
		field_changed.emit(key, ob.get_item_metadata(i)))
	row.add_child(ob)
	_body.add_child(row)
	return ob


func _add_check(key: String, label: String, on: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.name = "F_" + key
	cb.text = label
	cb.button_pressed = on
	cb.add_theme_font_size_override("font_size", 16)
	cb.toggled.connect(func(v: bool) -> void: field_changed.emit(key, v))
	_body.add_child(cb)
	return cb


func _add_button(text: String, handler: Callable, btn_name: String = "") -> Button:
	var b := Button.new()
	if not btn_name.is_empty():
		b.name = btn_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(handler)
	_body.add_child(b)
	return b


# ---------------------------------------------------------------------------
# 三种选中形态
# ---------------------------------------------------------------------------

func _build_tile(sel: Dictionary) -> void:
	var x := int(sel.get("x", 0))
	var y := int(sel.get("y", 0))
	var t: int = int(session.call("tile_at", x, y))
	_add_title("格子 (%d, %d)" % [x, y])
	_add_note("瓦片：%s" % _tile_name(t))
	_add_sep()
	var u = _unit_at(x, y)
	if u == null:
		_add_note("这一格没有单位。")
		_add_button("放一个我方单位", func() -> void:
			field_changed.emit("place_unit_here", {"x": x, "y": y, "team": "ally"}),
			"BtnPlaceAlly")
		_add_button("放一个敌方单位", func() -> void:
			field_changed.emit("place_unit_here", {"x": x, "y": y, "team": "enemy"}),
			"BtnPlaceEnemy")
	else:
		_add_note("这一格有单位，切换选中即可编辑它。")


func _build_unit(sel: Dictionary) -> void:
	var x := int(sel.get("x", 0))
	var y := int(sel.get("y", 0))
	var u = _unit_at(x, y)
	if u == null:
		_add_title("单位已不存在")
		_add_note("选中的单位已被删除（撤销可以找回来）。")
		return
	var team := str(u.get("team", "ally"))
	_add_title("单位 · %s" % ("我方" if team == "ally" else "敌方"))
	_add_sep()

	_add_option("type", "类型", unit_type_ids, str(u.get("type", "")), unit_type_names)
	_add_option("team", "阵营", ["ally", "enemy"], team,
		{"ally": LevelDataScript.team_display_name("ally"),
		 "enemy": LevelDataScript.team_display_name("enemy")})
	var pos: Array = u.get("pos", [0, 0])
	_add_spin("pos_x", "X", float(pos[0]), 0, 999, 1)
	_add_spin("pos_y", "Y", float(pos[1]), 0, 999, 1)
	# 【必须给默认值】`u.get("is_primary_target")` 在键不存在时返回 null，
	# 而 `bool(null)` 会抛 "Nonexistent constructor" —— **并中断整个 _build_unit**，
	# 于是它之后的所有字段都凭空消失（实测：面板只剩 type/team/pos_x/pos_y）。
	# 凡是从 Dictionary 取值再转型，一律带上默认值。
	_add_check("is_primary_target", "主要目标（敌人 AI 优先）",
		bool(u.get("is_primary_target", false)))

	_add_sep()
	_add_note("数值覆盖（留空表示用 units.json 里的基础值）")
	var ov: Dictionary = u.get("overrides", {})
	# 只暴露最常用的三个覆盖项：全列出来会把面板撑得很长，
	# 而 MVP 的关卡设计实际只会调这几个（详设 07 的 8.2 也提到"不做系数编辑"）。
	_add_spin("ov_max_hp", "血量上限", float(ov.get("max_hp", 0.0)), 0, 9999, 1)
	_add_spin("ov_move_speed", "移速", float(ov.get("move_speed", 0.0)), 0, 99, 0.5)
	_add_spin("ov_range", "射程", float(ov.get("range", 0.0)), 0, 99, 1)
	_add_button("清空覆盖", func() -> void: field_changed.emit("clear_overrides", {}),
		"BtnClearOverrides")


func _build_global() -> void:
	var lv = session.get("level_data")
	_add_title("关卡全局")
	_add_note("路径：%s" % str(session.get("source_path")))
	_add_sep()
	_add_line("id", "id", str(lv.get("id")))
	_add_line("name", "名称", str(lv.get("name")))
	_add_spin("beacon_quota", "信标配额", float(lv.get("beacon_quota")), 0, 99, 1)
	_add_spin("signal_count", "信号数", float(lv.get("signal_count")), 0, 99, 1)
	_add_spin("map_width", "地图宽", float(session.call("map_width")), 1, 64, 1)
	_add_spin("map_height", "地图高", float(session.call("map_height")), 1, 64, 1)
	_add_spin("time_limit", "时限（0=不限）", float(lv.get("time_limit")), 0, 9999, 1)

	_add_sep()
	var intro: Dictionary = lv.get("intro")
	_add_line("intro_title", "介绍标题", str(intro.get("title", "")))
	var tips: Array = intro.get("tips", [])
	_add_note("介绍提示（每行一条，共 %d 条）" % tips.size())
	var tips_edit := TextEdit.new()
	tips_edit.name = "F_intro_tips"
	tips_edit.custom_minimum_size = Vector2(0, 110)
	tips_edit.text = "\n".join(tips)
	tips_edit.text_changed.connect(func() -> void:
		field_changed.emit("intro_tips", tips_edit.text))
	_body.add_child(tips_edit)

	_add_sep()
	_build_conditions("win", "胜利条件")
	_build_conditions("lose", "失败条件")


## 胜负条件区：组间逻辑 + 每条条件的**类型选择与参数编辑** + 增删。
##
## 【FR-EDIT-04/05 要求"可增删条件并配置参数"】原来的实现只硬编码加一条
## `reach_position` / `all_allies_dead`，既不能选类型也不能填参数
## （比如「超时 30 秒」就没法配）—— 那只是"能加"，不是"能配"。
func _build_conditions(which: String, title: String) -> void:
	var lv = session.get("level_data")
	var block: Dictionary = lv.get(which)
	_add_section_label(title)
	_add_option(which + "_logic", "组间逻辑", ["any", "all"],
		str(block.get("logic", "any")),
		{"any": LevelDataScript.logic_display_name("any"),
		 "all": LevelDataScript.logic_display_name("all")})

	var conds: Array = block.get("conditions", [])
	if conds.is_empty():
		_add_note("（暂无条件）")
	for i in conds.size():
		_build_one_condition(which, i, conds[i])

	_add_button("+ 条件", func() -> void: condition_added.emit(which),
		"AddCond_" + which)


## 一条条件：类型下拉 + 按 schema 生成的参数 + 删除
func _build_one_condition(which: String, i: int, c: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Cond_%s_%d" % [which, i]
	row.add_theme_constant_override("separation", 6)

	var picker := OptionButton.new()
	picker.name = "CondType_%s_%d" % [which, i]
	picker.clip_text = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var types: Array = LevelDataScript.condition_types(which)
	for k in types.size():
		# 显示中文名，元数据仍是英文 id
		picker.add_item(LevelDataScript.condition_display_name(str(types[k])))
		picker.set_item_metadata(k, str(types[k]))
		if str(types[k]) == str(c.get("type")):
			picker.selected = k
	picker.item_selected.connect(func(_s: int) -> void:
		condition_type_changed.emit(which, i,
			str(picker.get_item_metadata(picker.selected))))
	row.add_child(picker)

	var del := Button.new()
	del.name = "DelCond_%s_%d" % [which, i]
	del.text = "删"
	del.custom_minimum_size = Vector2(44, 30)
	del.pressed.connect(func() -> void: condition_removed.emit(which, i))
	row.add_child(del)
	_body.add_child(row)

	# 参数控件：schema 驱动
	for spec in (LevelDataScript.condition_schema(str(c.get("type"))) as Array):
		var sd := spec as Dictionary
		var key := str(sd.get("key"))
		if str(sd.get("type")) == "cell_list":
			_body.add_child(_make_cell_list(which, i, c.get(key, [])))
		else:
			_body.add_child(RuleFieldFactoryScript.make_row(
				sd, c.get(key), {"beacon_count": 0, "signal_count": 0},
				func(k: String, v) -> void:
					condition_param_changed.emit(which, i, k, v)))


## 格子列表（reach_position 的 area）：用只读文本显示 + 一行提示，
## 因为"刷目标区的格子"本来就该在地图上刷，不该在这里手填坐标。
func _make_cell_list(which: String, i: int, area) -> Control:
	var box := VBoxContainer.new()
	box.name = "Cells_%s_%d" % [which, i]
	box.add_theme_constant_override("separation", 2)
	var lab := Label.new()
	lab.text = "目标格（%d 格）：%s" % [(area as Array).size(), str(area)]
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", C_DIM)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lab)
	var hint := Label.new()
	hint.text = "在地图上用「刷目标区」工具改，会自动同步到这里"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box


func _tile_name(t: int) -> String:
	match t:
		0: return "空地"
		1: return "障碍（不可通行）"
		2: return "目标区域"
		_: return "未知(%d)" % t


func _unit_at(x: int, y: int):
	var units: Array = session.get("level_data").get("units")
	for u in units:
		var p: Array = (u as Dictionary).get("pos", [0, 0])
		if int(p[0]) == x and int(p[1]) == y:
			return u
	return null


# ---------------------------------------------------------------------------
# 测试/断言用
# ---------------------------------------------------------------------------

func title_text() -> String:
	return _title.text if _title != null else ""


func field_names() -> Array:
	var out: Array = []
	for c in _body.get_children():
		if c is HBoxContainer:
			for g in (c as Node).get_children():
				if str((g as Node).name).begins_with("F_"):
					out.append(str((g as Node).name).substr(2))
		elif str((c as Node).name).begins_with("F_"):
			out.append(str((c as Node).name).substr(2))
		elif c is CheckBox and str((c as Node).name).begins_with("F_"):
			out.append(str((c as Node).name).substr(2))
	return out


func find_field(key: String) -> Node:
	for c in _body.get_children():
		if str((c as Node).name) == "F_" + key:
			return c
		if c is Node:
			var n := (c as Node).find_child("F_" + key, true, false)
			if n != null:
				return n
	return null
