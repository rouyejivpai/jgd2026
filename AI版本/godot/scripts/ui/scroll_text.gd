class_name ScrollText
extends Control
## 文字溢出处理（P6，用户 2026-10-05）：把一个现有 Label 包进遮罩区域（clip_contents），内容超出时滚动。
## - 方向：单行（Label 不换行）左右滚动；多行（Label 自动换行）上下滚动
## - 模式 AUTO（名字、标题、按钮文字等短文本）：超出时自动往返滚动——停顿 → 匀速滚到末端 → 停顿 → 滚回
## - 模式 MANUAL（指令、介绍、提示等长文本）：鼠标滚轮与按住拖动滚动；按下后移动不超过阈值视为点击（发 clicked）
## 不超出时不滚动、位置与普通 Label 相同（按 Label 自身的对齐方式摆放）。Label 的 text 仍由原代码直接设置，本节点每帧跟随其尺寸。
## 页边距：遮罩区域就是布局给出的文字区（manifest 的 text_rect，已扣除框体边距）；edge_fade_px 为遮罩两端的渐隐宽度。
## 参数（速度、停顿、滚轮步长、拖动阈值、渐隐宽度）在 data/ui_motion.json 的 "scroll_text"，代码里不写数字。
## wrap_box：包裹一个容器（如问题列表 VBox）而不是单个 Label——总是上下滚动、不做两端渐隐（渐隐只对单个 Label）。

signal clicked()

enum Mode { AUTO, MANUAL }

const NODE_PREFIX: String = "Scroll_"
const FADE_SHADER: Shader = preload("res://assets/shaders/scroll_fade.gdshader")

var mode: int = Mode.AUTO
var source: Button = null               ## 按钮文字代理（UiKit.button_scroll_text）：每帧同步文字、颜色、文字区
var source_colors: Dictionary = {}      ## 代理：按钮原来的文字颜色 { normal, disabled }
var label: Label                        ## 包裹的 Label（wrap_box 时为 null）
var content: Control                    ## 被滚动的节点（Label 或容器）
var offset: float = 0.0                 ## 当前滚动量（像素，沿滚动方向，0 = 起点）
var params: Dictionary = {}
var _vertical: bool = false
var _phase: int = 0                     ## AUTO：0 起点停顿 1 去程 2 末端停顿 3 回程
var _phase_t: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragged: bool = false
var _press_offset: float = 0.0
var _fade_mat: ShaderMaterial = null
var bar_track: Control = null           ## 可选滚动条（与本节点同级，不被遮罩裁掉）：轨道
var bar_thumb: Control = null           ## 滑块：长度 = 轨道长 × 可见比例，位置随滚动量
var bar_min_px: float = 0.0             ## 滑块最短长度
var bar_arrows: Array[Control] = []     ## 可选滚动条两端箭头 [上, 下]：与滚动条同显隐，点击滚动一格（滚轮步长）


## 把 label 包进 ScrollText：wrapper 占据 rect（缺省 = label 当前矩形；未裁剪的单行 Label 会被文字撑大，应先 clip_text 或显式给 rect），
## label 成为其子节点（节点名与 text 用法不变）
static func wrap(l: Label, p_mode: int, rect: Rect2 = Rect2()) -> ScrollText:
	var parent: Node = l.get_parent()
	var s := ScrollText.new()
	s.name = NODE_PREFIX + l.name
	s.mode = p_mode
	s.params = UiKit.motion_params("scroll_text")
	var r: Rect2 = rect if rect.has_area() else Rect2(l.position, l.size)
	s.position = r.position
	s.size = r.size
	s.label = l
	s.content = l
	var internal: bool = not parent.get_children(false).has(l)      # 内部子节点（如卡面文字）包裹后仍为内部
	var index: int = l.get_index(internal)
	l.reparent(s, false)
	if internal:
		parent.add_child(s, false, Node.INTERNAL_MODE_BACK)
	else:
		parent.add_child(s)
		parent.move_child(s, index)
	return s


## 把容器包进 ScrollText（上下滚动）：wrapper 占据 rect，容器成为其子节点
static func wrap_box(box: Control, p_mode: int, rect: Rect2) -> ScrollText:
	var parent: Node = box.get_parent()
	var s := ScrollText.new()
	s.name = NODE_PREFIX + box.name
	s.mode = p_mode
	s.params = UiKit.motion_params("scroll_text")
	s.position = rect.position
	s.size = rect.size
	s.content = box
	var index: int = box.get_index()
	box.reparent(s, false)
	parent.add_child(s)
	parent.move_child(s, index)
	return s


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == Mode.MANUAL else Control.MOUSE_FILTER_IGNORE
	_vertical = label == null or label.autowrap_mode != TextServer.AUTOWRAP_OFF
	if mode == Mode.MANUAL:
		content.mouse_filter = Control.MOUSE_FILTER_PASS
	if label != null:
		label.clip_text = false
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_layout_label()


## 代理：文字区 = 按钮 normal 样式的内容区；颜色 = 按钮动效写入的颜色（Label meta motion_color），否则按钮原色 / 禁用色
func _sync_source() -> void:
	label.text = source.text
	var sb: StyleBox = source.get_theme_stylebox("normal")
	var tl: Vector2 = Vector2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP)) if sb != null else Vector2.ZERO
	var br: Vector2 = Vector2(sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_BOTTOM)) if sb != null else Vector2.ZERO
	position = tl
	size = source.size - tl - br
	var col: Color = source_colors.get("disabled" if source.disabled else "normal", Color.WHITE) as Color
	if label.has_meta(&"motion_color"):
		col = label.get_meta(&"motion_color") as Color
	label.add_theme_color_override("font_color", col)


## 超出量（像素）：内容比遮罩区长出的部分；0 = 不需要滚动
func overflow() -> float:
	if _vertical:
		return maxf(content.get_combined_minimum_size().y - size.y, 0.0)
	return maxf(content.get_combined_minimum_size().x - size.x, 0.0)


func _layout_label() -> void:
	var over: float = overflow()
	offset = clampf(offset, 0.0, over)
	if _vertical:
		content.size = Vector2(size.x, maxf(size.y, content.get_combined_minimum_size().y))
		content.position = Vector2(0.0, -offset)
	else:
		content.size = Vector2(maxf(size.x, content.get_combined_minimum_size().x), size.y)
		content.position = Vector2(-offset, 0.0)
	_layout_bar(over)
	if label == null:
		return
	var fade: float = float(params.get("edge_fade_px", 0.0))
	if over <= 0.0 or fade <= 0.0:
		label.material = null
		return
	if _fade_mat == null:
		_fade_mat = ShaderMaterial.new()
		_fade_mat.shader = FADE_SHADER
	label.material = _fade_mat
	_fade_mat.set_shader_parameter("vertical", _vertical)
	_fade_mat.set_shader_parameter("window_start", offset)
	_fade_mat.set_shader_parameter("window_len", size.y if _vertical else size.x)
	_fade_mat.set_shader_parameter("fade", fade)
	_fade_mat.set_shader_parameter("fade_start", offset > 0.0)
	_fade_mat.set_shader_parameter("fade_end", offset < over)


func _process(delta: float) -> void:
	if source != null:
		_sync_source()
	var over: float = overflow()
	if over <= 0.0:
		_phase = 0
		_phase_t = 0.0
		offset = 0.0
	elif mode == Mode.AUTO and UiKit.motion_enabled:
		_auto_step(delta, over)
	_layout_label()


## 自动往返：起点停顿 → 去程 → 末端停顿 → 回程
func _auto_step(delta: float, over: float) -> void:
	var pause: float = float(params.get("auto_pause_s", 1.0))
	var speed: float = maxf(float(params.get("auto_speed_px", 30.0)), 1.0)
	_phase_t += delta
	match _phase:
		0, 2:
			if _phase_t >= pause:
				_phase = _phase + 1
				_phase_t = 0.0
		1:
			offset = minf(offset + speed * delta, over)
			if offset >= over:
				_phase = 2
				_phase_t = 0.0
		3:
			offset = maxf(offset - speed * delta, 0.0)
			if offset <= 0.0:
				_phase = 0
				_phase_t = 0.0


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.MANUAL:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if overflow() > 0.0:
				scroll_by(float(params.get("wheel_step_px", 40.0)) * (-1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragged = false
				_press_pos = mb.position
				_press_offset = offset
			elif _pressing:
				_pressing = false
				if not _dragged:
					clicked.emit()
			accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _pressing:
		var d: Vector2 = mm.position - _press_pos
		var along: float = d.y if _vertical else d.x
		if not _dragged and absf(along) > float(params.get("drag_threshold_px", 6.0)):
			_dragged = true
		if _dragged:
			offset = clampf(_press_offset - along, 0.0, overflow())
			_layout_label()
		accept_event()


## 挂上滚动条（轨道与滑块已由调用方按布局摆好；滑块最短 = 布局里滑块的原始长度的一半）
func attach_scrollbar(track: Control, thumb: Control) -> void:
	bar_track = track
	bar_thumb = thumb
	bar_min_px = thumb.size.y * 0.5
	_layout_bar(overflow())


## 挂上滚动条两端箭头（调用方已摆好位置）：点击 = 滚轮一格
func attach_arrows(up: Control, down: Control) -> void:
	bar_arrows = [up, down]
	for i: int in 2:
		var dir: float = -1.0 if i == 0 else 1.0
		bar_arrows[i].mouse_filter = Control.MOUSE_FILTER_STOP
		bar_arrows[i].gui_input.connect(func(e: InputEvent) -> void:
			var mb: InputEventMouseButton = e as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				scroll_by(float(params.get("wheel_step_px", 40.0)) * dir))
	_layout_bar(overflow())


func _layout_bar(over: float) -> void:
	for a: Control in bar_arrows:
		a.visible = over > 0.0
	if bar_track == null:
		return
	bar_track.visible = over > 0.0
	bar_thumb.visible = over > 0.0
	if over <= 0.0:
		return
	var content_len: float = size.y + over
	var len_px: float = maxf(bar_track.size.y * size.y / content_len, bar_min_px)
	bar_thumb.size.y = len_px
	bar_thumb.position.y = bar_track.position.y + (bar_track.size.y - len_px) * (offset / over)


func scroll_by(px: float) -> void:
	offset = clampf(offset + px, 0.0, overflow())
	_layout_label()
