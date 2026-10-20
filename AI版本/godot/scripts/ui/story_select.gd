class_name StorySelect
extends Control
## 剧情选择浮层（2026-10-21 04.zip：J01 剧情卡 / J02 返回 / J03 叠层，参考 docs/reference/ui_04/design_story_select.png；
## 布局 data/ui_layout/story_select.json，由 assets/ui/story_select/manifest.json 生成）。
## 盖在所在界面之上：最底是下层画面的高斯模糊（screen_blur 着色器），其上 J03 压暗叠层（左侧纹饰），
## 卡片从布局 card 的位置起每 data.step 一张横排，可见区为 data.clip_left 到视口右缘；放不下时滚轮 / 拖动 / 左右键横向滚动。
## 右下 J02「返回」或 Esc：返回上一页，栈空则关闭。
## 一页 = { heading, entries }，entry = { title, short_title?, locked, ... }（其余字段调用方自用）；点未锁定的卡发 entry_chosen(entry)，
## 由调用方决定播剧情（先 suspend()，播完 resume()）还是 push() 下一页（主界面图鉴：关卡 → 开头 / 结尾）。
## 用处：选关「剧情回放」（该关开头 / 结尾两卡）、主界面「剧情」（剧情回顾图鉴）。

signal entry_chosen(entry: Dictionary)
signal closed()

const SCREEN: String = "story_select"
const BLUR_SHADER: Shader = preload("res://assets/shaders/screen_blur.gdshader")
const NODE_NAMES: Dictionary = { "overlay": "Overlay", "heading": "Heading", "btn_back": "BackButton" }
const Z_INDEX: int = 50
const DRAG_THRESHOLD: float = 6.0              ## 按下后移动 ≤ 6 px 视为点击
const RIGHT_MARGIN: float = 60.0               ## 滚到最右时最后一张卡与视口右缘的留白
const HOVER_MODULATE: Color = Color(1.25, 1.25, 1.25)
const LOCKED_MODULATE: Color = Color(0.5, 0.5, 0.5)
const SHORT_TITLE_FONT: int = 16               ## 带 short_title 的卡：完整标题要缩到此字号以下才放得下时改用短标题

var nodes: Dictionary = {}
var scroll: float = 0.0                        ## 横向滚动量（像素）
var _pages: Array[Dictionary] = []
var _cards: Array[Button] = []
var _blur: ColorRect
var _clip: Control
var _strip: Control
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _drag_moved: float = 0.0
var _press_scroll: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # 挡住下层界面的点击
	z_index = Z_INDEX                            # 选关里选中的节点 / 解锁动画抬过 z_index，浮层要压住它们
	_blur = ColorRect.new()
	_blur.name = "Blur"
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	_blur.material = mat
	add_child(_blur)
	nodes = UiKit.build_from_layout(self, SCREEN, NODE_NAMES)
	for id: String in ["card", "card_label"]:   # 只当模板：位置 / 主题变体从布局读，卡片按页现建
		(nodes[id] as Node).queue_free()
		nodes.erase(id)
	_clip = Control.new()
	_clip.name = "CardClip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_strip = Control.new()
	_strip.name = "CardStrip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_strip)
	var back: Button = nodes["btn_back"] as Button
	back.tooltip_text = back.text
	back.focus_mode = Control.FOCUS_NONE
	back.set_meta("sfx_press", "ui_back")
	back.pressed.connect(back_page)
	move_child(back, -1)
	resized.connect(_layout)
	visible = false


## 打开第一页（清空页栈）
func open(heading: String, entries: Array) -> void:
	_pages.clear()
	push(heading, entries)


## 推入一页并显示
func push(heading: String, entries: Array) -> void:
	_pages.append({ "heading": heading, "entries": entries.duplicate() })
	_show_page()


## 返回上一页；栈空则关闭
func back_page() -> void:
	if _pages.size() <= 1:
		close()
		return
	_pages.pop_back()
	_show_page()


func close() -> void:
	if not visible and _pages.is_empty():
		return
	_pages.clear()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## 播剧情时暂时隐藏（不清页栈、不发 closed）；resume() 原样回来
func suspend() -> void:
	visible = false


func resume() -> void:
	if _pages.is_empty():
		return
	visible = true
	_layout()
	UiKit.slide_in([_strip], _cards_rect(), [_blur, nodes["overlay"]])


func page_count() -> int:
	return _pages.size()


func cards() -> Array[Button]:
	return _cards


func current_entries() -> Array:
	return (_pages.back()["entries"] as Array) if not _pages.is_empty() else []


func _show_page() -> void:
	var page: Dictionary = _pages.back()
	(nodes["heading"] as Label).text = str(page["heading"])
	_build_cards(page["entries"] as Array)
	scroll = 0.0
	visible = true
	_layout()
	UiKit.slide_in([_strip], _cards_rect(), [_blur, nodes["overlay"]])


func _build_cards(entries: Array) -> void:
	for c: Button in _cards:
		c.queue_free()
	_cards.clear()
	var e_card: Dictionary = UiKit.layout_element(SCREEN, "card")
	var e_lab: Dictionary = UiKit.layout_element(SCREEN, "card_label")
	var card_r: Rect2 = UiKit.layout_rect(SCREEN, "card", Vector2.ZERO)
	var lab_r: Rect2 = UiKit.layout_text_rect(SCREEN, "card_label", Vector2.ZERO)
	var step: float = float((e_card.get("data", {}) as Dictionary).get("step", card_r.size.x))
	var min_font: int = int((e_lab.get("data", {}) as Dictionary).get("min_size", 13))
	var tex: Texture2D = load(str(e_card["file"])) as Texture2D
	var empty := StyleBoxEmpty.new()
	for i: int in entries.size():
		var entry: Dictionary = entries[i] as Dictionary
		var locked: bool = bool(entry.get("locked", false))
		var b := Button.new()
		b.name = "Card%d" % i
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, empty)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS        # 滚轮等未处理的事件交给浮层
		b.position = Vector2(step * i, 0.0)
		b.size = card_r.size
		b.disabled = locked
		b.modulate = LOCKED_MODULATE if locked else Color.WHITE
		_strip.add_child(b)                            # 先进树：量字宽要用主题字体
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(art)
		var lab := Label.new()
		lab.name = "Title"
		lab.theme_type_variation = StringName(str(e_lab["theme_type"]))
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.horizontal_alignment = UiKit.text_align(str(e_lab.get("align", "left")))
		lab.clip_text = true
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.position = lab_r.position - card_r.position
		lab.size = lab_r.size
		lab.text = DataRegistry.get_string("ui.locked") if locked else str(entry.get("title", ""))
		b.add_child(lab)
		if not locked and entry.has("short_title") and not _fits(lab, SHORT_TITLE_FONT):
			lab.text = str(entry["short_title"])      # 「01 落子」放不下（字号要缩到 16 以下）时只放关名
		_fit_label(lab, min_font)
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				UiKit.ease_to(b, "modulate", HOVER_MODULATE))
		b.mouse_exited.connect(func() -> void:
			if not b.disabled:
				UiKit.ease_to(b, "modulate", Color.WHITE))
		b.pressed.connect(_on_card_pressed.bind(i))
		_cards.append(b)


func _fits(lab: Label, font_size: int) -> bool:
	return lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= lab.size.x


## 字宽超出标签框时逐级缩字（最小 min_font）
func _fit_label(lab: Label, min_font: int) -> void:
	var font: Font = lab.get_theme_font("font")
	var fs: int = lab.get_theme_font_size("font_size")
	while fs > min_font and font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > lab.size.x:
		fs -= 1
	lab.add_theme_font_size_override("font_size", fs)


func _on_card_pressed(i: int) -> void:
	if _drag_moved > DRAG_THRESHOLD:
		return
	var entries: Array = current_entries()
	if i < entries.size():
		entry_chosen.emit(entries[i] as Dictionary)


# ---- 排版与滚动 ----
func _layout() -> void:
	UiKit.relayout(SCREEN, nodes, size)
	_blur.position = Vector2.ZERO
	_blur.size = size
	var card_r: Rect2 = UiKit.layout_rect(SCREEN, "card", size)
	var clip_left: float = float((UiKit.layout_element(SCREEN, "card").get("data", {}) as Dictionary).get("clip_left", 0.0))
	var design_x: float = float((UiKit.layout_element(SCREEN, "card")["rect"] as Array)[0])
	var clip_x: float = card_r.position.x - (design_x - clip_left)
	_clip.position = Vector2(clip_x, 0.0)
	_clip.size = Vector2(maxf(size.x - clip_x, 0.0), size.y)
	_strip.size = Vector2(_content_width(), card_r.size.y)
	_apply_scroll()


func _content_width() -> float:
	if _cards.is_empty():
		return 0.0
	var last: Button = _cards.back()
	return last.position.x + last.size.x


func max_scroll() -> float:
	var card_r: Rect2 = UiKit.layout_rect(SCREEN, "card", size)
	var origin: float = card_r.position.x - _clip.position.x
	return maxf(0.0, origin + _content_width() + RIGHT_MARGIN - _clip.size.x)


func scroll_to(v: float) -> void:
	scroll = clampf(v, 0.0, max_scroll())
	_apply_scroll()


func _apply_scroll() -> void:
	var card_r: Rect2 = UiKit.layout_rect(SCREEN, "card", size)
	_strip.position = Vector2(card_r.position.x - _clip.position.x - scroll, card_r.position.y)


func _cards_rect() -> Rect2:
	var r: Rect2 = UiKit.layout_rect(SCREEN, "card", size)
	return Rect2(r.position, Vector2(minf(_content_width(), _clip.size.x), r.size.y))


func _step() -> float:
	return float((UiKit.layout_element(SCREEN, "card").get("data", {}) as Dictionary).get("step", 347.0))


## 滚轮 / 拖动 / 左右键 / Esc（浮层铺满屏幕，打开时它先于下层界面处理输入）
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		UiKit.close_sfx()
		back_page()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		scroll_to(scroll + _step() * (1.0 if event.is_action_pressed("ui_right") else -1.0))
		get_viewport().set_input_as_handled()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if mb.pressed:
				scroll_to(scroll + _step() * 0.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			if mb.pressed:
				scroll_to(scroll - _step() * 0.5)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_press_pos = mb.position
				_press_scroll = scroll
				_drag_moved = 0.0
			else:
				_pressing = false        # 松开后的 pressed 信号仍读得到本次的 _drag_moved
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _pressing:
		_drag_moved = maxf(_drag_moved, absf(mm.position.x - _press_pos.x))
		if _drag_moved > DRAG_THRESHOLD and max_scroll() > 0.0:
			scroll_to(_press_scroll - (mm.position.x - _press_pos.x))
