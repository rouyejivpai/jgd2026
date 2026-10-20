extends Control
## 选关：章节地图（07 §10.1；第三阶段 10 §3 改造；P6 按批准整图 ui_22～ui_26 换皮，位置 / 样式见 data/ui_layout/chapter.json）。
## - 地图铺满窗口（R3 低噪宽图，按窗口高等比），详情面板浮在右侧；左键按住空白处拖动、滚轮亦可横移，
##   范围 [0, 地图宽 − 详情面板左缘]（地图右端可滚到面板左缘，所有节点都能露出），无惯性，按下后移动 ≤ 6 px 视为点击。
##   底部金线 = 可滚范围，亮段 = 当前可见部分。
## - 点击节点 = 选中（金环放大 + 名牌高亮），不进关；进入地图默认选中最新可挑战节点并滚到可见区中央。
##   2026-10-20（用户）：进入时详情面板收起、默认节点不画选中样式；节点平铺整张区域地图（不再避让面板）；
##   点节点时面板滑出，并把该节点滚到可见区横向正中（可出框）；收起面板时立刻弹回可滚范围。
## - 右侧上框：第 N 关、关名、区域；下框：关卡特征（summary，空则 subtitle）、任务、状态、锁定时的前置关卡。
##   「进入」（锁定时禁用）；「剧情回放」（D04，该关 _intro / _win 任一在 stories_seen 里才显示）打开剧情选择浮层（StorySelect）：
##   「开头剧情」「结尾剧情」两卡（没看过的锁定），点卡用 StoryPlayer 播放（浮层暂隐，播完回到浮层），不改 stories_seen
##   （2026-10-21 用户 04.zip；之前 2026-10-20 是并排两个按钮）。
## - 选中占位节点（未开放）时右侧换成整图 ui_25 的紧凑版式：标题牌 + 说明框「未解锁」+ 禁用的「进入」，不显示区域与回放（布局 ph_*）。
## - 节点：深底金环圆盘 + 名牌胶囊（「01 · 田埂」）；锁定环暗并带锁；Boss 圆盘更大、青底；占位节点（9–25）恒锁定。
##   区域图标（整图里的耙子 / 网格 / 盾 / 准星 / 花）缺素材，暂显示关卡编号（docs/P6_MISSING_ASSETS.md）。
## - 连线：已完成金、可挑战暗金、锁定暗紫（指向占位节点的按锁定色）。story_on_unlock 行为不变。
## - 2026-10-18 分区域：章节的区域带区域地图时按区域分屏——只显示当前区域（GameState.current_region_id，缺省 = 最近关卡所在区域）的节点与区域地图，
##   标题 = 区域名，「返回」回到一级地图（world_map）；跨区域的连线不画。没有区域地图的章节（第一章旧 Demo）仍整章显示。
## - 2026-10-20（用户）：
##   · 地图两端不再接镜像图，左右边缘沿腐蚀线羽化（parchment_edge），地图后面与一级地图相同：暗品红底光 + 彼岸花瓣（前后两层）。
##   · 左键拖动可左右拖出框，最多视口宽的 1/8：越拉越紧（橡皮筋，不硬卡），松手后弹回范围内；上下不动。滚轮仍限制在范围内。
##   · 点地图空白处（按下后移动 ≤ 6 px）收起右侧详情面板（向右滑出），地图可见宽随之铺满窗口；点任一节点再滑回并选中。
##   · 未解锁关卡名牌是空的，锁压在名牌上，详情标题显示「？？？」、不显示特征与任务；关卡新解锁（存档 levels_revealed 没有它）时，
##     进场后播与一级地图相同的解锁动画（UnlockBurst：锁颤抖 → 白色粒子 → 名牌闪白换名 → 渐回）；有解锁剧情时等剧情播完。调试版 F9 重播选中关。

signal enter_requested(level_id: String)

const MENU_BGM: String = "menu_main"
const NODE_ART_DIR: String = "res://assets/ui/chapter/nodes/"
const REPLAY_KINDS: Array[String] = ["intro", "win"]      ## 回放按钮：开头剧情 / 结尾剧情
const STORY_PLAYER_SCENE: PackedScene = preload("res://scenes/ui/dialogue_overlay.tscn")
const SKIN: String = "chapter"
const ELITE_DISC_TINT: Color = Color(1.0, 0.55, 0.6)   ## 精英关节点徽章（首领青底徽章染暗红）
const EDGE_SHADER: Shader = preload("res://assets/shaders/parchment_edge.gdshader")
const BACKDROP_SHADER: Shader = preload("res://assets/shaders/magenta_backdrop.gdshader")
const FEATHER_PX: float = 170.0          ## 区域地图左右羽化宽（视口像素）
const OVERSCROLL_FRAC: float = 0.125     ## 左右最多拖出框 = 视口宽 × 1/8
const SPRING_TIME: float = 0.45          ## 拖出框松手后弹回的时长
const PANEL_TIME: float = 0.38           ## 详情面板收起 / 展开的时长
const REVEAL_DELAY: float = 0.9          ## 进场（或解锁剧情播完）后多久开始播解锁动画
const REVEAL_GAP: float = 0.35           ## 同时解锁多关时，依次播放的间隔
const LOCKED_PLATE_TINT: Color = Color(0.78, 0.76, 0.80, 0.92)

var chapter: ChapterDef = null
var node_buttons: Dictionary = {}        ## node id -> Button
var selected_id: String = ""
var highlighted: bool = false            ## 节点是否画选中样式：进入时默认关卡只填详情面板、不高亮，玩家点击后才高亮
var scroll_x: float = 0.0
var navigate: bool = true                ## false：「进入」只发 enter_requested（测试用）
var _scale: float = 1.0
var _story: StoryPlayer = null
var story_select: StorySelect = null     ## 剧情回放浮层（开头 / 结尾两卡）
var _replaying: bool = false             ## 正在从浮层播回放：播完回到浮层
var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_scroll: float = 0.0

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
var _level_no: Label
var _objective_head: Label
var _skin: Dictionary = {}               ## 布局元素 id → 节点（框体、分隔线等）
var _lower: VBoxContainer = null         ## 下框内容（竖排）
var _lower_scroll: ScrollText = null
var _ph_title: Label
var _ph_text: Label
var _ph_enter: Button                    ## 占位版式的「进入」（恒禁用）
const NORMAL_ONLY: Array[String] = ["panel_top", "panel_bottom", "moon_orn", "astro_orn", "gem1_orn", "gem2_orn", "gem3_orn", "gem4_orn", "level_no", "level_title", "sep_top", "region", "btn_enter"]
const PLACEHOLDER_ONLY: Array[String] = ["ph_plaque", "ph_panel", "ph_title", "ph_text", "ph_enter"]
var _node_clip: Control = null           ## 节点与连线的遮罩层：宽 = 地图可见宽（详情面板左缘），节点不露在面板之间的空隙里
var _node_layer: Control = null          ## 节点 / 连线所在层，随滚动横移（与 MapContent 同步）
## 多章节：指定显示第几个章节（测试 / 调试用）；-1 = 自动（最近关卡所在章节；不在任何章节时取带一级地图的章节）
static var chapter_index: int = -1
var region_id: String = ""               ## 当前显示的区域（"" = 整章显示）
var panel_open: bool = true              ## 右侧详情面板是否展开
var revealing: Array[String] = []        ## 正在 / 等待播放解锁动画的节点（显示为锁住）
var _panel_t: float = 0.0                ## 面板收起进度：0 展开 → 1 收起
var _panel_tween: Tween = null
var _scroll_tween: Tween = null
var _reveal_tween: Tween = null
var _burst: UnlockBurst = null


func _ready() -> void:
	_background.color = Color.WHITE
	var bm := ShaderMaterial.new()          # 地图后面：暗品红底光（与一级地图相同）
	bm.shader = BACKDROP_SHADER
	_background.material = bm
	var far := _make_petals("PetalsFar", 24, 0.7)
	move_child(far, _background.get_index() + 1)
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	var chapters: Array[ChapterDef] = DataRegistry.get_chapters()
	chapter = chapters[_pick_chapter(chapters)] if not chapters.is_empty() else null
	region_id = pick_region()
	_back_button.text = DataRegistry.get_string("ui.back")
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.set_meta("sfx_press", "ui_back")
	_settings_button.text = DataRegistry.get_string("ui.menu_settings")
	_settings_button.pressed.connect(func() -> void: SceneRouter.open_settings())      # 10 §2：章节地图顶栏「设置」
	_back_button.tooltip_text = _back_button.text      # 2026-10-20：返回 / 设置改为与战斗 HUD 同款无字图标，悬停提示文字
	_settings_button.tooltip_text = _settings_button.text
	_enter_button.text = DataRegistry.get_string("ui.node_enter")
	_enter_button.pressed.connect(_on_enter_pressed)
	_enter_button.set_meta("sfx_press", "ui_confirm_major")
	_replay_button.text = DataRegistry.get_string("ui.replay")
	_replay_button.tooltip_text = _replay_button.text
	_replay_button.pressed.connect(_on_replay_pressed)
	for b: BaseButton in [_back_button, _settings_button, _enter_button, _replay_button] as Array[BaseButton]:
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
	var near := _make_petals("PetalsNear", 14, 1.0)      # 前层花瓣：地图之上、节点之下
	near.reparent(_viewport)
	_viewport.move_child(near, _node_clip.get_index())
	_viewport.gui_input.connect(_on_viewport_input)
	_viewport.resized.connect(_layout)
	resized.connect(_place_skin)
	revealing = pending_reveals()
	if not revealing.is_empty():
		var lids: Array = revealing.map(func(nid: String) -> String: return str(chapter.node_of(nid)["level"]))
		SaveManager.mark_revealed("levels_revealed", lids)
		if not UiKit.motion_enabled:
			revealing.clear()
	_build_nodes()
	_burst = UnlockBurst.new()
	_burst.name = "UnlockBurst"
	_burst.z_index = 5
	_node_layer.add_child(_burst)
	_layout()
	set_panel_open(false, true)      # 进入时不显示详情面板，点节点才滑出
	select_node(default_node())
	center_on(selected_id)
	story_select = StorySelect.new()
	story_select.name = "StorySelect"
	add_child(story_select)
	story_select.entry_chosen.connect(_on_replay_chosen)
	_story = STORY_PLAYER_SCENE.instantiate() as StoryPlayer
	add_child(_story)                                   # 剧情层在浮层之上
	_story.set_base_material(_background.material)      # 选关里播剧情：背景用最后方的品红底光，不透出地图
	_story.finished.connect(_on_story_finished)
	_play_unlock_stories.call_deferred()
	_start_reveals.call_deferred()


func _make_petals(n: String, amount: int, depth: float) -> LilyPetals:
	var p := LilyPetals.new()
	p.name = n
	p.count = amount
	p.depth = depth
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	return p


## 换皮：主题；框体 / 分隔线等贴图节点（2026-10-21 用户：底部横向滚动条删掉——地图不够长）；场景里各节点的主题变体；摆放见 _place_skin
func _apply_skin() -> void:
	theme = UiKit.ui_theme(SKIN)
	_background.color = Palette.BG_DEEP
	for id: String in ["panel_top", "panel_bottom", "ph_plaque", "ph_panel", "moon_orn", "astro_orn", "gem1_orn", "gem2_orn", "gem3_orn", "gem4_orn", "sep_top", "sep_bottom", "title_plaque", "title_moon", "title_line"]:
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
		"btn_replay": _replay_button,
	}
	for id: String in pairs.keys():
		var c: Control = pairs[id] as Control
		c.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
		_skin[id] = c
		if c is Label:
			(c as Label).clip_text = true
			(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			(c as Label).horizontal_alignment = UiKit.text_align(str(UiKit.layout_element(SKIN, id).get("align", "left")))      # 哥特面板：关名居中
		elif c is Button:
			(c as Button).clip_text = true
	_detail_summary.clip_text = false
	_detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_objective.clip_text = false
	_detail_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_locked.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "objective").get("theme_type", "")))
	_detail_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_skin()
	for id: String in ["title", "level_title", "region", "ph_title"]:
		var l: Label = _skin[id] as Label
		_skin[id] = ScrollText.wrap(l, ScrollText.Mode.AUTO)


func _make_label(id: String) -> Label:
	var l := Label.new()
	l.name = "Skin_" + id
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = UiKit.text_align(str(UiKit.layout_element(SKIN, id).get("align", "left")))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.get_node("DetailColumn").add_child(l)
	_skin[id] = l
	return l


## 按布局摆放（设计坐标 → 屏幕坐标只在 UiKit.layout_rect 一处换算）；下框的特征 / 任务 / 状态按文字实际高度顺排
func _place_skin() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var slid: float = _detail.position.x                 # 收起时面板整体右移：按展开位置摆放，再移回去
	_detail.position.x = 0.0
	for id: String in _skin.keys():
		if id in ["sep_bottom", "summary", "objective", "objective_head", "state"] and _lower != null:
			continue
		var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
		UiKit.place(_skin[id] as Control, UiKit.layout_text_rect(SKIN, id, vp) if text else UiKit.layout_rect(SKIN, id, vp))
	_flow_detail()
	_detail.position.x = slid
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
	var slid: float = _detail.position.x
	_detail.position.x = 0.0
	UiKit.place(_lower_scroll, Rect2(sm.position.x, sm.position.y, sm.size.x, inner_bottom - sm.position.y))
	_detail.position.x = slid


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
		var node_px: float = node_size * (float(nd.get("boss_scale", 1.3)) if bool(n["boss"]) else (float(nd.get("elite_scale", 1.15)) if bool(n.get("elite", false)) else 1.0))
		b.custom_minimum_size = Vector2(node_px, node_px)
		b.size = Vector2(node_px, node_px)
		b.focus_mode = Control.FOCUS_NONE
		b.pivot_offset = b.size * 0.5
		b.text = str(level.display_index) if level != null else ""
		b.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate_text").get("theme_type", "")))
		var art: Texture2D = Art.texture(NODE_ART_DIR + "%s.png" % str(n["node_art"])) if str(n["node_art"]) != "" else null
		if bool(n.get("elite", false)) and level != null and not level.reward_relics().is_empty():     # 精英关：节点图标 = 奖励遗物
			art = Art.texture(str(DataRegistry.get_relic(level.reward_relics()[0]).get("icon", "")))
		if art != null:
			b.icon = art
			b.expand_icon = true
			b.text = ""
		b.pressed.connect(_on_node_pressed.bind(nid))
		b.set_meta("sfx_press", "")              # 点击音由 _on_node_pressed 按锁定与否自己播
		_node_layer.add_child(b)
		var disc := TextureRect.new()           # 节点徽章（按状态换图，画在按钮图标之下；边长 = 金环直径 × art_scale）
		disc.name = "Disc"
		disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.show_behind_parent = true
		disc.size = Vector2(node_px, node_px) * float(nd.get("art_scale", 1.0))
		var art_off := Vector2.ZERO
		if nd.has("art_size"):                  # 2026-10-19 哥特节点：竖长切图按原尺寸（随首领 / 精英缩放）画，偏移让上半身对准节点坐标
			var k: float = node_px / node_size
			disc.size = Vector2(float((nd["art_size"] as Array)[0]), float((nd["art_size"] as Array)[1])) * k
			art_off = Vector2(float((nd.get("art_offset", [0, 0]) as Array)[0]), float((nd.get("art_offset", [0, 0]) as Array)[1])) * k
		disc.position = (Vector2(node_px, node_px) - disc.size) * 0.5 + art_off
		if not UiKit.layout_element(SKIN, "node_shade").is_empty():      # 哥特节点：图标后一块左右渐隐的黑底，让图标融进地图
			var shade := TextureRect.new()
			shade.name = "Shade"
			shade.texture = Art.texture(str(UiKit.layout_element(SKIN, "node_shade").get("file", "")))
			shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shade.stretch_mode = TextureRect.STRETCH_SCALE
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shade.show_behind_parent = true
			shade.size = UiKit.layout_rect(SKIN, "node_shade", vp).size * (node_px / node_size)
			shade.position = disc.position + (disc.size - shade.size) * 0.5
			b.add_child(shade)
		b.add_child(disc)
		var plate_bg := Panel.new()            # 名牌胶囊（P6 #24 名牌切片）
		plate_bg.name = "PlateBg"
		plate_bg.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate").get("theme_type", "")))
		plate_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate_bg.material = UnlockBurst.flash_material()
		b.add_child(plate_bg)
		var name_label := Label.new()
		name_label.name = "Nameplate"
		name_label.text = node_label(nid)
		name_label.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate_text").get("theme_type", "")))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.material = UnlockBurst.flash_material()
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
		var st: Dictionary = UiKit.layout_element(SKIN, "score_tag")
		if not st.is_empty():                    # 哥特换皮：综合分铭牌切片（横向九宫格）代替金边胶囊
			var tex := StyleBoxTexture.new()
			tex.texture = Art.texture(str(st.get("file", "")))
			var np_: Array = st.get("ninepatch", [0, 0, 0, 0]) as Array
			var cm: Array = (st.get("data", {}) as Dictionary).get("content", np_) as Array
			for i: int in 4:
				tex.set_texture_margin(i as Side, float(np_[i]))
				tex.set_content_margin(i as Side, float(cm[i]))
			score_tag.add_theme_stylebox_override("panel", tex)
		var score_text := Label.new()
		score_text.name = "Text"
		score_text.theme_type_variation = name_label.theme_type_variation
		score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var sd: Dictionary = st.get("data", {}) as Dictionary
		score_text.add_theme_color_override("font_color", Color(str(sd["color"])) if sd.has("color") else Palette.ALCHEMY_GOLD)
		score_text.add_theme_font_size_override("font_size", int(sd.get("font_size", SCORE_TAG_FONT)))
		score_tag.add_child(score_text)
		score_tag.set_meta(&"anchor", center + Vector2(0.0, plate.size.y * SCORE_TAG_OFFSET))
		b.add_child(score_tag)
		for m: Array in [["Lock", "node_lock_marker"], ["Check", "node_check_marker"]]:     # 已完成角标（右下）；锁压在名牌正中（2026-10-20），尺寸取布局
			var mark := TextureRect.new()
			mark.name = str(m[0])
			mark.texture = Art.texture(str(UiKit.layout_element(SKIN, str(m[1])).get("file", "")))
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.size = UiKit.layout_rect(SKIN, str(m[1]), vp).size
			if str(m[0]) == "Lock":
				mark.position = (plate.size - mark.size) * 0.5
				mark.pivot_offset = mark.size * 0.5
				mark.material = UnlockBurst.flash_material()
				plate_bg.add_child(mark)
			else:
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
	if level.elite:
		return DataRegistry.get_string("ui.elite_plate").format({ "title": level.title })
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


## 显示用的状态：等解锁动画的节点仍按锁定显示
func shown_state(node_id: String) -> int:
	return 0 if revealing.has(node_id) else node_state(node_id)


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
		var state: int = shown_state(nid)
		var sel: bool = highlighted and nid == selected_id
		var n: Dictionary = chapter.node_of(nid)
		var tex_id: String = ["node_tex_locked", "node_tex_open", "node_tex_done"][state]
		var elite: bool = bool(n.get("elite", false))
		if bool(n.get("boss", false)) or elite:
			tex_id = "node_tex_boss"
		elif sel:
			tex_id = "node_tex_selected"
		(b.get_node("Disc") as TextureRect).texture = Art.texture(str(UiKit.layout_element(SKIN, tex_id).get("file", "")))
		var disc_tint: Color = ELITE_DISC_TINT if elite else Color.WHITE      # 精英关：首领徽章染暗红
		if not elite and nd.has("locked_modulate"):      # 哥特节点只有一张图标：锁定压暗、未选中略暗、选中原色（布局 node.data）
			disc_tint = Color(str(nd["locked_modulate"]) if state == 0 else ("#FFFFFF" if sel else str(nd.get("idle_modulate", "#FFFFFF"))))
		UiKit.ease_to(b.get_node("Disc"), "modulate", disc_tint)      # 2026-10-19：选中 / 非选中缓动
		var pad: float = b.size.x * (1.0 - float(nd.get("icon_ratio", 0.5))) * 0.5
		var box := StyleBoxEmpty.new()
		box.set_content_margin_all(pad)
		for style: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(style, box)
		b.add_theme_stylebox_override("focus", empty)
		var glyph := Color(str(nd.get("glyph_locked" if state == 0 else "glyph_color", "#FFFFFF")))
		if elite:                                  # 遗物图标保留原色，锁定时压暗
			glyph = Color(0.45, 0.42, 0.5) if state == 0 else Color.WHITE
		for c: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "font_color"]:
			b.add_theme_color_override(c, glyph)
		var target_scale: float = float(nd.get("selected_scale", 1.3)) if sel else 1.0
		b.z_index = 1 if sel else 0
		var hidden: bool = state == 0 and not bool(n.get("placeholder", false))      # 占位节点（未开放的后续内容）照旧写「未开放」、不压锁
		(b.get_node("PlateBg/Lock") as Control).visible = hidden
		(b.get_node("Check") as Control).visible = state == 2
		var plate_bg: Control = b.get_node("PlateBg") as Control
		UiKit.ease_to(plate_bg, "modulate", Color(str(pd.get("selected_modulate", "#FFFFFF"))) if sel else (LOCKED_PLATE_TINT if hidden else Color.WHITE))
		var name_plate: Label = b.get_node("Nameplate") as Label
		name_plate.text = "" if hidden else node_label(nid)      # 打到之前看不见名字
		if sel:
			name_plate.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
		else:
			name_plate.remove_theme_color_override("font_color")
		var score_tag: Control = b.get_node("ScoreTag") as Control
		var lid: String = str(n.get("level", ""))
		var best: int = SaveManager.best_score(lid) if state == 2 and lid != "" else -1
		score_tag.visible = best >= 0
		(score_tag.get_node("Text") as Label).text = DataRegistry.get_string("ui.level_best_score").format({ "total": best }) if best >= 0 else ""
		score_tag.tooltip_text = Scoring.tip_text(SaveManager.best_score_detail(lid)) if best >= 0 else ""      # 悬停看分数构成
		score_tag.mouse_filter = Control.MOUSE_FILTER_PASS if best >= 0 else Control.MOUSE_FILTER_IGNORE
		score_tag.reset_size()
		score_tag.position = (score_tag.get_meta(&"anchor") as Vector2) - score_tag.size * 0.5
		for c: Control in [plate_bg, name_plate, score_tag] as Array[Control]:
			c.pivot_offset = c.size * 0.5
		_ease_node_scale(b, target_scale)


## 节点放大（选中）缓动；名牌 / 综合分标签同步反向缩放，始终保持原大小（参数 data/ui_motion.json 的 state_ease）
func _ease_node_scale(b: Button, target: float) -> void:
	var apply := func(s: float) -> void:
		b.scale = Vector2.ONE * s
		for n: String in ["PlateBg", "Nameplate", "ScoreTag"]:
			(b.get_node(n) as Control).scale = Vector2.ONE / s
	var old: Tween = b.get_meta(&"_scale_tween", null) as Tween if b.has_meta(&"_scale_tween") else null
	if old != null and old.is_valid():
		old.kill()
	if not UiKit.motion_enabled or not b.is_inside_tree() or is_equal_approx(b.scale.x, target):
		apply.call(target)
		return
	var p: Dictionary = UiKit.motion_params("state_ease")
	var t: Tween = b.create_tween()
	t.tween_method(apply, b.scale.x, target, float(p.get("duration", 0.18))).set_trans(UiKit.motion_trans(p)).set_ease(UiKit.motion_ease(p))
	b.set_meta(&"_scale_tween", t)


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


## 点击节点 = 选中（不进关）；详情面板收起时滑回；把节点滚到可见区横向正中（可出框，收起面板时弹回）
## 音效：锁定节点 locked_click + ui_error（锁晃一下，仍可选中看详情），其余 node_select（地图滚动、面板滑出不另配音）
func _on_node_pressed(node_id: String) -> void:
	if shown_state(node_id) == 0:
		AudioManager.play_ui("locked_click")
		AudioManager.play_ui("ui_error", -6.0)
		_wiggle_lock(node_id)
	else:
		AudioManager.play_ui("node_select")
	highlighted = true
	select_node(node_id)
	if panel_open:
		var x: float = center_scroll(node_id, _open_width())
		_scroll_to(x, PANEL_TIME, Tween.TRANS_CUBIC)
	else:
		set_panel_open(true)


## 点锁定节点：名牌上的锁左右晃两下（与一级地图相同；解锁动画中不晃）
func _wiggle_lock(node_id: String) -> void:
	var b: Button = node_buttons.get(node_id, null) as Button
	if b == null or not UiKit.motion_enabled or revealing.has(node_id):
		return
	var lock: Control = b.get_node("PlateBg/Lock") as Control
	if not lock.visible or lock.has_meta(&"wiggling"):
		return
	lock.set_meta(&"wiggling", true)
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void: lock.rotation = sin(k * TAU * 2.5) * 0.22 * (1.0 - k), 0.0, 1.0, 0.4)
	tw.tween_callback(func() -> void:
		lock.rotation = 0.0
		lock.remove_meta(&"wiggling"))


## 选中（不进关）
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
	if _burst != null:
		_burst.size = _content.size
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
	var edge := ShaderMaterial.new()         # 2026-10-20：左右沿腐蚀线羽化，露出后面的品红底光（不再接镜像图）
	edge.shader = EDGE_SHADER
	edge.set_shader_parameter("edge_uv", Vector2(FEATHER_PX / maxf(_content.size.x, 1.0), 0.0))
	r.material = edge
	_content.add_child(r)
	_content.move_child(r, 0)


## 地图可见宽 = 详情面板左缘（地图铺满窗口，面板浮在右侧）；布局有 map_view 时取其右缘（哥特面板左侧是渐隐，不透明处才算面板）。
## 面板收起时按收起进度过渡到整个窗口宽
func visible_width() -> float:
	return lerpf(_open_width(), get_viewport_rect().size.x, _panel_t)


func _open_width() -> float:
	var vp: Vector2 = get_viewport_rect().size
	if not UiKit.layout_element(SKIN, "map_view").is_empty():
		return UiKit.layout_rect(SKIN, "map_view", vp).end.x
	return UiKit.layout_rect(SKIN, "panel_top", vp).position.x


## 可滚范围（x = 下限，y = 上限）：地图宽于可见区时 [0, 地图宽 − 可见宽]；窄于可见区时居中（上下限相等，为负）
func scroll_range(vis: float = -1.0) -> Vector2:
	var v: float = visible_width() if vis < 0.0 else vis
	var w: float = _content.size.x
	if w <= v:
		return Vector2.ONE * (w - v) * 0.5
	return Vector2(0.0, w - v)


func max_scroll() -> float:
	return scroll_range().y


func min_scroll() -> float:
	return scroll_range().x


## 直接滚到 x（限制在范围内，打断弹回）
func set_scroll(x: float) -> void:
	_kill_scroll_tween()
	var r: Vector2 = scroll_range()
	_apply_scroll(clampf(x, r.x, r.y))


## 不限制范围地摆放（拖出框 / 弹回动画用）
func _apply_scroll(x: float) -> void:
	scroll_x = x
	_content.position.x = -scroll_x
	if _node_layer != null:
		_node_layer.position.x = -scroll_x


func _kill_scroll_tween() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null


## 平滑滚到 x（x 已限制在目标范围内）；无动效时直接到位
func _scroll_to(x: float, duration: float = SPRING_TIME, trans: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	_kill_scroll_tween()
	if not UiKit.motion_enabled or not is_inside_tree() or is_equal_approx(x, scroll_x):
		_apply_scroll(x)
		return
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_apply_scroll, scroll_x, x, duration).set_trans(trans).set_ease(Tween.EASE_OUT)


## 拖动时的橡皮筋：范围内一比一；出框部分越拉越紧，渐近视口宽的 1/8（不硬卡）。
## 按下时已出框（选中节点居中）则范围扩到按下位置，拖动起步不跳
func _rubber(x: float) -> float:
	var r: Vector2 = scroll_range()
	r = Vector2(minf(r.x, _press_scroll), maxf(r.y, _press_scroll))
	var lim: float = get_viewport_rect().size.x * OVERSCROLL_FRAC
	if x < r.x:
		return r.x - lim * (1.0 - exp(-(r.x - x) / lim))
	if x > r.y:
		return r.y + lim * (1.0 - exp(-(x - r.y) / lim))
	return x


## 松手：出框则弹回范围内
func _spring_back() -> void:
	var r: Vector2 = scroll_range()
	if scroll_x < r.x - 0.01 or scroll_x > r.y + 0.01:
		_scroll_to(clampf(scroll_x, r.x, r.y))


# ---- 详情面板收起 / 展开 ----
## 收起 = 面板整体向右滑出窗口，地图可见宽铺满窗口，同时立刻弹回可滚范围内；
## 展开时把选中节点滚到可见区横向正中（可出框）。instant：不播动画（进场用）
func set_panel_open(open: bool, instant: bool = false) -> void:
	if open == panel_open:
		return
	panel_open = open
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	var target: float = 0.0 if open else 1.0
	var vis: float = lerpf(_open_width(), get_viewport_rect().size.x, target)
	var r: Vector2 = scroll_range(vis)
	var want: float = center_scroll(selected_id, vis) if open else clampf(scroll_x, r.x, r.y)
	if not instant and not open:           # 滑出由点节点的 node_select 出声；收起（点空白处）这次点击本身要有声音
		AudioManager.play_ui("ui_panel_close")
	if instant or not UiKit.motion_enabled or not is_inside_tree():
		_apply_panel(target)
		_kill_scroll_tween()
		_apply_scroll(want)
		return
	_panel_tween = create_tween()
	_panel_tween.tween_method(_apply_panel, _panel_t, target, PANEL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN_OUT)
	_scroll_to(want, PANEL_TIME, Tween.TRANS_CUBIC)


func _apply_panel(t: float) -> void:
	_panel_t = t
	_detail.position.x = t * _panel_slide()
	if _node_clip != null:
		_node_clip.size.x = visible_width()


## 面板滑出的距离：面板（含左侧渐隐与纹饰）整个出窗口
func _panel_slide() -> float:
	var vp: Vector2 = get_viewport_rect().size
	return vp.x - UiKit.layout_rect(SKIN, "panel_top", vp).position.x + 40.0


## 让节点落在可见宽 vis 横向正中所需的滚动量（不限制范围，可出框）
func center_scroll(node_id: String, vis: float) -> float:
	var n: Dictionary = chapter.node_of(node_id) if chapter != null else {}
	if n.is_empty():
		return scroll_x
	return (n["pos"] as Vector2).x * _scale - vis * 0.5


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
					_kill_scroll_tween()
					_pressing = true
					_dragging = false
					_press_pos = mb.position
					_press_scroll = scroll_x
				else:
					var was_click: bool = _pressing and not _dragging
					_pressing = false
					_dragging = false
					_spring_back()
					if was_click and mb.position.x < visible_width():      # 点地图空白处：收起详情面板
						set_panel_open(false)
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
			_apply_scroll(_rubber(_press_scroll - (mm.position.x - _press_pos.x)))


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
	var state: int = shown_state(selected_id)
	var level: LevelDefinition = DataRegistry.get_level(str(n.get("level", ""))) if not bool(n.get("placeholder", false)) else null
	if level != null:
		_level_no.text = RuleText.level_label(level)
		if bool((UiKit.layout_element(SKIN, "level_no").get("data", {}) as Dictionary).get("short_no", false)):    # 哥特面板：八芒星里只放短编号「01」
			_level_no.text = RuleText.level_no(level)
		_detail_title.text = level.title
		_detail_summary.text = level.summary if level.summary != "" else level.subtitle
		if not level.reward_relics().is_empty():          # 2026-10-20 精英关去掉后遗物改由剧情关掉落
			_detail_summary.text += "\n" + DataRegistry.get_string("ui.detail_elite_note" if level.elite else "ui.detail_relic_note").format({ "name": str(DataRegistry.get_relic(level.reward_relics()[0]).get("name", "")) })
		_detail_objective.text = level.objective_text
		if state == 0:                              # 打到之前看不见名字与内容，只留前置关卡
			_detail_title.text = DataRegistry.get_string("ui.node_unknown")
			_detail_summary.text = ""
			_detail_objective.text = ""
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
	_detail_state.tooltip_text = Scoring.tip_text(SaveManager.best_score_detail(level.id)) if best >= 0 else ""     # 悬停看综合分构成
	_detail_state.mouse_filter = Control.MOUSE_FILTER_PASS if best >= 0 else Control.MOUSE_FILTER_IGNORE
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
				names.append("%s %s" % [RuleText.level_label(pl), pl.title])
		_detail_locked.text = DataRegistry.get_string("ui.node_locked_by").format({ "levels": DataRegistry.get_string("ui.list_sep").join(names) })
	_fill_replay(level)
	_apply_detail_mode()
	ArtText.attach(_detail_title, SKIN, "level_title")         # P8：关卡名、章节名艺术字（R6b；选中首领关时章节名用 boss 款）
	ArtText.attach(_title, SKIN, "title", "boss" if bool(n.get("boss", false)) else "")
	_flow_detail.call_deferred()


## 「剧情回放」：该关 _intro / _win 任一在 stories_seen 里才显示；占位 / 无关卡时不显示
func _fill_replay(level: LevelDefinition) -> void:
	var ph: bool = bool(chapter.node_of(selected_id).get("placeholder", false))
	_replay_button.visible = level != null and not ph and not replay_ids().is_empty()


## 当前选中关卡可回放的剧情 id（按显示顺序：开头 / 结尾）
func replay_ids() -> Array[String]:
	var out: Array[String] = []
	var n: Dictionary = chapter.node_of(selected_id) if chapter != null else {}
	var level: LevelDefinition = DataRegistry.get_level(str(n.get("level", "")))
	if level == null or bool(n.get("placeholder", false)):
		return out
	for kind: String in REPLAY_KINDS:
		if SaveManager.is_story_seen("%s_%s" % [level.id, kind]):
			out.append("%s_%s" % [level.id, kind])
	return out


## 打开剧情选择：开头 / 结尾两卡，没看过的锁定
func _on_replay_pressed() -> void:
	var level: LevelDefinition = DataRegistry.get_level(str(chapter.node_of(selected_id).get("level", "")))
	if level == null:
		return
	story_select.open("%s  %s" % [RuleText.level_no(level), level.title], replay_entries(level.id))


## 某关的回放卡（主界面图鉴共用）：开头剧情 / 结尾剧情，未看过 = 锁定
static func replay_entries(level_id: String) -> Array:
	var out: Array = []
	for kind: String in REPLAY_KINDS:
		var sid: String = "%s_%s" % [level_id, kind]
		out.append({ "title": DataRegistry.get_string("ui.replay_intro" if kind == "intro" else "ui.replay_end"),
			"story": sid, "locked": not SaveManager.is_story_seen(sid) })
	return out


func _on_replay_chosen(entry: Dictionary) -> void:
	_replaying = true
	story_select.suspend()
	if not _story.play_story(str(entry.get("story", ""))):      # 回放不改 stories_seen
		_on_story_finished()


func _on_story_finished() -> void:
	if _replaying:
		_replaying = false
		story_select.resume()


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



# ---- 解锁动画 ----
## 本区域里已解锁、还没揭开过的关卡节点（开局就开放的关卡不算）。旧存档没有揭开记录时补种为「已通关的关卡」，即可挑战未通关的补播一次
func pending_reveals() -> Array[String]:
	var seen: Variant = SaveManager.revealed("levels_revealed")
	if seen == null:
		seen = (GameState.progress.get("completed", []) as Array).duplicate()
		SaveManager.data["levels_revealed"] = seen
	var initial: Array = DataRegistry.get_initial_levels()
	var out: Array[String] = []
	for n: Dictionary in shown_nodes():
		if bool(n["placeholder"]) or DataRegistry.get_level(str(n["level"])) == null:
			continue
		var lid: String = str(n["level"])
		if node_state(str(n["id"])) != 0 and not initial.has(lid) and not (seen as Array).has(lid):
			out.append(str(n["id"]))
	return out


## 进场后（有解锁剧情时等它播完）依次播放解锁动画
func _start_reveals() -> void:
	if revealing.is_empty():
		return
	if _story != null and _story.is_playing():
		await _story.finished
	if not is_inside_tree():
		return
	_play_reveals(revealing.duplicate(), REVEAL_DELAY)


func _play_reveals(ids: Array, delay: float) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	for nid: String in ids:
		if not revealing.has(nid):
			revealing.append(nid)
	_restyle_nodes()
	_refresh_detail()
	var tw: Tween = create_tween()
	_reveal_tween = tw
	tw.tween_interval(delay)
	for i: int in ids.size():
		var nid: String = str(ids[i])
		var b: Button = node_buttons[nid] as Button
		if i > 0:
			tw.tween_interval(REVEAL_GAP)
		_burst.append_reveal(tw, b.get_node("PlateBg/Lock") as Control, b.get_node("PlateBg") as Control, b.get_node("Nameplate") as Control,
			_reveal_name.bind(nid), _reveal_done.bind(nid))


func _reveal_name(nid: String) -> void:
	revealing.erase(nid)
	_restyle_nodes()
	if nid == selected_id:
		_refresh_detail()
	_node_layer.queue_redraw()


func _reveal_done(nid: String) -> void:
	revealing.erase(nid)


## 测试 / 跳过：立刻结束所有解锁动画
func skip_reveals() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	revealing.clear()
	_burst.clear()
	for nid: String in node_buttons.keys():
		var b: Button = node_buttons[nid] as Button
		var lock: Control = b.get_node("PlateBg/Lock") as Control
		for c: Control in [b.get_node("PlateBg") as Control, b.get_node("Nameplate") as Control, lock]:
			UnlockBurst.set_flash(c, 0.0)
		lock.rotation = 0.0
		lock.scale = Vector2.ONE
		lock.position = lock.get_meta(&"shake_base", lock.position) as Vector2
	_restyle_nodes()
	_refresh_detail()


## 调试版 F9：重播选中关卡的解锁动画（只是表现，不改存档）
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9 or not OS.is_debug_build() or chapter == null:
		return
	if node_state(selected_id) != 0 and not DataRegistry.get_initial_levels().has(str(chapter.node_of(selected_id).get("level", ""))):
		skip_reveals()
		_play_reveals([selected_id], 0.3)


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
