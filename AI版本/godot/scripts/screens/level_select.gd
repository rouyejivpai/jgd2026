extends Control
## 选关：章节地图（07 §10.1；第三阶段 10 §3 改造；P6 按批准整图 ui_22～ui_26 换皮，位置 / 样式见 data/ui_layout/chapter.json）。
## - 地图铺满窗口（R3 低噪宽图，按窗口高等比），详情面板浮在右侧；左键按住空白处拖动、滚轮亦可横移，
##   范围 [0, 地图宽 − 详情面板左缘]（地图右端可滚到面板左缘，所有节点都能露出），无惯性，按下后移动 ≤ 6 px 视为点击。
##   底部金线 = 可滚范围，亮段 = 当前可见部分。
## - 点击节点 = 选中（金环放大 + 名牌高亮），不进关；进入地图默认选中最新可挑战节点并滚到可见区中央。
## - 右侧上框：第 N 关、关名、区域；下框：关卡特征（summary，空则 subtitle）、任务、状态、锁定时的前置关卡。
##   「进入」（锁定时禁用）；「开场剧情」下拉列出该关 _intro / _win / _lose 中 stories_seen 已含的条目，「回放剧情」用 StoryPlayer 播放，不改 stories_seen。
## - 选中占位节点（未开放）时右侧换成整图 ui_25 的紧凑版式：标题牌 + 说明框「未解锁」+ 禁用的「进入」，不显示区域与回放（布局 ph_*）。
## - 节点：深底金环圆盘 + 名牌胶囊（「01 · 田埂」）；锁定环暗并带锁；Boss 圆盘更大、青底；占位节点（9–25）恒锁定。
##   区域图标（整图里的耙子 / 网格 / 盾 / 准星 / 花）缺素材，暂显示关卡编号（docs/P6_MISSING_ASSETS.md）。
## - 连线：已完成金、可挑战暗金、锁定暗紫（指向占位节点的按锁定色）。story_on_unlock 行为不变。
## - 2026-10-18 分区域：章节的区域带区域地图时按区域分屏——只显示当前区域（GameState.current_region_id，缺省 = 最近关卡所在区域）的节点与区域地图，
##   标题 = 区域名，「返回」回到一级地图（world_map）；跨区域的连线不画。没有区域地图的章节（第一章旧 Demo）仍整章显示。

signal enter_requested(level_id: String)

const MENU_BGM: String = "menu_main"
const NODE_ART_DIR: String = "res://assets/ui/chapter/nodes/"
const STORY_KINDS: Array[String] = ["intro", "win", "lose"]
const STORY_PLAYER_SCENE: PackedScene = preload("res://scenes/ui/dialogue_overlay.tscn")
const SKIN: String = "chapter"

var chapter: ChapterDef = null
var node_buttons: Dictionary = {}        ## node id -> Button
var selected_id: String = ""
var scroll_x: float = 0.0
var navigate: bool = true                ## false：「进入」只发 enter_requested（测试用）
var _scale: float = 1.0
var _story: StoryPlayer = null
var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_scroll: float = 0.0
var _replay_ids: Array[String] = []

const SCORE_TAG_OFFSET: float = 1.15       ## 综合分胶囊中心在名牌中心下方的偏移（名牌高的倍数）
const SCORE_TAG_FONT: int = 22
@onready var _background: ColorRect = %Background
@onready var _viewport: Control = %MapViewport
@onready var _content: Control = %MapContent
@onready var _title: Label = %ChapterTitle
@onready var _back_button: Button = %BackButton
@onready var _settings_button: Button = %SettingsButton
@onready var _detail: Control = %DetailPanel
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_region: Label = %DetailRegion
@onready var _detail_summary: Label = %DetailSummary
@onready var _detail_objective: Label = %DetailObjective
@onready var _detail_state: Label = %DetailState
@onready var _detail_locked: Label = %DetailLockedBy
@onready var _enter_button: Button = %EnterButton
@onready var _replay_button: Button = %ReplayButton
@onready var _replay_pick: OptionButton = %ReplayPick
var _level_no: Label
var _objective_head: Label
var _skin: Dictionary = {}               ## 布局元素 id → 节点（框体、分隔线、滚动指示等）
var _lower: VBoxContainer = null         ## 下框内容（竖排）
var _lower_scroll: ScrollText = null
var _ph_title: Label
var _ph_text: Label
var _ph_enter: Button                    ## 占位版式的「进入」（恒禁用）
const NORMAL_ONLY: Array[String] = ["panel_top", "panel_bottom", "moon_orn", "astro_orn", "gem1_orn", "gem2_orn", "gem3_orn", "gem4_orn", "level_no", "level_title", "sep_top", "region", "btn_enter", "replay_pick", "btn_replay"]
const PLACEHOLDER_ONLY: Array[String] = ["ph_plaque", "ph_panel", "ph_title", "ph_text", "ph_enter"]
var _node_clip: Control = null           ## 节点与连线的遮罩层：宽 = 地图可见宽（详情面板左缘），节点不露在面板之间的空隙里
var _node_layer: Control = null          ## 节点 / 连线所在层，随滚动横移（与 MapContent 同步）
## 多章节：指定显示第几个章节（测试 / 调试用）；-1 = 自动（最近关卡所在章节；不在任何章节时取带一级地图的章节）
static var chapter_index: int = -1
var region_id: String = ""               ## 当前显示的区域（"" = 整章显示）


func _ready() -> void:
	_background.color = Palette.BG_DEEP
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	var chapters: Array[ChapterDef] = DataRegistry.get_chapters()
	chapter = chapters[_pick_chapter(chapters)] if not chapters.is_empty() else null
	region_id = pick_region()
	_back_button.text = DataRegistry.get_string("ui.back")
	_back_button.pressed.connect(_on_back_pressed)
	_settings_button.text = DataRegistry.get_string("ui.menu_settings")
	_settings_button.pressed.connect(func() -> void: SceneRouter.open_settings())      # 10 §2：章节地图顶栏「设置」
	_enter_button.text = DataRegistry.get_string("ui.node_enter")
	_enter_button.pressed.connect(_on_enter_pressed)
	_replay_button.text = DataRegistry.get_string("ui.replay_story")
	_replay_button.pressed.connect(func() -> void: _on_replay_pressed(_replay_pick.selected))
	for b: BaseButton in [_back_button, _settings_button, _enter_button, _replay_button, _replay_pick] as Array[BaseButton]:
		b.focus_mode = Control.FOCUS_NONE
	_apply_skin()
	if chapter == null:
		return
	_title.text = chapter.region_title(region_id) if region_id != "" else chapter.title
	_node_clip = Control.new()
	_node_clip.name = "NodeClip"
	_node_clip.clip_contents = true
	_node_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_node_clip)
	_node_layer = Control.new()
	_node_layer.name = "NodeLayer"
	_node_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_node_clip.add_child(_node_layer)
	_node_layer.draw.connect(_draw_links)
	_viewport.gui_input.connect(_on_viewport_input)
	_viewport.resized.connect(_layout)
	resized.connect(_place_skin)
	_build_nodes()
	_layout()
	select_node(default_node())
	center_on(selected_id)
	_story = STORY_PLAYER_SCENE.instantiate() as StoryPlayer
	add_child(_story)
	_play_unlock_stories.call_deferred()


## 换皮：主题；框体 / 分隔线 / 滚动指示等贴图节点；场景里各节点的主题变体；摆放见 _place_skin
func _apply_skin() -> void:
	theme = UiKit.ui_theme(SKIN)
	_background.color = Palette.BG_DEEP
	for id: String in ["panel_top", "panel_bottom", "ph_plaque", "ph_panel", "moon_orn", "astro_orn", "gem1_orn", "gem2_orn", "gem3_orn", "gem4_orn", "sep_top", "sep_bottom", "title_plaque", "title_moon", "title_line", "scroll_line", "scroll_thumb"]:
		var c: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		c.name = "Skin_" + id
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var orn: bool = id.ends_with("_orn")
		var frame: bool = (id.begins_with("panel") or id.begins_with("ph_")) and not orn
		var parent: Node = _detail if frame or orn or id.begins_with("sep") else self
		parent.add_child(c)
		parent.move_child(c, 0 if frame else parent.get_child_count() - 1)
		_skin[id] = c
	for id: String in ["moon_orn", "astro_orn", "gem1_orn", "gem2_orn", "gem3_orn", "gem4_orn"]:      # 框体纹饰（P6 #20）叠在四个框体之上、文字之下
		_detail.move_child(_skin[id] as Control, 4)
	move_child(_skin["title_plaque"] as Control, _title.get_index())     # 标题深色底牌（P6 #18）在章节名之下
	_detail.move_child(_detail.get_node("DetailColumn"), -1)
	_level_no = _make_label("level_no")
	_objective_head = _make_label("objective_head")
	_objective_head.text = DataRegistry.get_string("ui.objectives_popup")
	_ph_title = _make_label("ph_title")
	_ph_text = _make_label("ph_text")
	_ph_text.text = DataRegistry.get_string("ui.locked")
	_ph_enter = UiKit.node_for(UiKit.layout_element(SKIN, "ph_enter")) as Button
	_ph_enter.name = "Skin_ph_enter"
	_ph_enter.text = DataRegistry.get_string("ui.node_enter")
	_ph_enter.disabled = true
	_ph_enter.focus_mode = Control.FOCUS_NONE
	_ph_enter.clip_text = true
	_detail.get_node("DetailColumn").add_child(_ph_enter)
	_skin["ph_enter"] = _ph_enter
	var pairs: Dictionary = {
		"title": _title, "btn_back": _back_button, "btn_settings": _settings_button, "level_title": _detail_title, "region": _detail_region,
		"summary": _detail_summary, "objective": _detail_objective, "state": _detail_state, "btn_enter": _enter_button,
		"replay_pick": _replay_pick, "btn_replay": _replay_button,
	}
	for id: String in pairs.keys():
		var c: Control = pairs[id] as Control
		c.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
		_skin[id] = c
		if c is Label:
			(c as Label).clip_text = true
			(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		elif c is Button:
			(c as Button).clip_text = true
	_detail_summary.clip_text = false
	_detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_objective.clip_text = false
	_detail_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_locked.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "objective").get("theme_type", "")))
	_detail_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_replay_pick.fit_to_longest_item = false
	_replay_pick.add_theme_icon_override("arrow", UiKit.transparent_texture(Vector2i.ONE))      # 箭头画在下拉切片上
	_place_skin()
	for id: String in ["title", "level_title", "region", "ph_title"]:
		var l: Label = _skin[id] as Label
		_skin[id] = ScrollText.wrap(l, ScrollText.Mode.AUTO)


func _make_label(id: String) -> Label:
	var l := Label.new()
	l.name = "Skin_" + id
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.get_node("DetailColumn").add_child(l)
	_skin[id] = l
	return l


## 按布局摆放（设计坐标 → 屏幕坐标只在 UiKit.layout_rect 一处换算）；下框的特征 / 任务 / 状态按文字实际高度顺排
func _place_skin() -> void:
	var vp: Vector2 = get_viewport_rect().size
	for id: String in _skin.keys():
		if id in ["scroll_thumb", "sep_bottom", "summary", "objective", "objective_head", "state"] and _lower != null:
			continue
		if id == "scroll_thumb":
			continue
		var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
		UiKit.place(_skin[id] as Control, UiKit.layout_text_rect(SKIN, id, vp) if text else UiKit.layout_rect(SKIN, id, vp))
	_flow_detail()
	_place_scroll_thumb()
	_apply_detail_mode()


## 普通版式 / 占位版式（选中占位节点时，整图 ui_25）切换：显隐两组件
func _apply_detail_mode() -> void:
	if _skin.is_empty() or selected_id == "":         # 换皮时（尚未包 ScrollText、未选中）不动显隐
		return
	var ph: bool = chapter != null and bool(chapter.node_of(selected_id).get("placeholder", false))
	for id: String in NORMAL_ONLY:
		(_skin[id] as Control).visible = not ph
	for id: String in PLACEHOLDER_ONLY:
		(_skin[id] as Control).visible = ph
	if _lower_scroll != null:
		_lower_scroll.visible = not ph


## 下框内容：特征（可多行）→ 分隔线 → 任务 → 任务句（可多行）→ 状态 → 前置关卡，间距取整图；
## 放在一个竖排容器里，包进 ScrollText（超出下框时滚轮 / 拖动上下滚动，用户 2026-10-05 规则）
func _flow_detail() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r := func(id: String) -> Rect2: return UiKit.layout_text_rect(SKIN, id, vp) if str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style" else UiKit.layout_rect(SKIN, id, vp)
	var sm: Rect2 = r.call("summary")
	var panel: Rect2 = r.call("panel_bottom")
	var sep: Rect2 = r.call("sep_bottom")
	var oh: Rect2 = r.call("objective_head")
	var ob: Rect2 = r.call("objective")
	var st: Rect2 = r.call("state")
	if _lower == null:
		_lower = VBoxContainer.new()
		_lower.name = "LowerBody"
		_lower.add_theme_constant_override("separation", 0)
		_lower.mouse_filter = Control.MOUSE_FILTER_PASS
		var col: Node = _detail.get_node("DetailColumn")
		col.add_child(_lower)
		var sep_img: Control = _skin["sep_bottom"] as Control     # 菱形分隔线切片（P6 #21）比文字列宽：放进与文字列等宽的占位框，图片自身溢出（不撑宽竖排）
		var sep_node := Control.new()
		sep_node.name = "SepHolder"
		sep_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sep_node.custom_minimum_size = Vector2(sm.size.x, sep.size.y)
		sep_img.reparent(sep_node)
		sep_img.position = Vector2(sep.position.x - sm.position.x, 0.0)
		sep_img.size = sep.size
		var items: Array = [_detail_summary, _gap(sep.position.y - sm.end.y), sep_node, _gap(oh.position.y - sep.end.y), _objective_head,
			_gap(ob.position.y - oh.end.y), _detail_objective, _gap(st.position.y - ob.end.y), _detail_state, _gap(4.0), _detail_locked]
		for c: Control in items:
			if c.get_parent() != _lower:
				if c.get_parent() != null:
					c.reparent(_lower)
				else:
					_lower.add_child(c)
			_lower.move_child(c, -1)
		var heights: Array[float] = [sm.size.y, oh.size.y, ob.size.y, st.size.y, ob.size.y]     # 单行时占满布局文字区高（与整图量取的行位一致），多行时自然增高
		var flowed: Array[Control] = [_detail_summary, _objective_head, _detail_objective, _detail_state, _detail_locked]
		for i: int in flowed.size():
			flowed[i].custom_minimum_size = Vector2(sm.size.x, heights[i])
		_lower_scroll = ScrollText.wrap_box(_lower, ScrollText.Mode.MANUAL, Rect2(Vector2.ZERO, Vector2.ONE))
	var inner_bottom: float = st.end.y + (panel.end.y - st.end.y) * 0.25         # 遮罩下沿：整图状态行下沿再留四分之一的底边距（文字不压金边）
	UiKit.place(_lower_scroll, Rect2(sm.position.x, sm.position.y, sm.size.x, inner_bottom - sm.position.y))


func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, maxf(h, 0.0))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


# ---- 节点 ----
func _build_nodes() -> void:
	var vp: Vector2 = UiKit.design_size(SKIN)
	var node_size: float = UiKit.layout_rect(SKIN, "node", vp).size.x
	var nd: Dictionary = UiKit.layout_element(SKIN, "node").get("data", {}) as Dictionary
	var plate: Rect2 = UiKit.layout_rect(SKIN, "plate", vp)
	for n: Dictionary in shown_nodes():
		var nid: String = str(n["id"])
		var level: LevelDefinition = DataRegistry.get_level(str(n["level"])) if not bool(n["placeholder"]) else null
		if not bool(n["placeholder"]) and level == null:
			continue
		var b := Button.new()
		b.name = "Node_" + nid
		var node_px: float = node_size * (float(nd.get("boss_scale", 1.3)) if bool(n["boss"]) else 1.0)
		b.custom_minimum_size = Vector2(node_px, node_px)
		b.size = Vector2(node_px, node_px)
		b.focus_mode = Control.FOCUS_NONE
		b.pivot_offset = b.size * 0.5
		b.text = str(level.display_index) if level != null else ""
		b.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate_text").get("theme_type", "")))
		var art: Texture2D = Art.texture(NODE_ART_DIR + "%s.png" % str(n["node_art"])) if str(n["node_art"]) != "" else null
		if art != null:
			b.icon = art
			b.expand_icon = true
			b.text = ""
		b.pressed.connect(select_node.bind(nid))
		_node_layer.add_child(b)
		var disc := TextureRect.new()           # 节点徽章（按状态换图，画在按钮图标之下；边长 = 金环直径 × art_scale）
		disc.name = "Disc"
		disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.show_behind_parent = true
		disc.size = Vector2(node_px, node_px) * float(nd.get("art_scale", 1.0))
		disc.position = (Vector2(node_px, node_px) - disc.size) * 0.5
		b.add_child(disc)
		var plate_bg := Panel.new()            # 名牌胶囊（P6 #24 名牌切片）
		plate_bg.name = "PlateBg"
		plate_bg.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate").get("theme_type", "")))
		plate_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(plate_bg)
		var name_label := Label.new()
		name_label.name = "Nameplate"
		name_label.text = node_label(nid)
		name_label.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate_text").get("theme_type", "")))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_label)
		var off: Array = (UiKit.layout_element(SKIN, "plate").get("data", {}) as Dictionary).get("offset", [0, 0]) as Array
		var center := Vector2(node_px * 0.5, node_px * 0.5) + Vector2(float(off[0]), float(off[1])) + Vector2(0.0, (node_px - node_size) * 0.5)
		for c: Control in [plate_bg, name_label] as Array[Control]:
			c.size = plate.size
			c.position = center - plate.size * 0.5
		var score_tag := PanelContainer.new()  # 2026-10-18：已通关关卡在名牌下显示综合分（越低越好）：深色小胶囊 + 金字
		score_tag.name = "ScoreTag"
		score_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(Palette.VIOLET_DEEP, 0.9)
		pill.border_color = Color(Palette.ALCHEMY_GOLD, 0.85)
		pill.set_border_width_all(2)
		pill.set_corner_radius_all(14)
		pill.set_content_margin_all(2)
		pill.content_margin_left = 14
		pill.content_margin_right = 14
		score_tag.add_theme_stylebox_override("panel", pill)
		var score_text := Label.new()
		score_text.name = "Text"
		score_text.theme_type_variation = name_label.theme_type_variation
		score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_text.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
		score_text.add_theme_font_size_override("font_size", SCORE_TAG_FONT)
		score_tag.add_child(score_text)
		score_tag.set_meta(&"anchor", center + Vector2(0.0, plate.size.y * SCORE_TAG_OFFSET))
		b.add_child(score_tag)
		for m: Array in [["Lock", "node_lock_marker"], ["Check", "node_check_marker"]]:     # 锁定 / 已完成角标（右下，尺寸取布局）
			var mark := TextureRect.new()
			mark.name = str(m[0])
			mark.texture = Art.texture(str(UiKit.layout_element(SKIN, str(m[1])).get("file", "")))
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.size = UiKit.layout_rect(SKIN, str(m[1]), vp).size
			mark.position = Vector2(node_px, node_px) * 0.86 - mark.size * 0.5
			b.add_child(mark)
		node_buttons[nid] = b
	_restyle_nodes()


## 名牌文字：关卡节点「01 · 田埂」；占位节点为名称
func node_label(node_id: String) -> String:
	var n: Dictionary = chapter.node_of(node_id)
	var level: LevelDefinition = DataRegistry.get_level(str(n.get("level", ""))) if not bool(n.get("placeholder", false)) else null
	if level == null:
		return node_title(node_id)
	return DataRegistry.get_string("ui.node_plate").format({ "index": "%02d" % level.display_index, "title": level.title })


## 节点状态：0 锁定、1 可挑战、2 已完成（参数为节点 id；占位节点恒为 0）
func node_state(node_id: String) -> int:
	var n: Dictionary = chapter.node_of(node_id)
	if n.is_empty() or bool(n["placeholder"]):
		return 0
	var lid: String = str(n["level"])
	if GameState.is_level_completed(lid):
		return 2
	return 1 if GameState.is_level_unlocked(lid) else 0


## 节点名：关卡名；占位节点用 title_key（缺省「未开放」）
func node_title(node_id: String) -> String:
	var n: Dictionary = chapter.node_of(node_id)
	if bool(n.get("placeholder", false)):
		var key: String = str(n["title_key"])
		return DataRegistry.get_string(key if key != "" else "ui.node_placeholder")
	var level: LevelDefinition = DataRegistry.get_level(str(n.get("level", "")))
	return level.title if level != null else node_id


func _state_color(state: int) -> Color:
	return [Palette.VIOLET_MUTE, Palette.BONE, Palette.ALCHEMY_GOLD][state]


## 节点样式（P6 #24 节点切片）：徽章按状态换图（锁定 / 可挑战 / 已完成 / 选中，首领恒用青底徽章），选中放大；
## 区域图标边长 = 金环直径 × icon_ratio，锁定时压暗；锁 / 勾角标；名牌胶囊选中时提亮、金字。参数取布局 node / plate / node_tex_*
func _restyle_nodes() -> void:
	var nd: Dictionary = UiKit.layout_element(SKIN, "node").get("data", {}) as Dictionary
	var pd: Dictionary = UiKit.layout_element(SKIN, "plate").get("data", {}) as Dictionary
	var empty := StyleBoxEmpty.new()
	for nid: String in node_buttons.keys():
		var b: Button = node_buttons[nid] as Button
		var state: int = node_state(nid)
		var sel: bool = nid == selected_id
		var n: Dictionary = chapter.node_of(nid)
		var tex_id: String = ["node_tex_locked", "node_tex_open", "node_tex_done"][state]
		if bool(n.get("boss", false)):
			tex_id = "node_tex_boss"
		elif sel:
			tex_id = "node_tex_selected"
		(b.get_node("Disc") as TextureRect).texture = Art.texture(str(UiKit.layout_element(SKIN, tex_id).get("file", "")))
		var pad: float = b.size.x * (1.0 - float(nd.get("icon_ratio", 0.5))) * 0.5
		var box := StyleBoxEmpty.new()
		box.set_content_margin_all(pad)
		for style: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(style, box)
		b.add_theme_stylebox_override("focus", empty)
		var glyph := Color(str(nd.get("glyph_locked" if state == 0 else "glyph_color", "#FFFFFF")))
		for c: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "font_color"]:
			b.add_theme_color_override(c, glyph)
		b.scale = Vector2.ONE * (float(nd.get("selected_scale", 1.3)) if sel else 1.0)
		b.z_index = 1 if sel else 0
		(b.get_node("Lock") as Control).visible = state == 0
		(b.get_node("Check") as Control).visible = state == 2
		var plate_bg: Control = b.get_node("PlateBg") as Control
		plate_bg.modulate = Color(str(pd.get("selected_modulate", "#FFFFFF"))) if sel else Color.WHITE
		var name_plate: Label = b.get_node("Nameplate") as Label
		if sel:
			name_plate.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
		else:
			name_plate.remove_theme_color_override("font_color")
		var score_tag: Control = b.get_node("ScoreTag") as Control
		var lid: String = str(n.get("level", ""))
		var best: int = SaveManager.best_score(lid) if state == 2 and lid != "" else -1
		score_tag.visible = best >= 0
		(score_tag.get_node("Text") as Label).text = DataRegistry.get_string("ui.level_best_score").format({ "total": best }) if best >= 0 else ""
		score_tag.reset_size()
		score_tag.position = (score_tag.get_meta(&"anchor") as Vector2) - score_tag.size * 0.5
		plate_bg.scale = Vector2.ONE / b.scale       # 名牌不随选中放大
		name_plate.scale = Vector2.ONE / b.scale
		score_tag.scale = Vector2.ONE / b.scale
		for c: Control in [plate_bg, name_plate, score_tag] as Array[Control]:
			c.pivot_offset = c.size * 0.5


## 默认选中：最新可挑战节点（按数据顺序最后一个）；没有则最后一个已完成；再没有则第一个
func default_node() -> String:
	var playable: String = ""
	var done: String = ""
	var ns: Array[Dictionary] = shown_nodes()
	for n: Dictionary in ns:
		var nid: String = str(n["id"])
		if not node_buttons.has(nid):
			continue
		match node_state(nid):
			1:
				playable = nid
			2:
				done = nid
	if playable != "":
		return playable
	if done != "":
		return done
	return str(ns[0]["id"]) if not ns.is_empty() else ""


## 点击节点 = 选中（不进关）
func select_node(node_id: String) -> void:
	if not node_buttons.has(node_id):
		return
	selected_id = node_id
	_restyle_nodes()
	_refresh_detail()


# ---- 地图视口：缩放、横移 ----
func _layout() -> void:
	if chapter == null:
		return
	var vp_h: float = maxf(_viewport.size.y, 1.0)
	_scale = vp_h / map_size().y
	_content.size = Vector2(map_size().x * _scale, vp_h)
	_node_clip.size = Vector2(visible_width(), vp_h)
	_node_layer.size = _content.size
	_build_map_tiles()
	for nid: String in node_buttons.keys():
		var b: Button = node_buttons[nid] as Button
		b.position = (chapter.node_of(nid)["pos"] as Vector2) * _scale - b.size * 0.5
	set_scroll(scroll_x)
	_node_layer.queue_redraw()


## 章节宽图：单张按视口高等比（R3 低噪宽图；map_size 与图同比例）
func _build_map_tiles() -> void:
	for c: Node in _content.get_children():
		if c.name.begins_with("MapTile"):
			c.queue_free()
	var tex: Texture2D = Art.texture(map_path())
	if tex == null:
		return
	var r := TextureRect.new()
	r.name = "MapTile0"
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = _content.size
	r.show_behind_parent = true
	_content.add_child(r)
	_content.move_child(r, 0)
	var mirror := TextureRect.new()          # 地图右端之后（详情面板背后）接一张水平镜像，滚到最右时面板后不露底
	mirror.name = "MapTile1"
	mirror.texture = tex
	mirror.flip_h = true
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_SCALE
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror.position = Vector2(_content.size.x, 0.0)
	mirror.size = _content.size
	mirror.show_behind_parent = true
	_content.add_child(mirror)
	_content.move_child(mirror, 1)


## 地图可见宽 = 详情面板左缘（地图铺满窗口，面板浮在右侧）
func visible_width() -> float:
	return UiKit.layout_rect(SKIN, "panel_top", get_viewport_rect().size).position.x


func max_scroll() -> float:
	return maxf(0.0, _content.size.x - visible_width())


func set_scroll(x: float) -> void:
	scroll_x = clampf(x, 0.0, max_scroll())
	_content.position.x = -scroll_x
	if _node_layer != null:
		_node_layer.position.x = -scroll_x
	_place_scroll_thumb()


## 底部滚动指示：亮段长度 = 可见比例，位置随滚动
func _place_scroll_thumb() -> void:
	if not _skin.has("scroll_thumb") or _content.size.x <= 0.0:
		return
	var vp: Vector2 = get_viewport_rect().size
	var line: Rect2 = UiKit.layout_rect(SKIN, "scroll_line", vp)
	var th: Rect2 = UiKit.layout_rect(SKIN, "scroll_thumb", vp)
	var frac: float = clampf(visible_width() / _content.size.x, 0.05, 1.0)
	var w: float = line.size.x * frac
	var t: float = scroll_x / maxf(max_scroll(), 1.0) if max_scroll() > 0.0 else 0.0
	UiKit.place(_skin["scroll_thumb"] as Control, Rect2(line.position.x + (line.size.x - w) * t, th.position.y, w, th.size.y))


## 把节点滚到视口中央（受范围限制）
func center_on(node_id: String) -> void:
	var n: Dictionary = chapter.node_of(node_id)
	if n.is_empty():
		return
	var target: float = (n["pos"] as Vector2).x * _scale - visible_width() * 0.5
	# 显示中的节点能同时放进可见区时，保证它们全部可见（分区域后每区节点少，不该为了居中把首关挤出左缘）
	var lo: float = INF
	var hi: float = -INF
	for m: Dictionary in shown_nodes():
		lo = minf(lo, (m["pos"] as Vector2).x * _scale)
		hi = maxf(hi, (m["pos"] as Vector2).x * _scale)
	var margin: float = UiKit.layout_rect(SKIN, "plate", get_viewport_rect().size).size.x * 0.6
	if hi - lo + margin * 2.0 <= visible_width():
		target = clampf(target, hi + margin - visible_width(), lo - margin)
	set_scroll(target)


## 节点在视口内的屏幕矩形（测试 / 截图用）
func node_rect_in_viewport(node_id: String) -> Rect2:
	var b: Button = node_buttons.get(node_id, null) as Button
	return Rect2(b.position + _content.position, b.size) if b != null else Rect2()


func _on_viewport_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressing = true
					_dragging = false
					_press_pos = mb.position
					_press_scroll = scroll_x
				else:
					_pressing = false
					_dragging = false
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				if mb.pressed:
					set_scroll(scroll_x + UiKit.CHAPTER_WHEEL_STEP)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				if mb.pressed:
					set_scroll(scroll_x - UiKit.CHAPTER_WHEEL_STEP)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _pressing:
		if not _dragging and mm.position.distance_to(_press_pos) > UiKit.CHAPTER_DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			set_scroll(_press_scroll - (mm.position.x - _press_pos.x))


func is_dragging() -> bool:
	return _dragging


func _draw_links() -> void:
	var w: float = float((UiKit.layout_element(SKIN, "link").get("data", {}) as Dictionary).get("width", 2.5))
	var gem: Texture2D = Art.texture(str(UiKit.layout_element(SKIN, "link_gem").get("file", "")))
	var gem_size: Vector2 = UiKit.layout_rect(SKIN, "link_gem", UiKit.design_size(SKIN)).size
	for n: Dictionary in chapter.nodes:
		var from_id: String = str(n["id"])
		if not node_buttons.has(from_id):
			continue
		for to: String in n["links"] as Array:
			if not node_buttons.has(to):
				continue
			var c: Color = link_color(from_id, to)
			var a: Vector2 = (n["pos"] as Vector2) * _scale
			var b: Vector2 = (chapter.node_of(to)["pos"] as Vector2) * _scale
			_node_layer.draw_line(a, b, c, w, true)
			if gem != null:                  # 连线中点的菱形（P6 #25），颜色随连线状态（锁定暗）
				_node_layer.draw_texture_rect(gem, Rect2((a + b) * 0.5 - gem_size * 0.5, gem_size), false, Color(1.0, 1.0, 1.0, c.a))


## 连线颜色：已完成金、可挑战骨白、锁定暗紫（指向占位节点 = 锁定）
func link_color(from_id: String, to_id: String) -> Color:
	var state: int = chapter.link_state(from_id, to_id, GameState.progress.get("completed", []) as Array)
	var d: Dictionary = UiKit.layout_element(SKIN, "link").get("data", {}) as Dictionary
	return Color(str(d.get(["locked", "open", "done"][state], "#FFFFFF")))


# ---- 详情面板 ----
func _refresh_detail() -> void:
	var n: Dictionary = chapter.node_of(selected_id)
	var state: int = node_state(selected_id)
	var level: LevelDefinition = DataRegistry.get_level(str(n.get("level", ""))) if not bool(n.get("placeholder", false)) else null
	if level != null:
		_level_no.text = DataRegistry.get_string("ui.level_label").format({ "index": level.display_index })
		_detail_title.text = level.title
		_detail_summary.text = level.summary if level.summary != "" else level.subtitle
		_detail_objective.text = level.objective_text
	else:
		_level_no.text = ""
		_detail_title.text = node_title(selected_id)
		_ph_title.text = node_title(selected_id)
		_detail_summary.text = ""
		_detail_objective.text = ""
	_detail_region.text = DataRegistry.get_string("ui.detail_dot").format({ "label": DataRegistry.get_string("ui.detail_region"), "value": chapter.region_title(str(n.get("region", ""))) })
	var state_word: String = DataRegistry.get_string(["ui.locked", "ui.playable", "ui.completed"][state])
	var best: int = SaveManager.best_score(level.id) if level != null and state == 2 else -1
	if best >= 0:                                 # 已通关：状态后跟综合分（越低越好）
		state_word = DataRegistry.get_string("ui.detail_state_score").format({ "state": state_word, "total": best })
	_detail_state.text = DataRegistry.get_string("ui.detail_dot").format({ "label": DataRegistry.get_string("ui.detail_state"), "value": state_word })
	if state == 0:
		_detail_state.add_theme_color_override("font_color", _state_color(0))
	else:
		_detail_state.remove_theme_color_override("font_color")      # 布局字色（整图金）
	_detail_summary.visible = _detail_summary.text != ""
	_detail_objective.visible = _detail_objective.text != ""
	_objective_head.visible = _detail_objective.visible
	_enter_button.disabled = level == null or state == 0
	_detail_locked.visible = level != null and state == 0
	if _detail_locked.visible:
		var names: PackedStringArray = PackedStringArray()
		for p: String in chapter.predecessors(selected_id):
			var pl: LevelDefinition = DataRegistry.get_level(str(chapter.node_of(p).get("level", "")))
			if pl != null:
				names.append("%s %s" % [DataRegistry.get_string("ui.level_label").format({ "index": pl.display_index }), pl.title])
		_detail_locked.text = DataRegistry.get_string("ui.node_locked_by").format({ "levels": DataRegistry.get_string("ui.list_sep").join(names) })
	_fill_replay(level)
	_apply_detail_mode()
	ArtText.attach(_detail_title, SKIN, "level_title")         # P8：关卡名、章节名艺术字（R6b；选中首领关时章节名用 boss 款）
	ArtText.attach(_title, SKIN, "title", "boss" if bool(n.get("boss", false)) else "")
	_flow_detail.call_deferred()


## 回放剧情：只列 stories_seen 已含的 _intro / _win / _lose；一条都没有则禁用
func _fill_replay(level: LevelDefinition) -> void:
	_replay_pick.clear()
	_replay_ids.clear()
	if level != null:
		for kind: String in STORY_KINDS:
			var sid: String = "%s_%s" % [level.id, kind]
			if SaveManager.is_story_seen(sid):
				_replay_pick.add_item(DataRegistry.get_string("ui.replay_" + kind), _replay_ids.size())
				_replay_ids.append(sid)
	if _replay_ids.is_empty():
		_replay_pick.add_item(DataRegistry.get_string("ui.replay_intro"), 0)      # 占位显示（禁用）
	_replay_pick.select(0)
	_replay_button.disabled = _replay_ids.is_empty()
	_replay_pick.disabled = _replay_ids.is_empty()


func replay_ids() -> Array[String]:
	return _replay_ids.duplicate()


func _on_replay_pressed(index: int) -> void:
	if index >= 0 and index < _replay_ids.size():
		_story.play_story(_replay_ids[index])      # 回放不改 stories_seen


func _on_enter_pressed() -> void:
	var n: Dictionary = chapter.node_of(selected_id)
	if bool(n.get("placeholder", true)) or node_state(selected_id) == 0:
		return
	var lid: String = str(n["level"])
	enter_requested.emit(lid)
	if navigate:
		SceneRouter.goto_battle(lid)


## 07 §10.2：已解锁且未播放过的 story_on_unlock，进入地图时依次播放一段（文件不存在则静默跳过）
func _play_unlock_stories() -> void:
	for n: Dictionary in chapter.nodes:
		var sid: String = str(n["story_on_unlock"])
		if sid == "" or SaveManager.is_story_seen(sid) or node_state(str(n["id"])) == 0:
			continue
		SaveManager.mark_story_seen(sid)
		SaveManager.save()
		if _story.play_story(sid):
			return


## 分区域时回到一级地图，否则回主菜单
func _on_back_pressed() -> void:
	if region_id != "" and chapter.has_world():
		SceneRouter.goto_world_map()
	else:
		SceneRouter.goto_main_menu()



# ---- 章节 / 区域 ----
## 章节：显式指定（chapter_index）> 最近关卡所在的章节（不带一级地图的旧章节，如第一章 Demo 与其测试）> 带一级地图的章节 > 第一个
func _pick_chapter(chapters: Array[ChapterDef]) -> int:
	if chapter_index >= 0 and chapter_index < chapters.size():
		return chapter_index
	var last: ChapterDef = DataRegistry.chapter_of(GameState.current_level_id) if GameState.current_level_id != "" else null
	if last != null and not last.has_world():
		return chapters.find(last)
	var wc: ChapterDef = DataRegistry.world_chapter()
	if wc != null:
		return chapters.find(wc)
	return maxi(0, chapters.find(last)) if last != null else 0


## 区域：本章区域没有区域地图 → ""（整章）；否则 GameState.current_region_id > 最近关卡所在区域 > 第一个有地图的区域
func pick_region() -> String:
	if chapter == null:
		return ""
	var want: String = GameState.current_region_id
	if want != "" and chapter.region_has_map(want):
		return want
	var by_level: String = chapter.region_of_level(GameState.current_level_id)
	if by_level != "" and chapter.region_has_map(by_level):
		return by_level
	for r: Dictionary in chapter.regions:
		if chapter.region_has_map(str(r["id"])):
			return str(r["id"])
	return ""


## 当前显示的节点：分区域时只含本区域
func shown_nodes() -> Array[Dictionary]:
	if region_id == "":
		return chapter.nodes
	return chapter.region_nodes(region_id)


func map_path() -> String:
	return str(chapter.region(region_id).get("map", "")) if region_id != "" else chapter.map


func map_size() -> Vector2:
	return chapter.region(region_id).get("map_size", chapter.map_size) as Vector2 if region_id != "" else chapter.map_size
