extends CanvasLayer
## 场景切换（01_程序架构.md §4）。2026-10-19 起转场为「菱晶碎裂波」：切换前截下旧画面盖在最上层，立即换场景，
## 然后旧画面碎成菱晶、从最近一次点击处向外一圈圈收缩消失（assets/shaders/transition_shatter.gdshader，参数 ui_motion.json 的 transition），
## 新界面从下面露出。动效总闸关闭（截图 --no-motion）时直接切换；截不到画面时退回黑幕淡入淡出。
## 转场本身不配音（用户 2026-10-20）：切换总是由按钮触发，按钮音就是这次操作的反馈。
## 10 §2：常驻持有设置浮窗 SettingsOverlay（子 CanvasLayer 层 100，低于黑幕 128），任何界面可开。
## 10 §1（P5）：只有战斗场景使用 HDR 2D（辉光需要）；菜单类界面关闭 HDR 2D，按 sRGB 空间混合半透明切片，与设计图的合成方式一致（Q-069）。

signal settings_opened()
signal settings_closed()

const STUDIO_LOGO_SCENE: String = "res://scenes/screens/studio_logo.tscn"   ## 2026-10-20：启动先播工作室标志
const OPENING_SCENE: String = "res://scenes/screens/opening.tscn"   ## 2026-10-20：标志之后播开场动画（长按 Esc 跳过）
const MAIN_MENU_SCENE: String = "res://scenes/screens/main_menu.tscn"
const LEVEL_SELECT_SCENE: String = "res://scenes/screens/level_select.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/screens/world_map.tscn"   ## 2026-10-18：一级地图（选区域）
const BATTLE_SCENE: String = "res://scenes/battle/battle_root.tscn"
const CREDITS_SCENE: String = "res://scenes/screens/credits_roll.tscn"   ## 2026-10-20：第 30 关胜利剧情之后的片尾名单
const CONFIG_EDITOR_SCENE: String = "res://tools/config_editor.tscn"   ## 第五阶段：教学与解锁配置器（开发工具）
const SETTINGS_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/settings_overlay.tscn")
const SETTINGS_LAYER: int = 100
const FADE_SECONDS: float = 0.25
const CREDITS_FADE_SECONDS: float = 0.9   ## 剧情 → 片尾：淡到纯黑
const REVEAL_SECONDS: float = 0.7        ## 开场标志 → 开场动画 → 主菜单的淡入
const MAX_STEP: float = 1.0 / 30.0        ## 转场每帧最多推进的秒数

var _fade: ColorRect
var _shatter: TextureRect                ## 转场：旧画面 + 碎裂着色器
var _last_click: Vector2 = Vector2(-1.0, -1.0)   ## 最近一次鼠标按下的视口坐标（转场波心）
var _busy: bool = false
var _settings_layer: CanvasLayer
var _settings: SettingsOverlay


func _ready() -> void:
	UiKit.install_button_motion_hook(get_tree())      # P8：此后进入场景树的全部按钮自动挂按钮动效（10 §1.5）
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Palette.BG_DEEP
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_shatter = TextureRect.new()
	_shatter.name = "Transition"
	_shatter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shatter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shatter.stretch_mode = TextureRect.STRETCH_SCALE
	_shatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shatter.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/transition_shatter.gdshader") as Shader
	_shatter.material = mat
	add_child(_shatter)
	_settings_layer = CanvasLayer.new()
	_settings_layer.layer = SETTINGS_LAYER
	add_child(_settings_layer)
	_settings = SETTINGS_OVERLAY_SCENE.instantiate() as SettingsOverlay
	_settings_layer.add_child(_settings)
	_settings.closed.connect(func() -> void: settings_closed.emit())
	_apply_hdr.call_deferred()


## 当前场景为战斗 / 片尾名单（金色光效要辉光）时开启 HDR 2D，否则关闭
func _apply_hdr() -> void:
	var scene: Node = get_tree().current_scene
	get_tree().root.use_hdr_2d = scene != null and _wants_hdr(scene.scene_file_path)


func _wants_hdr(path: String) -> bool:
	return path == BATTLE_SCENE or path == CREDITS_SCENE


func goto_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


## 主菜单挂机 → 开场动画：淡到纯黑再换场景（开场动画自己从黑场淡入）
func goto_opening() -> void:
	if _busy:
		return
	_busy = true
	if is_settings_open():
		close_settings()
	_fade.color = Color("#08070A")
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, CREDITS_FADE_SECONDS).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_switch(OPENING_SCENE)
	for i: int in 2:
		await get_tree().process_frame
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Palette.BG_DEEP
	_busy = false


## 开场标志结束后进入下一界面：标志已淡到纯色底，截图碎裂没有意义——直接换场景，再从同色幕布淡出
func reveal_scene(path: String, from_color: Color) -> void:
	if _busy:
		return
	_busy = true
	_fade.color = from_color
	_fade.modulate.a = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_switch(path)
	for i: int in 2:                          # 等新界面排好再淡出
		await get_tree().process_frame
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, REVEAL_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Palette.BG_DEEP
	_busy = false


func goto_level_select() -> void:
	_change_scene(LEVEL_SELECT_SCENE)


## 一级地图（选区域）；没有带一级地图的章节时直接进选关
func goto_world_map() -> void:
	_change_scene(WORLD_MAP_SCENE if DataRegistry.world_chapter() != null else LEVEL_SELECT_SCENE)


## 片尾名单：当前画面淡到纯黑再换场景（名单本身从全黑开始，换完直接撤掉黑幕）
func goto_credits() -> void:
	if _busy:
		return
	_busy = true
	if is_settings_open():
		close_settings()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if UiKit.motion_enabled:
		var tween: Tween = create_tween()
		tween.tween_property(_fade, "modulate:a", 1.0, CREDITS_FADE_SECONDS).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await tween.finished
	_switch(CREDITS_SCENE)
	for i: int in 2:
		await get_tree().process_frame
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Palette.BG_DEEP
	_busy = false


## 进入某区域的选关地图
func goto_region(region_id: String) -> void:
	GameState.current_region_id = region_id
	_change_scene(LEVEL_SELECT_SCENE)


## 契约保留：第三阶段起设置是浮窗，等同 open_settings()
func goto_settings() -> void:
	open_settings()


## 打开设置浮窗（已打开时不重复）
func open_settings() -> void:
	if _settings.visible:
		return
	_settings.open()
	settings_opened.emit()


## 关闭设置浮窗（写存档）
func close_settings() -> void:
	_settings.close()


func is_settings_open() -> bool:
	return _settings != null and _settings.visible


func settings_overlay() -> SettingsOverlay:
	return _settings


## 第五阶段：打开配置器（主菜单 F10 / 命令行 -- --config-editor；预览、拾取结束后返回）
func goto_config_editor() -> void:
	GameState.tutorial_preview = {}
	_change_scene(CONFIG_EDITOR_SCENE)


func goto_battle(level_id: String) -> void:
	GameState.current_level_id = level_id
	var wc: ChapterDef = DataRegistry.world_chapter()
	if wc != null and wc.has_level(level_id):
		GameState.current_region_id = wc.region_of_level(level_id)    # 「下一关」跨区域时，退出后回到新关卡所在区域
	if not ResourceLoader.exists(BATTLE_SCENE):
		push_warning("[SceneRouter] battle scene not implemented yet (M2): %s" % level_id)
		return
	_change_scene(BATTLE_SCENE)


## 记下最近一次点击位置（转场从这里碎开）；不拦截输入
func _input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		_last_click = mb.position


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	if is_settings_open():
		close_settings()
	if not UiKit.motion_enabled:             # 截图 / 无动效：直接切换
		_switch(path)
		_busy = false
		return
	var shot: Texture2D = _capture()
	if shot != null:
		await _shatter_to(path, shot)
		_busy = false
		return
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	await tween_out.finished
	_switch(path)
	var tween_in: Tween = create_tween()
	tween_in.tween_property(_fade, "modulate:a", 0.0, FADE_SECONDS)
	await tween_in.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _switch(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[SceneRouter] change_scene_to_file failed (%d): %s" % [err, path])
	get_tree().root.use_hdr_2d = _wants_hdr(path)


## 截下当前画面（HDR 2D 的战斗画面是线性浮点：转 8 位后转回 sRGB，新场景按 sRGB 贴图采样）
func _capture() -> Texture2D:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return null
	if get_tree().root.use_hdr_2d:
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	return ImageTexture.create_from_image(img)


## 菱晶碎裂波：旧画面盖住 → 换场景（等 hold_frames 帧让新界面排好）→ progress 0 → 1
func _shatter_to(path: String, shot: Texture2D) -> void:
	var p: Dictionary = UiKit.motion_params("transition")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var mat: ShaderMaterial = _shatter.material as ShaderMaterial
	var origin: Vector2 = _last_click / vp if _last_click.x >= 0.0 else Vector2(0.5, 0.5)
	mat.set_shader_parameter("origin", origin.clamp(Vector2.ZERO, Vector2.ONE))
	mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	mat.set_shader_parameter("cells", float(p.get("cells", 14.0)))
	mat.set_shader_parameter("spread", float(p.get("spread", 0.55)))
	mat.set_shader_parameter("rim", float(p.get("rim", 0.09)))
	mat.set_shader_parameter("rim_color", Color(str(p.get("rim_color", "#ECE6F2"))))
	mat.set_shader_parameter("ember_color", Color(str(p.get("ember_color", "#B01C2A"))))
	mat.set_shader_parameter("progress", 0.0)
	_shatter.texture = shot
	_shatter.visible = true
	_shatter.mouse_filter = Control.MOUSE_FILTER_STOP        # 转场期间不接受点击
	_switch(path)
	for i: int in int(p.get("hold_frames", 2)):
		await get_tree().process_frame
	# 逐帧推进，单帧最多推进 MAX_STEP 秒：新场景首帧加载 / 编译着色器的卡顿不会把碎裂波跳过去
	var dur: float = maxf(float(p.get("duration", 0.55)), 0.01)
	var e: float = 0.0
	while e < dur:
		await get_tree().process_frame
		e += minf(get_process_delta_time(), MAX_STEP)
		mat.set_shader_parameter("progress", clampf(e / dur, 0.0, 1.0))
	_shatter.visible = false
	_shatter.texture = null
	_shatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_last_click = Vector2(-1.0, -1.0)
