extends Control
## 2026-10-18 一级地图（选区域）：腐土平原七个区域（人偶工坊 → 枯骨农田 → 灰棘林 → 圣钟城废墟 → 肉巢沼泽 → 畸变回廊 → 骨花温室）。
## - 数据：带 world 的章节（DataRegistry.world_chapter()，现为 chapter_02）——world.map 整图、各区域 world_pos（图标中心）。
## - 解锁：区域内任一关解锁即解锁（沿用章节解锁规则，c06 通关解锁枯骨农田首关 c07 …）。
## 2026-10-20 美化（用户）：
## - 去掉右侧详情面板与区域图标上的圆形（压暗圆 / 选中圈）；地图居中铺满窗口高。
## - 羊皮纸四边羽化，羽化沿腐蚀线推进（parchment_edge.gdshader）；地图后方是暗品红底光，缓慢亮暗循环（magenta_backdrop.gdshader，
##   品红取自原选关详情面板 #601050）；彼岸花瓣粒子向左上角飘散，前后两层，不亮、只散发微光（LilyPetals）。
## - 名牌：已解锁 = 区域名 + 进度（已通关 / 关卡数），全部通关的带勾；未解锁 = 空名牌 + 锁（锁直接压在名牌上，打到之前看不见名字）。
## - 点已解锁区域（图标或名牌）直接进入；点未解锁的，锁晃一下。下一个要去的区域名牌后有一团缓慢呼吸的微光。
## - 解锁动画：区域已解锁但还没揭开过（存档 regions_revealed 没有它）时，进场后先按锁住的样子显示，然后锁颤抖 → 炸成白色粒子 →
##   整块名牌闪白、白里换上区域名 → 渐变回原样。揭开记录在动画开始时写入存档，每个区域只播一次。
##   调试版按 F9 重播最近解锁的区域（只是表现，不改存档）。

signal region_entered(region_id: String)

const SKIN: String = "chapter"
const MENU_BGM: String = "menu_main"
const HOTSPOT_PX: float = 230.0           ## 区域图标热区边长（一级地图坐标）
const EDGE_SHADER: Shader = preload("res://assets/shaders/parchment_edge.gdshader")
const BACKDROP_SHADER: Shader = preload("res://assets/shaders/magenta_backdrop.gdshader")
const REVEAL_DELAY: float = 0.9           ## 进场后多久开始播解锁动画（等转场碎裂波散开）
const REVEAL_GAP: float = 0.35            ## 同时揭开多个区域时，前一个闪白结束到下一个开始颤抖的间隔
const GLOW_COLOR: Color = Color("#FFF1D2")
const HOVER_TINT: Color = Color(1.22, 1.18, 1.28, 1.0)
const LOCKED_TINT: Color = Color(0.78, 0.76, 0.80, 0.92)

var chapter: ChapterDef = null
var navigate: bool = true                 ## false：「进入」只发 region_entered（测试用）
var hotspots: Dictionary = {}             ## 区域 id -> Button（覆盖图标与名牌）
var revealing: Array[String] = []         ## 正在 / 等待播放解锁动画的区域（显示为锁住）
var _animating: Array[String] = []        ## 解锁动画从开始到渐变回原样期间的区域（不受悬停 / 呼吸光影响）
var frontier: String = ""                 ## 下一个要去的区域（最后一个已解锁且未全部通关的）
var _map: TextureRect
var _backdrop: ColorRect                  ## 暗品红底光
var _vignette: TextureRect
var _petals_far: LilyPetals
var _petals_near: LilyPetals
var _fx: Control                          ## 已通关的勾（画在名牌之上）
var _burst: UnlockBurst                   ## 解锁动画的粒子层（名牌之上）
var _cards: Dictionary = {}               ## 区域 id -> { glow, plate, text, lock, hover, lock_rect }
var _title: Label
var _back: Button
var _settings: Button
var _lock_tex: Texture2D
var _check_tex: Texture2D
var _soft_tex: GradientTexture2D          ## 白色径向渐隐（名牌微光）
var _panels: Array[Control] = []
var _reveal_tween: Tween = null
var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.ui_theme(SKIN)
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	chapter = DataRegistry.world_chapter()
	_soft_tex = _radial(Color.WHITE, Color(1.0, 1.0, 1.0, 0.0), 0.0)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = BACKDROP_SHADER
	_backdrop.material = bm
	add_child(_backdrop)
	_petals_far = _make_petals("PetalsFar", 24, 0.7)
	_map = _rect("WorldMap", null)
	var edge := ShaderMaterial.new()
	edge.shader = EDGE_SHADER
	_map.material = edge
	_vignette = _rect("Vignette", _radial(Color(0.0, 0.0, 0.0, 0.0), Color(0.05, 0.03, 0.06, 0.55), 0.5))
	_petals_near = _make_petals("PetalsNear", 16, 1.0)
	_lock_tex = Art.texture(str(UiKit.layout_element(SKIN, "node_lock_marker").get("file", "")))
	_check_tex = Art.texture(str(UiKit.layout_element(SKIN, "node_check_marker").get("file", "")))
	if chapter != null:
		_map.texture = Art.texture(str(chapter.world.get("map", "")))
		for r: Dictionary in chapter.regions:
			_build_card(str(r["id"]))
		for r: Dictionary in chapter.regions:
			_build_hotspot(str(r["id"]))
	_fx = Control.new()
	_fx.name = "Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_burst = UnlockBurst.new()
	_burst.name = "UnlockBurst"
	_burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_burst)
	_build_chrome()
	if chapter == null:
		return
	_title.text = chapter.title
	resized.connect(_layout)
	_layout()
	_queue_reveals()
	_refresh()


func _rect(n: String, tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.name = n
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


## 径向渐变贴图：中心 inner → 边缘 outer；hold = 中心保持 inner 的半径比例
static func _radial(inner: Color, outer: Color, hold: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, hold, 1.0])
	g.colors = PackedColorArray([inner, inner, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 256
	return t


func _make_petals(n: String, amount: int, depth: float) -> LilyPetals:
	var p := LilyPetals.new()
	p.name = n
	p.count = amount
	p.depth = depth
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	return p

# ---- 界面骨架：只留左上角的区域名、返回、设置 ----
func _build_chrome() -> void:
	for id: String in ["title_plaque"]:
		var c: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		c.name = "Skin_" + id
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		c.set_meta(&"skin_id", id)
		_panels.append(c)
	_title = _label("title")
	_back = _button("btn_back", DataRegistry.get_string("ui.back"), func() -> void: SceneRouter.goto_main_menu())
	_settings = _button("btn_settings", DataRegistry.get_string("ui.menu_settings"), func() -> void: SceneRouter.open_settings())


func _label(id: String) -> Label:
	var l := Label.new()
	l.name = "Skin_" + id
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = UiKit.text_align(str(UiKit.layout_element(SKIN, id).get("align", "left")))
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


## 名牌：微光（加色） + 六角牌 + 文字 + 锁，各自一份闪白材质
func _build_card(rid: String) -> void:
	var glow := TextureRect.new()
	glow.name = "PlateGlow_" + rid
	glow.texture = _soft_tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.self_modulate = Color(GLOW_COLOR, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	add_child(glow)
	var plate := Panel.new()
	plate.name = "PlateBg_" + rid
	plate.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate").get("theme_type", "")))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.material = UnlockBurst.flash_material()
	add_child(plate)
	var l := Label.new()
	l.name = "Plate_" + rid
	l.theme_type_variation = StringName(str(UiKit.layout_element(SKIN, "plate_text").get("theme_type", "")))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.material = UnlockBurst.flash_material()
	add_child(l)
	var lock := TextureRect.new()
	lock.name = "Lock_" + rid
	lock.texture = _lock_tex
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.material = UnlockBurst.flash_material()
	add_child(lock)
	_cards[rid] = { "glow": glow, "plate": plate, "text": l, "lock": lock, "hover": 0.0, "lock_rect": Rect2() }


func _build_hotspot(rid: String) -> void:
	var b := Button.new()
	b.name = "Region_" + rid
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(_on_hotspot.bind(rid))
	b.mouse_entered.connect(func() -> void:
		if shown_unlocked(rid):
			AudioManager.play_sfx("ui_hover"))
	add_child(b)
	hotspots[rid] = b


# ---- 布局 ----
## 一级地图在屏幕上的矩形：按窗口等比，居中
func map_rect() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var ms: Vector2 = chapter.world.get("map_size", Vector2(1080.0, 1080.0)) as Vector2 if chapter != null else Vector2(1080.0, 1080.0)
	var k: float = minf(vp.y / ms.y, vp.x / ms.x)
	var sz: Vector2 = ms * k
	return Rect2((vp - sz) * 0.5, sz)


## 区域图标中心的屏幕坐标
func region_screen_pos(rid: String) -> Vector2:
	var r: Rect2 = map_rect()
	var ms: Vector2 = chapter.world.get("map_size", Vector2.ONE) as Vector2
	return r.position + (chapter.region(rid).get("world_pos", Vector2.ZERO) as Vector2) * (r.size.x / ms.x)


## 区域名牌的屏幕矩形（图标正下方）
func plate_rect(rid: String) -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var plate: Rect2 = UiKit.layout_rect(SKIN, "plate", vp)
	var c: Vector2 = region_screen_pos(rid)
	return Rect2(Vector2(c.x - plate.size.x * 0.5, c.y + _hotspot_size() * 0.42), plate.size)


func _hotspot_size() -> float:
	return HOTSPOT_PX * map_rect().size.x / (chapter.world.get("map_size", Vector2.ONE) as Vector2).x


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	for c: Control in _panels:
		var id: String = str(c.get_meta(&"skin_id"))
		var text: bool = str(UiKit.layout_element(SKIN, id).get("kind", "")) == "text_style"
		UiKit.place(c, UiKit.layout_text_rect(SKIN, id, vp) if text else UiKit.layout_rect(SKIN, id, vp))
	if chapter == null:
		return
	var mr: Rect2 = map_rect()
	UiKit.place(_map, mr)
	(_backdrop.material as ShaderMaterial).set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	UiKit.place(_vignette, Rect2(Vector2(-vp.x * 0.1, -vp.y * 0.15), vp * Vector2(1.2, 1.3)))
	UiKit.place(_fx, Rect2(Vector2.ZERO, vp))
	var hs: float = _hotspot_size()
	for rid: String in hotspots.keys():
		var c: Vector2 = region_screen_pos(rid)
		var pr: Rect2 = plate_rect(rid)
		var cd: Dictionary = _cards[rid]
		for n: String in ["plate", "text"]:
			var ctl: Control = cd[n] as Control
			UiKit.place(ctl, pr)
			ctl.pivot_offset = pr.size * 0.5
		UiKit.place(cd["glow"] as Control, Rect2(pr.get_center() - pr.size * Vector2(0.8, 1.9), pr.size * Vector2(1.6, 3.8)))
		var ls := Vector2(44.0, 38.0) * (pr.size.y / 36.0)
		var lr := Rect2(pr.get_center() - ls * 0.5, ls)
		cd["lock_rect"] = lr
		var lock: TextureRect = cd["lock"] as TextureRect
		UiKit.place(lock, lr)
		lock.pivot_offset = ls * 0.5
		var w: float = maxf(hs, pr.size.x)
		var b: Button = hotspots[rid] as Button
		b.position = Vector2(c.x - w * 0.5, c.y - hs * 0.5)
		b.size = Vector2(w, pr.end.y - (c.y - hs * 0.5))
	_fx.queue_redraw()


# ---- 状态 ----
func _completed() -> Array:
	return GameState.progress.get("completed", []) as Array


func region_unlocked(rid: String) -> bool:
	return chapter.region_unlocked(rid, _completed(), DataRegistry.get_initial_levels())


func region_done(rid: String) -> bool:
	var p: Vector2i = chapter.region_progress(rid, _completed())
	return p.y > 0 and p.x == p.y


## 名牌按已解锁显示（已解锁且不在等解锁动画）
func shown_unlocked(rid: String) -> bool:
	return region_unlocked(rid) and not revealing.has(rid)


## 开局就解锁的区域（不播解锁动画）
func _initial_region(rid: String) -> bool:
	return chapter.region_unlocked(rid, [], DataRegistry.get_initial_levels())


## 已解锁但还没揭开过的区域（按区域顺序）。旧存档没有揭开记录时：除最后一个解锁的区域外都算已揭开（只给最新的那个补播一次）
func pending_reveals() -> Array[String]:
	var seen: Variant = SaveManager.revealed_regions()
	var unlocked: Array[String] = []
	for r: Dictionary in chapter.regions:
		var rid: String = str(r["id"])
		if region_unlocked(rid) and not _initial_region(rid):
			unlocked.append(rid)
	if seen == null:
		seen = unlocked.slice(0, unlocked.size() - 1)
		SaveManager.data["regions_revealed"] = seen
	var out: Array[String] = []
	for rid: String in unlocked:
		if not (seen as Array).has(rid):
			out.append(rid)
	return out


## 下一个要去的区域：最后一个已解锁且未全部通关的
func frontier_region() -> String:
	var out: String = ""
	for r: Dictionary in chapter.regions:
		var rid: String = str(r["id"])
		if shown_unlocked(rid) and not region_done(rid):
			out = rid
	return out


func _on_hotspot(rid: String) -> void:
	if shown_unlocked(rid):
		enter_region(rid)
	elif not revealing.has(rid):
		AudioManager.play_sfx("ui_error")
		_wiggle_lock(rid)


func enter_region(rid: String) -> void:
	if not hotspots.has(rid) or not shown_unlocked(rid):
		return
	AudioManager.play_sfx("ui_click")
	GameState.current_region_id = rid
	region_entered.emit(rid)
	if navigate:
		SceneRouter.goto_region(rid)


func _refresh() -> void:
	for rid: String in hotspots.keys():
		_apply_card(rid, shown_unlocked(rid))
	frontier = frontier_region()
	_fx.queue_redraw()


## 名牌外观：解锁 = 名字 + 进度；锁住 = 空牌 + 锁
func _apply_card(rid: String, unlocked: bool) -> void:
	var cd: Dictionary = _cards[rid]
	var p: Vector2i = chapter.region_progress(rid, _completed())
	(cd["text"] as Label).text = DataRegistry.get_string("ui.region_plate").format({ "title": chapter.region_title(rid), "done": p.x, "total": p.y }) if unlocked else ""
	(cd["plate"] as Control).modulate = Color.WHITE if unlocked else LOCKED_TINT
	var lock: TextureRect = cd["lock"] as TextureRect
	lock.visible = not unlocked
	lock.rotation = 0.0
	lock.scale = Vector2.ONE
	lock.position = (cd["lock_rect"] as Rect2).position - _origin()
	(lock.material as ShaderMaterial).set_shader_parameter("flash", 0.0)


func _origin() -> Vector2:
	return get_global_rect().position


# ---- 动效 ----
func _process(delta: float) -> void:
	if chapter == null:
		return
	_time += delta
	for rid: String in hotspots.keys():
		var cd: Dictionary = _cards[rid]
		var want: float = 1.0 if shown_unlocked(rid) and (hotspots[rid] as Button).is_hovered() else 0.0
		var h: float = move_toward(float(cd["hover"]), want, delta * 6.0)
		cd["hover"] = h
		if _animating.has(rid):
			continue
		if shown_unlocked(rid):
			(cd["plate"] as Control).modulate = Color.WHITE.lerp(HOVER_TINT, h)
			(cd["text"] as Control).modulate = Color.WHITE.lerp(Color(1.15, 1.12, 1.2), h)
		var breathe: float = (0.20 + 0.12 * sin(_time * 2.1)) if rid == frontier else 0.0
		(cd["glow"] as Control).self_modulate.a = maxf(breathe, h * 0.38)



## 进场时把待揭开的区域记进存档，然后（有动效时）依次播放解锁动画；无动效直接显示结果
func _queue_reveals() -> void:
	revealing = pending_reveals()
	if revealing.is_empty():
		return
	SaveManager.mark_regions_revealed(revealing)
	if not UiKit.motion_enabled:
		revealing.clear()
		return
	_play_reveals(revealing.duplicate(), REVEAL_DELAY)


func _play_reveals(ids: Array, delay: float) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	for rid: String in ids:
		if not revealing.has(rid):
			revealing.append(rid)
		if not _animating.has(rid):
			_animating.append(rid)
		_apply_card(rid, false)
		((_cards[rid] as Dictionary)["glow"] as Control).self_modulate.a = 0.0
	_refresh()
	var tw: Tween = create_tween()
	_reveal_tween = tw
	tw.tween_interval(delay)
	for i: int in ids.size():
		var rid: String = str(ids[i])
		var cd: Dictionary = _cards[rid]
		var plate: Control = cd["plate"] as Control
		var text: Control = cd["text"] as Control
		var glow: Control = cd["glow"] as Control
		if i > 0:
			tw.tween_interval(REVEAL_GAP)
		_burst.append_reveal(tw, cd["lock"] as Control, plate, text, _reveal_name.bind(rid), _reveal_done.bind(rid), glow)


func _reveal_name(rid: String) -> void:
	revealing.erase(rid)
	_apply_card(rid, true)
	((_cards[rid] as Dictionary)["text"] as Control).modulate = Color.WHITE


func _reveal_done(rid: String) -> void:
	revealing.erase(rid)
	_animating.erase(rid)
	_refresh()


## 测试 / 跳过：立刻结束所有解锁动画，名牌直接显示最终样子
func skip_reveals() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	revealing.clear()
	_animating.clear()
	_burst.clear()
	for rid: String in hotspots.keys():
		var cd: Dictionary = _cards[rid]
		for n: String in ["plate", "text"]:
			var ctl: Control = cd[n] as Control
			ctl.material.set_shader_parameter("flash", 0.0)
			ctl.scale = Vector2.ONE
		(cd["plate"] as Control).position = plate_rect(rid).position - _origin()
		(cd["glow"] as Control).self_modulate.a = 0.0
	_refresh()


## 点未解锁区域：锁左右晃两下
func _wiggle_lock(rid: String) -> void:
	var lock: TextureRect = (_cards[rid] as Dictionary)["lock"] as TextureRect
	if not UiKit.motion_enabled or lock.has_meta(&"wiggling"):
		return
	lock.set_meta(&"wiggling", true)
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void: lock.rotation = sin(k * TAU * 2.5) * 0.22 * (1.0 - k), 0.0, 1.0, 0.4)
	tw.tween_callback(func() -> void:
		lock.rotation = 0.0
		lock.remove_meta(&"wiggling"))


func _draw_fx() -> void:
	if chapter == null:
		return
	for rid: String in hotspots.keys():
		if shown_unlocked(rid) and region_done(rid) and _check_tex != null:
			var pr: Rect2 = plate_rect(rid)
			var cs: Vector2 = Vector2(30.0, 26.0) * (pr.size.y / 36.0)
			_fx.draw_texture_rect(_check_tex, Rect2(Vector2(pr.end.x - cs.x * 0.35, pr.get_center().y - cs.y * 0.62), cs), false)


## 调试版 F9：重播最近解锁区域的解锁动画（只是表现，不改存档）
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9 or not OS.is_debug_build() or chapter == null:
		return
	var last: String = ""
	for r: Dictionary in chapter.regions:
		var rid: String = str(r["id"])
		if region_unlocked(rid) and not _initial_region(rid):
			last = rid
	if last != "":
		skip_reveals()
		_play_reveals([last], 0.3)
