class_name StoryPlayer
extends Control
## 剧情播放器（07 §10.2，由 01 §9 dialogue_overlay 升级）：播放 data/stories/<story_id>.json 的场景列表
## （说话人、立绘、背景、文本逐字显示、点击继续），可在剧情后接一张机制提示卡。
## 触发约定【用户已定】：每关开始 <level_id>_intro、胜利 <level_id>_win、失败 <level_id>_lose；章节节点 story_on_unlock。
## 配置不存在 = 不触发：文件缺失或 scenes 为空时直接返回 false，不弹任何界面、不告警（只有 --verbose 下打印一行）。
## 立绘：场景 illustration 指定（assets/sprites/illustrations/<名>.png），为空则不显示；文件尚未生成时显示占位色块。

signal finished()

const CHARS_PER_SECOND: float = 40.0
const ILLUSTRATION_DIR: String = "res://assets/sprites/illustrations/"
const WITCH: String = "witch"

var story_dir: String = ""                       ## 空 = 使用 DataRegistry.story_dir
var current_story: String = ""                   ## 正在播放的 story_id（无则 ""）
var _lines: Array = []
var _mechanic_hint: String = ""
var _index: int = -1
var _showing_hint: bool = false
var _backdrop: TextureRect
var _portrait_rect: ColorRect
var _portrait_tex: TextureRect
var _speaker: Label
var _text: Label
var _continue: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var dim := ColorRect.new()
	dim.color = Color(Palette.BG_DEEP, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
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
	visible = false


## 是否存在可播放的剧情（文件存在且 scenes 非空）
func has_story(story_id: String) -> bool:
	return not DataRegistry.load_story(story_id, _dir()).is_empty()


func _dir() -> String:
	return story_dir if story_dir != "" else DataRegistry.story_dir


## 播放剧情；mechanic_hint 非空时在剧情结束后接一张机制提示卡。剧情不存在 → 不显示、返回 false（07 §10.2）
func play_story(story_id: String, mechanic_hint: String = "") -> bool:
	var story: Dictionary = DataRegistry.load_story(story_id, _dir())
	if story.is_empty():
		print_verbose("[StoryPlayer] no story, skipped: %s" % story_id)
		return false
	current_story = story_id
	_lines = story["scenes"] as Array
	_mechanic_hint = mechanic_hint
	_index = -1
	_showing_hint = false
	visible = true
	_next()
	return true


## 是否正在播放
func is_playing() -> bool:
	return visible


func _process(delta: float) -> void:
	if visible and _text.visible_ratio < 1.0:
		var total: int = maxi(_text.get_total_character_count(), 1)
		_text.visible_ratio = minf(1.0, _text.visible_ratio + delta * CHARS_PER_SECOND / float(total))
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
		_show_portrait(str(line.get("illustration", "")))
		_show_backdrop(str(line.get("backdrop", "")))
	elif not _showing_hint and _mechanic_hint != "":
		_showing_hint = true
		_speaker.text = DataRegistry.get_string("ui.mechanics")
		_show_text(_mechanic_hint)
		_show_portrait("")
	else:
		visible = false
		current_story = ""
		finished.emit()


func _show_text(t: String) -> void:
	_text.text = t
	_text.visible_ratio = 0.0


## illustration 为空时不显示立绘
func _show_portrait(who: String) -> void:
	var path: String = ILLUSTRATION_DIR + who + ".png"
	var has_tex: bool = who != "" and ResourceLoader.exists(path)
	_portrait_tex.texture = load(path) as Texture2D if has_tex else null
	_portrait_rect.visible = not has_tex and who != ""
	_portrait_rect.color = Color(Palette.DIVINE_VIOLET if who == WITCH else Palette.BONE_DIM, 0.25)


## backdrop 为空时保持上一张（首句为空则不显示）
func _show_backdrop(path: String) -> void:
	if path == "":
		if _index == 0:
			_backdrop.texture = null
		return
	_backdrop.texture = Art.texture(path)
