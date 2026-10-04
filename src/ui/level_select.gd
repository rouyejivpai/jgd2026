extends Control
## 选关界面。详细设计：[docs/design/10-主界面与HUD.md](../../docs/design/10-主界面与HUD.md) 4.4
##
## 读 `data/levels/manifest.json` 决定顺序与内容（FR-LV-04：新增关卡只要
## 放文件 + 追加 id，无需改代码）。点一个关卡 → 进玩法场景。
##
## 【布局约定 —— 本文件是后面所有 UI 的样板】
## 曾用「绝对像素坐标」写过一版（`position = Vector2(80, 960)` 之类），
## 结果窗口一小于 1920×1080、或宽高比不是 16:9，控件就跑到画面外、文字被裁
## （用户实测反馈）。根因是把控件钉死在「1920×1080 左上角」这个假设上。
##
## 现在的三条硬规则：
##  1. **不用 `position = Vector2(...)` 定位主体控件** —— 一律用锚点 + 容器
##  2. 可能变长的内容放进 `ScrollContainer`（条目多了也不会溢出）
##  3. 文本控件设 `autowrap_mode`，让它随容器伸缩而不是被裁
##
## 这样任何窗口尺寸与宽高比都不会溢出。

const LevelLoaderScript := preload("res://src/core/level/level_loader.gd")
const DataLoaderScript := preload("res://src/core/data/data_loader.gd")

const PLAY_SCENE := "res://src/play/play_scene.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _list: VBoxContainer
var _hint: Label
var _back: Button
## 关卡条目：{id, name, order, file}
var entries: Array = []


func _ready() -> void:
	_build_ui()
	_reload_entries()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 外边距容器：把内容从屏幕边缘推开，并随窗口伸缩
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	var title := Label.new()
	title.name = "Title"
	title.text = "选择关卡"
	title.add_theme_font_size_override("font_size", 44)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	# 关卡列表：放进滚动容器，关卡多了也不会溢出画面
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)

	_back = Button.new()
	_back.name = "BackButton"
	_back.text = "返回主菜单"
	_back.custom_minimum_size = Vector2(200, 48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(_on_back)
	col.add_child(_back)


## 读清单，生成关卡按钮（顺序即 manifest 顺序）
func _reload_entries() -> void:
	for c in _list.get_children():
		c.queue_free()
	entries.clear()

	var loader: RefCounted = LevelLoaderScript.new()
	var data: RefCounted = DataLoaderScript.new()
	var derrs: Array = data.call("load_all")
	var known: Array = data.call("unit_type_ids")

	var ids: Array = loader.call("list_level_ids")
	if ids.is_empty():
		_hint.text = "manifest.json 里没有关卡"
		return

	var problems: Array = []
	for id in ids:
		var res: Dictionary = loader.call("load_level", str(id), known)
		if not bool(res.get("ok", false)):
			problems.append("%s：%s" % [str(id), str(res.get("errors", []))])
			continue
		var lv = res["level"]
		entries.append({
			"id": str(id), "name": str(lv.name), "order": int(lv.order),
			"file": str(res.get("path", "")),
		})

	for e in entries:
		var d: Dictionary = e
		var b := Button.new()
		b.name = "Level_" + str(d["id"])
		b.text = "%s  (%s)" % [str(d["name"]), str(d["id"])]
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true                     # 名字再长也不会撑破按钮
		b.pressed.connect(_on_level_pressed.bind(str(d["id"])))
		_list.add_child(b)

	# 数据载入问题要显式说出来，不要静默少列几关
	if not derrs.is_empty():
		_hint.text = "数据载入错误：%s" % str(derrs)
	elif not problems.is_empty():
		_hint.text = "有 %d 关载入失败：%s" % [problems.size(), str(problems)]
	else:
		_hint.text = "共 %d 关（来自 manifest.json，新增关卡无需改代码）" % entries.size()

	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()
	else:
		_back.grab_focus()


func level_ids_in_order() -> Array:
	var out: Array = []
	for e in entries:
		out.append(str((e as Dictionary)["id"]))
	return out


func level_buttons() -> Array:
	var out: Array = []
	for c in _list.get_children():
		if c is Button:
			out.append(c)
	return out


func _on_back() -> void:
	if has_node("/root/SceneLoader"):
		get_node("/root/SceneLoader").call("goto", MENU_SCENE)


func _on_level_pressed(id: String) -> void:
	var packed: PackedScene = load(PLAY_SCENE)
	if packed == null:
		_hint.text = "找不到玩法场景：%s" % PLAY_SCENE
		return
	var ps = packed.instantiate()
	ps.call("load_level_id", id)
	var root := get_tree().root
	var old := get_tree().current_scene
	root.add_child(ps)
	get_tree().current_scene = ps
	if old != null and old != ps:
		old.queue_free()
