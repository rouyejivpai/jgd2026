extends ScrollContainer
## 第五阶段：配置器「关卡配置」页（数值策划用）。编辑本关的
##   出场（roster：预算、人数上下限、可用形态、信标价格 / 每包数量）、部署区、胜负条件中的数值与文案、
##   敌方与预置单位（形态、阵营、位置、显示名、计入全灭、属性覆盖）、关卡加成（modifiers）。
## 写回规则：与关卡 JSON 原值比较，roster / objectives 只记有差异的键（按键覆盖），deploy_zone / initial_units / modifiers 有差异时整体记录；
## 与原值相同的项从 teaching.json 中移除。第七关数据冻结，只读。敌人的指令（rules）随单位原样保留，本页不编辑。

const STATS: Array[String] = ["max_hp", "attack", "attack_speed", "move_speed", "vision", "range"]
const STAT_LABELS: Dictionary = { "max_hp": "生命", "attack": "攻击", "attack_speed": "攻速", "move_speed": "移速", "vision": "视野", "range": "射程" }
const ROSTER_NUMS: Array[String] = ["budget", "max_units", "min_units", "beacon_cost", "beacon_bundle"]
const ROSTER_LABELS: Dictionary = { "budget": "出场预算（Cost）", "max_units": "出场人数上限", "min_units": "出场人数下限", "beacon_cost": "信标价格（Cost/包）", "beacon_bundle": "每包信标数" }
const FACTIONS: Array[String] = ["enemy", "ally", "neutral"]

var editor: Control = null
var lid: String = ""
var roster: Dictionary = {}
var deploy: Dictionary = {}
var objectives: Dictionary = {}
var units: Array = []
var mods: Array = []
var cur_unit: int = -1
var cur_mod: int = -1
var _filling: bool = false
var _frozen: bool = false

var _note: Label
var _roster_spins: Dictionary = {}        ## 键 -> SpinBox
var _forms: Dictionary = {}               ## 形态 id -> CheckBox
var _deploy_box: VBoxContainer
var _obj_box: VBoxContainer
var _unit_list: ItemList
var _u_id: LineEdit
var _u_unit: OptionButton
var _u_faction: OptionButton
var _u_x: SpinBox
var _u_y: SpinBox
var _u_name: LineEdit
var _u_counts: CheckBox
var _u_stat_on: Dictionary = {}           ## stat -> CheckBox
var _u_stat_val: Dictionary = {}          ## stat -> SpinBox
var _u_stat_base: Dictionary = {}         ## stat -> Label
var _mod_list: ItemList
var _m_target: LineEdit
var _m_stat: OptionButton
var _m_mul: SpinBox
var _m_add: SpinBox
var _controls: Array[Control] = []        ## 第七关只读时统一禁用


func setup(p_editor: Control) -> void:
	editor = p_editor
	name = "关卡配置"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	_note = Label.new()
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_note)
	top.add_child(_reg(_btn("恢复本关原值（关卡配置）", reset_override)))
	top.add_child(_btn("试玩本关（用未保存的配置）", func() -> void: editor.call("play_level")))
	# 出场
	body.add_child(_title("出场"))
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for k: String in ROSTER_NUMS:
		var l := Label.new()
		l.text = str(ROSTER_LABELS[k])
		grid.add_child(l)
		var sb: SpinBox = _spin(0.0, 999.0, 1.0)
		sb.value_changed.connect(func(_v: float) -> void: _commit_roster())
		grid.add_child(sb)
		_roster_spins[k] = sb
	var fl := Label.new()
	fl.text = "可用形态"
	body.add_child(fl)
	var flow := HFlowContainer.new()
	body.add_child(flow)
	var forms: Array = DataRegistry.get_units().keys()
	forms.sort()
	for fid: Variant in forms:
		var ud: UnitDefinition = DataRegistry.get_unit(str(fid))
		if ud.cost <= 0:
			continue
		var cb := CheckBox.new()
		cb.text = "%s %s（Cost %d）" % [ud.display_name, ud.id, ud.cost]
		cb.toggled.connect(func(_on: bool) -> void: _commit_roster())
		flow.add_child(_reg(cb))
		_forms[ud.id] = cb
	# 部署区
	body.add_child(_title("部署区"))
	_deploy_box = VBoxContainer.new()
	body.add_child(_deploy_box)
	# 胜负
	body.add_child(_title("胜负条件"))
	_obj_box = VBoxContainer.new()
	body.add_child(_obj_box)
	# 单位
	body.add_child(_title("敌方与预置单位（属性覆盖不勾 = 用形态基础值）"))
	var usplit := HBoxContainer.new()
	body.add_child(usplit)
	var ucol := VBoxContainer.new()
	ucol.custom_minimum_size = Vector2(300, 0)
	usplit.add_child(ucol)
	_unit_list = ItemList.new()
	_unit_list.custom_minimum_size = Vector2(0, 260)
	_unit_list.item_selected.connect(func(i: int) -> void:
		cur_unit = i
		_fill_unit())
	ucol.add_child(_unit_list)
	var ub := HBoxContainer.new()
	ucol.add_child(ub)
	ub.add_child(_reg(_btn("新增", add_unit)))
	ub.add_child(_reg(_btn("复制", dup_unit)))
	ub.add_child(_reg(_btn("删除", delete_unit)))
	var uform := VBoxContainer.new()
	uform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	usplit.add_child(uform)
	_u_id = _row(uform, "id（目标 / 引导引用）", _reg(LineEdit.new())) as LineEdit
	_u_id.text_changed.connect(func(_t: String) -> void: _write_unit())
	var unit_items: Array = []
	var uids: Array = DataRegistry.get_units().keys()
	uids.sort()
	for u: Variant in uids:
		unit_items.append(["%s %s" % [(DataRegistry.get_unit(str(u)) as UnitDefinition).display_name, str(u)], str(u)])
	_u_unit = _row(uform, "形态", _reg(_option(unit_items, _on_unit_type))) as OptionButton
	_u_faction = _row(uform, "阵营", _reg(_option([["敌方", "enemy"], ["己方", "ally"], ["中立", "neutral"]], _write_unit))) as OptionButton
	var pos := HBoxContainer.new()
	_u_x = _spin(0.0, 99.0, 1.0)
	_u_y = _spin(0.0, 99.0, 1.0)
	for sb: SpinBox in [_u_x, _u_y]:
		sb.value_changed.connect(func(_v: float) -> void: _write_unit())
		pos.add_child(sb)
	_row(uform, "位置 x / y", pos)
	_u_name = _row(uform, "显示名", _reg(LineEdit.new())) as LineEdit
	_u_name.text_changed.connect(func(_t: String) -> void: _write_unit())
	_u_counts = CheckBox.new()
	_u_counts.text = "计入「全灭」胜利"
	_u_counts.toggled.connect(func(_on: bool) -> void: _write_unit())
	uform.add_child(_reg(_u_counts))
	var sg := GridContainer.new()
	sg.columns = 4
	uform.add_child(sg)
	for st: String in STATS:
		var on := CheckBox.new()
		on.text = "覆盖" + str(STAT_LABELS[st])
		on.toggled.connect(func(_b: bool) -> void: _write_unit())
		sg.add_child(_reg(on))
		var sb: SpinBox = _spin(0.0, 99999.0, 0.01)
		sb.value_changed.connect(func(_v: float) -> void: _write_unit())
		sg.add_child(sb)
		var base := Label.new()
		sg.add_child(base)
		sg.add_child(Control.new())
		_u_stat_on[st] = on
		_u_stat_val[st] = sb
		_u_stat_base[st] = base
	# 加成
	body.add_child(_title("关卡加成（结果 = 当前值 × 倍率 + 加值；目标 spawn:<id> / form:<形态> / faction:<阵营>）"))
	var msplit := HBoxContainer.new()
	body.add_child(msplit)
	var mcol := VBoxContainer.new()
	mcol.custom_minimum_size = Vector2(300, 0)
	msplit.add_child(mcol)
	_mod_list = ItemList.new()
	_mod_list.custom_minimum_size = Vector2(0, 140)
	_mod_list.item_selected.connect(func(i: int) -> void:
		cur_mod = i
		_fill_mod())
	mcol.add_child(_mod_list)
	var mb := HBoxContainer.new()
	mcol.add_child(mb)
	mb.add_child(_reg(_btn("新增", add_mod)))
	mb.add_child(_reg(_btn("删除", delete_mod)))
	var mform := VBoxContainer.new()
	mform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msplit.add_child(mform)
	_m_target = _row(mform, "目标", _reg(LineEdit.new())) as LineEdit
	_m_target.text_changed.connect(func(_t: String) -> void: _write_mod())
	var stat_items: Array = []
	for st: String in STATS:
		stat_items.append([str(STAT_LABELS[st]) + " " + st, st])
	_m_stat = _row(mform, "属性", _reg(_option(stat_items, _write_mod))) as OptionButton
	_m_mul = _row(mform, "倍率", _spin(0.0, 100.0, 0.01)) as SpinBox
	_m_add = _row(mform, "加值", _spin(-99999.0, 99999.0, 0.01)) as SpinBox
	for sb: SpinBox in [_m_mul, _m_add]:
		sb.value_changed.connect(func(_v: float) -> void: _write_mod())


# ---- 小工具 ----
func _reg(c: Control) -> Control:
	_controls.append(c)
	return c


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = "■ " + text
	l.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	return l


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.allow_greater = true
	sb.custom_minimum_size = Vector2(120, 0)
	_controls.append(sb)
	return sb


func _option(items: Array, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it: Variant in items:
		var pair: Array = it as Array
		o.add_item(str(pair[0]))
		o.set_item_metadata(o.item_count - 1, pair[1])
	o.item_selected.connect(func(_i: int) -> void: cb.call())
	return o


func _row(parent: Control, label: String, ctl: Control) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctl)
	parent.add_child(h)
	return ctl


static func _select_meta(o: OptionButton, value: String) -> void:
	for i: int in o.item_count:
		if str(o.get_item_metadata(i)) == value:
			o.select(i)
			return


static func _meta(o: OptionButton) -> String:
	return str(o.get_item_metadata(o.selected)) if o.selected >= 0 else ""


static func _same(a: Variant, b: Variant) -> bool:
	var ca: Variant = editor_clean(a)
	var cb: Variant = editor_clean(b)
	return JSON.stringify(ca, "", true) == JSON.stringify(cb, "", true)


## 与 config_editor._clean 同口径（整数写成整数），用于比较
static func editor_clean(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in (v as Dictionary).keys():
			var val: Variant = editor_clean((v as Dictionary)[k])
			if val is Dictionary and (val as Dictionary).is_empty():
				continue
			d[k] = val
		return d
	if v is Array:
		var a: Array = []
		for x: Variant in v as Array:
			a.append(editor_clean(x))
		return a
	if v is float and is_equal_approx(float(v), roundf(float(v))) and absf(float(v)) < 1e9:
		return int(roundf(float(v)))
	return v


func _raw() -> Dictionary:
	return (editor.get("raw_levels") as Dictionary).get(lid, {}) as Dictionary


func _entry(create: bool) -> Dictionary:
	return editor.call("_entry", create, lid) as Dictionary


# ---- 回填 ----
func fill(level_id: String) -> void:
	lid = level_id
	var raw: Dictionary = _raw()
	var eff: Dictionary = TeachingDef.apply_overrides(raw, _entry(false))
	roster = (eff.get("roster", {}) as Dictionary).duplicate(true)
	deploy = (eff.get("deploy_zone", {}) as Dictionary).duplicate(true)
	objectives = (eff.get("objectives", {}) as Dictionary).duplicate(true)
	units = (eff.get("initial_units", []) as Array).duplicate(true)
	mods = (eff.get("modifiers", []) as Array).duplicate(true)
	_frozen = lid == TeachingDef.FROZEN_LEVEL
	var e: Dictionary = _entry(false)
	var over: bool = TeachingDef.LEVEL_CONFIG_KEYS.any(func(k: String) -> bool: return e.has(k))
	_note.text = "%s · %s · %s" % [lid, "出场模式 " + str(roster.get("mode", "")), "第七关数据冻结，只读" if _frozen else ("已有覆盖（teaching.json）" if over else "关卡原值")]
	_filling = true
	for k: String in ROSTER_NUMS:
		(_roster_spins[k] as SpinBox).value = float(roster.get(k, 0))
	var avail: Array = roster.get("available_forms", []) as Array if roster.get("available_forms", null) is Array else []
	for fid: String in _forms.keys():
		(_forms[fid] as CheckBox).button_pressed = avail.has(fid)
	_filling = false
	_build_deploy()
	_build_objectives()
	cur_unit = 0 if not units.is_empty() else -1
	_refresh_units()
	cur_mod = 0 if not mods.is_empty() else -1
	_refresh_mods()
	for c: Control in _controls:
		if c is BaseButton:
			(c as BaseButton).disabled = _frozen
		elif c is LineEdit:
			(c as LineEdit).editable = not _frozen
		elif c is SpinBox:
			(c as SpinBox).editable = not _frozen


# ---- 写回 ----
func _commit() -> void:
	if _filling or _frozen or lid == "":
		return
	var raw: Dictionary = _raw()
	var e: Dictionary = _entry(true)
	for key: String in ["roster", "objectives"]:
		var cur: Dictionary = roster if key == "roster" else objectives
		var base: Dictionary = raw.get(key, {}) as Dictionary
		var diff: Dictionary = {}
		for k: Variant in cur.keys():
			if not base.has(k) and _same(cur[k], 0):
				continue                    # 原值没有此键且为 0（如信标价格）：不记录
			if not base.has(k) or not _same(cur[k], base[k]):
				diff[k] = _copy(cur[k])
		if diff.is_empty():
			e.erase(key)
		else:
			e[key] = diff
	for pair: Array in [["deploy_zone", deploy], ["initial_units", units], ["modifiers", mods]]:
		var key: String = str(pair[0])
		var cur: Variant = pair[1]
		var base: Variant = raw.get(key, null)
		if base == null and key == "deploy_zone":
			base = {}
		elif base == null:
			base = []
		if _same(cur, base):
			e.erase(key)
		else:
			e[key] = _copy(cur)
	editor.call("_changed")


static func _copy(v: Variant) -> Variant:
	if v is Array:
		return (v as Array).duplicate(true)
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return v


func reset_override() -> void:
	var e: Dictionary = _entry(false)
	for k: String in TeachingDef.LEVEL_CONFIG_KEYS:
		e.erase(k)
	editor.call("_changed")
	fill(lid)


func _commit_roster() -> void:
	if _filling:
		return
	for k: String in ROSTER_NUMS:
		var v: float = (_roster_spins[k] as SpinBox).value
		if roster.has(k) or v != 0.0:
			roster[k] = int(v)
	var avail: Array = []
	for fid: String in _forms.keys():
		if (_forms[fid] as CheckBox).button_pressed:
			avail.append(fid)
	if roster.get("available_forms", null) is Array or not avail.is_empty():
		roster["available_forms"] = avail
	_commit()


# ---- 部署区 ----
func _build_deploy() -> void:
	for c: Node in _deploy_box.get_children():
		c.queue_free()
	if deploy.get("rect", null) is Array and (deploy["rect"] as Array).size() == 4:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "矩形 x0 / y0 / x1 / y1（含两端）"
		l.custom_minimum_size = Vector2(240, 0)
		h.add_child(l)
		var rect: Array = deploy["rect"] as Array
		for i: int in 4:
			var sb: SpinBox = _spin(0.0, 99.0, 1.0)
			sb.value = float(rect[i])
			sb.editable = not _frozen
			sb.value_changed.connect(func(v: float) -> void:
				(deploy["rect"] as Array)[i] = int(v)
				_commit())
			h.add_child(sb)
		_deploy_box.add_child(h)
	var key: String = "exclude" if deploy.has("rect") else "cells"
	var le := LineEdit.new()
	le.text = _cells_text(deploy.get(key, []) as Array)
	le.editable = not _frozen
	le.placeholder_text = "x,y; x,y"
	le.text_changed.connect(func(t: String) -> void:
		var cs: Array = _text_cells(t)
		if cs.is_empty() and key == "exclude":
			deploy.erase("exclude")
		else:
			deploy[key] = cs
		_commit())
	_row(_deploy_box, "排除的格" if key == "exclude" else "部署格", le)


static func _cells_text(cells: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Variant in cells:
		var a: Array = c as Array
		if a.size() == 2:
			parts.append("%d,%d" % [int(a[0]), int(a[1])])
	return "; ".join(parts)


static func _text_cells(text: String) -> Array:
	var out: Array = []
	for part: String in text.split(";", false):
		var xy: PackedStringArray = part.strip_edges().split(",", false)
		if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
			out.append([int(xy[0]), int(xy[1])])
	return out


# ---- 胜负条件 ----
func _build_objectives() -> void:
	for c: Node in _obj_box.get_children():
		c.queue_free()
	var txt := TextEdit.new()
	txt.custom_minimum_size = Vector2(0, 60)
	txt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	txt.text = str(objectives.get("objective_text", ""))
	txt.editable = not _frozen
	txt.text_changed.connect(func() -> void:
		objectives["objective_text"] = txt.text
		_commit())
	_row(_obj_box, "任务一句话", txt)
	for side: String in ["win", "lose"]:
		var list: Array = objectives.get(side, []) as Array
		for i: int in list.size():
			var o: Dictionary = list[i] as Dictionary
			var t: String = str(o.get("type", ""))
			var h := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s · %s（%s）" % ["胜利" if side == "win" else "失败", t, str(o.get("id", ""))]
			l.custom_minimum_size = Vector2(300, 0)
			h.add_child(l)
			if t == "survive":
				h.add_child(_obj_num(o, "seconds", "坚持秒数", 0.5))
			if t == "reach_zone":
				h.add_child(_obj_num(o, "count", "需到达人数", 1.0))
			if o.has("cells"):
				h.add_child(_obj_text(o, "cells", "区域格 x,y; x,y"))
			if o.has("targets"):
				h.add_child(_obj_text(o, "targets", "目标 id，逗号分隔"))
			elif o.has("target"):
				h.add_child(_obj_text(o, "target", "目标 id"))
			_obj_box.add_child(h)


func _obj_num(o: Dictionary, key: String, label: String, step: float) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	h.add_child(l)
	var sb: SpinBox = _spin(0.0, 9999.0, step)
	sb.value = float(o.get(key, 1))
	sb.editable = not _frozen
	sb.value_changed.connect(func(v: float) -> void:
		o[key] = v
		_commit())
	h.add_child(sb)
	return h


func _obj_text(o: Dictionary, key: String, hint: String) -> LineEdit:
	var le := LineEdit.new()
	le.custom_minimum_size = Vector2(260, 0)
	le.placeholder_text = hint
	le.editable = not _frozen
	match key:
		"cells":
			le.text = _cells_text(o.get("cells", []) as Array)
		"targets":
			le.text = ",".join(PackedStringArray((o.get("targets", []) as Array).map(func(v: Variant) -> String: return str(v))))
		_:
			le.text = str(o.get(key, ""))
	le.text_changed.connect(func(t: String) -> void:
		match key:
			"cells":
				o["cells"] = _text_cells(t)
			"targets":
				o["targets"] = Array(t.replace("，", ",").split(",", false)).map(func(v: String) -> String: return v.strip_edges())
			_:
				o[key] = t.strip_edges()
		_commit())
	return le


# ---- 单位 ----
static func unit_label(d: Dictionary) -> String:
	var p: Array = d.get("pos", [0, 0]) as Array
	var ud: UnitDefinition = DataRegistry.get_unit(str(d.get("unit", "")))
	return "%s  %s %s  (%d,%d)%s" % [str(d.get("id", "")), str(d.get("faction", "")), ud.display_name if ud != null else str(d.get("unit", "")),
		int(p[0]) if p.size() == 2 else 0, int(p[1]) if p.size() == 2 else 0, "  *覆盖" if not (d.get("overrides", {}) as Dictionary).is_empty() else ""]


func _refresh_units() -> void:
	_unit_list.clear()
	for u: Variant in units:
		_unit_list.add_item(unit_label(u as Dictionary))
	cur_unit = clampi(cur_unit, -1, units.size() - 1)
	if cur_unit >= 0:
		_unit_list.select(cur_unit)
	_fill_unit()


func _unit() -> Dictionary:
	return units[cur_unit] as Dictionary if cur_unit >= 0 and cur_unit < units.size() else {}


func _fill_unit() -> void:
	var d: Dictionary = _unit()
	_filling = true
	_u_id.text = str(d.get("id", ""))
	_select_meta(_u_unit, str(d.get("unit", "")))
	_select_meta(_u_faction, str(d.get("faction", "enemy")))
	var p: Array = d.get("pos", [0, 0]) as Array
	_u_x.value = float(p[0]) if p.size() == 2 else 0.0
	_u_y.value = float(p[1]) if p.size() == 2 else 0.0
	_u_name.text = str(d.get("display_name", ""))
	_u_counts.button_pressed = bool(d.get("counts_for_annihilate", true))
	var ov: Dictionary = d.get("overrides", {}) as Dictionary
	var ud: UnitDefinition = DataRegistry.get_unit(str(d.get("unit", "")))
	for st: String in STATS:
		var base: float = _base_stat(ud, st)
		(_u_stat_on[st] as CheckBox).button_pressed = ov.has(st)
		(_u_stat_val[st] as SpinBox).value = float(ov.get(st, base))
		(_u_stat_base[st] as Label).text = "基础 %s" % str(snappedf(base, 0.01))
	_filling = false


static func _base_stat(ud: UnitDefinition, st: String) -> float:
	if ud == null:
		return 0.0
	match st:
		"max_hp":
			return ud.max_hp
		"attack":
			return ud.attack
		"attack_speed":
			return ud.attack_speed
		"move_speed":
			return ud.move_speed
		"vision":
			return ud.vision
		"range":
			return ud.attack_range
	return 0.0


func _write_unit() -> void:
	if _filling:
		return
	var d: Dictionary = _unit()
	if d.is_empty():
		return
	d["id"] = _u_id.text.strip_edges()
	d["unit"] = _meta(_u_unit)
	d["faction"] = _meta(_u_faction)
	d["pos"] = [int(_u_x.value), int(_u_y.value)]
	if _u_name.text.strip_edges() != "":
		d["display_name"] = _u_name.text.strip_edges()
	else:
		d.erase("display_name")
	if _u_counts.button_pressed:
		d.erase("counts_for_annihilate")
	else:
		d["counts_for_annihilate"] = false
	var ov: Dictionary = {}
	for st: String in STATS:
		if (_u_stat_on[st] as CheckBox).button_pressed:
			ov[st] = (_u_stat_val[st] as SpinBox).value
	if ov.is_empty():
		d.erase("overrides")
	else:
		d["overrides"] = ov
	_commit()
	_unit_list.set_item_text(cur_unit, unit_label(d))     # 只改列表文字，不回填表单（输入中光标不跳）


func _on_unit_type() -> void:
	_write_unit()
	_fill_unit()


func add_unit() -> void:
	var raw: Dictionary = _raw()
	var g: Dictionary = raw.get("grid", {}) as Dictionary
	var n: int = units.size() + 1
	while units.any(func(u: Variant) -> bool: return str((u as Dictionary).get("id", "")) == "E%d" % n):
		n += 1
	units.append({ "id": "E%d" % n, "unit": "raider", "faction": "enemy", "pos": [maxi(0, int(g.get("width", 2)) - 2), int(int(g.get("height", 2)) / 2.0)] })
	cur_unit = units.size() - 1
	_commit()
	_refresh_units()


func dup_unit() -> void:
	var d: Dictionary = _unit()
	if d.is_empty():
		return
	var c: Dictionary = d.duplicate(true)
	var n: int = 2
	while units.any(func(u: Variant) -> bool: return str((u as Dictionary).get("id", "")) == "%s_%d" % [str(d["id"]), n]):
		n += 1
	c["id"] = "%s_%d" % [str(d["id"]), n]
	units.insert(cur_unit + 1, c)
	cur_unit += 1
	_commit()
	_refresh_units()


func delete_unit() -> void:
	if cur_unit < 0 or cur_unit >= units.size():
		return
	units.remove_at(cur_unit)
	cur_unit = mini(cur_unit, units.size() - 1)
	_commit()
	_refresh_units()


# ---- 关卡加成 ----
static func mod_label(d: Dictionary) -> String:
	return "%s · %s ×%s +%s" % [str(d.get("target", "")), str(d.get("stat", "")), str(d.get("mul", 1)), str(d.get("add", 0))]


func _refresh_mods() -> void:
	_mod_list.clear()
	for m: Variant in mods:
		_mod_list.add_item(mod_label(m as Dictionary))
	cur_mod = clampi(cur_mod, -1, mods.size() - 1)
	if cur_mod >= 0:
		_mod_list.select(cur_mod)
	_fill_mod()


func _mod() -> Dictionary:
	return mods[cur_mod] as Dictionary if cur_mod >= 0 and cur_mod < mods.size() else {}


func _fill_mod() -> void:
	var d: Dictionary = _mod()
	_filling = true
	_m_target.text = str(d.get("target", ""))
	_select_meta(_m_stat, str(d.get("stat", "max_hp")))
	_m_mul.value = float(d.get("mul", 1.0))
	_m_add.value = float(d.get("add", 0.0))
	_filling = false


func _write_mod() -> void:
	if _filling:
		return
	var d: Dictionary = _mod()
	if d.is_empty():
		return
	d["target"] = _m_target.text.strip_edges()
	d["stat"] = _meta(_m_stat)
	d["mul"] = _m_mul.value
	d["add"] = _m_add.value
	_commit()
	_mod_list.set_item_text(cur_mod, mod_label(d))


func add_mod() -> void:
	mods.append({ "target": "faction:enemy", "stat": "max_hp", "mul": 1.0, "add": 0.0 })
	cur_mod = mods.size() - 1
	_commit()
	_refresh_mods()


func delete_mod() -> void:
	if cur_mod < 0 or cur_mod >= mods.size():
		return
	mods.remove_at(cur_mod)
	cur_mod = mini(cur_mod, mods.size() - 1)
	_commit()
	_refresh_mods()
