extends Control
## 剧情播放器（D-25，策划案 v2 3.7）
##
## 详细设计：[docs/design/10-主界面与HUD.md](../../docs/design/10-主界面与HUD.md)
##
## 屏幕**左侧**放说话角色的立绘，**下方**是角色名称与文本框 —— 与策划案 3.7 的描述一致。
##
## 【数据驱动】剧本是 `res://data/story/*.json`，结构见 `data/story/chapter_01.json`：
## `segments[] = { speaker, portrait, text }`。换剧本只改数据，不改代码（D-25 的要求）。
##
## 【占位立绘】D-09 规定本阶段美术全用纯色占位，所以 `portrait` 目前被当作"色块的名字"：
## 同一个名字永远是同一种颜色（按名字哈希取色相），不同角色一眼能区分。
## 若 `portrait` 写成图片路径且文件存在，就真的显示那张图 —— **替换接口已经留好**。
##
## 【只管呈现】不算分、不影响关卡状态，关掉就回到原界面（与 help_panel 同一套习惯：
## `load_story()` → `open_player()` → `advance()/skip_all()` → `closed`）。

signal closed

const DEFAULT_STORY := "res://data/story/chapter_01.json"

var _dim: ColorRect
var _root: PanelContainer
var _title: Label
var _portrait: ColorRect
var _portrait_img: TextureRect
var _portrait_name: Label
var _speaker_label: Label
var _text_label: RichTextLabel
var _progress: Label
var _skip_btn: Button
var _next_btn: Button
var _hint: Label

var _segments: Array = []
var _index := -1
var _story_title := ""
var _story_id := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_to_viewport()
	_build_ui()
	visible = false


func _fit_to_viewport() -> void:
	# 与 help_panel 同一套做法：不进容器，自己铺满视口
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect()
		position = Vector2.ZERO
		size = r.size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_fit_to_viewport()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# 压暗背景（点它也能推进，剧情里"点哪都能继续"是通用习惯）
	_dim = ColorRect.new()
	_dim.name = "StoryDim"
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_root = PanelContainer.new()
	_root.name = "StoryPanel"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 120.0
	_root.offset_top = 90.0
	_root.offset_right = -120.0
	_root.offset_bottom = -90.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.98)
	sb.border_color = Color(0.35, 0.38, 0.48)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_root.add_child(outer)

	var title := Label.new()
	title.name = "StoryTitle"
	title.text = "剧情"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	outer.add_child(title)
	_title = title

	var mid := HBoxContainer.new()
	mid.name = "StoryMid"
	mid.add_theme_constant_override("separation", 18)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(mid)

	# 左侧：立绘（占位色块 + 名字；有真图就显示真图）
	var pic_box := Control.new()
	pic_box.name = "StoryPortraitBox"
	pic_box.custom_minimum_size = Vector2(320, 0)
	pic_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(pic_box)

	_portrait = ColorRect.new()
	_portrait.name = "StoryPortrait"
	_portrait.color = Color(0.30, 0.34, 0.45)
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic_box.add_child(_portrait)

	_portrait_img = TextureRect.new()
	_portrait_img.name = "StoryPortraitImage"
	_portrait_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_img.visible = false
	pic_box.add_child(_portrait_img)

	_portrait_name = Label.new()
	_portrait_name.name = "StoryPortraitName"
	_portrait_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_name.add_theme_font_size_override("font_size", 18)
	_portrait_name.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	pic_box.add_child(_portrait_name)

	# 右侧：说话人 + 文本（策划案：下方是角色名称与文本框）
	var col := VBoxContainer.new()
	col.name = "StoryTextCol"
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(col)

	_speaker_label = Label.new()
	_speaker_label.name = "StorySpeaker"
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.add_theme_color_override("font_color", Color(0.80, 0.86, 1.0))
	col.add_child(_speaker_label)

	var box := PanelContainer.new()
	box.name = "StoryTextBox"
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.11, 0.12, 0.16, 1.0)
	bs.border_color = Color(0.28, 0.31, 0.40)
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(6)
	bs.set_content_margin_all(16)
	box.add_theme_stylebox_override("panel", bs)
	col.add_child(box)

	_text_label = RichTextLabel.new()
	_text_label.name = "StoryText"
	_text_label.bbcode_enabled = false
	_text_label.fit_content = false
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	box.add_child(_text_label)

	# 底部：进度 + 跳过 + 继续
	var bottom := HBoxContainer.new()
	bottom.name = "StoryBottom"
	bottom.add_theme_constant_override("separation", 12)
	outer.add_child(bottom)

	_progress = Label.new()
	_progress.name = "StoryProgress"
	_progress.add_theme_font_size_override("font_size", 18)
	_progress.add_theme_color_override("font_color", Color(0.65, 0.68, 0.78))
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_progress)

	_hint = Label.new()
	_hint.name = "StoryHint"
	_hint.text = "空格 / 点击 继续 · ESC 关闭"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.68))
	bottom.add_child(_hint)

	_skip_btn = Button.new()
	_skip_btn.name = "StorySkipButton"
	_skip_btn.text = "跳过"
	_skip_btn.custom_minimum_size = Vector2(120, 38)
	_skip_btn.pressed.connect(skip_all)
	bottom.add_child(_skip_btn)

	_next_btn = Button.new()
	_next_btn.name = "StoryNextButton"
	_next_btn.text = "继续"
	_next_btn.custom_minimum_size = Vector2(120, 38)
	_next_btn.pressed.connect(advance)
	bottom.add_child(_next_btn)


# ---------------------------------------------------------------------------
# 数据
# ---------------------------------------------------------------------------

## 读剧本。返回错误列表（空数组＝成功）。**出错时不清空已有内容**，由调用方决定怎么办。
func load_story(path: String) -> Array:
	var errs: Array = []
	var segs: Array = []
	var title := ""
	var sid := ""
	if not FileAccess.file_exists(path):
		errs.append("剧本文件不存在：%s" % path)
		return errs
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errs.append("打不开剧本文件：%s" % path)
		return errs
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		errs.append("%s: 顶层应为对象" % path)
		return errs
	var d: Dictionary = parsed
	sid = str(d.get("id", ""))
	title = str(d.get("title", sid))
	var raw = d.get("segments")
	if not (raw is Array) or (raw as Array).is_empty():
		errs.append("%s: segments 应为非空数组" % path)
		return errs
	for i in (raw as Array).size():
		var seg = (raw as Array)[i]
		if not (seg is Dictionary):
			errs.append("%s: segments[%d] 期望对象" % [path, i])
			continue
		if str((seg as Dictionary).get("text", "")).is_empty():
			errs.append("%s: segments[%d].text 不能为空" % [path, i])
		segs.append(seg)
	if not errs.is_empty():
		return errs
	_segments = segs
	_story_title = title
	_story_id = sid
	return errs


func segment_count() -> int:
	return _segments.size()


func current_index() -> int:
	return _index


func current_text() -> String:
	if _index < 0 or _index >= _segments.size():
		return ""
	return str((_segments[_index] as Dictionary).get("text", ""))


func current_speaker() -> String:
	if _index < 0 or _index >= _segments.size():
		return ""
	return str((_segments[_index] as Dictionary).get("speaker", ""))


func story_title() -> String:
	return _story_title


# ---------------------------------------------------------------------------
# 交互
# ---------------------------------------------------------------------------

## 打开播放器。没有段落时不打开并返回 false（由调用方给出提示）。
func open_player() -> bool:
	if _segments.is_empty():
		return false
	visible = true
	_index = 0
	_render()
	if _next_btn != null:
		_next_btn.grab_focus()
	return true


## 推进一段；已是最后一段则关闭
func advance() -> void:
	if not visible:
		return
	_index += 1
	if _index >= _segments.size():
		close_player()
		return
	_render()


## 跳过全部：直接关闭（剧情是弱引导，不该拦住玩家）
func skip_all() -> void:
	if visible:
		close_player()


func close_player() -> void:
	visible = false
	_index = -1
	closed.emit()


func is_open() -> bool:
	return visible


## 面板矩形（像素断言用）
func panel_rect() -> Rect2:
	if _root == null:
		return Rect2()
	return Rect2(_root.global_position, _root.size)


func _render() -> void:
	if _index < 0 or _index >= _segments.size():
		return
	var seg: Dictionary = _segments[_index]
	var speaker := str(seg.get("speaker", ""))
	_speaker_label.text = speaker
	_text_label.text = str(seg.get("text", ""))
	_portrait_name.text = speaker
	_progress.text = "%d / %d" % [_index + 1, _segments.size()]
	if _title != null:
		_title.text = "剧情 · %s" % _story_title if not _story_title.is_empty() else "剧情"

	# 占位立绘：同名同色；若 portrait 是存在的图片路径就直接显示图片
	var pic := str(seg.get("portrait", ""))
	_portrait_img.visible = false
	_portrait.color = _color_for(pic if not pic.is_empty() else speaker)
	if pic.begins_with("res://") or pic.begins_with("user://"):
		var tex := load(pic)
		if tex is Texture2D:
			_portrait_img.texture = tex
			_portrait_img.visible = true


## 名字 → 稳定的占位颜色（同一角色每次都是同一色）
func _color_for(key: String) -> Color:
	var h := 0
	for i in key.length():
		h = (h * 31 + key.unicode_at(i)) % 360
	return Color.from_hsv(float(h) / 360.0, 0.32, 0.52)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_player()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
