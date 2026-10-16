class_name UiKit
extends RefCounted
## 代码构建界面用的小工具（只做节点创建与样式，不含文案）。
## 第三阶段（10 §10 新增铁律 1）：换皮前的程序化占位布局数字集中在此；P5 起由 data/ui_layout/*.json 取代。

# ---- 局内 HUD（10 §6.1 程序化占位版）----
const TOP_BAR_HEIGHT: float = 64.0             ## 与 Playfield.TOP_BAR 一致（玩法矩形公式不变）
const BOTTOM_BAR_HEIGHT: float = 120.0         ## 与 Playfield.BOTTOM_BAR 一致
const TOP_RIGHT_ROW_HEIGHT: float = 52.0       ## 右上角「退出」下方的「任务」「机制说明」一行
const HUD_MARGIN: float = 16.0
const SIDE_WIDTH: float = 520.0                ## 08 ⑥ 对侧浮动面板
const START_BUTTON_SIZE: Vector2 = Vector2(240.0, 96.0)   ## 10 §6.1：开始按钮放左并放大
const TOP_BUTTON_WIDTH: float = 96.0           ## 右上角功能按钮（重试 / 暂停 / 设置 / 退出 / 任务 / 机制说明）
const SPEED_BUTTON_WIDTH: float = 64.0
const BOTTOM_BUTTON_WIDTH: float = 120.0       ## 底栏清空
const HINT_BUTTON_WIDTH: float = 170.0
const OBJECTIVE_POPUP_WIDTH: float = 640.0     ## 「任务」悬浮弹窗
const RULE_ROW_INDENT: float = 24.0            ## 指令行条件缩进
# ---- 局内镜头横移（10 §6.4）----
const PAN_MAX: float = SIDE_WIDTH              ## 偏移 ∈ [−PAN_MAX, +PAN_MAX]，= 侧栏宽
const PAN_EDGE_PX: float = 24.0                ## 鼠标距窗口左右边 < 24 px 触发
const PAN_SPEED: float = 600.0                 ## 像素 / 秒【建议】
const PAN_RECENTER_SECONDS: float = 0.2        ## 取消选中 / 开始战斗时回正
const ZOOM_MIN: float = 0.8                     ## 第四阶段 Ctrl + 滚轮缩放范围与每档倍率【建议】
const ZOOM_MAX: float = 2.5
const ZOOM_STEP: float = 1.12
# ---- 章节地图（10 §3.2）----
const CHAPTER_DETAIL_WIDTH: float = 560.0      ## 右侧详情面板固定宽
const CHAPTER_DRAG_THRESHOLD: float = 6.0      ## 按下后移动 ≤ 6 px 视为点击
const CHAPTER_WHEEL_STEP: float = 160.0        ## 滚轮一格横移
const CHAPTER_NODE_SIZE: float = 84.0
const CHAPTER_BOSS_SIZE: float = 112.0
const CHAPTER_LINK_WIDTH: float = 6.0
const CHAPTER_SELECTED_BORDER: int = 6
const CHAPTER_MARGIN: float = 48.0
const CHAPTER_TOP_BUTTON_SIZE: Vector2 = Vector2(160.0, 56.0)
# ---- 设置浮窗（10 §2）----
const OVERLAY_MASK_ALPHA: float = 0.6
const SETTINGS_PANEL_WIDTH: float = 720.0
const SETTINGS_SLIDER_WIDTH: float = 360.0


static func label(text: String, variation: String = "", wrap_text: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = StringName(variation)
	if wrap_text:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(10.0, 0.0)
	return l


static func button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44.0)
	return b


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func panel_style(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	return sb


## 下拉框：items 为 [[显示文本, 元数据字符串], ...]，选中 current
static func fill_option(o: OptionButton, items: Array, current: String) -> void:
	o.clear()
	for i: int in items.size():
		var pair: Array = items[i] as Array
		o.add_item(str(pair[0]), i)
		o.set_item_metadata(i, str(pair[1]))
		if str(pair[1]) == current:
			o.select(i)
	if o.selected < 0 and o.item_count > 0:
		o.select(0)


static func option_value(o: OptionButton, index: int) -> String:
	return str(o.get_item_metadata(index))


## 圆形遮罩头像（缺图时显示纯色圆块占位）
static func portrait(size_px: float) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(size_px, size_px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/circle_mask.gdshader") as Shader
	r.material = m
	return r


static func set_portrait(r: TextureRect, path: String, fallback: Color) -> void:
	var tex: Texture2D = Art.texture(path)
	if tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(fallback)
		tex = ImageTexture.create_from_image(img)
	r.texture = tex


# ---- 第三阶段 P5（10 §1.3）：manifest 生成的布局与主题 ----
## data/ui_layout/<screen>.json（tools/apply_ui_manifest.py 生成）与 assets/themes/ui_<screen>.tres。
## UI 脚本只读这两样，不写布局数字；设计坐标 → 屏幕坐标只在 layout_rect() 一处换算（07 §1 居中规则：
## canvas_items 拉伸 + expand，逻辑视口不小于设计尺寸，设计画布居中；铺满设计画布的元素按 cover 铺满视口）。
const UI_LAYOUT_DIR: String = "res://data/ui_layout/"
const UI_THEME_PATTERN: String = "res://assets/themes/ui_%s.tres"

static var _layouts: Dictionary = {}


## 整个布局文件（缓存）；缺失返回 {}
static func ui_layout(screen: String) -> Dictionary:
	if not _layouts.has(screen):
		var path: String = UI_LAYOUT_DIR + screen + ".json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_layouts[screen] = parsed as Dictionary if parsed is Dictionary else {}
	return _layouts[screen] as Dictionary


static func ui_theme(screen: String) -> Theme:
	return load(UI_THEME_PATTERN % screen) as Theme


## 元素列表（manifest 绘制顺序，从后往前）
static func layout_elements(screen: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(ui_layout(screen).get("elements", []) as Array)
	return out


static func layout_element(screen: String, id: String) -> Dictionary:
	for e: Dictionary in layout_elements(screen):
		if str(e["id"]) == id:
			return e
	return {}


static func _rect_of(a: Variant) -> Rect2:
	var r: Array = a as Array
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func design_size(screen: String) -> Vector2:
	var d: Array = ui_layout(screen).get("design_size", [1920, 1080]) as Array
	return Vector2(float(d[0]), float(d[1]))


## 设计坐标 → 屏幕坐标：设计画布在视口中居中（取整到像素）；铺满整个设计画布的元素返回整个视口（cover）
static func layout_rect(screen: String, id: String, viewport_size: Vector2) -> Rect2:
	var e: Dictionary = layout_element(screen, id)
	if e.is_empty():
		return Rect2()
	var design: Vector2 = design_size(screen)
	var r: Rect2 = _rect_of(e["rect"])
	if r.position == Vector2.ZERO and r.size == design:
		return Rect2(Vector2.ZERO, viewport_size)
	return Rect2(r.position + ((viewport_size - design) * 0.5).floor(), r.size)


## 元素内部文字区（text_rect）对应的屏幕矩形；没有 text_rect 时为元素本身
static func layout_text_rect(screen: String, id: String, viewport_size: Vector2) -> Rect2:
	var r: Rect2 = layout_rect(screen, id, viewport_size)
	var e: Dictionary = layout_element(screen, id)
	if not e.has("text_rect"):
		return r
	var t: Rect2 = _rect_of(e["text_rect"])
	return Rect2(r.position + t.position, t.size)


## 按布局建出一个界面的静态节点（挂在 root 下，root 设主题）：image / icon → TextureRect，ninepatch → PanelContainer（主题变体），
## text_style → Label（主题变体、对齐，文字取 strings key），button → Button（主题变体、文字取 key，焦点复用 hover 贴图），
## toggle → TextureButton（on / off）。names：元素 id → 节点名（不在表中的用 id）。error_only / merged_into 的元素跳过。
## 返回 id → Control；位置由 relayout() 统一设置。
static func build_from_layout(root: Control, screen: String, names: Dictionary = {}) -> Dictionary:
	root.theme = ui_theme(screen)
	var nodes: Dictionary = {}
	for e: Dictionary in layout_elements(screen):
		if e.has("merged_into") or bool(e.get("error_only", false)):
			continue
		var id: String = str(e["id"])
		var c: Control = node_for(e)
		if c == null:
			continue
		c.name = str(names.get(id, id))
		root.add_child(c)
		nodes[id] = c
	return nodes


static func node_for(e: Dictionary) -> Control:
	match str(e["kind"]):
		"image", "icon":
			var t := TextureRect.new()
			t.texture = load(str(e["file"])) as Texture2D
			var data: Dictionary = e.get("data", {}) as Dictionary
			if data.has("region"):                # 只取切片的一块（贴图像素 [x, y, w, h]），如从整张纹饰里裁出月牙刻纹
				var at := AtlasTexture.new()
				at.atlas = t.texture
				at.region = _rect_of(data["region"])
				t.texture = at
			if data.has("modulate"):              # 调色 / 半透明（如把亮金纹饰压成整图里的低对比刻纹）
				t.modulate = Color(str(data["modulate"]))
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return t
		"ninepatch", "flatbox":
			var p := PanelContainer.new()
			p.theme_type_variation = StringName(str(e["theme_type"]))
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return p
		"text_style":
			var l := Label.new()
			l.theme_type_variation = StringName(str(e["theme_type"]))
			l.horizontal_alignment = _align(str(e.get("align", "left")))
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if e.has("key"):
				l.text = DataRegistry.get_string(str(e["key"]))
			return l
		"button":
			var b: Button = OptionButton.new() if str(e["id"]).begins_with("dropdown_") else Button.new()
			b.theme_type_variation = StringName(str(e["theme_type"]))
			b.alignment = _align(str(e.get("align", "center")))
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			if e.has("key"):
				b.text = DataRegistry.get_string(str(e["key"]))
			_focus_as_hover(b)
			return b
		"toggle":
			var tb := TextureButton.new()
			var states: Dictionary = e["states"] as Dictionary
			tb.toggle_mode = true
			tb.texture_normal = load(str(states["off"])) as Texture2D
			tb.texture_pressed = load(str(states["on"])) as Texture2D
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_SCALE
			tb.focus_mode = Control.FOCUS_NONE
			return tb
	return null


static func text_align(a: String) -> HorizontalAlignment:
	return _align(a)


static func _align(a: String) -> HorizontalAlignment:
	match a:
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
	return HORIZONTAL_ALIGNMENT_LEFT


## 设计约定（TEXT_BINDINGS）：焦点复用 hover 贴图——有焦点时 normal 样式临时换成 hover，失焦恢复（主题 focus 样式为空，不叠加）
## 挂了按钮动效（ButtonMotion）的按钮由动效层按焦点显示 hover，这里不再改样式。
static func _focus_as_hover(b: Button) -> void:
	b.focus_entered.connect(func() -> void:
		if not b.has_meta(ButtonMotion.META):
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover")))
	b.focus_exited.connect(func() -> void:
		if not b.has_meta(ButtonMotion.META):
			b.remove_theme_stylebox_override("normal"))


## 按布局摆放全部节点（视口尺寸变化时再调用）；text_style 用 text_rect 定位文字
static func relayout(screen: String, nodes: Dictionary, viewport_size: Vector2) -> void:
	for id: String in nodes.keys():
		var c: Control = nodes[id] as Control
		var e: Dictionary = layout_element(screen, id)
		var r: Rect2 = layout_text_rect(screen, id, viewport_size) if str(e["kind"]) == "text_style" else layout_rect(screen, id, viewport_size)
		c.position = r.position
		c.size = r.size


## 透明占位贴图（隐藏引擎自带的滑条把手 / 下拉箭头，由布局里的切片代替绘制）
static func transparent_texture(size: Vector2i) -> ImageTexture:
	var img := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)


# ---- 第三阶段 P8（10 §1.5）：UI 动效 ----
## 动效参数在 data/ui_motion.json（时长、曲线、幅度都是数据）。motion_enabled 是代码级总闸（本阶段不做设置项）：
## 关闭时不挂任何动效节点、不创建 Tween，界面停在静止态（= 设计图，截图 --no-motion 用）。
const UI_MOTION_PATH: String = "res://data/ui_motion.json"
const MOTION_TRANS: Dictionary = {
	"linear": Tween.TRANS_LINEAR, "sine": Tween.TRANS_SINE, "quad": Tween.TRANS_QUAD, "cubic": Tween.TRANS_CUBIC,
	"quart": Tween.TRANS_QUART, "quint": Tween.TRANS_QUINT, "expo": Tween.TRANS_EXPO, "circ": Tween.TRANS_CIRC,
	"back": Tween.TRANS_BACK, "elastic": Tween.TRANS_ELASTIC, "bounce": Tween.TRANS_BOUNCE, "spring": Tween.TRANS_SPRING,
}
const MOTION_EASE: Dictionary = { "in": Tween.EASE_IN, "out": Tween.EASE_OUT, "in_out": Tween.EASE_IN_OUT, "out_in": Tween.EASE_OUT_IN }

static var motion_enabled: bool = true
static var _motion: Dictionary = {}


## ui_motion.json 的一档（"button" / "button_menu" 等，缓存）；"extends" 指向的档作底、本档覆盖（浅合并）；缺失返回 {}
static func motion_params(kind: String) -> Dictionary:
	if _motion.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UI_MOTION_PATH)) if FileAccess.file_exists(UI_MOTION_PATH) else null
		_motion = parsed as Dictionary if parsed is Dictionary else {}
	var own: Dictionary = _motion.get(kind, {}) as Dictionary
	if not own.has("extends"):
		return own
	var merged: Dictionary = motion_params(str(own["extends"])).duplicate()
	merged.merge(own, true)
	merged.erase("extends")
	return merged


static func motion_trans(spec: Dictionary) -> Tween.TransitionType:
	return MOTION_TRANS.get(str(spec.get("trans", "linear")), Tween.TRANS_LINEAR) as Tween.TransitionType


static func motion_ease(spec: Dictionary) -> Tween.EaseType:
	return MOTION_EASE.get(str(spec.get("ease", "in_out")), Tween.EASE_IN_OUT) as Tween.EaseType


## 给按钮挂按钮动效（总闸关闭时不挂，返回 null；已挂过则返回已有的）。profile = ui_motion.json 的档名。
## 须在按钮进入场景树后调用；以调用时（未聚焦）的样式为原样式，之后外部改样式由 ButtonMotion 自动重新接管。
static func attach_button_motion(b: Button, profile: String = "button") -> ButtonMotion:
	if not motion_enabled:
		return null
	return ButtonMotion.attach(b, motion_params(profile))


## P8 第 4 条（通用化）：SceneRouter 启动时调用，之后任何进入场景树的 Button 都在本帧末自动挂上通用档动效，
## 各界面不需要逐个调用（界面先以别的档调用 attach_button_motion 的，以先挂的为准）。
static func install_button_motion_hook(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(n: Node) -> void:
	if not motion_enabled or not n is Button:
		return
	_attach_deferred.call_deferred(n.get_instance_id())      # 帧末再挂：创建者先设好样式；按 id 取回，按钮可能已被释放


static func _attach_deferred(id: int) -> void:
	var b: Button = instance_from_id(id) as Button
	if b != null and b.is_inside_tree() and wants_button_motion(b):
		attach_button_motion(b)


## 哪些按钮挂动效：普通 Button / OptionButton；不挂：flat 按钮（本来就不画底板）、复选框与开关（CheckBox / CheckButton）、
## 菜单与取色按钮、带 meta "no_motion" 的按钮
static func wants_button_motion(b: Button) -> bool:
	if b.flat or b.has_meta(&"no_motion") or b.has_meta(ButtonMotion.META):
		return false
	return not (b is CheckBox or b is CheckButton or b is MenuButton or b is ColorPickerButton)


# ---- 第三阶段 P6（12）：按批准整图拼接的界面 ----
const TEXT_PROXY_META: StringName = &"text_proxy"   ## 按钮文字改由子 Label 绘制（遮罩 + 滚动）时，按钮上的 meta = 该 Label
const TIMER_FORMAT: String = "%04.1f"               ## 局内计时显示（批准整图：00.0）


## 把布局给出的屏幕矩形（视口坐标）摆到 c 上：换成父节点内坐标；c 的尺寸 = 矩形（Label 需 clip_text 或被 ScrollText 包裹，否则最小尺寸会撑大）
static func place(c: Control, r: Rect2) -> void:
	var parent: Control = c.get_parent() as Control
	var origin: Vector2 = parent.get_global_rect().position if parent != null else Vector2.ZERO
	c.position = r.position - origin
	c.size = r.size


## 按钮文字可能超出框体时（如「提示 ○○○○」）：文字改由按钮内部的 Label 绘制，包进 ScrollText 遮罩在按钮文字区内滚动。
## button.text 仍是唯一来源（ScrollText 每帧同步），按钮自身的文字设为透明；按钮动效的文字颜色改写到该 Label（ButtonMotion 读 meta）。
static func button_scroll_text(b: Button, mode: int) -> ScrollText:
	var l := Label.new()
	l.name = "TextProxy"
	l.add_theme_font_override("font", b.get_theme_font("font"))
	l.add_theme_font_size_override("font_size", b.get_theme_font_size("font_size"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := ScrollText.new()
	st.name = ScrollText.NODE_PREFIX + "TextProxy"
	st.mode = mode
	st.params = motion_params("scroll_text")
	st.source = b
	st.source_colors = { "normal": b.get_theme_color("font_color"), "disabled": b.get_theme_color("font_disabled_color") }
	st.label = l
	st.content = l
	st.add_child(l)
	b.add_child(st, false, Node.INTERNAL_MODE_BACK)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0.0, 0.0, 0.0, 0.0))
	b.set_meta(TEXT_PROXY_META, l)
	return st
