extends Control
## 2026-10-18 一级地图（选区域）：腐土平原七个区域（人偶工坊 → 枯骨农田 → 灰棘林 → 圣钟城废墟 → 肉巢沼泽 → 畸变回廊 → 骨花温室）。
## - 数据：带 world 的章节（DataRegistry.world_chapter()，现为 chapter_02）——world.map 整图、各区域 world_pos（图标中心）。
## - 地图按窗口高等比，放在详情面板左侧居中；每个区域图标上一块热区：点击 = 选中（金环），再点已选中的已解锁区域 = 进入。
## - 区域名牌：区域名 + 进度（已通关 / 关卡数）；未解锁的区域压暗并带锁，已全部通关的带勾。
## - 右侧详情（与选关同一套换皮 chapter）：第 N 区、区域名、进度；本区关卡列表与状态；未解锁时写明前置关卡；「进入区域」。
## - 解锁：区域内任一关解锁即解锁（沿用章节解锁规则，c06 通关解锁枯骨农田首关 c07 …）。

signal region_entered(region_id: String)

const SKIN: String = "chapter"
const MENU_BGM: String = "menu_main"
const HOTSPOT_PX: float = 230.0           ## 热区边长（一级地图坐标）

var chapter: ChapterDef = null
var selected_id: String = ""
var navigate: bool = true                 ## false：「进入」只发 region_entered（测试用）
var hotspots: Dictionary = {}             ## 区域 id -> Button
var _map: TextureRect
var _overlay: Control                     ## 金环 / 压暗 / 锁 / 勾（画在地图之上）
var _plates: Dictionary = {}              ## 区域 id -> Label（名牌文字）
var _plate_bgs: Dictionary = {}
var _title: Label
var _back: Button
var _settings: Button
var _region_no: Label
var _region_title: Label
var _progress: Label
var _status: Label                        ## 下框第一行：下一关 / 已全部通关 / 前置关卡
var _list: VBoxContainer
var _locked_by: Label
var _enter: Button
var _lock_tex: Texture2D
var _check_tex: Texture2D
var _panels: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.ui_theme(SKIN)
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	chapter = DataRegistry.world_chapter()
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Palette.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_map = TextureRect.new()
	_map.name = "WorldMap"
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_lock_tex = Art.texture(str(UiKit.layout_element(SKIN, "node_lock_marker").get("file", "")))
	_check_tex = Art.texture(str(UiKit.layout_element(SKIN, "node_check_marker").get("file", "")))
	_build_chrome()
	if chapter == null:
		return
	_map.texture = Art.texture(str(chapter.world.get("map", "")))
	_title.text = chapter.title
	for r: Dictionary in chapter.regions:
		_build_hotspot(str(r["id"]))
	resized.connect(_layout)
	_layout()
	select_region(default_region())


# ---- 界面骨架（与选关同一套布局元素）----
func _build_chrome() -> void:
	for id: String in ["title_plaque", "panel_top", "panel_bottom", "sep_top", "sep_bottom"]:
		var c: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		c.name = "Skin_" + id
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		c.set_meta(&"skin_id", id)
		_panels.append(c)
	_title = _label("title")
	_region_no = _label("level_no")
	_region_title = _label("level_title")
	_progress = _label("region")
	_status = _label("summary")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.clip_text = false
	var head: Label = _label("objective_head")
	head.text = DataRegistry.get_string("ui.region_levels")
	_list = VBoxContainer.new()
	_list.name = "LevelList"
	_list.add_theme_constant_override("separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	_locked_by = Label.new()                 # 兼容字段：前置关卡说明并入 _status
	_locked_by.visible = false
	_back = _button("btn_back", DataRegistry.get_string("ui.back"), func() -> void: SceneRouter.goto_main_menu())
	_settings = _button("btn_settings", DataRegistry.get_string("ui.menu_settings"), func() -> void: SceneRouter.open_settings())
	_enter = _button("btn_enter", DataRegistry.get_string("ui.region_enter"), func() -> void: enter_region(selected_id))
	_enter.name = "EnterButton"


func _label(id: String) -> Label:
	var l := Label.new()
	l.name = "Skin_" + id
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta(&"skin_id", id)
	add_child(l)
	_panels.append(l)
	return l


func _button(id: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = "Skin_" + id
	b.text = text
	b.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.pressed.connect(cb)
	b.set_meta(&"skin_id", id)
	add_child(b)
	_panels.append(b)
	return b


func _build_hotspot(rid: String) -> void:
	var b := Button.new()
	b.name = "Region_" + rid
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = chapter.region_title(rid)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(_on_hotspot.bind(rid))
	b.mouse_entered.connect(_overlay.queue_redraw)
	b.mouse_exited.connect(_overlay.queue_redraw)
	add_child(b)
	hotspots[rid] = b
	var plate := Panel.new()
	plate.name = "PlateBg_" + rid
	plate.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate").get("theme_type", "")))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	_plate_bgs[rid] = plate
	var l := Label.new()
	l.name = "Plate_" + rid
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate_text").get("theme_type", "")))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_plates[rid] = l


# ---- 布局 ----
## 一级地图在屏幕上的矩形：按窗口高等比，居中于详情面板左侧
func map_rect() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var ms: Vector2 = chapter.world.get("map_size", Vector2(1080.0, 1080.0)) as Vector2 if chapter != null else Vector2(1080.0, 1080.0)
	var panel_left: float = UiKit.layout_rect(SKIN, "panel_top", vp).position.x
	var k: float = minf(vp.y / ms.y, panel_left / ms.x)
	var sz: Vector2 = ms * k
	return Rect2(Vector2(maxf(0.0, (panel_left - sz.x) * 0.5), (vp.y - sz.y) * 0.5), sz)


## 区域图标中心的屏幕坐标
func region_screen_pos(rid: String) -> Vector2:
	var r: Rect2 = map_rect()
	var ms: Vector2 = chapter.world.get("map_size", Vector2.ONE) as Vector2
	return r.position + (chapter.region(rid).get("world_pos", Vector2.ZERO) as Vector2) * (r.size.x / ms.x)


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	for c: Control in _panels:
		var id: String = str(c.get_meta(&"skin_id"))
		var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
		UiKit.place(c, UiKit.layout_text_rect(SKIN, id, vp) if text else UiKit.layout_rect(SKIN, id, vp))
	var sm: Rect2 = UiKit.layout_text_rect(SKIN, "objective", vp)
	_list.position = sm.position
	_list.size = Vector2(sm.size.x, 0.0)
	var su: Rect2 = UiKit.layout_text_rect(SKIN, "summary", vp)
	_status.size = Vector2(su.size.x, su.size.y * 2.0)
	_status.position.y = su.position.y - su.size.y * 0.5
	if chapter == null:
		return
	var mr: Rect2 = map_rect()
	UiKit.place(_map, mr)
	UiKit.place(_overlay, Rect2(Vector2.ZERO, vp))
	var k: float = mr.size.x / (chapter.world.get("map_size", Vector2.ONE) as Vector2).x
	var plate: Rect2 = UiKit.layout_rect(SKIN, "plate", vp)
	for rid: String in hotspots.keys():
		var c: Vector2 = region_screen_pos(rid)
		var hs: float = HOTSPOT_PX * k
		var b: Button = hotspots[rid] as Button
		b.position = c - Vector2(hs, hs) * 0.5
		b.size = Vector2(hs, hs)
		var pr := Rect2(Vector2(c.x - plate.size.x * 0.5, c.y + hs * 0.42), plate.size)
		UiKit.place(_plate_bgs[rid] as Control, pr)
		UiKit.place(_plates[rid] as Control, pr)
	_overlay.queue_redraw()


# ---- 状态 ----
func _completed() -> Array:
	return GameState.progress.get("completed", []) as Array


func region_unlocked(rid: String) -> bool:
	return chapter.region_unlocked(rid, _completed(), DataRegistry.get_initial_levels())


func region_done(rid: String) -> bool:
	var p: Vector2i = chapter.region_progress(rid, _completed())
	return p.y > 0 and p.x == p.y


## 默认选中：当前区域（已解锁时）> 最后一个已解锁且未全部通关的区域 > 最后一个已解锁的区域 > 第一个
func default_region() -> String:
	if GameState.current_region_id != "" and hotspots.has(GameState.current_region_id) and region_unlocked(GameState.current_region_id):
		return GameState.current_region_id
	var frontier: String = ""
	var last: String = ""
	for r: Dictionary in chapter.regions:
		var rid: String = str(r["id"])
		if region_unlocked(rid):
			last = rid
			if not region_done(rid):
				frontier = rid
	if frontier != "":
		return frontier
	return last if last != "" else str(chapter.regions[0]["id"])


func select_region(rid: String) -> void:
	if not hotspots.has(rid):
		return
	selected_id = rid
	_refresh()


func _on_hotspot(rid: String) -> void:
	if rid == selected_id and region_unlocked(rid):
		enter_region(rid)
	else:
		select_region(rid)


func enter_region(rid: String) -> void:
	if not hotspots.has(rid) or not region_unlocked(rid):
		return
	GameState.current_region_id = rid
	region_entered.emit(rid)
	if navigate:
		SceneRouter.goto_region(rid)


func _refresh() -> void:
	for rid: String in hotspots.keys():
		var p: Vector2i = chapter.region_progress(rid, _completed())
		(_plates[rid] as Label).text = DataRegistry.get_string("ui.region_plate").format({ "title": chapter.region_title(rid), "done": p.x, "total": p.y })
		(_plates[rid] as Label).modulate = Color(1.0, 1.0, 1.0, 1.0 if region_unlocked(rid) else 0.55)
		(_plate_bgs[rid] as Control).modulate = (_plates[rid] as Label).modulate
	var rid2: String = selected_id
	var pr: Vector2i = chapter.region_progress(rid2, _completed())
	var unlocked: bool = region_unlocked(rid2)
	_region_no.text = DataRegistry.get_string("ui.region_no").format({ "n": chapter.region_index(rid2) + 1 })
	_region_title.text = chapter.region_title(rid2)
	_progress.text = DataRegistry.get_string("ui.region_progress").format({ "done": pr.x, "total": pr.y })
	UiKit.clear(_list)
	for lid: String in chapter.region_level_ids(rid2):
		var L: LevelDefinition = DataRegistry.get_level(lid)
		if L == null:
			continue
		var state: String = "region_state_done" if _completed().has(lid) else ("region_state_open" if chapter.is_unlocked(lid, _completed(), DataRegistry.get_initial_levels()) else "region_state_locked")
		var l := Label.new()
		l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "objective").get("theme_type", "")))
		l.text = DataRegistry.get_string("ui.region_level_line").format({ "no": "%02d" % L.display_index, "title": L.title, "state": DataRegistry.get_string("ui." + state) })
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(l)
	_status.text = status_text(rid2)
	_locked_by.text = _status.text if not unlocked else ""
	_enter.disabled = not unlocked
	_overlay.queue_redraw()


## 下框状态行：未解锁 → 前置关卡；全部通关 → 已全部通关；否则 → 下一关（第一个可挑战且未通关的关卡）
func status_text(rid: String) -> String:
	if not region_unlocked(rid):
		var req: String = chapter.region_requirement(rid)
		var rl: LevelDefinition = DataRegistry.get_level(req) if req != "" else null
		return DataRegistry.get_string("ui.region_locked_by").format({ "level": _level_name(rl) }) if rl != null else DataRegistry.get_string("ui.locked")
	if region_done(rid):
		return DataRegistry.get_string("ui.region_all_done")
	for lid: String in chapter.region_level_ids(rid):
		if not _completed().has(lid) and chapter.is_unlocked(lid, _completed(), DataRegistry.get_initial_levels()):
			return DataRegistry.get_string("ui.region_next").format({ "level": _level_name(DataRegistry.get_level(lid)) })
	return ""


static func _level_name(L: LevelDefinition) -> String:
	return "%s %s" % [DataRegistry.get_string("ui.level_label").format({ "index": L.display_index }), L.title] if L != null else ""


func _draw_overlay() -> void:
	if chapter == null:
		return
	var k: float = map_rect().size.x / (chapter.world.get("map_size", Vector2.ONE) as Vector2).x
	var r: float = HOTSPOT_PX * k * 0.5
	for rid: String in hotspots.keys():
		var c: Vector2 = region_screen_pos(rid)
		var b: Button = hotspots[rid] as Button
		if not region_unlocked(rid):
			_overlay.draw_circle(c, r, Color(0.05, 0.03, 0.06, 0.45))
			if _lock_tex != null:
				_overlay.draw_texture_rect(_lock_tex, Rect2(c - Vector2(18.0, 20.0), Vector2(36.0, 40.0)), false)
		elif region_done(rid) and _check_tex != null:
			_overlay.draw_texture_rect(_check_tex, Rect2(c + Vector2(r * 0.55, r * 0.35), Vector2(30.0, 34.0)), false)
		if rid == selected_id:
			_overlay.draw_arc(c, r, 0.0, TAU, 72, Palette.ALCHEMY_GOLD, 4.0, true)
		elif b.is_hovered():
			_overlay.draw_arc(c, r, 0.0, TAU, 72, Color(Palette.ALCHEMY_GOLD, 0.45), 2.0, true)
