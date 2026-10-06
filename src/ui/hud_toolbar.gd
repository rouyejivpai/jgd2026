class_name HudToolbar
extends PanelContainer
## 详细设计：[docs/design/10-主界面与HUD.md](../../docs/design/10-主界面与HUD.md) 1.3 / 4.2
##
## 顶部工具条：**从左到右固定顺序**
## 退出 / 关卡介绍 / 机制说明 / 信标 / 开始 / 重置 / 清空 / 倍速
##
## 【为什么用代码搭而不是手写 .tscn】按钮顺序、禁用规则、速度挡位都是
## 「可断言的行为」，用代码搭就能被 headless 测试逐条验证；.tscn 手写则
## 只能靠眼睛看，而且容易在合并时冲突。UI 的观感仍然要在窗口里确认。
##
## 【只管呈现与接线】不知道胜负、不算分、不改单位状态。点下去只发信号，
## 由 PlayScene 决定做什么（详设 10 的 2.3）。

## 按钮的标识（顺序即界面从左到右的顺序）
const BTN_EXIT := "exit"
const BTN_INTRO := "intro"
const BTN_HELP := "help"
const BTN_BEACON := "beacon"
const BTN_START := "start"
const BTN_RESET := "reset"
## 「清空」（D-33，策划案 v2 3.2：「清除所有我方单位，回到关卡开始」）
const BTN_CLEAR := "clear"
const BTN_SPEED := "speed"

## 固定顺序（验收要求「从左到右」）。
## 「信标」按钮按详设 10 的 4.2 放在「机制说明」之后、「开始」之前 ——
## 它是编制期的操作开关，紧挨着开始按钮更顺手。
const BUTTON_ORDER := [BTN_EXIT, BTN_INTRO, BTN_HELP, BTN_BEACON, BTN_START, BTN_RESET,
	BTN_CLEAR, BTN_SPEED]

const LABELS := {
	BTN_EXIT: "退出",
	BTN_INTRO: "关卡介绍",
	BTN_HELP: "机制说明",
	BTN_BEACON: "信标",
	BTN_START: "开始",
	BTN_RESET: "重置",
	BTN_CLEAR: "清空",
	BTN_SPEED: "倍速",
}

## 会话状态（与 LevelSession.State 对应，这里只用来决定按钮可用性）
const STATE_BUILD := 0
const STATE_RUN := 1
const STATE_RESULT := 2

## 按钮被按下。发：HudToolbar　收：PlayScene
signal button_pressed(id: String)
## 倍速被切换
signal speed_changed(speed: float)
## 「视野」辅助显示的开关变化（FR-TUT-04；我方与敌方都会画）
signal vision_toggled(on: bool)

## 倍速挡位（详设 01：1x / 2x / 3x）
const SPEED_CHOICES := [1.0, 2.0, 3.0]

var speed_multiplier := 1.0
var _buttons: Dictionary = {}          ## id → Button
var _row: HBoxContainer
var _speed_label: Label
## 无效指令角标（详设 10 的 1.3：右侧状态 = 已用信标 n/N + 无效指令角标）
var _invalid_label: Label = null
var _invalid_gap: Control = null
var _beacon_label: Label
## 「视野」辅助显示开关（FR-TUT-04），默认开启
var _vision_toggle: CheckButton = null
var show_vision := true
## 是否处于信标模式（工具条按钮的开关状态）
var beacon_mode := false

var _state := STATE_BUILD


func _ready() -> void:
	_build_ui()
	apply_state(_state)


func _build_ui() -> void:
	if _row != null:
		return
	# 半透明底，避免盖住地图时看不清
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.92)
	sb.border_color = Color(0.30, 0.33, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)

	var outer := HBoxContainer.new()
	outer.name = "Row"
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)
	_row = outer

	for id in BUTTON_ORDER:
		var b := Button.new()
		b.name = "Btn_" + str(id)
		b.text = str(LABELS[id])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(96, 34)
		b.pressed.connect(_on_button_pressed.bind(str(id)))
		outer.add_child(b)
		_buttons[str(id)] = b

	# 右侧留白 + 视野开关 + 信标计数
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(spacer)

	# 「视野」辅助显示开关（FR-TUT-04，详设 10 的 4.6）。
	# 【文案是「视野」不是「敌人视野」】第 14 轮起我方视野也会画出来，
	# 再叫「敌人视野」就与实际行为不符了。
	# 【为什么放这里而不是加进 BUTTON_ORDER】详设 1.3 明确规定了工具条那 6 个按钮
	# 及顺序，插一个进去会破坏"左→右顺序固定"的验收项。辅助显示是**视图选项**，
	# 与信标计数同属右侧状态区，放这儿既显眼又不动已定的按钮集。
	_vision_toggle = CheckButton.new()
	_vision_toggle.name = "VisionToggle"
	_vision_toggle.text = "视野"
	_vision_toggle.button_pressed = true          # 默认开启
	_vision_toggle.add_theme_font_size_override("font_size", 16)
	_vision_toggle.toggled.connect(_on_vision_toggled)
	outer.add_child(_vision_toggle)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	outer.add_child(gap)

	# 无效指令角标：**不弹窗、不阻断**（需求 12.1 决策），只在有无效指令时出现
	_invalid_label = Label.new()
	_invalid_label.name = "InvalidBadge"
	_invalid_label.add_theme_font_size_override("font_size", 16)
	_invalid_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	_invalid_label.visible = false
	outer.add_child(_invalid_label)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(16, 0)
	gap2.visible = false
	outer.add_child(gap2)
	_invalid_gap = gap2

	_beacon_label = Label.new()
	_beacon_label.name = "BeaconCount"
	_beacon_label.text = "信标 0/0"
	_beacon_label.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
	outer.add_child(_beacon_label)


## 刷新无效指令角标（n == 0 时隐藏）
func set_invalid_count(n: int) -> void:
	if _invalid_label == null:
		return
	_invalid_label.text = "无效指令 %d" % n
	_invalid_label.visible = n > 0
	if _invalid_gap != null:
		_invalid_gap.visible = n > 0


func invalid_text() -> String:
	return _invalid_label.text if _invalid_label != null else ""


func is_invalid_badge_visible() -> bool:
	return _invalid_label != null and _invalid_label.visible


func _on_vision_toggled(on: bool) -> void:
	show_vision = on
	vision_toggled.emit(on)


## 程序化设置开关（设置持久化或测试用），**不发信号**避免回环
func set_vision_visible(on: bool) -> void:
	show_vision = on
	if _vision_toggle != null:
		_vision_toggle.set_pressed_no_signal(on)


func is_vision_visible() -> bool:
	return show_vision


## 视野开关的**文案**（供"帮助文档与实际 UI 一致"的跨模块用例比对）。
##
## 【为什么要这个访问器】帮助文档里写的是「视野」这个开关名。
## 一旦有人改了工具条文案而没同步文档，这条用例会立刻失败 ——
## 否则这种漂移只能靠玩家发现（第 14 轮改名时就发生过一次）。
func vision_label() -> String:
	return _vision_toggle.text if _vision_toggle != null else ""


## 按会话状态刷新按钮可用性（详设 10 的 1.3 那张表）
func apply_state(state: int) -> void:
	_state = state
	# 退出 / 关卡介绍 / 机制说明：三期都可用
	for id in [BTN_EXIT, BTN_INTRO, BTN_HELP]:
		_set_enabled(id, true)
	# 信标：**只在编制期可见**（推演期信标不可改，需求 3.1）
	_set_visible(BTN_BEACON, state == STATE_BUILD)
	if state != STATE_BUILD:
		set_beacon_mode(false)          # 离开编制期自动退出信标模式
	# 开始：仅编制期
	_set_enabled(BTN_START, state == STATE_BUILD)
	# 重置：编制期与推演期可用，结算期禁用
	_set_enabled(BTN_RESET, state == STATE_BUILD or state == STATE_RUN)
	# 倍速：结算期禁用（编制期可调 —— 那时虽不推进，但允许预选）
	_set_enabled(BTN_SPEED, state != STATE_RESULT)
	_update_speed_text()


func _set_visible(id: String, on: bool) -> void:
	var b = _buttons.get(id)
	if b != null:
		(b as Button).visible = on


## 某个按钮当前是否可见。
##
## 【命名注意】不能叫 `is_visible()` —— CanvasItem 已经有同名方法，
## 覆盖它会直接编译失败（「函数签名与父类不匹配」）。本会话第二次踩同类坑
## （第一次是 `reference()` / `has_signal()`）。
func is_button_visible(id: String) -> bool:
	var b = _buttons.get(id)
	if b == null:
		return false
	return (b as Button).visible


## 切换信标模式；返回切换后的状态
func toggle_beacon_mode() -> bool:
	set_beacon_mode(not beacon_mode)
	return beacon_mode


func set_beacon_mode(on: bool) -> void:
	beacon_mode = on
	_update_beacon_text()


func _update_beacon_text() -> void:
	var b = _buttons.get(BTN_BEACON)
	if b != null:
		(b as Button).text = "信标 ✓" if beacon_mode else "信标"


func _set_enabled(id: String, on: bool) -> void:
	var b = _buttons.get(id)
	if b != null:
		(b as Button).disabled = not on


func is_enabled(id: String) -> bool:
	var b = _buttons.get(id)
	if b == null:
		return false
	return not (b as Button).disabled


func _on_button_pressed(id: String) -> void:
	if id == BTN_SPEED:
		cycle_speed()
	elif id == BTN_BEACON:
		toggle_beacon_mode()
	button_pressed.emit(id)


## 循环切到下一挡：1x → 2x → 3x → 1x
func cycle_speed() -> void:
	var idx := SPEED_CHOICES.find(speed_multiplier)
	if idx < 0:
		idx = 0
	speed_multiplier = float(SPEED_CHOICES[(idx + 1) % SPEED_CHOICES.size()])
	_update_speed_text()
	speed_changed.emit(speed_multiplier)


func set_speed(speed: float) -> void:
	speed_multiplier = speed
	_update_speed_text()
	speed_changed.emit(speed_multiplier)


func _update_speed_text() -> void:
	var b = _buttons.get(BTN_SPEED)
	if b != null:
		(b as Button).text = "倍速 %dx" % int(speed_multiplier)


## 刷新信标计数显示（来自 BeaconLayer 的变更广播）
func set_beacon_count(used: int, quota: int) -> void:
	if _beacon_label != null:
		_beacon_label.text = "信标 %d/%d" % [used, quota]


func beacon_text() -> String:
	return _beacon_label.text if _beacon_label != null else ""


## 当前按钮从左到右的标识顺序（测试用）
func button_ids_in_order() -> Array:
	var out: Array = []
	if _row == null:
		return out
	for c in _row.get_children():
		if c is Button:
			var nm: String = str(c.name)
			if nm.begins_with("Btn_"):
				out.append(nm.substr(4))
	return out


func button_text(id: String) -> String:
	var b = _buttons.get(id)
	return (b as Button).text if b != null else ""
