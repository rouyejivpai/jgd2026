class_name RuleFieldFactory
extends RefCounted
## 由系统 02 的参数 schema 生成控件。
## 详细设计：[docs/design/09-指令编辑界面.md](../../docs/design/09-指令编辑界面.md) 3.2 / 6.1
##
## 【为什么要工厂】参数控件要按类型分支（数值 SpinBox / 枚举 OptionButton /
## 开关 CheckBox / 信标与信号引用）。集中在一处，以后系统 02 新增参数类型时
## 只加一个分支，面板本身不用改。
##
## 【引用类参数必须每次重建】`beacon_ref` / `signal_ref` 的候选项来自**当前关卡**：
## 信标是玩家动态放的、信号数来自 `signal_count`。所以每次打开面板都要用
## 最新的 `ctx` 重建下拉项（详设 09 的 3.2 明确要求）。

## 比较符的显示名（存的是枚举字符串，显示给人看）
const OP_LABELS := {
	"lt": "小于", "le": "不大于", "eq": "等于", "ge": "不小于", "gt": "大于",
}
const STATUS_LABELS := {"slowed": "减速"}


## 造一行「标签 + 控件」。返回的 HBox 直接 add_child 即可。
##
## spec      参数 schema 的一项
## value     当前值
## ctx       {"beacon_count": int, "signal_count": int}
## on_changed  Callable(key: String, value) —— 改了立刻回调写回数据
static func make_row(spec: Dictionary, value, ctx: Dictionary, on_changed: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lab := Label.new()
	lab.text = str(spec.get("label", spec.get("key", "")))
	lab.add_theme_font_size_override("font_size", 17)
	lab.custom_minimum_size = Vector2(72, 0)
	row.add_child(lab)

	var ctrl := make_control(spec, value, ctx, on_changed)
	if ctrl != null:
		row.add_child(ctrl)
	return row


## 只造控件本身（标签由调用方决定放哪）
static func make_control(spec: Dictionary, value, ctx: Dictionary,
		on_changed: Callable) -> Control:
	var key := str(spec.get("key", ""))
	var t := str(spec.get("type", "float"))
	match t:
		"bool":
			var cb := CheckBox.new()
			cb.name = "F_" + key
			cb.button_pressed = bool(value) if value != null else bool(spec.get("default", false))
			cb.add_theme_font_size_override("font_size", 17)
			cb.toggled.connect(func(on: bool) -> void: on_changed.call(key, on))
			return cb

		"int", "float":
			var sb := SpinBox.new()
			sb.name = "F_" + key
			sb.min_value = float(spec.get("min", 0.0))
			sb.max_value = float(spec.get("max", 999.0))
			sb.step = float(spec.get("step", 1.0 if t == "int" else 0.5))
			sb.value = float(value) if value != null else float(spec.get("default", 0.0))
			sb.custom_minimum_size = Vector2(110, 0)
			sb.value_changed.connect(func(v: float) -> void:
				on_changed.call(key, int(v) if t == "int" else v))
			return sb

		"enum":
			return _make_options(spec, value, key, false, on_changed)

		"beacon_ref":
			return _make_options(spec, value, key, true, on_changed,
				int(ctx.get("beacon_count", 0)), "还没有放信标")

		"signal_ref":
			return _make_options(spec, value, key, true, on_changed,
				int(ctx.get("signal_count", 0)), "本关没有信号")

		"beacon_seq":
			# 信标序列用专门的网格控件（见 rule_panel._build_beacon_editor），
			# 这里不生成，返回 null 由调用方处理
			return null

		_:
			# 未知类型：给一个只读标签，避免静默不显示（新增类型时容易漏）
			var lbl := Label.new()
			lbl.name = "F_" + key
			lbl.text = "（未知控件类型 %s）" % t
			lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
			return lbl


## 下拉：`options` 显式给出（枚举），或按 `count` 生成 1..N（引用类）
static func _make_options(spec: Dictionary, value, key: String, is_ref: bool,
		on_changed: Callable, count: int = 0, empty_hint: String = "") -> Control:
	var ob := OptionButton.new()
	ob.name = "F_" + key
	ob.clip_text = true
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var values: Array = []
	if is_ref:
		if count <= 0:
			ob.add_item(empty_hint)
			ob.disabled = true
			return ob
		for i in range(1, count + 1):
			values.append(i)
	else:
		for o in (spec.get("options", []) as Array):
			values.append(o)

	var cur = value
	if cur == null:
		cur = spec.get("default")
	for i in values.size():
		var v = values[i]
		ob.add_item(_option_label(key, v))
		ob.set_item_metadata(i, v)
		if _same(v, cur):
			ob.selected = i
	if ob.selected < 0 and ob.item_count > 0:
		ob.selected = 0
	ob.item_selected.connect(func(i: int) -> void:
		on_changed.call(key, ob.get_item_metadata(i)))
	return ob


## 枚举值转人看的文字：比较符与状态有专门映射，其余原样
static func _option_label(key: String, v) -> String:
	var s := str(v)
	if key == "op":
		return str(OP_LABELS.get(s, s))
	if key == "status":
		return str(STATUS_LABELS.get(s, s))
	if key == "logic":
		return "与" if s == "0" else ("或" if s == "1" else s)
	return s


static func _same(a, b) -> bool:
	if a is float or a is int:
		if b is float or b is int:
			return is_equal_approx(float(a), float(b))
		return false
	return str(a) == str(b)


## 按 schema 的 `default` 造一个全新的条件/行为对象（详设 09 的 6.1：
## "新增条件取默认参数，按 schema 的 default 赋值"）。
##
## 【为什么不直接用 from_dict({"type": t})】`from_dict` 里的默认值是**字段级**的
## （例如 op 一律 OP_LE、percent 一律 0.0），而 schema 的 `default` 是**按类型给的**
## （SELF_HP 的 op 默认 OP_LT、percent 默认 60.0）。两者不一致，
## 直接用 from_dict 会得到"看似能跑但参数不是设计值"的对象。
static func make_default_from_schema(kind_script, type_id: String) -> RefCounted:
	var d := {"type": type_id}
	for spec in (kind_script.schema(type_id) as Array):
		var s := spec as Dictionary
		d[str(s.get("key"))] = s.get("default")
	return kind_script.from_dict(d)
