class_name ButtonMotion
extends Control
## 按钮动效（10 §1.5，第三阶段 P8）：挂在 Button 下的内部子节点（show_behind_parent，画在按钮文字之下），
## 用按钮自己的四态样式（R1 切片或程序化 StyleBox）做状态过渡，不需要额外素材：
## - 按钮本身的 normal / hover / pressed / disabled / hover_pressed / focus 样式换成同内边距的空样式（文字位置不变），
##   背景改由本节点的三层面板绘制：底层（normal 或 disabled）、hover 层、pressed 层；层的不透明度 = 状态权重
## - hover（含焦点）：hover 层淡入并整体提亮、金色描边常亮加强（hover_boost）且缓慢呼吸；文字提亮；
##   按钮整体（背景 + 文字）向右让出 hover_nudge_px；从普通态进入时金色描边扫过一道斜向光带（button_sheen.gdshader）
## - pressed：pressed 层淡入、按钮以中心微缩、文字微暗；松开时回弹（back 曲线）。切换按钮的按下常态（如 1× / 2×）只换 pressed 样式，不缩放、不压暗
## - disabled：立即切换，不播放任何动效
## 每帧按按钮的绘制状态求目标态；状态变化时杀掉当前 Tween、从当前权重出发补间到目标，因此任意时刻可被打断、不残留。
## 外部代码改按钮样式（如章节地图节点按选中重设 normal / hover / pressed）时，下一帧检测到并重新接管；
## 外部设的文字颜色覆盖在动效结束后恢复（动效期间外部改色也会被记下）。
## 参数来自 data/ui_motion.json 的一个档（UiKit.motion_params）：button = 通用，button_menu = 菜单大按钮（Q-072 焦点跟随鼠标：
## 悬停取焦点、离开交还焦点，同一时刻至多一个按钮呈选中态）。
## UiKit.motion_enabled = false 时不挂本节点，按钮保持原样（静止态 = 布局值）。

enum Visual { NORMAL, HOVER, PRESSED, DISABLED }

const NODE_NAME: String = "Motion"
const META: StringName = &"ui_motion"
const SHEEN_SHADER: Shader = preload("res://assets/shaders/button_sheen.gdshader")
const STYLE_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]
const WATCH_STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]
const FONT_COLORS: Array[String] = ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]
const SIDES: Array[int] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]

var params: Dictionary = {}       ## ui_motion.json 的一档
var visual: int = -1              ## 当前目标态（Visual）；-1 = 尚未求值（首帧直接落到目标态，不补间）
var hover_w: float = 0.0          ## hover 权重（0..1；回弹时可略超出）
var press_w: float = 0.0          ## pressed 权重（0..1；回弹时可略小于 0）
var tween: Tween                  ## 当前状态过渡
var sweep_tween: Tween            ## 光带扫过（hover 进入时的一次性点缀，不属于状态）
var button: Button
var _styles: Dictionary = {}      ## 样式名 → 按钮原样式（外部改动后重新接管）
var _empties: Dictionary = {}     ## 样式名 → 本节点放到按钮上的空样式
var _margins: Dictionary = {}     ## 样式名 → 原内边距 [左, 上, 右, 下]
var _color_stash: Dictionary = {} ## 动效改文字颜色前，外部已有的颜色覆盖（名 → Color）
var _text_color: Color = Color.WHITE
var _colored: bool = false        ## 当前文字颜色是否由本节点覆盖
var _last_color: Color = Color.WHITE
var _was_hovered: bool = false
var _base: Panel
var _hover: Panel
var _pressed: Panel
var _sheen: ShaderMaterial


## 给按钮挂上动效（重复调用返回已有的）
static func attach(b: Button, p: Dictionary) -> ButtonMotion:
	if b.has_meta(META):
		return b.get_node(NODE_NAME) as ButtonMotion
	var m := ButtonMotion.new()
	m.name = NODE_NAME
	m.params = p
	m.button = b
	b.set_meta(META, true)
	b.add_child(m, false, Node.INTERNAL_MODE_FRONT)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	_base = _layer("Base")
	_hover = _layer("Hover")
	_pressed = _layer("Pressed")
	_sheen = ShaderMaterial.new()
	_sheen.shader = SHEEN_SHADER
	var sweep: Dictionary = params.get("sweep", {}) as Dictionary
	_sheen.set_shader_parameter("band_px", float(sweep.get("band_px", 0.0)))
	_sheen.set_shader_parameter("slant", float(sweep.get("slant", 0.0)))
	_sheen.set_shader_parameter("sweep_strength", float(sweep.get("strength", 0.0)))
	_sheen.set_shader_parameter("breathe_period", maxf(float((params.get("breathe", {}) as Dictionary).get("period", 1.0)), 0.01))
	_sheen.set_shader_parameter("hover_boost", float(params.get("hover_boost", 0.0)))
	_sheen.set_shader_parameter("lift", float(params.get("hover_lift", 0.0)))
	var mask: Array = params.get("gold_mask", [0.0, 1.0]) as Array
	_sheen.set_shader_parameter("gold_mask", Vector2(float(mask[0]), float(mask[1])))
	_hover.material = _sheen
	_text_color = button.get_theme_color("font_color")
	_capture()
	if bool(params.get("focus_follows_mouse", false)):
		button.mouse_entered.connect(_on_mouse_entered)
		button.mouse_exited.connect(_on_mouse_exited)
	_apply()


func _layer(layer_name: String) -> Panel:
	var p := Panel.new()
	p.name = layer_name
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


## 接管按钮样式：凡是按钮当前样式不是本节点的空样式（首次，或外部代码改过 / 去掉了覆盖），记为原样式并换成同内边距的空样式
func _capture() -> void:
	for st: String in STYLE_STATES:
		var cur: StyleBox = button.get_theme_stylebox(st)
		if _empties.has(st) and cur == _empties[st]:
			continue
		_styles[st] = cur
		var m: Array[float] = [0.0, 0.0, 0.0, 0.0]
		for i: int in SIDES.size():
			m[i] = cur.get_margin(SIDES[i]) if cur != null else 0.0
		_margins[st] = m
		var empty := StyleBoxEmpty.new()
		_empties[st] = empty
		button.add_theme_stylebox_override(st, empty)
	_base.add_theme_stylebox_override("panel", _styles["disabled" if visual == Visual.DISABLED else "normal"] as StyleBox)
	_hover.add_theme_stylebox_override("panel", _styles["hover"] as StyleBox)
	_pressed.add_theme_stylebox_override("panel", _styles["pressed"] as StyleBox)


## 外部改了按钮的主题变体（theme_type_variation）时调用：去掉本节点的空样式覆盖，按新主题重新取原样式（2026-10-19：结算按钮按胜负换变体）
func recapture() -> void:
	for st: String in _empties.keys():
		button.remove_theme_stylebox_override(st)
	_empties.clear()
	_capture()
	_apply()


func _styles_changed() -> bool:
	for st: String in WATCH_STATES:
		if button.get_theme_stylebox(st) != _empties.get(st):
			return true
	return false


func _process(_delta: float) -> void:
	if _styles_changed():
		_capture()
		_apply()
	if _colored and _proxy() == null and button.get_theme_color("font_color") != _last_color:
		_color_stash["font_color"] = button.get_theme_color("font_color")      # 动效期间外部改了文字颜色：记下，结束后恢复
		_text_color = _color_stash["font_color"] as Color
		_apply()
	if button.toggle_mode and button.is_hovered() != _was_hovered:      # 切换按钮按下常态下的悬停只改文字（状态不变）
		_was_hovered = button.is_hovered()
		_apply()
	var target: int = target_visual()
	if target != visual:
		go(target)


## 焦点跟随鼠标：鼠标离开即交还焦点，按钮回到普通态（否则最后悬停过的按钮会一直亮着）
func _on_mouse_exited() -> void:
	if button.has_focus():
		button.release_focus()


func _on_mouse_entered() -> void:
	if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()


## 按钮当前应呈现的状态（焦点按 hover 显示）
func target_visual() -> int:
	if button.disabled:
		return Visual.DISABLED
	match button.get_draw_mode():
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
			return Visual.PRESSED
		BaseButton.DRAW_HOVER:
			return Visual.HOVER
		BaseButton.DRAW_DISABLED:
			return Visual.DISABLED
	return Visual.HOVER if button.has_focus() else Visual.NORMAL


## 切到目标态：首帧、disabled 或总闸关闭时立即落位；否则从当前权重补间（打断上一段）
func go(target: int) -> void:
	var from: int = visual
	visual = target
	if tween != null:
		tween.kill()
		tween = null
	var hover_t: float = 1.0 if target == Visual.HOVER or target == Visual.PRESSED else 0.0
	var press_t: float = 1.0 if target == Visual.PRESSED else 0.0
	if target != Visual.HOVER:
		_stop_sweep()
	if from < 0 or target == Visual.DISABLED or from == Visual.DISABLED or not UiKit.motion_enabled:
		hover_w = hover_t
		press_w = press_t
		_apply()
		return
	var spec_key: String = "hover_out"
	if target == Visual.PRESSED:
		spec_key = "press"
	elif from == Visual.PRESSED:
		spec_key = "release"
	elif target == Visual.HOVER:
		spec_key = "hover_in"
	var spec: Dictionary = params.get(spec_key, {}) as Dictionary
	var duration: float = float(spec.get("duration", 0.0))
	tween = create_tween().set_parallel(true)
	tween.tween_method(_set_hover_w, hover_w, hover_t, duration).set_trans(UiKit.motion_trans(spec)).set_ease(UiKit.motion_ease(spec))
	tween.tween_method(_set_press_w, press_w, press_t, duration).set_trans(UiKit.motion_trans(spec)).set_ease(UiKit.motion_ease(spec))
	if target == Visual.HOVER and from == Visual.NORMAL:
		_start_sweep()
	_apply()


func _set_hover_w(v: float) -> void:
	hover_w = v
	_apply()


func _set_press_w(v: float) -> void:
	press_w = v
	_apply()


func _start_sweep() -> void:
	_stop_sweep()
	var spec: Dictionary = params.get("sweep", {}) as Dictionary
	_sheen.set_shader_parameter("width_px", button.size.x)
	sweep_tween = create_tween()
	sweep_tween.tween_method(_set_sweep, 0.0, 1.0, float(spec.get("duration", 0.0))).set_trans(UiKit.motion_trans(spec)).set_ease(UiKit.motion_ease(spec))
	sweep_tween.tween_callback(_stop_sweep)


func _set_sweep(v: float) -> void:
	_sheen.set_shader_parameter("sweep", v)


func _stop_sweep() -> void:
	if sweep_tween != null:
		sweep_tween.kill()
		sweep_tween = null
	_sheen.set_shader_parameter("sweep", -1.0)


## 按权重刷新各层、让位、缩放与文字颜色；权重全 0 时恢复文字颜色、缩放为 1、不让位（= 静止态）
func _apply() -> void:
	var h: float = clampf(hover_w, 0.0, 1.0)
	var p: float = clampf(press_w, 0.0, 1.0)
	_base.add_theme_stylebox_override("panel", _styles["disabled" if visual == Visual.DISABLED else "normal"] as StyleBox)
	_pressed.modulate.a = p
	_pressed.visible = p > 0.0
	_hover.modulate.a = h
	_hover.visible = h > 0.0 and p < 1.0
	_base.visible = h < 1.0 and p < 1.0
	var breathe: Dictionary = params.get("breathe", {}) as Dictionary
	_sheen.set_shader_parameter("breathe_amp", float(breathe.get("amplitude", 0.0)) if visual == Visual.HOVER else 0.0)
	var nudge: float = roundf(float(params.get("hover_nudge_px", 0.0)) * hover_w)
	position.x = nudge
	for st: String in _empties.keys():
		var m: Array[float] = _margins[st] as Array[float]
		var e: StyleBoxEmpty = _empties[st] as StyleBoxEmpty
		e.content_margin_left = m[0] + nudge
		e.content_margin_top = m[1]
		e.content_margin_right = m[2] - nudge
		e.content_margin_bottom = m[3]
	button.pivot_offset = button.size * 0.5
	var press_scale: float = 1.0 if button.toggle_mode else float(params.get("press_scale", 1.0))
	button.scale = Vector2.ONE * lerpf(1.0, press_scale, press_w)
	# 文字权重：切换按钮的按下是常态（如 1× / 2×）——不压暗；鼠标不在其上时也不提亮（与无动效时相同）
	var text_h: float = h
	var text_p: float = p
	if button.toggle_mode:
		text_p = 0.0
		if visual == Visual.PRESSED and not button.is_hovered() and not button.has_focus():
			text_h = 0.0
	if visual == Visual.DISABLED or (is_zero_approx(text_h) and is_zero_approx(text_p)):
		_restore_colors()
		return
	var proxy: Label = _proxy()
	if proxy != null:                       # 文字由代理 Label 绘制（UiKit.button_scroll_text）：颜色写到它的 meta，由 ScrollText 应用
		if not _colored:
			_text_color = ((proxy.get_parent() as ScrollText).source_colors.get("normal", Color.WHITE)) as Color
			_colored = true
		proxy.set_meta(&"motion_color", _text_color.lightened(float(params.get("text_hover_lighten", 0.0)) * text_h).darkened(float(params.get("text_press_darken", 0.0)) * text_p))
		return
	if not _colored:
		_color_stash.clear()
		for c: String in FONT_COLORS:
			if button.has_theme_color_override(c):
				_color_stash[c] = button.get_theme_color(c)
		_text_color = button.get_theme_color("font_color")
		_colored = true
	_last_color = _text_color.lightened(float(params.get("text_hover_lighten", 0.0)) * text_h).darkened(float(params.get("text_press_darken", 0.0)) * text_p)
	for c: String in FONT_COLORS:
		button.add_theme_color_override(c, _last_color)


func _proxy() -> Label:
	return button.get_meta(UiKit.TEXT_PROXY_META) as Label if button.has_meta(UiKit.TEXT_PROXY_META) else null


func _restore_colors() -> void:
	if not _colored:
		return
	_colored = false
	var proxy: Label = _proxy()
	if proxy != null:
		proxy.remove_meta(&"motion_color")
		return
	for c: String in FONT_COLORS:
		if _color_stash.has(c):
			button.add_theme_color_override(c, _color_stash[c] as Color)
		else:
			button.remove_theme_color_override(c)
	_color_stash.clear()


## 测试与截图用：立即完成当前过渡（含光带）
func settle() -> void:
	if tween != null and tween.is_valid():
		tween.custom_step(1000.0)
	_stop_sweep()
