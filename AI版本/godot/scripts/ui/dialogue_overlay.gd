class_name StoryPlayer
extends Control
## 剧情播放器（07 §10.2，由 01 §9 dialogue_overlay 升级）：播放 data/stories/<story_id>.json 的场景列表
## （说话人、立绘、背景、文本逐字显示、点击继续）。2026-10-20：剧情后不再接机制提示卡（本关提示仍在「机制说明」弹窗里）。
## 触发约定【用户已定】：每关开始 <level_id>_intro、胜利 <level_id>_win、失败 <level_id>_lose；章节节点 story_on_unlock。
## 配置不存在 = 不触发：文件缺失或 scenes 为空时直接返回 false，不弹任何界面、不告警（只有 --verbose 下打印一行）。
## 立绘：场景 illustration 指定（assets/sprites/illustrations/<名>.png），为空则不显示；文件尚未生成时显示占位色块。
## 2026-10-20 旁白立绘：无人说话（speaker 为 narrator / system / 空）但在描写某个角色时，该句也可写 illustration，立绘压暗显示；
## 场景 dim 可显式覆盖（true 压暗 / false 不压暗）。
## 2026-10-19 哥特换皮：版式取 data/ui_layout/dialogue.json（assets/ui/dialogue/manifest.json → apply_ui_manifest.py）：
## 底部对话框切图 + 名牌（说话人）+ 正文 + 右下继续提示；立绘画在对话框之下、底对齐。布局缺失时退回旧的程序化版式。
## 2026-10-20 CG：场景 cg 指定（assets/cg/<名>.png 或 .jpg），铺满全屏、压在压暗层之上、对话框之下，期间不显示立绘；
## 连续几句写同一个 cg 即停留，下一句不写 cg 则淡出。写了 cg 而 text 为空 = 纯 CG 句：隐藏对话框，只看图，点击继续。
## 2026-10-21 跳过：右上角「Skip >>」（衬一块四边羽化的黑色矩形），点击弹出确认窗（复用 ConfirmDialog 素材），「确定」才结束整段剧情（同播完，发出 finished）。

signal finished()

const CHARS_PER_SECOND: float = 40.0
const ILLUSTRATION_DIR: String = "res://assets/sprites/illustrations/"
const CG_DIR: String = "res://assets/cg/"
const CG_FADE: float = 0.5
const WITCH: String = "witch"
const SKIN: String = "dialogue"
const SILENT_SPEAKERS: Array[String] = ["narrator", "system", ""]      ## 无人说话：此时的立绘是被描写的对象，压暗
const DIM_MODULATE: Color = Color(0.42, 0.42, 0.48)
## 2026-10-21 个别立绘额外放大（默认 1）：以画布内 PORTRAIT_ZOOM_PIVOT（比例坐标）为中心缩放。
## 敲钟魔女是坐姿横构图，画布里只占一条，脚落在画布 60% 高处（正好没入对话框），以脚为中心放大，脚仍压在对话框里
const PORTRAIT_ZOOM: Dictionary = {"bell_witch": 1.2}
const PORTRAIT_ZOOM_PIVOT: Vector2 = Vector2(0.5, 0.6)
const BLIP_EVERY: int = 2                        ## 逐字音：每显示 N 个字响一声 text_blip
const SKIP_MARGIN: Vector2 = Vector2(40.0, 32.0)  ## 跳过按钮距视口右上角
const SKIP_FONT_SIZE: int = 28
const SKIP_BACKING_PAD: Vector2 = Vector2(56.0, 18.0)   ## 黑色衬底比按钮外扩（含羽化带）
const SKIP_BACKING_HEIGHT: float = 0.5                  ## 衬底高度 = （按钮高 + 上下外扩）× 此值，垂直居中于按钮
const SKIP_BACKING_SHADER: String = """
shader_type canvas_item;
uniform vec2 feather = vec2(0.32, 0.42);   // 四边羽化带占宽 / 高的比例
uniform float strength = 0.7;
void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV) / (feather * 0.5);
	float m = smoothstep(0.0, 1.0, clamp(d.x, 0.0, 1.0)) * smoothstep(0.0, 1.0, clamp(d.y, 0.0, 1.0));
	COLOR = vec4(0.0, 0.0, 0.0, strength * m);
}
"""

var story_dir: String = ""                       ## 空 = 使用 DataRegistry.story_dir
var current_story: String = ""                   ## 正在播放的 story_id（无则 ""）
var _lines: Array = []
var _index: int = -1
var _base: ColorRect = null                     ## 底层背景（set_base_material 设置后才有），压在 backdrop 之下
var _backdrop: TextureRect
var _cg: TextureRect
var _cg_name: String = ""
var _cg_tween: Tween
var _box_nodes: Array = []                       ## 对话框各部件；纯 CG 句（无 text）时整体隐藏
var _portrait_rect: ColorRect
var _portrait_tex: TextureRect
var _speaker: Label
var _text: Label
var _continue: Control                   ## 继续提示（旧版为「继续 ▸」文字，哥特版为切图 F01）
var _blip_chars: int = 0                 ## 上次响逐字音时已显示的字数
var _skip: Button                        ## 右上角「Skip >>」
var _skip_confirm: ConfirmDialog         ## 「确定要结束剧情吗」确认窗


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)      # 连偏移一起铺满：选关里由代码实例化时尺寸为 0，只设锚点会一直是 0 × 0、收不到点击（卡在第一句）
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	if not UiKit.ui_layout(SKIN).is_empty():
		_build_skinned()
		visible = false
		return
	var dim := ColorRect.new()
	dim.color = Color(Palette.BG_DEEP, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_add_cg_layer(true)
	_portrait_rect = ColorRect.new()
	_portrait_rect.position = Vector2(120.0, 180.0)
	_portrait_rect.size = Vector2(420.0, 640.0)
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_rect)
	_portrait_tex = TextureRect.new()
	_portrait_tex.position = _portrait_rect.position
	_portrait_tex.size = _portrait_rect.size
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_tex)
	var box := PanelContainer.new()
	box.position = Vector2(620.0, 560.0)
	box.size = Vector2(1180.0, 300.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	box.add_child(col)
	_speaker = UiKit.label("", "TitleLabel")
	_speaker.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	col.add_child(_speaker)
	_text = UiKit.label("", "", true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 24)
	col.add_child(_text)
	_continue = UiKit.label(DataRegistry.get_string("ui.continue") + " ▸", "SmallLabel")
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_continue)
	_box_nodes = [box]
	_add_skip_button()
	_skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_skip.position += Vector2(-SKIP_MARGIN.x, SKIP_MARGIN.y)
	visible = false


## 按布局建出：压暗层、立绘、对话框、继续提示、说话人、正文（位置随视口经 UiKit.layout_rect 换算）
func _build_skinned() -> void:
	theme = UiKit.ui_theme(SKIN)
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1      # 剧情层压在所在界面的一切之上（选关里选中节点 z_index = 1，否则会画到剧情上面）
	var nodes: Dictionary = {}
	for id: String in ["dim", "box", "next", "speaker", "text"]:
		var c: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		c.name = "Skin_" + id
		nodes[id] = c
	add_child(nodes["dim"] as Control)
	_add_cg_layer(false)
	_portrait_rect = ColorRect.new()
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_rect)
	_portrait_tex = TextureRect.new()
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_tex)
	for id: String in ["box", "next", "speaker", "text"]:
		add_child(nodes[id] as Control)
		_box_nodes.append(nodes[id])
	_speaker = nodes["speaker"] as Label
	_speaker.clip_text = true
	_text = nodes["text"] as Label
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.add_theme_constant_override("line_spacing", int((UiKit.layout_element(SKIN, "text").get("data", {}) as Dictionary).get("line_spacing", 0)))
	_continue = nodes["next"] as Control
	nodes["portrait"] = _portrait_tex
	set_meta(&"skin", nodes)
	_add_skip_button()
	resized.connect(_layout_skinned)
	_layout_skinned()


func _layout_skinned() -> void:
	var nodes: Dictionary = get_meta(&"skin", {}) as Dictionary
	var vp: Vector2 = get_viewport_rect().size
	for id: String in nodes.keys():
		var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
		var r: Rect2 = UiKit.layout_text_rect(SKIN, id, vp) if text else UiKit.layout_rect(SKIN, id, vp)
		(nodes[id] as Control).position = r.position
		(nodes[id] as Control).size = r.size
	_cg.position = (nodes["dim"] as Control).position      # 本节点自身尺寸可能为 0，CG 跟压暗层一样铺满视口
	_cg.size = (nodes["dim"] as Control).size
	if _base != null:
		_base.position = _cg.position
		_base.size = _cg.size
	var art: Array = (UiKit.layout_element(SKIN, "portrait").get("data", {}) as Dictionary).get("art_size", []) as Array
	if art.size() == 2:                           # 立绘按原尺寸、下沿超出屏幕（布局 rect 只是可见部分）
		_portrait_tex.size = Vector2(float(art[0]), float(art[1]))
	_portrait_tex.pivot_offset = _portrait_tex.size * PORTRAIT_ZOOM_PIVOT
	_portrait_rect.position = _portrait_tex.position
	_portrait_rect.size = _portrait_tex.size
	_skip.size = _skip.get_combined_minimum_size()       # 同 CG 层：按压暗层（= 视口）右上角摆放
	var top_right: Vector2 = (nodes["dim"] as Control).position + Vector2((nodes["dim"] as Control).size.x, 0.0)
	_skip.position = top_right + Vector2(-SKIP_MARGIN.x - _skip.size.x, SKIP_MARGIN.y)


## 右上角「Skip >>」：无底板的文字按钮（骨白，悬停金色），点击结束整段剧情；自身拦截点击，不会同时触发「下一句」
func _add_skip_button() -> void:
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = DataRegistry.get_string("ui.story_skip")
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip.add_theme_font_size_override("font_size", SKIP_FONT_SIZE)
	var empty := StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_skip.add_theme_stylebox_override(st, empty)
	for c: String in ["font_color", "font_focus_color"]:
		_skip.add_theme_color_override(c, Color(Palette.BONE_DIM, 0.9))
	for c: String in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_skip.add_theme_color_override(c, Palette.ALCHEMY_GOLD)
	_skip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_skip.add_theme_constant_override("outline_size", 6)
	_skip.pressed.connect(skip)
	add_child(_skip)
	var backing := ColorRect.new()
	backing.name = "Backing"
	backing.show_behind_parent = true        # 画在按钮文字之下
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SKIP_BACKING_SHADER
	backing.material = mat
	_skip.add_child(backing)
	var fit: Callable = func() -> void:
		var full: Vector2 = _skip.size + SKIP_BACKING_PAD * 2.0
		backing.size = Vector2(full.x, full.y * SKIP_BACKING_HEIGHT)
		backing.position = Vector2(-SKIP_BACKING_PAD.x, (_skip.size.y - backing.size.y) * 0.5)
	_skip.resized.connect(fit)
	fit.call()
	_skip_confirm = ConfirmDialog.new()
	_skip_confirm.name = "SkipConfirm"
	_skip_confirm.top_level = true          # 按视口铺满：本节点自身尺寸可能为 0（哥特版靠 _layout_skinned 摆放各部件）
	_skip_confirm.z_as_relative = false     # top_level 不再继承剧情层的 z_index，单独压到最上（否则画在立绘之下）
	_skip_confirm.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	add_child(_skip_confirm)
	_skip_confirm.confirmed.connect(_on_skip_confirmed)


## 点击「Skip >>」：弹出确认窗；遮罩挡住下层点击，剧情暂停在当前句
func skip() -> void:
	if not visible or _skip_confirm.is_open():
		return
	_skip_confirm.open("ui.story_skip_confirm_title", "ui.story_skip_confirm_body", "ui.story_skip_confirm_ok", "ui.story_skip_confirm_cancel")


## 确认窗是否打开
func is_skip_confirm_open() -> bool:
	return _skip_confirm.is_open()


## 确认跳过：直接结束当前剧情（CG、对话框一并收起），与播完相同地发出 finished
func _on_skip_confirmed() -> void:
	if visible:
		close()


## 2026-10-20 底层背景：铺满视口、在剧情 backdrop / 压暗层之下的 ColorRect，用给定材质绘制
## （选关界面回放剧情时传入其最后方的品红底光，剧情背景不再透出地图）
func set_base_material(mat: Material) -> void:
	if _base == null:
		_base = ColorRect.new()
		_base.name = "Base"
		_base.color = Color.WHITE
		_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_base)
		move_child(_base, 0)
		if has_meta(&"skin"):          # 哥特版不用锚点，由 _layout_skinned 按压暗层定尺寸（同 CG 层）
			_layout_skinned()
		else:
			_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base.material = mat


## 是否存在可播放的剧情（文件存在且 scenes 非空）
func has_story(story_id: String) -> bool:
	return not DataRegistry.load_story(story_id, _dir()).is_empty()


func _dir() -> String:
	return story_dir if story_dir != "" else DataRegistry.story_dir


## 播放剧情。剧情不存在 → 不显示、返回 false（07 §10.2）
func play_story(story_id: String) -> bool:
	var story: Dictionary = DataRegistry.load_story(story_id, _dir())
	if story.is_empty():
		print_verbose("[StoryPlayer] no story, skipped: %s" % story_id)
		return false
	current_story = story_id
	_lines = story["scenes"] as Array
	_index = -1
	var was_open: bool = visible
	if not was_open:
		_set_cg_now("")
	visible = true
	_next()
	if not was_open:
		_slide_in()
	return true


## 2026-10-19：对话框（横向铺满、贴底）连同立绘、名牌、正文从下方滑入，压暗层 / 背景淡入
func _slide_in() -> void:
	var nodes: Dictionary = get_meta(&"skin", {}) as Dictionary
	if nodes.is_empty():
		UiKit.slide_in([self])
		return
	var group: Array = [_portrait_rect]
	for id: String in nodes.keys():
		if id != "dim":
			group.append(nodes[id])
	var fades: Array = [nodes["dim"], _backdrop]
	if _base != null:
		fades.append(_base)
	UiKit.slide_in(group, (nodes["box"] as Control).get_global_rect(), fades)


## 是否正在播放
func is_playing() -> bool:
	return visible


func _process(delta: float) -> void:
	if visible and _text.visible_ratio < 1.0 and not _skip_confirm.is_open():      # 确认窗打开期间逐字暂停
		var total: int = maxi(_text.get_total_character_count(), 1)
		_text.visible_ratio = minf(1.0, _text.visible_ratio + delta * CHARS_PER_SECOND / float(total))
		var shown: int = int(_text.visible_ratio * float(total))
		if shown - _blip_chars >= BLIP_EVERY and _text.visible_ratio < 1.0:
			_blip_chars = shown
			AudioManager.play_sfx("text_blip", "UI", -6.0, 1.0, 0.08, 30)
	_continue.modulate.a = 1.0 if _text.visible_ratio >= 1.0 else 0.3


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


## 点击：正在逐字时先显示全句，否则进入下一句
func advance() -> void:
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
		AudioManager.play_ui("ui_skip", -6.0)
	else:
		AudioManager.play_sfx("dialogue_advance", "UI")
		_next()


func _next() -> void:
	_index += 1
	if _index < _lines.size():
		var line: Dictionary = _lines[_index] as Dictionary
		var speaker: String = str(line.get("speaker", ""))
		_speaker.text = DataRegistry.get_string("speakers." + speaker)
		_show_text(str(line.get("text", "")))
		_show_cg(str(line.get("cg", "")))
		_set_box_visible(_cg_name == "" or _text.text != "")
		_show_portrait("" if _cg_name != "" else str(line.get("illustration", "")), bool(line.get("dim", speaker in SILENT_SPEAKERS)))
		_show_backdrop(str(line.get("backdrop", "")))
	else:
		close()


## 结束当前剧情（隐藏并发出 finished）；未在播放时不做事
func close() -> void:
	if not visible:
		return
	visible = false
	current_story = ""
	_skip_confirm.visible = false
	_set_cg_now("")
	_set_box_visible(true)
	finished.emit()


func _show_text(t: String) -> void:
	_text.text = t
	_text.visible_ratio = 0.0 if t != "" else 1.0       # 空句（纯 CG）一次点击即继续
	_blip_chars = 0


func _set_box_visible(v: bool) -> void:
	for c: Control in _box_nodes:
		c.visible = v


## 对话框是否显示（纯 CG 句时为 false）
func is_box_visible() -> bool:
	return _box_nodes.is_empty() or (_box_nodes[0] as Control).visible


## illustration 为空时不显示立绘；dimmed = 被描写而非说话的角色，压暗
func _show_portrait(who: String, dimmed: bool = false) -> void:
	var path: String = ILLUSTRATION_DIR + who + ".png"
	var has_tex: bool = who != "" and ResourceLoader.exists(path)
	_portrait_tex.texture = load(path) as Texture2D if has_tex else null
	_portrait_tex.pivot_offset = _portrait_tex.size * PORTRAIT_ZOOM_PIVOT
	_portrait_tex.scale = Vector2.ONE * float(PORTRAIT_ZOOM.get(who, 1.0))
	_portrait_rect.visible = not has_tex and who != ""
	_portrait_rect.color = Color(Palette.DIVINE_VIOLET if who == WITCH else Palette.BONE_DIM, 0.25)
	var tint: Color = DIM_MODULATE if dimmed else Color.WHITE
	_portrait_tex.self_modulate = tint
	_portrait_rect.self_modulate = tint


## 当前立绘是否压暗
func is_portrait_dimmed() -> bool:
	return _portrait_tex.self_modulate != Color.WHITE


## CG 层：铺满视口、保持比例裁边（同 backdrop），初始隐藏；哥特版不用锚点，由 _layout_skinned 按压暗层定尺寸
func _add_cg_layer(anchored: bool) -> void:
	_cg = TextureRect.new()
	_cg.name = "Cg"
	if anchored:
		_cg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cg.visible = false
	add_child(_cg)


## <名> → assets/cg/<名>.png，没有则 .jpg；都没有返回 ""
static func cg_path(cg_name: String) -> String:
	for ext: String in [".png", ".jpg"]:
		if ResourceLoader.exists(CG_DIR + cg_name + ext):
			return CG_DIR + cg_name + ext
	return ""


## 换 CG：同名保持；新 CG 淡入，空则淡出（关闭动效时立即切换）；文件缺失按无 CG 处理
func _show_cg(cg_name: String) -> void:
	if cg_name != "" and cg_path(cg_name) == "":
		push_warning("[StoryPlayer] CG 不存在: %s" % cg_name)
		cg_name = ""
	if cg_name == _cg_name:
		return
	if not UiKit.motion_enabled:
		_set_cg_now(cg_name)
		return
	if _cg_tween != null:
		_cg_tween.kill()
	_cg_name = cg_name
	_cg_tween = create_tween()
	if cg_name != "":
		_cg.texture = load(cg_path(cg_name)) as Texture2D
		if not _cg.visible:
			_cg.modulate.a = 0.0
		_cg.visible = true
		_cg_tween.tween_property(_cg, "modulate:a", 1.0, CG_FADE)
	else:
		_cg_tween.tween_property(_cg, "modulate:a", 0.0, CG_FADE)
		_cg_tween.tween_callback(_cg.hide)


func _set_cg_now(cg_name: String) -> void:
	if _cg_tween != null:
		_cg_tween.kill()
		_cg_tween = null
	_cg_name = cg_name
	_cg.texture = load(cg_path(cg_name)) as Texture2D if cg_name != "" else null
	_cg.visible = cg_name != ""
	_cg.modulate.a = 1.0


## 当前显示的 CG 名（无则 ""）
func current_cg() -> String:
	return _cg_name


## backdrop 为空时保持上一张（首句为空则不显示）
func _show_backdrop(path: String) -> void:
	if path == "":
		if _index == 0:
			_backdrop.texture = null
		return
	_backdrop.texture = Art.texture(path)
