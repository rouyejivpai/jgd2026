class_name SettingsOverlay
extends Control
## 设置浮窗（10 §2，取代第一阶段的独立设置界面 settings.tscn）：由 SceneRouter 常驻持有（CanvasLayer 层 100，低于黑幕 128），
## 主界面、章节地图顶栏、局内右上角三处可开；Esc、「关闭」或点击面板外任意位置关闭（用户 2026-10-21；遮罩仍挡住下层点击）。
## 内容：主音量 / 音乐 / 音效、全屏、目标连线、字体大小（「调试」一节的模拟日志开关 2026-10-20 起隐藏）；修改即时生效，关闭时写存档。
## 局内打开时的暂停（决策 ⑦）由 BattleRoot 监听 SceneRouter.settings_opened 处理。
## 第三阶段 P5 按 R1 设计换皮（10 §1）：节点、位置、贴图、字体全部来自 data/ui_layout/settings_overlay.json 与
## assets/themes/ui_settings_overlay.tres（apply_ui_manifest.py 生成），本脚本只做文字 / 数值绑定与接线：
## - 滑条 = 布局里的轨（ninepatch）、填充（ninepatch，宽 = 满宽 × 值）、把手（icon，居中于填充末端）三层，
##   上面叠一个透明的 HSlider 接收输入（slider_<key>_track / _fill / _grabber、pct_<key>）
## - 开关 toggle_<key> = TextureButton（on / off 切片）；字体大小 dropdown_font_scale = OptionButton（主题变体）+ 切片箭头
## 2026-10-21 04.zip：面板换成 I01 整图（标题画在图上），关闭 = 面板右上角的无字徽记（悬停提示「关闭」）；
## 整图不能拉伸，布局 panel_settings.data.fixed_frame 时不再收起「调试」一节的空位。

signal closed()

const SCREEN: String = "settings_overlay"
const FONT_SCALES: Array[float] = [1.0, 1.15, 1.3]
const VOLUME_KEYS: Array[String] = ["master", "music", "sfx"]
const TOGGLE_KEYS: Array[String] = ["fullscreen", "target_lines", "sim_log"]
const DEBUG_IDS: Array[String] = ["section_debug", "label_sim_log", "toggle_sim_log", "log_hint"]
const VOLUME_STEP: float = 0.05
const GRABBER_STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]
const PANEL_HIT_ALPHA: float = 0.4               ## 面板整图不透明度高于此处算「面板内」，其余点击关闭
const NODE_NAMES: Dictionary = {
	"mask": "Mask", "panel_settings": "SettingsPanel", "btn_close": "CloseButton", "dropdown_font_scale": "FontScaleOption",
	"toggle_fullscreen": "Toggle_fullscreen", "toggle_target_lines": "Toggle_target_lines", "toggle_sim_log": "Toggle_sim_log",
}

var save_path: String = SaveManager.SAVE_PATH    ## 关闭时写入的存档路径（测试可改为临时路径）
var nodes: Dictionary = {}                       ## 元素 id → Control
var _sliders: Dictionary = {}                    ## 音量键 → HSlider（透明，接收输入）
var _grabber_textures: Dictionary = {}           ## 状态 → Texture2D
var _font_option: OptionButton
var _close_button: Button
var _panel_hit: BitMap                           ## 面板整图的不透明区域（fixed_frame 时）；null = 按面板矩形判断


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # 遮罩吞掉点击，点击遮罩不关闭
	nodes = UiKit.build_from_layout(self, SCREEN, NODE_NAMES)
	(nodes["mask"] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	(nodes["mask"] as Control).gui_input.connect(_on_mask_input)
	_build_panel_hit()
	_close_button = nodes["btn_close"] as Button
	_close_button.pressed.connect(close)
	_close_button.set_meta("sfx_press", "ui_panel_close")
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.tooltip_text = _close_button.text
	(nodes["title"] as Label).text = DataRegistry.get_string("ui.menu_settings")
	_build_sliders()
	for key: String in TOGGLE_KEYS:
		var tb: TextureButton = nodes["toggle_" + key] as TextureButton
		tb.toggled.connect(_on_toggled.bind(key))
	_build_font_option()
	for id: String in DEBUG_IDS:                 # 2026-10-20 临近发布：隐藏「调试」一节（模拟日志开关照旧按存档生效）
		(nodes[id] as Control).visible = false
	resized.connect(_layout)
	visible = false


## 打开：按当前设置刷新数值并显示
func open() -> void:
	for key: String in VOLUME_KEYS:
		(_sliders[key] as HSlider).set_value_no_signal(GameState.setting_float(key, 1.0))
		_update_slider(key)
	for key: String in TOGGLE_KEYS:
		(nodes["toggle_" + key] as TextureButton).set_pressed_no_signal(GameState.setting_bool(key))
	var current: float = GameState.setting_float("font_scale", 1.0)
	for i: int in FONT_SCALES.size():
		if is_equal_approx(FONT_SCALES[i], current):
			_font_option.select(i)
	(nodes["log_hint"] as Label).text = DataRegistry.get_string("ui.settings_log_hint").format(
		{ "path": ProjectSettings.globalize_path(DebugLog.LOG_DIR) })
	var was_open: bool = visible
	visible = true
	_layout()
	if not was_open:                         # 2026-10-19：面板与控件一起滑入，遮罩淡入
		var group: Array = []
		for id: String in nodes.keys():
			if id != "mask":
				group.append(nodes[id])
		UiKit.slide_in(group, (nodes["panel_settings"] as Control).get_global_rect(), [nodes.get("mask")])


## Esc 关闭（先于场景内其他 Esc 处理，例如局内收起侧栏）
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		UiKit.close_sfx()
		close()
		get_viewport().set_input_as_handled()


## 点击面板外（遮罩上、面板整图透明处）关闭；面板上的控件自己吞掉点击，不会到这里
func _on_mask_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _inside_panel(mb.global_position):
		return
	accept_event()
	UiKit.close_sfx()
	close()


func _build_panel_hit() -> void:
	var panel: TextureRect = nodes["panel_settings"] as TextureRect
	if panel == null or panel.texture == null:
		return
	var img: Image = panel.texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	_panel_hit = BitMap.new()
	_panel_hit.create_from_image_alpha(img, PANEL_HIT_ALPHA)


func _inside_panel(global_pos: Vector2) -> bool:
	var panel: Control = nodes["panel_settings"] as Control
	var local: Vector2 = panel.get_global_transform().affine_inverse() * global_pos
	if not Rect2(Vector2.ZERO, panel.size).has_point(local):
		return false
	if _panel_hit == null:
		return true
	var bm: Vector2i = _panel_hit.get_size()
	var px := Vector2i(clampi(int(local.x / panel.size.x * bm.x), 0, bm.x - 1), clampi(int(local.y / panel.size.y * bm.y), 0, bm.y - 1))
	return _panel_hit.get_bitv(px)


## 关闭：写存档并隐藏（SceneRouter.close_settings 同样走这里）
func close() -> void:
	if not visible:
		return
	visible = false
	SaveManager.save(save_path)
	closed.emit()


func _layout() -> void:
	UiKit.relayout(SCREEN, nodes, size)
	for key: String in VOLUME_KEYS:
		var track: Rect2 = UiKit.layout_rect(SCREEN, "slider_%s_track" % key, size)
		var grab: Rect2 = UiKit.layout_rect(SCREEN, "slider_%s_grabber" % key, size)
		var s: HSlider = _sliders[key] as HSlider
		s.position = Vector2(track.position.x, grab.position.y)
		s.size = Vector2(track.size.x, grab.size.y)
		_update_slider(key)
	_collapse_debug_section()


## 「调试」一节隐藏后收起它的空位：面板底边与底部分隔线上移，整体下移一半保持居中
func _collapse_debug_section() -> void:
	if bool((UiKit.layout_element(SCREEN, "panel_settings").get("data", {}) as Dictionary).get("fixed_frame", false)):
		return
	var cut: float = UiKit.layout_rect(SCREEN, "separator_footer", size).position.y - UiKit.layout_rect(SCREEN, "section_debug", size).position.y
	var panel: Control = nodes["panel_settings"] as Control
	panel.size.y -= cut
	(nodes["separator_footer"] as Control).position.y -= cut
	var shift: float = floorf(cut * 0.5)
	for id: String in nodes.keys():
		if id != "mask":
			(nodes[id] as Control).position.y += shift
	for s: HSlider in _sliders.values():
		s.position.y += shift


# ---- 音量滑条 ----
func _build_sliders() -> void:
	var common: Dictionary = UiKit.layout_element(SCREEN, "slider_master_grabber")
	var base: String = str(common["file"]).get_base_dir()
	for st: String in GRABBER_STATES:
		_grabber_textures[st] = load(base.path_join("slider_grabber_%s.png" % st)) as Texture2D
	var empty := StyleBoxEmpty.new()
	for key: String in VOLUME_KEYS:
		var grab_size: Vector2 = UiKit.layout_rect(SCREEN, "slider_%s_grabber" % key, Vector2.ZERO).size
		var s := HSlider.new()
		s.name = "Volume_" + key
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = VOLUME_STEP
		s.focus_mode = Control.FOCUS_NONE
		for style: String in ["slider", "grabber_area", "grabber_area_highlight"]:
			s.add_theme_stylebox_override(style, empty)
		var clear: ImageTexture = UiKit.transparent_texture(Vector2i(grab_size))
		for icon: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
			s.add_theme_icon_override(icon, clear)
		s.value_changed.connect(_on_volume_changed.bind(key))
		s.drag_ended.connect(func(_changed: bool) -> void: _update_slider(key))
		s.drag_started.connect(func() -> void: _set_grabber(key, "pressed"))
		s.mouse_entered.connect(func() -> void: _set_grabber(key, "hover"))
		s.mouse_exited.connect(func() -> void: _set_grabber(key, "normal"))
		add_child(s)
		_sliders[key] = s


## 只有玩家拖动 / 点轨道会触发（open 用 set_value_no_signal）；滑条无焦点，AudioManager 的自动刻度音不响，这里自己播
func _on_volume_changed(v: float, key: String) -> void:
	GameState.settings[key] = v
	AudioManager.apply_volumes()
	AudioManager.play_sfx("ui_value_tick", "UI", 0.0, 1.0, 0.04, 45)
	_update_slider(key)


## 填充宽 = 满宽 × 值（满宽 = 轨右端 − 填充左端）；把手居中于填充末端；百分比文字
func _update_slider(key: String) -> void:
	var v: float = (_sliders[key] as HSlider).value
	var track: Rect2 = UiKit.layout_rect(SCREEN, "slider_%s_track" % key, size)
	var fill: Rect2 = UiKit.layout_rect(SCREEN, "slider_%s_fill" % key, size)
	var full: float = track.end.x - fill.position.x
	var fill_node: Control = nodes["slider_%s_fill" % key] as Control
	fill_node.size = Vector2(floorf(full * v), fill.size.y)
	fill_node.visible = fill_node.size.x >= 1.0
	var grab: Control = nodes["slider_%s_grabber" % key] as Control
	grab.position.x = floorf(fill.position.x + fill_node.size.x - grab.size.x * 0.5)
	(nodes["pct_" + key] as Label).text = _pct(v)


func _set_grabber(key: String, state: String) -> void:
	var s: HSlider = _sliders[key] as HSlider
	if state == "normal" and s.get_rect().has_point(get_local_mouse_position()):
		state = "hover"
	(nodes["slider_%s_grabber" % key] as TextureRect).texture = _grabber_textures.get(state, _grabber_textures["normal"]) as Texture2D


# ---- 开关 / 字体大小 ----
func _on_toggled(on: bool, key: String) -> void:
	GameState.settings[key] = on
	if key == "fullscreen":
		_on_display_changed()


func _build_font_option() -> void:
	_font_option = nodes["dropdown_font_scale"] as OptionButton
	_font_option.focus_mode = Control.FOCUS_NONE
	_font_option.fit_to_longest_item = false
	_font_option.add_theme_icon_override("arrow", UiKit.transparent_texture(Vector2i.ONE))   # 箭头用布局里的切片
	# 布局里的 font_scale_value 文字层与下拉自带文字重叠（且只显示未填充的 "{pct}%"）：隐藏它，把它的字体 / 字号 / 颜色给下拉
	var value_label: Label = nodes["font_scale_value"] as Label
	value_label.visible = false
	_font_option.add_theme_font_override("font", value_label.get_theme_font("font"))
	_font_option.add_theme_font_size_override("font_size", value_label.get_theme_font_size("font_size"))
	var value_color: Color = value_label.get_theme_color("font_color")
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_font_option.add_theme_color_override(c, value_color)
	for i: int in FONT_SCALES.size():
		_font_option.add_item(DataRegistry.get_string("ui.settings_font_scale_option").format({ "pct": roundi(FONT_SCALES[i] * 100.0) }), i)
	_font_option.select(0)
	var e: Dictionary = UiKit.layout_element(SCREEN, "dropdown_font_scale")
	_font_option.get_popup().theme_type_variation = StringName(str(e.get("popup_theme_type", "")))
	_font_option.item_selected.connect(_on_font_selected)
	move_child(nodes["dropdown_arrow"] as Control, -1)     # 箭头画在下拉之上


func _on_font_selected(index: int) -> void:
	GameState.settings["font_scale"] = FONT_SCALES[index]
	_on_display_changed()
	var value_label: Label = nodes["font_scale_value"] as Label     # 下拉的字号是建时从主题抄的覆盖值，跟着重抄（直接查主题：控件的主题缓存要下一帧才刷新）
	_font_option.add_theme_font_size_override("font_size", theme.get_font_size("font_size", value_label.theme_type_variation))


func _on_display_changed() -> void:
	GameState.apply_display_settings()


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
