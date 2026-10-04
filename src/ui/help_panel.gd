class_name HelpPanel
extends Control
## 机制说明面板：读 `res://data/help/机制说明.md`，按 `## ` 标题分节显示。
## 详细设计：[docs/design/10-主界面与HUD.md](../../docs/design/10-主界面与HUD.md) 2.1
##
## 【边界】Markdown 的解析在**表现层**，不进逻辑层（详设 10 的 2.3：
## `src/core/` 不关心 Markdown）。
##
## 【为什么自己写而不是引 Markdown 库】只用 `## ` 分节 + 表格/列表原样显示，
## 需求是"按二级标题分节切换"，不值得为一个 MVP 引第三方解析器。
## 表格与列表**原样保留**（等宽显示），不渲染成富文本 —— 宁可朴素，不要解析错。
##
## 发：`closed`

signal closed

const HELP_PATH := "res://data/help/机制说明.md"
## 左侧分节列表的宽度
const INDEX_WIDTH := 300

var _root: PanelContainer
var _index_box: VBoxContainer
var _content: RichTextLabel
var _title: Label
## [{title: String, body: String}]，第一节是开头的引言（没有标题）
var _sections: Array = []
var _current := -1


func _ready() -> void:
	_build_ui()
	visible = false
	_fit_to_viewport()
	load_document()


## 【必须自己撑满视口】挂 CanvasLayer 下的 Control 尺寸实测为 (0,0)，
## 否则内层容器全都会塌成内容尺寸、面板贴到左上角（本工程踩过三次）。
func _fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0 and size != vp:
		size = vp


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_to_viewport()
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_fit_to_viewport()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_root = PanelContainer.new()
	_root.name = "Panel"
	_root.custom_minimum_size = Vector2(1180, 760)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.15, 0.99)
	sb.border_color = Color(0.32, 0.36, 0.44)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_root.add_theme_stylebox_override("panel", sb)
	center.add_child(_root)

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 12)
	_root.add_child(col)

	# ---- 标题行 ----
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "机制说明"
	_title.add_theme_font_size_override("font_size", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "关闭（Esc）"
	close_btn.custom_minimum_size = Vector2(150, 44)
	close_btn.pressed.connect(close_panel)
	head.add_child(close_btn)

	var sep := HSeparator.new()
	col.add_child(sep)

	# ---- 左目录 + 右内容 ----
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	# 目录用 ScrollContainer 包住：节多了也不会把面板撑高
	var idx_scroll := ScrollContainer.new()
	idx_scroll.name = "IndexScroll"
	idx_scroll.custom_minimum_size = Vector2(INDEX_WIDTH, 0)
	idx_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	idx_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(idx_scroll)

	_index_box = VBoxContainer.new()
	_index_box.name = "Index"
	_index_box.add_theme_constant_override("separation", 4)
	_index_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idx_scroll.add_child(_index_box)

	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(body_scroll)

	_content = RichTextLabel.new()
	_content.name = "Body"
	# 【开 BBCode 但只认我们自己转出来的标签】文档里的 `**粗体**` 若不转换，
	# 会原样显示成星号（截图里一眼可见）。转换在 to_bbcode 里做，
	# 并且先把内容里的 `[` 转义掉，避免文档文字意外注入标签。
	_content.bbcode_enabled = true
	_content.fit_content = false
	_content.selection_enabled = true        # 允许玩家复制文字
	_content.add_theme_font_size_override("normal_font_size", 18)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(_content)


# ---------------------------------------------------------------------------
# 文档解析
# ---------------------------------------------------------------------------

## 读并解析文档。**解析是可以单独调的**（便于测试，不依赖面板可见）。
func load_document() -> Array:
	var text := ""
	if FileAccess.file_exists(HELP_PATH):
		var f := FileAccess.open(HELP_PATH, FileAccess.READ)
		if f != null:
			text = f.get_as_text()
	_sections = parse_markdown(text)
	_rebuild_index()
	if not _sections.is_empty():
		show_section(0)
	else:
		_content.text = "（没有找到机制说明文档：%s）" % HELP_PATH
	return _sections


## 按 `## ` 二级标题切分。**纯函数**，方便直接喂字符串测试。
##
## 首个标题之前的内容作为第 0 节（引言），标题为「总览」。
static func parse_markdown(text: String) -> Array:
	var out: Array = []
	var cur_title := "总览"
	var cur_lines: Array = []
	var started := false

	for raw in text.split("\n"):
		var line := str(raw)
		# 只认二级标题（# 一级标题当作文档标题，跳过）
		if line.begins_with("## ") and not line.begins_with("### "):
			if started or not cur_lines.is_empty():
				out.append({"title": cur_title, "body": "\n".join(cur_lines).strip_edges()})
			cur_title = line.substr(3).strip_edges()
			cur_lines = []
			started = true
		elif line.begins_with("# ") and not started:
			continue                     # 文档大标题不进目录
		else:
			cur_lines.append(line)
	if started or not cur_lines.is_empty():
		out.append({"title": cur_title, "body": "\n".join(cur_lines).strip_edges()})
	# 丢掉空节（标题下面什么都没有）
	var kept: Array = []
	for s in out:
		if not str((s as Dictionary).get("body", "")).is_empty():
			kept.append(s)
	return kept


## Markdown 的**最小内联转换**：`**粗体**` → `[b]`、`` `代码` `` → `[code]`。
##
## 【安全】先把内容里的 `[` 转义成 `[lb]`，再插入我们自己的标签 ——
## 否则文档正文里出现的方括号会被 RichTextLabel 当成 BBCode 解析
## （内容来自文件，不该有注入标签的能力）。
static func to_bbcode(text: String) -> String:
	var s := text.replace("[", "[lb]")
	# 先处理成对的 `**`，再处理行内的反引号
	while s.find("**") >= 0:
		var a := s.find("**")
		var b := s.find("**", a + 2)
		if b < 0:
			break                       # 落单的 ** 原样保留，不要吞掉
		s = s.substr(0, a) + "[b]" + s.substr(a + 2, b - a - 2) + "[/b]" + s.substr(b + 2)
	while s.find("`") >= 0:
		var a2 := s.find("`")
		var b2 := s.find("`", a2 + 1)
		if b2 < 0:
			break
		s = s.substr(0, a2) + "[code]" + s.substr(a2 + 1, b2 - a2 - 1) + "[/code]" + s.substr(b2 + 1)
	return s


func _rebuild_index() -> void:
	for c in _index_box.get_children():
		# remove_child + queue_free：queue_free 帧末才生效，只调它会数到旧节点
		_index_box.remove_child(c)
		c.queue_free()
	for i in _sections.size():
		var b := Button.new()
		b.name = "Section_%d" % i
		b.text = str((_sections[i] as Dictionary).get("title", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.clip_text = true
		b.pressed.connect(show_section.bind(i))
		_index_box.add_child(b)


func show_section(i: int) -> void:
	if i < 0 or i >= _sections.size():
		return
	_current = i
	_content.text = to_bbcode(str((_sections[i] as Dictionary).get("body", "")))
	_content.scroll_to_line(0)
	_title.text = "机制说明 · %s" % str((_sections[i] as Dictionary).get("title", ""))
	# 高亮当前节
	for k in _index_box.get_child_count():
		var b := _index_box.get_child(k)
		if b is Button:
			(b as Button).disabled = (k == i)


# ---------------------------------------------------------------------------
# 开关
# ---------------------------------------------------------------------------

func open_panel() -> void:
	_fit_to_viewport()
	visible = true
	var close_btn := _root.get_node_or_null("Column/Head/CloseButton")
	if close_btn is Button:
		(close_btn as Button).grab_focus()


func close_panel() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


# ---------------------------------------------------------------------------
# 测试/断言用
# ---------------------------------------------------------------------------

func section_count() -> int:
	return _sections.size()


func section_title(i: int) -> String:
	if i < 0 or i >= _sections.size():
		return ""
	return str((_sections[i] as Dictionary).get("title", ""))


func current_index() -> int:
	return _current


func body_text() -> String:
	return _content.text if _content != null else ""


func panel_rect() -> Rect2:
	return _root.get_global_rect() if _root != null else Rect2()
