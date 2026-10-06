class_name RulePanel
extends Control
## 详细设计：[docs/design/09-指令编辑界面.md](../../docs/design/09-指令编辑界面.md)
##
## 左侧抽屉式指令面板：**占屏宽 1/3**，从左侧滑入。玩家点场上单位后打开，
## 在这里编「如果 / 则」指令。第一关只需要「沿着信标移动」这一条行为，
## 但面板按通用结构搭（条件区 + 行为区 + 信标序号列表），
## 后续加条件类型不用改结构。
##
## 【布局约定】与选关页一致：锚点 + 容器，宽度用 `anchor` 比例表达
## （左 0 → 右 1/3），因此任何窗口尺寸下都恰好占 1/3，不会溢出。
##
## 【边界】只操作传入单位的 `rules` 数组（Rule 对象）；不碰 LevelSession、
## 不改单位状态。规则求值归系统 02。

const RuleScript := preload("res://src/core/rule/rule.gd")
const RuleConditionScript := preload("res://src/core/rule/condition.gd")
const RuleActionScript := preload("res://src/core/rule/action.gd")

const ActionScript := preload("res://src/core/rule/action.gd")
const RuleFieldFactoryScript := preload("res://src/ui/rule_panel/field_factory.gd")
const RuleRowScript := preload("res://src/ui/rule_panel/rule_row.gd")

## 一行内直接显示的条件数上限，超过则折叠（D-20）
const MAX_VISIBLE_CONDITIONS := 3
## 抽屉宽度占屏宽比例。
##
## 【1/3 → 0.42】需求原本确认的是"左侧抽屉，占 1/3"。改成左右分栏后，
## 1/3（1920 下 640px，去掉内边距只剩 600px）分两栏每栏仅约 295px，
## 条件/行为的类型下拉会被压到显示不全。0.42（806px）下每栏约 377px，够用。
## **相机偏移是按 drawer_width() 算的**（见 play_scene 的 _apply_camera_offset），
## 所以加宽抽屉不会让地图跑偏。
const WIDTH_RATIO := 0.42

signal closed
## 规则表被改动（让上层可以刷新 UI / 标黄）
signal rules_changed
## 把一条指令复制到了别的单位（玩法场景据此重算 invalid_reason，详设 09 的 4.7）
signal rule_copied(target_unit)

var target_unit = null
var _open := false
## 抽屉顶端留白（由玩法场景设为工具条高度），避免遮住工具条按钮
var top_offset := 56.0
## 信标序号按钮最多显示到几号（由玩法场景按关卡配额设置）。
## 原来固定排到 10，第一关配额只有 4，白占 5 行（截图里看出来的）。
var max_beacons := 10
## 折叠状态：rule 序号(字符串) → 是否折起。**只是显示状态，不写入数据**（详设 09 的 4.7）
var _folded: Dictionary = {}
## 拖拽排序：插入指示线（详设 09 的 4.3）
var _indicator: ColorRect = null
## 正在拖的行号（-1 表示没在拖）
var _drag_from := -1
## 最近一次 hover 算出的"插入到第几位"（原始下标语义，可为 rules.size()）
var _drop_at := -1

## 面板内的临时提示条（冲突守卫等），HINT_SECONDS 秒后自动消失
var _hint: Label = null
var _hint_timer := 0.0
const HINT_SECONDS := 3.0

## 【D-23】策划案 v2 3.3.2：「每条指令至多有一个行为和 2 个条件」。
## 我们**只提示、不硬禁** —— D-20 已把「多条件折叠显示」定为 MVP 功能，
## 硬禁等于推翻已确认决策并删掉已实现的功能。等策划确认后再决定是否收紧。
const RULE_ACT_LIMIT := 1
const RULE_COND_LIMIT := 2
## 可以把指令复制过去的**其它我方单位**（由玩法场景提供）。
## 【为什么由外部给】面板只认识"正在编辑的那个单位"，
## 而"本关还有哪些我方单位"是关卡会话的知识。
var sibling_units: Array = []
## 每条指令的「左条件 / 右行为」两栏引用（供 `split_rects()` 报告布局）。
##
## 【为什么不靠节点名字去 find_child】我第一版是在截图脚本里
## `rp.find_child("Conds_0", true, false)` —— 结果**永远找不着**（返回 null），
## 于是"左条件右行为"的像素断言被**静默跳过**，报告照样全绿。
## 面板自己就知道这两栏是谁，直接把它报出来既准确又不会因改名而失效。
var _split_refs: Dictionary = {}
## 引用类参数（信标/信号）的候选项数量。**每次打开面板都要更新**：
## 信标是玩家动态放的（详设 09 的 3.2）。
var beacon_count := 0
var signal_count := 1

var _root: PanelContainer
var _title: Label
var _rules_box: VBoxContainer
var _empty_hint: Label
var _add_button: Button
var _scroll: ScrollContainer
## 正在编辑的行为下拉选中项
var _action_picker: OptionButton
var _action_param_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	_apply_open(false, true)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE        # 收起时不吃点击

	_root = PanelContainer.new()
	_root.name = "Drawer"
	# 【用绝对偏移，不用锚点比例】锚点比例依赖父 Control 的尺寸，而本面板挂在
	# CanvasLayer 下，实测父尺寸是 (0,0) → 锚点 0→1/3 算出 0 宽 → PanelContainer
	# 退化成"内容最小尺寸"（实测抽屉只有 334×293、比例 0.174 而不是 0.333）。
	# 改成锚点全 0 + `_layout_drawer()` 里按**视口尺寸**写显式偏移，结果确定。
	_root.anchor_left = 0.0
	_root.anchor_right = 0.0
	_root.anchor_top = 0.0
	_root.anchor_bottom = 0.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.16, 0.97)
	sb.border_color = Color(0.28, 0.32, 0.40)
	sb.border_width_right = 2
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 12)
	_root.add_child(col)

	# ---- 标题行 ----
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	_title = Label.new()
	_title.name = "UnitTitle"
	_title.text = "未选中单位"
	_title.add_theme_font_size_override("font_size", 26)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)

	var close := Button.new()
	close.name = "CloseButton"
	close.text = "关闭"
	close.custom_minimum_size = Vector2(88, 40)
	close.pressed.connect(_on_close_pressed)
	head.add_child(close)

	# ---- 规则列表（可滚动）----
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "指令表（自上而下；下面的覆盖上面的）"
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	# 【不要用 AUTOWRAP_WORD_SMART 之外的模式】并且**不设 custom_minimum_size.x**，
	# 否则会抬高整块的最小宽度、把抽屉撑出 1/3 之外。
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(caption)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	_rules_box = VBoxContainer.new()
	_rules_box.name = "Rules"
	_rules_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rules_box.add_theme_constant_override("separation", 10)
	_scroll.add_child(_rules_box)

	_empty_hint = Label.new()
	_empty_hint.name = "EmptyHint"
	_empty_hint.text = "还没有指令。点下面的「加一条指令」，选择行为。"
	_empty_hint.add_theme_font_size_override("font_size", 18)
	_empty_hint.add_theme_color_override("font_color", Color(0.70, 0.73, 0.80))
	_empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_box.add_child(_empty_hint)

	# ---- 新增区 ----
	var add_row := HBoxContainer.new()
	add_row.name = "AddRow"
	add_row.add_theme_constant_override("separation", 8)
	col.add_child(add_row)

	_action_picker = OptionButton.new()
	_action_picker.name = "ActionPicker"
	_action_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_picker.clip_text = true
	for t in ActionScript.all_types():
		# 装置互动在 MVP 不实现（D-13），不进候选
		if str(t) == ActionScript.T_INTERACT_DEVICE:
			continue
		_action_picker.add_item(ActionScript.display_name(str(t)))
		_action_picker.set_item_metadata(_action_picker.item_count - 1, str(t))
	add_row.add_child(_action_picker)

	_add_button = Button.new()
	_add_button.name = "AddRuleButton"
	_add_button.text = "加一条指令"
	_add_button.custom_minimum_size = Vector2(150, 44)
	_add_button.pressed.connect(_on_add_rule)
	add_row.add_child(_add_button)

	_action_param_box = VBoxContainer.new()
	_action_param_box.name = "ActionHint"
	col.add_child(_action_param_box)
	# 提示：所有指令都没有条件时无条件成立
	var note := Label.new()
	note.text = "第一关只需「沿着信标移动」：加一条指令，然后按顺序点信标列表里的序号。"
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_param_box.add_child(note)

	# 临时提示条（冲突守卫等）。默认隐藏，_flash_hint 时显示并在几秒后自动收起。
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.visible = false
	_action_param_box.add_child(_hint)

	# 插入指示线：**必须挂在 self 而不是 _rules_box 上** ——
	# _rules_box 是 VBoxContainer，会接管子节点的位置，手动定位会被它覆盖。
	# self（RulePanel）是 Control，子节点保留手动 position/size。
	_indicator = ColorRect.new()
	_indicator.name = "DropIndicator"
	_indicator.color = Color(0.45, 0.85, 1.0)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.visible = false
	add_child(_indicator)

	# 抽屉初始滑出屏外：靠 offset_left 负值实现（用宽度比例算）
	_layout_drawer()


func _process(delta: float) -> void:
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0 and _hint != null:
			_hint.visible = false


func _layout_drawer() -> void:
	# 一切尺寸都由**视口**推导，不读父节点尺寸（挂在 CanvasLayer 下实测父尺寸为 0）。
	#
	# 收起 = 整体平移到左边界外，**宽度不变**。
	# 【坑】"收起"不能只改 offset_left：那样 offset_right 仍是 0，抽屉会被
	# **拉宽**成 `屏宽×1/3 + 隐藏偏移`（1920 下实测被拉到 1288px）。
	# 正确做法是左右偏移一起平移，保持宽度恒定。
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 1920.0
	var vh: float = vp.y if vp.y > 0.0 else 1080.0
	var w: float = vw * WIDTH_RATIO
	var hide := -w - 8.0

	# 【锚点全 0 时，宽度 = offset_right - offset_left，所以两个偏移都要算】
	# 展开：left=0, right=w          → 宽 w
	# 收起：left=-w-8, right=-8     → 宽仍是 w，整体移出左边界
	# 只写 left 而让 right=left 的话宽度会变成 0，PanelContainer 就退化成内容尺寸
	# （实测收缩态只有 334 宽）。这一点我踩了两次。
	_root.offset_left = 0.0 if _open else hide
	_root.offset_right = w if _open else (hide + w)
	# 从工具条下方开始，避免遮住工具栏左侧的按钮
	_root.offset_top = top_offset
	_root.offset_bottom = vh


## 「左条件 / 右行为」两栏的全局矩形（供测试与截图断言用）。
##
## 返回 `{conds: [x,y,w,h], acts: [...], arrow: [...]}`；指令不存在时返回空字典。
func split_rects(rule_index: int = 0) -> Dictionary:
	if not _split_refs.has(rule_index):
		return {}
	var e: Dictionary = _split_refs[rule_index]
	var c = e.get("conds")
	var a = e.get("acts")
	if c == null or a == null or not is_instance_valid(c) or not is_instance_valid(a):
		return {}
	var rc: Rect2 = (c as Control).get_global_rect()
	var ra: Rect2 = (a as Control).get_global_rect()
	var out := {
		"conds": [rc.position.x, rc.position.y, rc.size.x, rc.size.y],
		"acts": [ra.position.x, ra.position.y, ra.size.x, ra.size.y],
		"arrow": [],
	}
	var arrow := (c as Control).get_parent().get_node_or_null("Arrow_%d" % rule_index)
	if arrow is Control:
		var rr: Rect2 = (arrow as Control).get_global_rect()
		out["arrow"] = [rr.position.x, rr.position.y, rr.size.x, rr.size.y]
	return out


## 公开的刷新入口。
##
## 【为什么需要】玩法场景要在"信标变动 / 指令被复制"后让面板重画，
## 而重画原本只有私有 `_rebuild()` —— 外部只能 `call("_rebuild")` 去捅私有方法，
## 既难看又容易改名后失效（我就先写成了不存在的 `refresh()`，一串运行期错误）。
func refresh() -> void:
	if _open:
		_rebuild()


## 设置"可以复制过去的其它我方单位"（由玩法场景提供本关的单位列表）。
## 面板不认识关卡会话，所以这份名单必须从外面递进来。
func set_sibling_units(units: Array) -> void:
	sibling_units = units
	if _open:
		_rebuild()


## 抽屉顶端留出的空间（由玩法场景设为工具条高度）
func set_top_offset(px: float) -> void:
	top_offset = maxf(0.0, px)
	_layout_drawer()


## 设信标序号按钮上限（= 关卡配额），避免排出一堆用不到的号
func set_max_beacons(n: int) -> void:
	max_beacons = maxi(1, n)
	if _open:
		_rebuild()


## 更新引用类参数的候选项数量。**信标数会随玩家放置变化**，
## 所以玩法场景在「打开面板」与「信标变动」时都要调它（详设 09 的 3.2）。
func set_context(p_beacon_count: int, p_signal_count: int) -> void:
	beacon_count = maxi(0, p_beacon_count)
	signal_count = maxi(1, p_signal_count)
	if _open:
		_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_drawer()


# ---------------------------------------------------------------------------
# 开关
# ---------------------------------------------------------------------------

func is_open() -> bool:
	return _open


## 打开面板并编辑指定单位
func open_for(unit) -> void:
	target_unit = unit
	_open = true
	_apply_open(true)
	_rebuild()


## 关闭面板
func close() -> void:
	_open = false
	_apply_open(false)
	target_unit = null
	closed.emit()


func _apply_open(animate_state: bool, immediate: bool = false) -> void:
	if _root == null:
		return
	visible = true
	_root.visible = true
	if immediate:
		_layout_drawer()
	else:
		_layout_drawer()
	if not _open:
		# 收起时整层不拦点击（地图还能操作）
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_root.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_close_pressed() -> void:
	close()


# ---------------------------------------------------------------------------
# 规则渲染
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	_split_refs.clear()
	for c in _rules_box.get_children():
		# 【必须先 remove_child 再 queue_free】queue_free 帧末才执行，
		# 只调它的话旧节点本帧仍是子节点 —— 同一帧里连续重建两次就会出现
		# 重复的行（介绍弹窗数 tip 时踩过同一个坑）。
		_rules_box.remove_child(c)
		c.queue_free()

	if target_unit == null:
		_title.text = "未选中单位"
		_add_empty_hint("请先点场上的单位")
		return

	var rules: Array = target_unit.get("rules")
	_title.text = "单位 %d（%s）" % [
		int(target_unit.get("entity_id")),
		"我方" if int(target_unit.get("team")) == 0 else "敌方",
	]

	if rules.is_empty():
		_add_empty_hint("还没有指令。点下面的「加一条指令」，选择行为。")
		return

	for i in rules.size():
		_rules_box.add_child(_build_rule_row(i, rules[i]))


func _add_empty_hint(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.70, 0.73, 0.80))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_box.add_child(l)


## 一条指令一块面板：序号 + 启用 + 与/或 + 条件列 + 行为列 + 删除
##
## 【结构对应详设 09 的 1.3 与 4.1】「如果」列可放多个条件（竖排），
## 「则」列可放多个行为；每条指令一个「与/或」；参数控件由 schema 生成。
func _build_rule_row(index: int, rule) -> Control:
	var row := RuleRowScript.new()
	row.name = "Rule_%d" % index
	row.set("row_index", index)
	row.connect("drag_started", _on_drag_started)
	row.connect("drag_hover", _on_drag_hover)
	row.connect("drag_dropped", _on_drag_dropped)
	row.connect("drag_ended", _on_drag_ended)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	# 【无效指令标黄用**行底色**，不依赖展开状态】详设 09 的 4.7 明确要求
	# 折叠时也要看得见。所以把标黄做在面板底色上。
	var invalid := not str(rule.get("invalid_reason")).is_empty()
	if invalid:
		sb.bg_color = Color(0.30, 0.24, 0.12, 1.0)
		sb.border_color = Color(1.0, 0.78, 0.35)
		sb.set_border_width_all(1)
	else:
		sb.bg_color = Color(0.16, 0.18, 0.23, 1.0)
	row.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.name = "Body"
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)

	# ---- 头部：序号 + 启用 + 与/或 + 删除 ----
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)

	var num := Label.new()
	num.text = "%d." % (index + 1)
	num.add_theme_font_size_override("font_size", 19)
	head.add_child(num)

	var enabled_cb := CheckBox.new()
	enabled_cb.name = "Enabled_%d" % index
	enabled_cb.text = "启用"
	enabled_cb.button_pressed = bool(rule.get("enabled"))
	enabled_cb.add_theme_font_size_override("font_size", 17)
	enabled_cb.toggled.connect(_on_toggle_enabled.bind(index))
	head.add_child(enabled_cb)

	var logic_lab := Label.new()
	logic_lab.text = "条件逻辑"
	logic_lab.add_theme_font_size_override("font_size", 17)
	head.add_child(logic_lab)

	var logic_ob := OptionButton.new()
	logic_ob.name = "Logic_%d" % index
	logic_ob.add_item("与")           # 0 = AND
	logic_ob.add_item("或")           # 1 = OR
	logic_ob.selected = int(rule.get("condition_logic"))
	logic_ob.item_selected.connect(_on_logic_changed.bind(index))
	head.add_child(logic_ob)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)


	# 上移/下移：拖拽之外的**可靠**排序途径（也便于自动化验证）。
	# 机制是"下面的覆盖上面的"，所以调序是核心操作，不能只有拖拽一条路。
	var up := Button.new()
	up.name = "Up_%d" % index
	up.text = "↑"
	up.tooltip_text = "上移（提高优先级）"
	up.custom_minimum_size = Vector2(38, 36)
	up.disabled = index == 0
	up.pressed.connect(_on_move_rule.bind(index, index - 1))
	head.add_child(up)

	var down := Button.new()
	down.name = "Down_%d" % index
	down.text = "↓"
	down.tooltip_text = "下移（降低优先级）"
	down.custom_minimum_size = Vector2(38, 36)
	down.disabled = index >= _rule_count() - 1
	down.pressed.connect(_on_move_rule.bind(index, index + 1))
	head.add_child(down)

	var copy_btn := Button.new()
	copy_btn.name = "Copy_%d" % index
	copy_btn.text = "复制到…"
	copy_btn.tooltip_text = "把这条指令深拷贝到本关其它我方单位（D-20）"
	copy_btn.custom_minimum_size = Vector2(84, 36)
	copy_btn.disabled = sibling_units.is_empty()
	copy_btn.pressed.connect(_on_copy_pressed.bind(index, copy_btn))
	head.add_child(copy_btn)

	var del := Button.new()
	del.name = "Del_%d" % index
	del.text = "删"
	del.custom_minimum_size = Vector2(48, 36)
	del.pressed.connect(_on_delete_rule.bind(index))
	head.add_child(del)

	# 【无效原因必须独占整行】原来它挂在头部的 HBoxContainer 里 + 开了 autowrap，
	# 而 HBox 会把子节点压到最小宽度 → 中文**逐字竖排**成一列
	# （截图里一眼可见）。这和提示条 Banner 踩的是同一个坑（见开发进度第 42 条）。
	# 全宽 Label 放在头行之下即可。
	if invalid:
		var warn := Label.new()
		warn.name = "InvalidReason_%d" % index
		warn.text = str(rule.get("invalid_reason"))
		warn.add_theme_font_size_override("font_size", 16)
		warn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(warn)

	# ---- 左：条件（如果） / 右：行为（则）----
	#
	# 【用户补充需求】「主角单位的行为编辑 UI 显示应为左条件右行为的结构」。
	# 原来是**上下堆叠**（先条件区、再行为区），一屏里最多只看得到一条指令的
	# 一半，而且"如果…则…"的对应关系要靠读文字才能建立。
	# 左右并排之后，一眼就是「条件 → 行为」，也与指令本身的语义同构。
	#
	# 两栏等宽（stretch_ratio 都是 1），中间放一个箭头当分隔兼提示。
	var split := HBoxContainer.new()
	split.name = "Split_%d" % index
	split.add_theme_constant_override("separation", 10)

	var left := _build_condition_section(index, rule)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	var arrow := Label.new()
	arrow.name = "Arrow_%d" % index
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 22)
	arrow.add_theme_color_override("font_color", Color(0.55, 0.60, 0.72))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	split.add_child(arrow)

	var right := _build_action_section(index, rule)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	col.add_child(split)
	_split_refs[index] = {"conds": left, "acts": right}

	# 【D-23】超过策划案建议时的**提示**（不是禁止）
	var n_conds := (rule.get("conditions") as Array).size()
	var n_acts := (rule.get("actions") as Array).size()
	if n_conds > RULE_COND_LIMIT or n_acts > RULE_ACT_LIMIT:
		var warn := Label.new()
		warn.name = "LimitWarn_%d" % index
		var bits: Array[String] = []
		if n_acts > RULE_ACT_LIMIT:
			bits.append("行为 %d 个（建议 ≤ %d）" % [n_acts, RULE_ACT_LIMIT])
		if n_conds > RULE_COND_LIMIT:
			bits.append("条件 %d 个（建议 ≤ %d）" % [n_conds, RULE_COND_LIMIT])
		warn.text = "⚠ 超出策划案建议：%s（仍可保存与运行）" % "、".join(bits)
		warn.add_theme_font_size_override("font_size", 16)
		warn.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)

	return row


## 「如果」区：条件列表 + 与/或提示 + 加条件
func _build_condition_section(rule_index: int, rule) -> Control:
	var box := VBoxContainer.new()
	box.name = "Conds_%d" % rule_index
	box.add_theme_constant_override("separation", 4)

	var conds: Array = rule.get("conditions")
	var header := Label.new()
	var logic_word := "与" if int(rule.get("condition_logic")) == 0 else "或"
	header.text = "条件（如果 %d 个，%s）" % [conds.size(), logic_word] if not conds.is_empty() \
		else "条件（无条件 → 总是成立）"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	box.add_child(header)

	# 【多条件折叠（D-20）】一行内多于 3 个条件时折叠为「N 个条件 ▸」。
	# 折叠只是**显示状态**，不写入数据（详设 09 的 4.7）。
	var fold_key := "%d" % rule_index
	var folded: bool = _folded.get(fold_key, false)
	var show_all := conds.size() <= MAX_VISIBLE_CONDITIONS or not folded

	if conds.size() > MAX_VISIBLE_CONDITIONS:
		var fold_btn := Button.new()
		fold_btn.name = "Fold_%d" % rule_index
		fold_btn.text = "%d 个条件 ▸" % conds.size() if folded else "收起 ▾"
		fold_btn.custom_minimum_size = Vector2(0, 30)
		fold_btn.pressed.connect(_on_toggle_fold.bind(fold_key))
		box.add_child(fold_btn)

	for i in conds.size():
		if not show_all and i >= MAX_VISIBLE_CONDITIONS:
			break
		box.add_child(_build_condition_row(rule_index, i, conds[i]))

	var add := Button.new()
	add.name = "AddCond_%d" % rule_index
	add.text = "+ 条件"
	add.custom_minimum_size = Vector2(0, 32)
	add.pressed.connect(_on_add_condition.bind(rule_index))
	box.add_child(add)
	return box


## 单个条件：类型下拉 + 按 schema 生成的参数控件 + 删
func _build_condition_row(rule_index: int, cond_index: int, cond) -> Control:
	var row := PanelContainer.new()
	row.name = "Cond_%d_%d" % [rule_index, cond_index]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.19, 1.0)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)

	var picker := OptionButton.new()
	picker.name = "CondType_%d_%d" % [rule_index, cond_index]
	picker.clip_text = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var types := RuleConditionScript.all_types()
	for i in types.size():
		picker.add_item(RuleConditionScript.display_name(str(types[i])))
		picker.set_item_metadata(i, str(types[i]))
		if str(types[i]) == str(cond.get("type")):
			picker.selected = i
	picker.item_selected.connect(func(_i: int) -> void:
		_on_condition_type_changed(rule_index, cond_index))
	head.add_child(picker)

	var del := Button.new()
	del.name = "DelCond_%d_%d" % [rule_index, cond_index]
	del.text = "删"
	del.custom_minimum_size = Vector2(44, 30)
	del.pressed.connect(_on_delete_condition.bind(rule_index, cond_index))
	head.add_child(del)

	# 参数控件：由 schema 决定
	col.add_child(_build_param_controls(rule_index, cond_index, RuleConditionScript, cond))
	return row


## 「则」区：行为列表 + 加行为；action 为空时给淡色提示
func _build_action_section(rule_index: int, rule) -> Control:
	var box := VBoxContainer.new()
	box.name = "Acts_%d" % rule_index
	box.add_theme_constant_override("separation", 4)

	var acts: Array = rule.get("actions")
	var header := Label.new()
	header.text = "行为（则 %d 个）" % acts.size()
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	box.add_child(header)

	if acts.is_empty():
		# 详设 09 的 4.1：actions 为空等价于「什么都不做」，但仍计入评价数量
		var hint := Label.new()
		hint.name = "NoAction_%d" % rule_index
		hint.text = "这条指令没有行为（不做事，但仍计入评价）"
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_color", Color(0.78, 0.70, 0.55))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)

	for i in acts.size():
		box.add_child(_build_action_row(rule_index, i, acts[i]))

	var add := Button.new()
	add.name = "AddAct_%d" % rule_index
	add.text = "+ 行为"
	add.custom_minimum_size = Vector2(0, 32)
	add.pressed.connect(_on_add_action.bind(rule_index))
	box.add_child(add)
	return box


func _build_action_row(rule_index: int, act_index: int, action) -> Control:
	var row := PanelContainer.new()
	row.name = "Act_%d_%d" % [rule_index, act_index]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.19, 1.0)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)

	var picker := OptionButton.new()
	picker.name = "ActType_%d_%d" % [rule_index, act_index]
	picker.clip_text = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var types: Array = []
	for t in ActionScript.all_types():
		if str(t) != ActionScript.T_INTERACT_DEVICE:      # MVP 不实现（D-13）
			types.append(str(t))
	for i in types.size():
		picker.add_item(ActionScript.display_name(str(types[i])))
		picker.set_item_metadata(i, str(types[i]))
		if str(types[i]) == str(action.get("type")):
			picker.selected = i
	picker.item_selected.connect(func(_i: int) -> void:
		_on_action_type_changed(rule_index, act_index))
	head.add_child(picker)

	var del := Button.new()
	del.name = "DelAct_%d_%d" % [rule_index, act_index]
	del.text = "删"
	del.custom_minimum_size = Vector2(44, 30)
	del.pressed.connect(_on_delete_action.bind(rule_index, act_index))
	head.add_child(del)

	# 【信标序列用专门的网格控件】schema 里的 beacon_seq 返回 null，
	# 由 _build_beacon_editor 负责（它要按 max_beacons 排号）。
	if str(action.get("type")) == ActionScript.T_MOVE_ALONG_BEACONS:
		col.add_child(_build_beacon_editor(rule_index, action))
	else:
		col.add_child(_build_param_controls(rule_index, act_index, ActionScript, action))
	return row


## 按 schema 生成参数控件行。kind_script 决定查哪张 schema 表。
func _build_param_controls(rule_index: int, item_index: int, kind_script, obj) -> Control:
	var box := VBoxContainer.new()
	box.name = "Params_%d_%d" % [rule_index, item_index]
	box.add_theme_constant_override("separation", 3)

	var ctx := {"beacon_count": beacon_count, "signal_count": signal_count}
	var changed := func(key: String, value) -> void:
		_on_param_changed(rule_index, item_index, kind_script, key, value)
	for spec in (kind_script.schema(str(obj.get("type"))) as Array):
		if str((spec as Dictionary).get("type")) == "beacon_seq":
			continue                       # 由 _build_beacon_editor 负责
		box.add_child(RuleFieldFactoryScript.make_row(
			spec as Dictionary, obj.get(spec["key"]), ctx, changed))
	return box


func _build_beacon_editor(rule_index: int, action) -> Control:
	var box := VBoxContainer.new()
	box.name = "BeaconEditor_%d" % rule_index
	box.add_theme_constant_override("separation", 4)

	var cap := Label.new()
	var seq: Array = action.get("beacon_indices")
	cap.text = "沿信标顺序：%s" % ("无" if seq.is_empty() else str(seq))
	cap.add_theme_font_size_override("font_size", 17)
	cap.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cap)

	# 【必须用网格而不是一行排开】抽屉宽度 = 屏宽 × 1/3（窄屏约 640px），
	# 而 PanelContainer 会在**内容最小宽度大于锚点宽度时把整块撑出去** ——
	# 一行放 8 个 40px 按钮 + 清空按钮时，抽屉实测撑到 1288px，
	# 「占 1/3」直接失效（M5 实测）。改成 2 列网格后最小宽度降下来，
	# 抽屉才真的守住 1/3。
	var grid := GridContainer.new()
	grid.name = "BeaconGrid_%d" % rule_index
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	for n in range(1, maxi(1, max_beacons) + 1):
		var b := Button.new()
		b.name = "Beacon_%d_%d" % [rule_index, n]
		b.text = str(n)
		b.custom_minimum_size = Vector2(44, 34)
		b.pressed.connect(_on_append_beacon.bind(rule_index, n))
		grid.add_child(b)

	var clr := Button.new()
	clr.name = "Clear_%d" % rule_index
	clr.text = "清空"
	clr.custom_minimum_size = Vector2(44, 34)
	clr.pressed.connect(_on_clear_beacons.bind(rule_index))
	grid.add_child(clr)
	return box


func _rule_summary(rule) -> String:
	var parts: Array = []
	var conds: Array = rule.get("conditions")
	if conds.is_empty():
		parts.append("无条件")
	else:
		for c in conds:
			parts.append(RuleConditionScript.display_name(str(c.get("type"))))
	for a in (rule.get("actions") as Array):
		parts.append(ActionScript.display_name(str(a.get("type"))))
	return " ｜ ".join(parts)


# ---------------------------------------------------------------------------
# 排序（FR-CMD-08：数组下标即优先级）
# ---------------------------------------------------------------------------

func _rule_count() -> int:
	if target_unit == null:
		return 0
	return (target_unit.get("rules") as Array).size()


## 把第 from_i 条指令移到 to_i。**排序的唯一数据改动入口** ——
## 上移/下移按钮与拖拽都调它，避免两套实现分叉。
##
## 语义：`to_i` 是移动后该条指令的**最终下标**（0 起，会被夹到合法范围）。
func move_rule(from_i: int, to_i: int) -> bool:
	if target_unit == null:
		return false
	var rules: Array = target_unit.get("rules")
	if from_i < 0 or from_i >= rules.size():
		return false
	to_i = clampi(to_i, 0, rules.size() - 1)
	if to_i == from_i:
		return false
	var r = rules[from_i]
	rules.remove_at(from_i)
	rules.insert(to_i, r)
	_rebuild()
	rules_changed.emit()
	return true


# ---------------------------------------------------------------------------
# 指令复制到其它单位（D-20 / 详设 09 的 4.7）
# ---------------------------------------------------------------------------

## 把本单位的第 rule_index 条指令**深拷贝**后追加到 target 的规则表末尾。
##
## 【深拷贝是硬要求】浅拷贝（或直接塞同一个对象）会让两个单位的指令联动 ——
## 改 B 的参数 A 也跟着变。详设 09 的 4.7 把这条列为验收项，所以
## 拷贝由 `Rule.clone()` 统一负责，本函数不做任何"手工拼字段"。
func copy_rule_to_unit(rule_index: int, target) -> bool:
	if target_unit == null or target == null or target == target_unit:
		return false
	var src_rules: Array = target_unit.get("rules")
	if rule_index < 0 or rule_index >= src_rules.size():
		return false
	var dst_rules: Array = target.get("rules")
	dst_rules.append(RuleScript.clone(src_rules[rule_index]))
	rules_changed.emit()
	rule_copied.emit(target)
	return true


## 点「复制到…」→ 弹一个本单位之外的我方单位列表
func _on_copy_pressed(rule_index: int, anchor: Button) -> void:
	if sibling_units.is_empty():
		_flash_hint("本关没有其它我方单位可以复制")
		return
	var menu := PopupMenu.new()
	menu.name = "CopyMenu_%d" % rule_index
	add_child(menu)
	for u in sibling_units:
		if u == null or u == target_unit:
			continue
		menu.add_item("单位 %d（我方）" % int(u.get("entity_id")), menu.item_count)
		menu.set_item_metadata(menu.item_count - 1, u)
	menu.id_pressed.connect(func(id: int) -> void:
		var tgt = menu.get_item_metadata(id)
		if copy_rule_to_unit(rule_index, tgt):
			_flash_hint("已复制到单位 %d" % int(tgt.get("entity_id")))
		menu.queue_free())
	# 弹出位置：贴在按钮下方。用 global 坐标避免受抽屉偏移影响
	menu.position = Vector2i(int(anchor.global_position.x),
		int(anchor.global_position.y + anchor.size.y))
	menu.popup()


func _on_move_rule(from_i: int, to_i: int) -> void:
	move_rule(from_i, to_i)


## 把"插到第 row 行之前/之后"翻译成 move_rule 要的最终下标。
##
## 【为什么要换算】拖拽给的是**原始下标里的插入位**（可为 rules.size()），
## 而 move_rule 要的是**移除之后**的最终下标。源在插入位之前时，移除会让
## 插入位前移一格 —— 漏掉这一步就会稳定偏一位。
func drop_to_index(from_i: int, row: int, before: bool) -> int:
	var insert_before := row if before else row + 1
	if from_i < insert_before:
		insert_before -= 1
	return insert_before


func _on_drag_started(row: int) -> void:
	_drag_from = row
	_drop_at = -1


func _on_drag_hover(row: int, before: bool) -> void:
	_drop_at = drop_to_index(_drag_from, row, before)
	_show_indicator(row, before)


func _on_drag_dropped(row: int, before: bool) -> void:
	var to_i := drop_to_index(_drag_from, row, before)
	_hide_indicator()
	if move_rule(_drag_from, to_i):
		_flash_hint("已移到第 %d 条" % (to_i + 1))
	_drag_from = -1


func _on_drag_ended() -> void:
	_hide_indicator()
	_drag_from = -1
	_drop_at = -1


## 把指示线画在目标行的上/下边缘
func _show_indicator(row: int, before: bool) -> void:
	if _indicator == null:
		return
	var node := _rules_box.get_node_or_null("Rule_%d" % row)
	if node == null:
		return
	var r := (node as Control).get_global_rect()
	var my := get_global_rect().position
	var y := (r.position.y - my.y) if before else (r.position.y + r.size.y - my.y)
	_indicator.position = Vector2(drawer_width() * 0.05, maxf(0.0, y - 1.5))
	_indicator.size = Vector2(drawer_width() * 0.9, 3.0)
	_indicator.visible = true
	_indicator.move_to_front()


func _hide_indicator() -> void:
	if _indicator != null:
		_indicator.visible = false


func indicator_visible() -> bool:
	return _indicator != null and _indicator.visible


func indicator_y() -> float:
	return _indicator.position.y if _indicator != null else -1.0


# ---------------------------------------------------------------------------
# 条件 / 行为的编辑处理
# ---------------------------------------------------------------------------

## 取该指令里第 item_index 个条件或行为。
## kind_script 传 RuleConditionScript 表示条件，传 ActionScript 表示行为。
func _item_at(rule_index: int, item_index: int, kind_script):
	if target_unit == null:
		return null
	var rules: Array = target_unit.get("rules")
	if rule_index < 0 or rule_index >= rules.size():
		return null
	var rule = rules[rule_index]
	var arr: Array = rule.get("conditions") if kind_script == RuleConditionScript \
		else rule.get("actions")
	if item_index < 0 or item_index >= arr.size():
		return null
	return arr[item_index]


## 把第 item_index 项**换掉**（用于"切换类型"）。
##
## 【为什么是"换对象"而不是"就地重置"】我原来写的是
## `c.call("reset_to_default", t)` —— 而 `Condition` / `Action` **都没有这个方法**
## （用户实测：把一条行为改成「开火模式」时直接报
## `Nonexistent function 'reset_to_default'` 并中断）。
##
## 换类型等于换**整套参数**（每个类型的 schema 不同），
## 最稳的做法就是照 schema 造一个全新的对象再替换 ——
## 而不是指望旧对象能"就地变成另一种类型"。
## 默认值也走 schema（`make_default_from_schema`），
## 这样 UI 上显示的值与数据结构里的值**始终一致**。
func _replace_item(rule_index: int, item_index: int, kind_script, type_id: String) -> bool:
	if target_unit == null:
		return false
	var rules: Array = target_unit.get("rules")
	if rule_index < 0 or rule_index >= rules.size():
		return false
	var rule = rules[rule_index]
	var arr: Array = rule.get("conditions") if kind_script == RuleConditionScript \
		else rule.get("actions")
	if item_index < 0 or item_index >= arr.size():
		return false
	arr[item_index] = RuleFieldFactoryScript.make_default_from_schema(kind_script, type_id)
	return true


func _on_toggle_enabled(on: bool, rule_index: int) -> void:
	var rule = _rule_at(rule_index)
	if rule == null:
		return
	rule.set("enabled", on)
	rules_changed.emit()


func _on_logic_changed(selected: int, rule_index: int) -> void:
	var rule = _rule_at(rule_index)
	if rule == null:
		return
	rule.set("condition_logic", selected)
	_rebuild()                      # 头部文字要跟着变
	rules_changed.emit()


## 折叠/展开多条件行。**只改显示状态，不碰 Rule.conditions**（详设 09 的 4.7）
func _on_toggle_fold(fold_key: String) -> void:
	_folded[fold_key] = not bool(_folded.get(fold_key, false))
	_rebuild()


func _on_add_condition(rule_index: int) -> void:
	var rule = _rule_at(rule_index)
	if rule == null:
		return
	# 默认取该类型 schema 的 default（详设 09 的 6.1）
	var default_type := str((RuleConditionScript.all_types() as Array)[0])
	var c: RefCounted = RuleFieldFactoryScript.make_default_from_schema(
		RuleConditionScript, default_type)
	(rule.get("conditions") as Array).append(c)
	_rebuild()
	rules_changed.emit()


func _on_delete_condition(rule_index: int, cond_index: int) -> void:
	var rule = _rule_at(rule_index)
	if rule == null:
		return
	var arr: Array = rule.get("conditions")
	if cond_index >= 0 and cond_index < arr.size():
		arr.remove_at(cond_index)
	_rebuild()
	rules_changed.emit()


func _on_condition_type_changed(rule_index: int, cond_index: int) -> void:
	var c = _item_at(rule_index, cond_index, RuleConditionScript)
	if c == null:
		return
	var picker := _rules_box.find_child("CondType_%d_%d" % [rule_index, cond_index], true, false)
	if picker is OptionButton:
		var t := str((picker as OptionButton).get_item_metadata((picker as OptionButton).selected))
		# 换类型 → 用该类型的 **schema 默认值**造一个新对象替换掉旧的
		_replace_item(rule_index, cond_index, RuleConditionScript, t)
	_rebuild()
	rules_changed.emit()


func _on_add_action(rule_index: int) -> void:
	var rule = _rule_at(rule_index)
	if rule == null:
		return
	# 默认追加的行为取「开火」（详设 09 的 4.1：新建指令 actions=[默认开火]）
	var default_type := ActionScript.T_SET_FIRE_MODE
	var a: RefCounted = RuleFieldFactoryScript.make_default_from_schema(
		ActionScript, default_type)
	# 【冲突守卫】互斥行为不能出现在同一条指令里（详设 09 的 4.4）。
	# 冲突键直接用系统 02 的 `conflict_key()`，不在这里另立一套口径。
	var conflict := str(a.call("conflict_key"))
	if not conflict.is_empty() and _rule_has_conflict_key(rule, conflict):
		_flash_hint("同一条指令里不能重复「%s」" % ActionScript.display_name(default_type))
		return
	(rule.get("actions") as Array).append(a)
	_rebuild()
	rules_changed.emit()


func _on_delete_action(rule_index: int, act_index: int) -> void:
	var rule = _rule_at(rule_index)
	if rule == null:
		return
	var arr: Array = rule.get("actions")
	if act_index >= 0 and act_index < arr.size():
		arr.remove_at(act_index)
	_rebuild()
	rules_changed.emit()


func _on_action_type_changed(rule_index: int, act_index: int) -> void:
	var a = _item_at(rule_index, act_index, ActionScript)
	if a == null:
		return
	var picker := _rules_box.find_child("ActType_%d_%d" % [rule_index, act_index], true, false)
	if picker is OptionButton:
		var t := str((picker as OptionButton).get_item_metadata((picker as OptionButton).selected))
		# 同上：换类型就是换对象（用户实测这里报 reset_to_default 不存在）
		_replace_item(rule_index, act_index, ActionScript, t)
	_rebuild()
	rules_changed.emit()


## 参数改动：直接写回对象，**不整体重建**（否则 SpinBox 会丢焦点、输入被打断）
func _on_param_changed(rule_index: int, item_index: int, kind_script,
		key: String, value) -> void:
	var obj = _item_at(rule_index, item_index, kind_script)
	if obj == null:
		return
	obj.set(key, value)
	rules_changed.emit()


func _rule_at(rule_index: int):
	if target_unit == null:
		return null
	var rules: Array = target_unit.get("rules")
	if rule_index < 0 or rule_index >= rules.size():
		return null
	return rules[rule_index]


## 判断某条指令里是否已存在同样冲突键的行为。
## 冲突键来自系统 02 的 `Action.conflict_key()`（"fire_mode"/"move"/"signal:N"）。
func _rule_has_conflict_key(rule, key: String) -> bool:
	if key.is_empty():
		return false
	for a in (rule.get("actions") as Array):
		if str(a.call("conflict_key")) == key:
			return true
	return false


## 面板内的一行提示（几秒后自动消失）
func _flash_hint(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = true
	_hint_timer = HINT_SECONDS


# ---------------------------------------------------------------------------
# 编辑动作
# ---------------------------------------------------------------------------

func _on_add_rule() -> void:
	if target_unit == null:
		return
	var idx: int = _action_picker.selected
	var type_id := str(_action_picker.get_item_metadata(idx)) if idx >= 0 else ""
	if type_id.is_empty():
		return
	# 【必须按 schema 的 default 造，不能用 from_dict】
	# `from_dict({"type": ...})` 用的是**字段级**默认值，与 schema 的按类型默认值不一致：
	# 例如 set_signal 的 signal_index 会默认成 0，而信号是 **1 起**的 ——
	# 新建出来就是非法指令。这与 field_factory 里那条注释是同一个坑。
	var action = RuleFieldFactoryScript.make_default_from_schema(ActionScript, type_id)
	var rule = RuleScript.new()
	rule.actions = [action]
	var rules: Array = target_unit.get("rules")
	rules.append(rule)
	rules_changed.emit()
	_rebuild()


func _on_delete_rule(index: int) -> void:
	if target_unit == null:
		return
	var rules: Array = target_unit.get("rules")
	if index < 0 or index >= rules.size():
		return
	rules.remove_at(index)
	rules_changed.emit()
	_rebuild()


func _on_append_beacon(rule_index: int, beacon_no: int) -> void:
	var action = _move_action_of(rule_index)
	if action == null:
		return
	var seq: Array = action.get("beacon_indices")
	seq.append(beacon_no)
	rules_changed.emit()
	_rebuild()


func _on_clear_beacons(rule_index: int) -> void:
	var action = _move_action_of(rule_index)
	if action == null:
		return
	action.set("beacon_indices", [])
	rules_changed.emit()
	_rebuild()


func _move_action_of(rule_index: int):
	if target_unit == null:
		return null
	var rules: Array = target_unit.get("rules")
	if rule_index < 0 or rule_index >= rules.size():
		return null
	for a in ((rules[rule_index] as RefCounted).get("actions") as Array):
		if str(a.get("type")) == ActionScript.T_MOVE_ALONG_BEACONS:
			return a
	return null


## 打开时选中的单位（测试与调试用）
func current_unit():
	return target_unit


## 抽屉当前实际宽度（测试断言「占屏宽 1/3」用）
func drawer_width() -> float:
	return _root.size.x if _root != null else 0.0


func drawer_rect() -> Rect2:
	return _root.get_global_rect() if _root != null else Rect2()


## 抽屉宽度 ÷ 视口宽度。
##
## 【为什么要除以视口而不是自身】本面板的根 Control 铺满屏幕，而
## 挂载它的父节点不一定和被拉满（比如单独挂在一个裸 Node 下时 size 为 0）。
## 除以视口宽度才是「占屏宽 1/3」的确切含义，也才能在两种挂法下都说得通。
func width_ratio() -> float:
	var vw := float(get_viewport_rect().size.x)
	if vw <= 0.0:
		vw = 1920.0
	return drawer_width() / vw


## 抽屉是否完全在屏幕内（防溢出回归）
func is_inside_screen() -> bool:
	var r := drawer_rect()
	var vw := get_viewport_rect().size.x
	return r.position.x >= -1.0 and r.position.x + r.size.x <= vw + 1.0
