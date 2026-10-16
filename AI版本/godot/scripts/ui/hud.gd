extends Control
## HUD（01 §9；第三阶段 P6 按批准整图 ui_01 换皮，10 §1 / 12）：
## 位置、贴图、字体全部来自 data/ui_layout/battle_hud.json 与 assets/themes/ui_battle_hud.tres
## （assets/ui/battle_hud/fit_spec.json → tools/ui_fit_reference.py 以批准整图为准拟合 → manifest.json → apply_ui_manifest.py），
## 本脚本只做文字绑定、接线，以及把场景里的节点按布局摆放（节点名与功能不变）：
## - 左上：关卡铭牌（「第 N 关 · 关名」+ 任务一句话，点击打开「任务」弹窗并让特殊目标闪烁）；中上：计时 + 阶段
## - 右上：重试 1× 2× 暂停/继续 设置 退出；下方「任务」「机制说明」
## - 左下：预算；中下：五个角色卡位（free = 形态卡，fixed = 槽位卡，其余为「未解锁」卡）；右下：清空 提示/推荐阵型，下方开始
## - 战场让出布局 reserved 的上下带（Playfield 读取）；底栏 = 下方带内的拖放区（把地图上的单位拖回 = 收回）
## - 文字超出框体时遮罩 + 滚动（ScrollText：名字类自动滚动、任务句等长文本滚轮 / 拖动）
## - 局内「设置」打开 SettingsOverlay；运行中打开自动暂停、关闭后保持暂停（决策 ⑦，BattleRoot 处理）
## - 角色 / 敌人详情（第四阶段）：停靠屏幕一侧、上下铺满的侧栏（批准整图 assets/ui/side_detail/design.png）；单位在左半屏时侧栏在右，反之在左，
##   不遮挡该单位与战场；没有遮罩，战场照常可点（点空地 = 取消选中并收起），Esc /「关闭」收起
## - 信标模式（第四阶段）：数字键 / 详情「信标」进入，底部信标边栏（替换出场卡）：标题、操作说明、移动方式（沿路径 / 循环 / 往返 / 自动寻路·待定）、完成
## 以及校验问题列表、悬浮原因、Toast、F3 调试信息、结算与对话等浮层。

const SKIN: String = "battle_hud"
const CARD_SLOTS: int = 5
## 布局元素 id → 场景节点名
const SKIN_NODES: Dictionary = {
	"quest_title": "TitleLabel", "quest_objective": "ObjectiveLabel", "timer_value": "TimerLabel", "timer_phase": "PhaseLabel",
	"btn_retry": "RetryButton", "btn_speed1": "Speed1Button", "btn_speed2": "Speed2Button", "btn_pause": "PauseButton",
	"btn_settings": "SettingsButton", "btn_exit": "ExitButton", "btn_task": "ObjectivesButton", "btn_mechanics": "MechanicsButton",
	"btn_clear": "ClearButton", "btn_hint": "HintButton", "btn_start": "StartButton",
	"budget_title": "BudgetTitle", "budget_value": "BudgetLabel", "budget_fixed": "BudgetFixedLabel",
}
## 贴图元素 id → 放在哪个节点下（画在同组文字 / 按钮之下）
const SKIN_IMAGES: Dictionary = { "quest": "TopBar/Row", "timer": "TopBar/Row", "budget": "BottomBar/Row/BudgetBox" }

const TOAST_SECONDS: float = 2.5
const COUNTDOWN_WARN_SECONDS: float = 5.0   ## 生存倒计时最后 5 秒变红（与 04 §3.2 timer_tick 同口径）

var _root: Node2D = null
var _controller: BattleController = null
var _level: LevelDefinition = null
var _cards: Array[RosterCard] = []
var _side_on_right: bool = true
var _toast_tween: Tween = null
var _last_tick_second: int = -1
var _last_phase: int = SimTypes.Phase.DEPLOY
var _skin_nodes: Dictionary = {}           ## 布局元素 id → 实际摆放的节点（被 ScrollText 包裹的为包裹节点）
var _locked_cards: Array[Control] = []     ## 补足五个卡位的「未解锁」卡
var _problems_scroll: ScrollText = null    ## 问题列表的滚动遮罩
var _popup_scroll: ScrollText = null       ## 「任务」弹窗正文的滚动遮罩
var _beacon_slot: String = ""              ## 第四阶段：信标模式中的单位（"" = 未进入）
var _beacon_bar: Control = null
var _beacon_nodes: Dictionary = {}         ## 信标边栏布局元素 id → 节点
const BEACON_BAR_IDS: Array[String] = ["beacon_bar", "beacon_bar_title", "beacon_bar_hint", "beacon_mode_once", "beacon_mode_loop", "beacon_mode_pingpong", "beacon_mode_auto", "beacon_done"]
const BEACON_MODE_BUTTONS: Dictionary = { "beacon_mode_once": SimTypes.BeaconMode.ONCE, "beacon_mode_loop": SimTypes.BeaconMode.LOOP, "beacon_mode_pingpong": SimTypes.BeaconMode.PINGPONG }

@onready var _title: Label = %TitleLabel
@onready var _objective: Label = %ObjectiveLabel
@onready var _progress: Label = %ProgressLabel
@onready var _timer: Label = %TimerLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _mechanics_button: Button = %MechanicsButton
@onready var _objectives_button: Button = %ObjectivesButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _start_button: Button = %StartButton
@onready var _retry_button: Button = %RetryButton
@onready var _speed1_button: Button = %Speed1Button
@onready var _speed2_button: Button = %Speed2Button
@onready var _pause_button: Button = %PauseButton
@onready var _hint_button: Button = %HintButton
@onready var _clear_button: Button = %ClearButton
@onready var _side_panel: Control = %SidePanel
@onready var _card_list: Control = %CardList
@onready var _budget_box: Control = %BudgetBox
@onready var _budget_title: Label = %BudgetTitle
@onready var _budget_label: Label = %BudgetLabel
@onready var _objective_popup: Control = %ObjectivePopup
@onready var _popup_column: VBoxContainer = %PopupColumn
@onready var _unit_panel: Control = %UnitPanel
@onready var _enemy_panel: Control = %EnemyPanel
@onready var _objective_panel: VBoxContainer = %ObjectivePanel
@onready var _map_input: Control = %MapInput
@onready var _problems_panel: Control = %ProblemsPanel
@onready var _problems_title: Label = %ProblemsTitle
@onready var _problems_list: VBoxContainer = %ProblemsList
@onready var _hint_panel: HintPanel = %HintPanel
@onready var _result_panel: Control = %ResultPanel
@onready var _mechanics_popup: Control = %MechanicsPopup
@onready var _tooltip: PanelContainer = %Tooltip
@onready var _tooltip_label: Label = %TooltipLabel
@onready var _debug_label: Label = %DebugLabel
@onready var _toast: Label = %Toast
@onready var _dialogue: StoryPlayer = %DialogueOverlay


func setup(root: Node2D) -> void:
	_root = root
	_controller = root.get("controller") as BattleController
	_level = root.get("level") as LevelDefinition
	_side_panel.theme = UiKit.ui_theme(DetailKit.SKIN)     # 先挂侧栏主题再建详情：入树时按默认主题算最小尺寸会把细件（滚动条、分隔线）撑大且不回缩
	_map_input.call("setup", root, _controller)
	($BottomBar as Control).set("controller", _controller)       # 把地图上的单位拖回底栏 = 收回
	_unit_panel.call("setup", _controller, _level)
	_enemy_panel.call("setup", _controller, _level)
	_objective_panel.call("setup", _controller, _level)
	_hint_panel.setup(_level, _controller)
	_result_panel.call("setup", _controller, _level)

	_title.text = DataRegistry.get_string("ui.hud_level_title").format({
		"label": DataRegistry.get_string("ui.level_label").format({ "index": _level.display_index }), "title": _level.title })
	_objective.text = _level.objective_text
	_mechanics_button.text = DataRegistry.get_string("ui.mechanics")
	_objectives_button.text = DataRegistry.get_string("ui.objectives_popup")
	_settings_button.text = DataRegistry.get_string("ui.menu_settings")
	_exit_button.text = DataRegistry.get_string("ui.exit")
	_start_button.text = DataRegistry.get_string("ui.start")
	_retry_button.text = DataRegistry.get_string("ui.retry")
	_clear_button.text = DataRegistry.get_string("ui.clear_units")
	_speed1_button.text = DataRegistry.get_string("ui.speed_1x")
	_speed2_button.text = DataRegistry.get_string("ui.speed_2x")
	_budget_title.text = DataRegistry.get_string("ui.budget")
	_objective.tooltip_text = DataRegistry.get_string("ui.objective_expand")
	_toast.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	_debug_label.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)

	_apply_skin()
	# 预算铭牌：free 关 = 「预算」+ 已用 / 预算；fixed 关 = 「固定出场」（批准整图 ui_04）
	_budget_title.visible = _level.is_free()
	_budget_label.visible = _level.is_free()
	_budget_fixed_label().visible = not _level.is_free()
	_skin_objective_popup()
	_skin_detail()
	_build_beacon_bar()
	_unit_panel.connect("beacon_mode_requested", enter_beacon_mode)

	_exit_button.pressed.connect(_controller.exit)
	_mechanics_button.pressed.connect(_on_mechanics_pressed)
	_objectives_button.pressed.connect(_on_objectives_pressed)
	_settings_button.pressed.connect(func() -> void: SceneRouter.open_settings())
	# 07 §6：任务句可点击（打开「任务」弹窗并让特殊目标闪烁）；超出铭牌时滚轮 / 拖动滚动，拖动不算点击
	var objective_scroll: ScrollText = _skin_nodes["quest_objective"] as ScrollText
	objective_scroll.clicked.connect(_on_objective_clicked)
	objective_scroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start_button.pressed.connect(_on_start_pressed)
	_retry_button.pressed.connect(_controller.reset)
	_clear_button.pressed.connect(_on_clear_pressed)
	_speed1_button.pressed.connect(_controller.set_speed.bind(1))
	_speed2_button.pressed.connect(_controller.set_speed.bind(2))
	_pause_button.pressed.connect(func() -> void: _root.call("toggle_pause"))
	_hint_button.pressed.connect(_on_hint_pressed)
	_hint_panel.state_changed.connect(_update_hint_button)
	_hint_panel.recommended_applied.connect(_on_recommended_applied)
	# A02：顶栏/底栏按钮不取键盘焦点，否则空格（开始战斗快捷键，也是 ui_accept）会再次按下刚点过的按钮
	for b: BaseButton in [_mechanics_button, _objectives_button, _settings_button, _exit_button, _start_button, _retry_button, _speed1_button, _speed2_button, _pause_button, _hint_button, _clear_button] as Array[BaseButton]:
		b.focus_mode = Control.FOCUS_NONE

	EventBus.battle_phase_changed.connect(_on_phase_changed)
	EventBus.battle_speed_changed.connect(_on_speed_changed)
	EventBus.deployment_changed.connect(_on_config_changed)
	EventBus.rules_changed.connect(func(_id: int) -> void: _on_config_changed())
	EventBus.validation_failed.connect(_on_validation_failed)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.toast.connect(show_toast)
	EventBus.toast_at.connect(show_bubble)
	_on_speed_changed(1)
	_update_hint_button()
	_update_budget()
	get_viewport().size_changed.connect(_place_side.bind(false))
	get_viewport().size_changed.connect(_relayout_skin)


## 关卡开始（控制器已 setup）：建出场卡，战前对话，然后若存档配置有失效项则提示；选中第一名已部署的单位
func begin() -> void:
	_build_cards()
	_update_budget()
	# 07 §10.2：开始剧情 <level_id>_intro，其后接本关机制提示卡；剧情不存在则不弹出（提示仍可在"机制说明"中查看）
	var hint: String = str(_level.briefing.get("mechanic_hint", ""))
	_mechanics_popup.call("set_level_hint", hint)
	_play_and_mark(story_id("intro"), hint)
	if not _controller.load_problems.is_empty():
		_show_problems(DataRegistry.get_string("ui.invalid_config"), _controller.load_problems)
	for uid: String in _controller.uids():
		if _controller.placements.has(uid):
			EventBus.unit_selected.emit(_controller.unit_id_of_slot(uid))
			break


## 按布局换皮：主题、贴图节点、各节点的主题变体与对齐；文字可能超出的节点包进 ScrollText；然后统一摆放
func _apply_skin() -> void:
	theme = UiKit.ui_theme(SKIN)
	var fixed := Label.new()
	fixed.name = "BudgetFixedLabel"
	fixed.text = DataRegistry.get_string("ui.roster_fixed")
	fixed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budget_box.add_child(fixed)
	# 开始校验问题面板（批准整图 ui_05）：九宫格底板 + 标题 + 问题列表（行数变化时下沿不动、向上长；超过可用高度时列表滚动）
	var bg: Control = UiKit.node_for(UiKit.layout_element(SKIN, "problems_panel"))
	bg.name = "Skin_problems_panel"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_problems_panel.add_child(bg)
	_problems_panel.move_child(bg, 0)
	_problems_title.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "problems_title").get("theme_type", "")))
	_problems_title.clip_text = true
	_problems_list.add_theme_constant_override("separation", int(_problem_line_gap()))
	for id: String in SKIN_IMAGES.keys():
		var img: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		img.name = "Skin_" + id
		var parent: Node = get_node(str(SKIN_IMAGES[id]))
		parent.add_child(img)
		parent.move_child(img, 0)
		_skin_nodes[id] = img
	for id: String in SKIN_NODES.keys():
		var e: Dictionary = UiKit.layout_element(SKIN, id)
		var c: Control = find_child(str(SKIN_NODES[id]), true, false) as Control
		c.theme_type_variation = StringName(str(e.get("theme_type", "")))
		_skin_nodes[id] = c
		if c is Button:
			(c as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
			(c as Button).clip_text = true          # 文字不撑大按钮（尺寸 = 布局）
		elif c is Label:
			(c as Label).horizontal_alignment = UiKit.text_align(str(e.get("align", "left")))
			(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			(c as Label).clip_text = true           # 不撑大、不出框（需要滚动的再由 ScrollText 接管）
	_relayout_skin()
	_problems_scroll = ScrollText.wrap_box(_problems_list, ScrollText.Mode.MANUAL, Rect2())
	ScrollText.wrap(_problems_title, ScrollText.Mode.AUTO, Rect2(Vector2.ZERO, Vector2.ONE))
	for id: String in SKIN_NODES.keys():
		var mode: String = str(UiKit.layout_element(SKIN, id).get("overflow", ""))
		if mode == "":
			continue
		var c: Control = _skin_nodes[id] as Control
		var st_mode: int = ScrollText.Mode.MANUAL if mode == "manual" else ScrollText.Mode.AUTO
		if c is Button:
			UiKit.button_scroll_text(c as Button, st_mode)      # 代理在按钮内部自行跟随文字区；摆放的仍是按钮本身
		else:
			_skin_nodes[id] = ScrollText.wrap(c as Label, st_mode)
	_relayout_skin()


func _budget_fixed_label() -> Label:
	return _budget_box.find_child("BudgetFixedLabel", true, false) as Label


## 按当前视口摆放全部换皮节点（设计坐标 → 屏幕坐标只在 UiKit.layout_rect 一处换算，UiKit.place 再换成父节点内坐标）
func _relayout_skin() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var reserved: Dictionary = UiKit.ui_layout(SKIN).get("reserved", {}) as Dictionary
	var band: float = float(reserved.get("bottom", 0.0))
	var bottom: Control = $BottomBar as Control
	bottom.anchor_top = 1.0
	bottom.offset_top = -band
	bottom.offset_bottom = 0.0
	for id: String in _skin_nodes.keys():
		var text_style: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
		UiKit.place(_skin_nodes[id] as Control, UiKit.layout_text_rect(SKIN, id, vp) if text_style else UiKit.layout_rect(SKIN, id, vp))
	_place_cards()
	_layout_objective_popup()
	_mechanics_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	UiKit.place(_mechanics_popup, UiKit.layout_rect(SKIN, "mech_panel", vp))     # 「机制说明」弹窗（批准整图 ui_07）
	_place_side(false)
	_layout_beacon_bar()
	_layout_problems()
	# 进度（生存关剩余时间 / 清除情况）：计时铭牌正下方
	var timer: Rect2 = UiKit.layout_rect(SKIN, "timer", vp)
	UiKit.place(_progress, Rect2(timer.position.x, timer.end.y, timer.size.x, _progress.get_combined_minimum_size().y))


## 「任务」弹窗（批准整图 ui_06）：居中的九宫格框体、标题、「关闭」、分隔线；正文（ObjectivePanel）超出时上下滚动
func _skin_objective_popup() -> void:
	var bg: Control = UiKit.node_for(UiKit.layout_element(SKIN, "obj_panel"))
	bg.name = "Skin_obj_panel"
	_objective_popup.add_child(bg)
	_objective_popup.move_child(bg, 0)
	var title := Label.new()
	title.name = "PopupTitle"
	title.text = DataRegistry.get_string("ui.objectives_popup")
	title.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "obj_title").get("theme_type", "")))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	_objective_popup.add_child(title)
	var close: Button = UiKit.node_for(UiKit.layout_element(SKIN, "obj_close")) as Button
	close.name = "PopupClose"
	close.text = DataRegistry.get_string("ui.close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: _objective_popup.visible = false)
	_objective_popup.add_child(close)
	var sep: Control = UiKit.node_for(UiKit.layout_element(SKIN, "obj_sep"))
	sep.name = "Skin_obj_sep"
	_objective_popup.add_child(sep)
	var moon: Control = UiKit.node_for(UiKit.layout_element(SKIN, "obj_moon"))       # 标题左侧月牙、「关闭」右端小宝石（P6 补充素材 #4）
	moon.name = "Skin_obj_moon"
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_popup.add_child(moon)
	var gem: Control = UiKit.node_for(UiKit.layout_element(SKIN, "obj_close_gem"))
	gem.name = "Skin_obj_close_gem"
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_popup.add_child(gem)
	_objective_popup.set_meta(&"skin", { "obj_panel": bg, "obj_title": title, "obj_close": close, "obj_sep": sep, "obj_moon": moon, "obj_close_gem": gem })
	_layout_objective_popup()
	ScrollText.wrap(title, ScrollText.Mode.AUTO, title.get_rect())
	_objective_popup.get_meta(&"skin")["obj_title"] = title.get_parent()
	_popup_scroll = ScrollText.wrap_box(_popup_column, ScrollText.Mode.MANUAL, _popup_column.get_rect())
	_layout_objective_popup()


## 弹窗内各部分按布局摆放（相对框体左上）；正文区 = 任务句顶 → 框体下边距以上
func _layout_objective_popup() -> void:
	if not _objective_popup.has_meta(&"skin"):
		return
	var vp: Vector2 = get_viewport_rect().size
	var panel: Rect2 = UiKit.layout_rect(SKIN, "obj_panel", vp)
	UiKit.place(_objective_popup, panel)
	var nodes: Dictionary = _objective_popup.get_meta(&"skin") as Dictionary
	for id: String in nodes.keys():
		var r: Rect2 = UiKit.layout_text_rect(SKIN, id, vp) if id == "obj_title" else UiKit.layout_rect(SKIN, id, vp)
		if id == "obj_panel":
			r = panel
		UiKit.place(nodes[id] as Control, r)
	var text: Rect2 = UiKit.layout_text_rect(SKIN, "obj_text", vp)
	var box2: Rect2 = UiKit.layout_rect(SKIN, "obj_box2", vp)
	var body := Rect2(text.position.x, text.position.y, box2.size.x, box2.end.y - text.position.y)
	var holder: Control = _popup_column
	if _popup_scroll != null:
		holder = _popup_scroll
	UiKit.place(holder, body)
	if _popup_scroll == null:
		_popup_column.size = body.size


# ---- 出场卡与预算（07 §4、§5）----
## 五个卡位（布局 card_1..card_5）：free 关依次放可用形态卡，fixed 关依次放槽位卡；空余卡位为「未解锁」卡（不可交互）
func _build_cards() -> void:
	for c: RosterCard in _cards:
		c.queue_free()
	_cards.clear()
	for c: Control in _locked_cards:
		c.queue_free()
	_locked_cards.clear()
	if _level.is_free():
		for form: String in _controller.card_forms():
			var card := RosterCard.new()
			_card_list.add_child(card)
			card.setup_form(form, _controller)
			_cards.append(card)
	else:
		for uid: String in _controller.uids():
			var card := RosterCard.new()
			_card_list.add_child(card)
			card.setup_slot(uid, _controller)
			_cards.append(card)
	if _cards.size() > CARD_SLOTS:
		push_warning("出场卡 %d 张，超过布局卡位 %d 个，多出的不显示" % [_cards.size(), CARD_SLOTS])
	for i: int in range(_cards.size(), CARD_SLOTS):
		var locked: Control = RosterCard.make_locked_card()
		_card_list.add_child(locked)
		_locked_cards.append(locked)
	_place_cards()


func _place_cards() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var all: Array[Control] = []
	all.append_array(_cards)
	all.append_array(_locked_cards)
	for i: int in all.size():
		all[i].visible = i < CARD_SLOTS
		if i < CARD_SLOTS:
			UiKit.place(all[i], UiKit.layout_rect(SKIN, "card_%d" % (i + 1), vp))


func _update_budget() -> void:
	_clear_button.disabled = _controller.phase != SimTypes.Phase.DEPLOY or _controller.placements.is_empty()
	if _controller.boss_pending:                                     # Boss 换阶段暂停：显示增援预算
		_budget_title.text = DataRegistry.get_string("ui.reinforce_budget")
		_budget_label.text = DataRegistry.get_string("ui.budget_value").format({ "used": _controller.reinforce_cost(), "budget": _controller.reinforce_budget })
		_budget_label.remove_theme_color_override("font_color")
	elif _level.is_free():
		_budget_title.text = DataRegistry.get_string("ui.budget")
		_budget_label.text = DataRegistry.get_string("ui.budget_value").format({ "used": _controller.budget_used(), "budget": _level.roster_budget })
		if _controller.budget_used() > _level.roster_budget:          # 超出预算：批准整图 ui_05 的红色
			_budget_label.add_theme_color_override("font_color", Color(str((UiKit.layout_element(SKIN, "budget_value").get("data", {}) as Dictionary).get("over_color", "#FF0000"))))
		else:
			_budget_label.remove_theme_color_override("font_color")
	for c: RosterCard in _cards:
		c.refresh()


# ---- 角色 / 敌人详情侧栏（第四阶段：批准整图 side_detail/design.png，居中弹窗改为停靠一侧）----
## SidePanel = 全屏透明容器（不拦截）；Frame = 侧栏框体（det_panel 九宫格，拦截其上的点击）+「关闭」；内容为 UnitPanel / EnemyPanel（位置见 DetailKit）。
## 「关闭」只收起侧栏、保留选中（便于随后在地图上放置信标，Q-082）。
func _skin_detail() -> void:
	_side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame: Control = _side_panel.get_node("Frame") as Control
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: Control = UiKit.node_for(UiKit.layout_element(DetailKit.SKIN, "det_panel"))
	bg.name = "Skin_det_panel"
	frame.add_child(bg)
	frame.move_child(bg, 0)
	var close: Button = UiKit.node_for(UiKit.layout_element(DetailKit.SKIN, "det_close")) as Button
	close.name = "DetailClose"
	close.text = DataRegistry.get_string("ui.close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_side)
	frame.add_child(close)
	_place_side(false)


## 单位在屏幕左半 → 侧栏停靠右侧，反之停靠左侧（不遮挡该单位）
func _show_side(unit_id: int) -> void:
	var on_right: bool = true
	var view_pos: Variant = _root.call("unit_screen_pos", unit_id)
	if view_pos is Vector2:
		on_right = (view_pos as Vector2).x < get_viewport_rect().size.x * 0.5
	_side_on_right = on_right
	_side_panel.visible = true
	_place_side(false)
	_layout_beacon_bar()


## 侧栏框体在视口中的矩形：设计矩形贴右边（停靠左侧时按设计画布镜像贴左边）；上下边距同设计，视口更高时侧栏随之加高
func side_rect() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var design: Vector2 = UiKit.design_size(DetailKit.SKIN)
	var r: Rect2 = UiKit.layout_rect(DetailKit.SKIN, "det_panel", design)
	var right_gap: float = design.x - r.end.x
	var bottom_gap: float = design.y - r.end.y
	var x: float = vp.x - right_gap - r.size.x if _side_on_right else right_gap
	return Rect2(x, r.position.y, r.size.x, vp.y - r.position.y - bottom_gap)


## 鼠标是否在侧栏上（侧栏与屏幕边之间的几像素缝也算，免得贴边时误触边平移）
func mouse_over_side(screen_pos: Vector2) -> bool:
	if not _side_panel.visible:
		return false
	var r: Rect2 = side_rect()
	var vp: Vector2 = get_viewport_rect().size
	var hit := Rect2(r.position.x, 0.0, vp.x - r.position.x, vp.y) if _side_on_right else Rect2(0.0, 0.0, r.end.x, vp.y)
	return hit.has_point(screen_pos)


## 框体与内容按 side_rect 摆放；关闭键与内容相对框体（内容不镜像，与批准整图一致）
func _place_side(_slide: bool) -> void:
	var frame: Control = _side_panel.get_node_or_null("Frame") as Control
	if frame == null or not frame.has_node("Skin_det_panel"):
		return
	var r: Rect2 = side_rect()
	frame.position = r.position
	frame.size = r.size
	(frame.get_node("Skin_det_panel") as Control).position = Vector2.ZERO
	(frame.get_node("Skin_det_panel") as Control).size = r.size
	var close: Control = frame.get_node("DetailClose") as Control
	var cr: Rect2 = DetailKit.rel("det_close")
	close.position = cr.position
	close.size = cr.size
	var extra: float = r.size.y - DetailKit.rel("det_panel").size.y
	for c: Control in [_unit_panel, _enemy_panel]:
		c.position = Vector2.ZERO
		c.size = r.size
		c.call("stretch", extra)


func hide_side() -> void:
	_side_panel.visible = false


func side_on_right() -> bool:
	return _side_on_right


func side_visible() -> bool:
	return _side_panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _beacon_slot != "":
		exit_beacon_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _side_panel.visible:
		hide_side()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _controller == null or _controller.world == null:
		return
	var w: SimWorld = _controller.world
	var left: float = ObjectivePanel.survive_time_left(w, _level)
	if left >= 0.0:
		# 生存关：顶栏显示倒计时（模拟时间，暂停不走、倍速不改变），最后几秒变红
		_timer.text = UiKit.TIMER_FORMAT % left
		var whole: int = int(ceil(left))
		if left <= COUNTDOWN_WARN_SECONDS and whole != _last_tick_second and _controller.phase == SimTypes.Phase.RUNNING:
			AudioManager.play_sfx("timer_tick")
		_last_tick_second = whole
		if left <= COUNTDOWN_WARN_SECONDS:
			_timer.add_theme_color_override("font_color", Palette.WARN_RED)
		else:
			_timer.remove_theme_color_override("font_color")      # 布局字色（批准整图）
	else:
		_timer.text = UiKit.TIMER_FORMAT % w.clock.time
	_progress.text = ObjectivePanel.progress_text(w, _level, false).replace("\n", "  ")
	_progress.visible = _progress.text != ""
	var cleared: bool = left >= 0.0 and w.clock.steps > 0 and ObjectiveSystem.enemies_cleared(w)
	_progress.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD if cleared else Palette.BONE_DIM)
	if _debug_label.visible:
		_debug_label.text = "t=%.3f  step=%d  hash=%d" % [w.clock.time, w.clock.steps, w.state_hash()]


## 10 §6.1「清空」（决策 ⑥ 不弹确认）：移除全部已放置角色、收起侧栏、toast 人数
func _on_clear_pressed() -> void:
	var n: int = _controller.clear_units()
	if n <= 0:
		return
	EventBus.unit_selected.emit(-1)
	show_toast(DataRegistry.get_string("ui.cleared_toast").format({ "n": n }))


func _on_start_pressed() -> void:
	if _controller.start():
		_problems_panel.visible = false


func _on_phase_changed(phase: int) -> void:
	var deploy: bool = phase == SimTypes.Phase.DEPLOY
	_start_button.disabled = not deploy
	_pause_button.disabled = phase != SimTypes.Phase.RUNNING and phase != SimTypes.Phase.PAUSED
	_pause_button.text = DataRegistry.get_string("ui.resume" if phase == SimTypes.Phase.PAUSED else "ui.pause")
	_retry_button.disabled = deploy
	_update_budget()
	match phase:
		SimTypes.Phase.DEPLOY:
			_phase_label.text = DataRegistry.get_string("ui.deploy_phase")
		SimTypes.Phase.RUNNING:
			_phase_label.text = DataRegistry.get_string("ui.running")
		SimTypes.Phase.PAUSED:
			_phase_label.text = DataRegistry.get_string("ui.paused")
		_:
			_phase_label.text = ""
	if not deploy:
		_problems_panel.visible = false
		hide_tooltip()
		exit_beacon_mode()
	if phase == SimTypes.Phase.RUNNING and _last_phase == SimTypes.Phase.DEPLOY:
		_toast_warnings(_controller.last_problems)
		show_battle_start()
	_last_phase = phase


## 开始时的非阻塞提醒（如 EMPTY_RULES：空指令允许开始，但单位将一直待机）
func _toast_warnings(problems: Array[Dictionary]) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for p: Dictionary in problems:
		if not bool(p.get("blocking", true)):
			lines.append(RuleText.problem_text(p, _level))
	if not lines.is_empty():
		show_toast("\n".join(lines))


func _on_speed_changed(multiplier: int) -> void:
	_speed1_button.button_pressed = multiplier == 1
	_speed2_button.button_pressed = multiplier == 2


func _on_config_changed() -> void:
	_problems_panel.visible = false
	_update_budget()


func _on_validation_failed(problems: Array) -> void:
	var list: Array[Dictionary] = []
	list.assign(problems)
	_show_problems(DataRegistry.get_string("ui.problems_title"), list)


## 问题列表：阻塞项为布局字色（红），提醒项（如空指令）为布局 data.warn_color；位置与行距按批准整图 ui_05
func _show_problems(title: String, problems: Array[Dictionary]) -> void:
	UiKit.clear(_problems_list)
	_problems_title.text = title
	var e: Dictionary = UiKit.layout_element(SKIN, "problems_line")
	var warn := Color(str((e.get("data", {}) as Dictionary).get("warn_color", "#FFFFFF")))
	var ordered: Array[Dictionary] = problems.filter(func(q: Dictionary) -> bool: return bool(q.get("blocking", true)))
	ordered.append_array(problems.filter(func(q: Dictionary) -> bool: return not bool(q.get("blocking", true))))
	for p: Dictionary in ordered:            # 阻塞项在前、提醒项在后（批准整图 ui_05）
		var l := Label.new()
		l.text = RuleText.problem_text(p, _level)
		l.theme_type_variation = StringName(str(e.get("theme_type", "")))
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY       # 长句在面板宽内换行，整列上下滚动
		l.custom_minimum_size = Vector2((e["rect"] as Array)[2], 0.0)   # 先给定宽度，行高才按换行算
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		if not bool(p.get("blocking", true)):
			l.add_theme_color_override("font_color", warn)
		_problems_list.add_child(l)
	_problems_panel.visible = _problems_list.get_child_count() > 0
	_layout_problems()
	_layout_problems.call_deferred()          # 换行后的行高下一帧才确定


func _problem_line_gap() -> float:
	var e: Dictionary = UiKit.layout_element(SKIN, "problems_line")
	return float((e.get("data", {}) as Dictionary).get("line_pitch", 0.0)) - float((e["rect"] as Array)[3])


## 面板：左右与下沿取布局；高 = 标题区 + 列表内容高 + 下边距，不超过 HUD 上带以下的可用高度（超出时列表滚动）
func _layout_problems() -> void:
	if _problems_scroll == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var panel: Rect2 = UiKit.layout_rect(SKIN, "problems_panel", vp)
	var title: Rect2 = UiKit.layout_text_rect(SKIN, "problems_title", vp)
	var line: Rect2 = UiKit.layout_text_rect(SKIN, "problems_line", vp)
	var pitch: float = line.size.y + _problem_line_gap()
	var top_pad: float = line.position.y - panel.position.y
	var bottom_pad: float = panel.end.y - (line.end.y + pitch)       # 整图有两行：第二行下沿到面板下沿
	_problems_list.size = Vector2(line.size.x, 0.0)
	var list_h: float = _problems_list.get_combined_minimum_size().y
	var max_h: float = panel.end.y - Playfield.bands().x
	var h: float = minf(top_pad + list_h + bottom_pad, max_h)
	UiKit.place(_problems_panel, Rect2(panel.position.x, panel.end.y - h, panel.size.x, h))
	(_problems_title.get_parent() as Control).position = title.position - panel.position
	(_problems_title.get_parent() as Control).size = title.size
	_problems_scroll.position = line.position - panel.position
	_problems_scroll.size = Vector2(line.size.x, h - top_pad - bottom_pad)


## 选中单位 → 对侧面板显示己方单位面板或敌人面板；-1（点击空地）→ 隐藏面板
func _on_unit_selected(unit_id: int) -> void:
	if unit_id < 0:
		hide_side()
		return
	if _beacon_slot != "" and _controller.slot_of_unit(unit_id) != _beacon_slot and _controller.slot_of_unit(unit_id) != "":
		enter_beacon_mode(_controller.slot_of_unit(unit_id))      # 信标模式中点了另一个己方单位：切过去
	var slot_id: String = _controller.slot_of_unit(unit_id)
	_unit_panel.visible = slot_id != ""
	_enemy_panel.visible = slot_id == ""
	if slot_id != "":
		_unit_panel.call("show_slot", slot_id)
	else:
		_enemy_panel.call("show_unit", unit_id)
	_show_side(unit_id)


# ---- 信标模式边栏（第四阶段）----
## 布局 side_detail 的 beacon_* 元素：九宫格底板、标题、说明、四个移动方式按钮（当前方式为按下态；自动寻路待定、禁用）、完成。
## 位置：设计矩形贴底；侧栏停靠左侧时按设计画布水平镜像（始终在未被侧栏遮住的一侧的底部中间）。出现时隐藏出场卡。
func _build_beacon_bar() -> void:
	_beacon_bar = Control.new()
	_beacon_bar.name = "BeaconBar"
	_beacon_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beacon_bar.visible = false
	_beacon_bar.theme = UiKit.ui_theme(DetailKit.SKIN)
	add_child(_beacon_bar)
	move_child(_beacon_bar, _side_panel.get_index())
	for id: String in BEACON_BAR_IDS:
		var c: Control = UiKit.node_for(UiKit.layout_element(DetailKit.SKIN, id))
		c.name = "Beacon_" + id
		_beacon_bar.add_child(c)
		_beacon_nodes[id] = c
	(_beacon_nodes["beacon_bar"] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	(_beacon_nodes["beacon_bar_hint"] as Label).clip_text = true
	(_beacon_nodes["beacon_bar_title"] as Label).clip_text = true
	for id: String in BEACON_MODE_BUTTONS.keys():
		var b: Button = _beacon_nodes[id] as Button
		b.toggle_mode = true
		b.text = RuleText.beacon_mode_name(int(BEACON_MODE_BUTTONS[id]))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_beacon_mode_button.bind(id))
	var auto: Button = _beacon_nodes["beacon_mode_auto"] as Button
	auto.text = DataRegistry.get_string("ui.beacon_mode_auto")
	auto.tooltip_text = DataRegistry.get_string("ui.beacon_mode_auto_tip")
	auto.disabled = true
	auto.focus_mode = Control.FOCUS_NONE
	var done: Button = _beacon_nodes["beacon_done"] as Button
	done.text = DataRegistry.get_string("ui.beacon_mode_done")
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(exit_beacon_mode)
	_beacon_nodes["beacon_bar_title"] = ScrollText.wrap(_beacon_nodes["beacon_bar_title"] as Label, ScrollText.Mode.AUTO)
	_beacon_nodes["beacon_bar_hint"] = ScrollText.wrap(_beacon_nodes["beacon_bar_hint"] as Label, ScrollText.Mode.AUTO)
	EventBus.rules_changed.connect(func(_id: int) -> void: _refresh_beacon_bar())
	_layout_beacon_bar()


func _layout_beacon_bar() -> void:
	if _beacon_bar == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var design: Vector2 = UiKit.design_size(DetailKit.SKIN)
	var bar: Rect2 = UiKit.layout_rect(DetailKit.SKIN, "beacon_bar", design)
	var dy: float = vp.y - design.y
	var center_x: float = vp.x * 0.5
	for id: String in _beacon_nodes.keys():
		var e: Dictionary = UiKit.layout_element(DetailKit.SKIN, id)
		var r: Rect2 = UiKit.layout_text_rect(DetailKit.SKIN, id, design) if str(e.get("kind", "")) == "text_style" else UiKit.layout_rect(DetailKit.SKIN, id, design)
		# 侧栏在左时底板按设计画布镜像，内部元素随底板整体平移（不反排）；横向相对视口中线、纵向贴底
		var xd: float = r.position.x if _side_on_right else (design.x - bar.end.x) + (r.position.x - bar.position.x)
		UiKit.place(_beacon_nodes[id] as Control, Rect2(center_x - design.x * 0.5 + xd, r.position.y + dy, r.size.x, r.size.y))


## 数字键 n：第 n 个已部署单位进入信标模式（没有该编号时忽略）
func enter_beacon_mode_number(n: int) -> void:
	var list: Array[String] = _controller.deployed_uids()
	if n >= 1 and n <= list.size():
		enter_beacon_mode(list[n - 1])


func enter_beacon_mode(slot_id: String) -> void:
	if slot_id == "" or not _controller.can_edit_beacons(slot_id) or not _controller.placements.has(slot_id):
		return
	_beacon_slot = slot_id
	_card_list.visible = false
	_beacon_bar.visible = true
	var uid: int = _controller.unit_id_of_slot(slot_id)
	if _root.get("selected_id") != uid:
		EventBus.unit_selected.emit(uid)
	_layout_beacon_bar()
	_refresh_beacon_bar()
	EventBus.beacons_changed.emit(uid)        # 地图重画（信标模式下地板高亮）


func exit_beacon_mode() -> void:
	if _beacon_slot == "":
		return
	var uid: int = _controller.unit_id_of_slot(_beacon_slot)
	_beacon_slot = ""
	if _beacon_bar != null:
		_beacon_bar.visible = false
	_card_list.visible = true
	EventBus.beacons_changed.emit(uid)


func beacon_mode_slot() -> String:
	return _beacon_slot


func _refresh_beacon_bar() -> void:
	if _beacon_slot == "" or _beacon_bar == null:
		return
	var n: int = _controller.deployed_uids().find(_beacon_slot) + 1
	_label_of(_beacon_nodes["beacon_bar_title"]).text = DataRegistry.get_string("ui.beacon_mode_title").format({ "n": n, "name": _controller.label_of(_beacon_slot) })
	_label_of(_beacon_nodes["beacon_bar_hint"]).text = DataRegistry.get_string("ui.beacon_mode_hint").format({ "max": maxi(_controller.deployed_uids().size(), 1) })
	var mode: int = _controller.beacon_follow_mode(_beacon_slot)
	for id: String in BEACON_MODE_BUTTONS.keys():
		(_beacon_nodes[id] as Button).set_pressed_no_signal(int(BEACON_MODE_BUTTONS[id]) == mode)


static func _label_of(c: Control) -> Label:
	if c is Label:
		return c as Label
	for ch: Node in c.get_children(true):
		if ch is Label:
			return ch as Label
	return null


func _on_beacon_mode_button(id: String) -> void:
	var mode: int = int(BEACON_MODE_BUTTONS[id])
	if _controller.set_beacon_follow_mode(_beacon_slot, mode):
		show_toast(DataRegistry.get_string("ui.beacon_mode_applied").format({ "mode": RuleText.beacon_mode_name(mode), "name": _controller.label_of(_beacon_slot) }))
	_refresh_beacon_bar()


# ---- 分层提示 / 推荐阵型 / 机制说明 / 任务弹窗（浮层互斥，避免半透明面板相互叠压）----
func _on_hint_pressed() -> void:
	_mechanics_popup.visible = false
	_objective_popup.visible = false
	_hint_panel.press()
	_update_hint_button()


func _update_hint_button() -> void:
	_hint_button.text = _hint_panel.button_text()


## 任务句点击：打开 / 收起「任务」弹窗并让特殊目标闪烁（07 §6）
func _on_objective_clicked() -> void:
	_on_objectives_pressed()
	_root.call("flash_objectives")


## 「任务」悬浮弹窗（10 §6.1：ObjectivePanel 从顶栏下拉改为弹窗，内容不变）
func _on_objectives_pressed() -> void:
	_objective_popup.visible = not _objective_popup.visible
	if _objective_popup.visible:
		_layout_objective_popup()
		_mechanics_popup.visible = false
		_hint_panel.close_panel()


func is_objectives_open() -> bool:
	return _objective_popup.visible


func _on_mechanics_pressed() -> void:
	_mechanics_popup.visible = not _mechanics_popup.visible
	if _mechanics_popup.visible:
		_objective_popup.visible = false
		_hint_panel.close_panel()


func _on_recommended_applied(problems: Array) -> void:
	var list: Array[Dictionary] = []
	list.assign(problems)
	if list.is_empty():
		show_toast(DataRegistry.get_string("ui.recommend_applied"))
	else:
		_show_problems(DataRegistry.get_string("ui.recommend_problems"), list)


# ---- 悬浮原因 / Toast / 调试 ----
func show_tooltip(text: String, screen_pos: Vector2) -> void:
	_tooltip_label.text = text
	_tooltip.visible = true
	_tooltip.reset_size()
	_tooltip.position = screen_pos + Vector2(18.0, 18.0)


func hide_tooltip() -> void:
	_tooltip.visible = false


## 不可放置气泡（批准整图 ui_21）：深红底红边、下沿三角指向格子；样式 / 内边距 / 显示时长取布局 fx_toast；同屏只保留一个
func show_bubble(text: String, anchor: Vector2) -> void:
	var old: Node = get_node_or_null("WarnBubble")
	if old != null:
		old.free()
	_toast.visible = false            # 同一条信息不在顶部重复
	var e: Dictionary = UiKit.layout_element(SKIN, "fx_toast")
	var data: Dictionary = e.get("data", {}) as Dictionary
	var box := PanelContainer.new()
	box.name = "WarnBubble"
	box.theme_type_variation = StringName(str(e.get("theme_type", "")))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(data.get("pad_x", 12)))
	m.add_theme_constant_override("margin_right", int(data.get("pad_x", 12)))
	m.add_theme_constant_override("margin_top", int(data.get("pad_y", 6)))
	m.add_theme_constant_override("margin_bottom", int(data.get("pad_y", 6)))
	box.add_child(m)
	var l := Label.new()
	l.text = text
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "fx_toast_text").get("theme_type", "")))
	m.add_child(l)
	add_child(box)
	box.reset_size()
	var ptr: float = float(data.get("pointer_px", 8))
	var sz: Vector2 = box.get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	box.position = Vector2(clampf(anchor.x - sz.x * 0.5, 0.0, vp.x - sz.x), anchor.y - ptr - sz.y)
	if ptr > 0.0:                              # 平面样式时程序画指向三角；P6 补充切片自带下沿尖角（pointer_px = 0）
		var sb: StyleBox = box.get_theme_stylebox("panel")
		var tri := Polygon2D.new()
		var tx: float = anchor.x - box.position.x
		tri.polygon = PackedVector2Array([Vector2(tx - ptr, sz.y - 1.0), Vector2(tx + ptr, sz.y - 1.0), Vector2(tx, sz.y + ptr)])
		tri.color = (sb as StyleBoxFlat).bg_color if sb is StyleBoxFlat else Palette.BG_DEEP
		box.add_child(tri)
	var t: Tween = box.create_tween()
	t.tween_interval(float(data.get("seconds", 2.5)))
	t.tween_property(box, "modulate:a", 0.0, 0.3)
	t.tween_callback(box.queue_free)


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


## 结算：结算面板 + 结束剧情（胜利 <level_id>_win / 失败 <level_id>_lose，不存在则不触发，07 §10.2）
func show_result(result: int, delay: float) -> void:
	_hint_panel.close_panel()
	_result_panel.call("show_result", result, delay)
	if result == SimTypes.BattleResult.WIN:
		_play_and_mark(story_id("win"))
	elif result == SimTypes.BattleResult.LOSE:
		_play_and_mark(story_id("lose"))


## 播放剧情；真的播放了就记入 stories_seen（10 §3.2：章节地图「回放剧情」只列已看过的条目；随下次存档写盘）
func _play_and_mark(sid: String, hint: String = "") -> void:
	if _dialogue.play_story(sid, hint):
		SaveManager.mark_story_seen(sid)


## 剧情固定命名（07 §10.2）：<level_id>_intro / _win / _lose
func story_id(kind: String) -> String:
	return "%s_%s" % [_level.id, kind]


func set_debug(on: bool) -> void:
	_debug_label.visible = on


## P8 战斗开始提示（决策 ⑭；R6b battle_start 艺术字，无素材时为普通文字）：玩法矩形中央淡入、停留、淡出并略上浮；
## 参数取 data/ui_motion.json 的 art_banner；motion_enabled 关闭时不显示。不拦截输入。
func show_battle_start() -> void:
	var old: Node = get_node_or_null("BattleStartBanner")
	if old != null:
		old.free()
	if not UiKit.motion_enabled:
		return
	var p: Dictionary = UiKit.motion_params("art_banner")
	var text: String = DataRegistry.get_string("ui.battle_start_banner")
	var holder := Control.new()
	holder.name = "BattleStartBanner"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: ArtText = ArtText.create(ArtText.dir_for_text(text), float(p.get("ink_height_px", 120.0)))
	var content: Control = art
	if art == null:
		var l := Label.new()
		l.text = text
		l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "win_title").get("theme_type", "")))
		content = l
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(content)
	add_child(holder)
	var sz: Vector2 = content.size if art != null else content.get_combined_minimum_size()
	var pf: Variant = _root.get("playfield_rect") if _root != null else null
	var center: Vector2 = (pf as Rect2).get_center() if pf is Rect2 else get_viewport_rect().size * 0.5
	holder.size = sz
	holder.pivot_offset = sz * 0.5
	holder.position = center - sz * 0.5
	holder.modulate.a = 0.0
	holder.scale = Vector2.ONE * float(p.get("start_scale", 1.0))
	var tw: Tween = holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "modulate:a", 1.0, float(p.get("fade_in_s", 0.2)))
	tw.tween_property(holder, "scale", Vector2.ONE, float(p.get("fade_in_s", 0.2)))
	tw.chain().tween_interval(float(p.get("hold_s", 0.8)))
	tw.chain().tween_property(holder, "modulate:a", 0.0, float(p.get("fade_out_s", 0.4)))
	tw.parallel().tween_property(holder, "position:y", holder.position.y - float(p.get("rise_px", 0.0)), float(p.get("fade_out_s", 0.4)))
	tw.chain().tween_callback(holder.queue_free)
