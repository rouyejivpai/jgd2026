extends CanvasLayer
## 场景切换（01_程序架构.md §4），带黑幕淡入淡出。
## 10 §2：常驻持有设置浮窗 SettingsOverlay（子 CanvasLayer 层 100，低于黑幕 128），任何界面可开。
## 10 §1（P5）：只有战斗场景使用 HDR 2D（辉光需要）；菜单类界面关闭 HDR 2D，按 sRGB 空间混合半透明切片，与设计图的合成方式一致（Q-069）。

signal settings_opened()
signal settings_closed()

const MAIN_MENU_SCENE: String = "res://scenes/screens/main_menu.tscn"
const LEVEL_SELECT_SCENE: String = "res://scenes/screens/level_select.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/screens/world_map.tscn"   ## 2026-10-18：一级地图（选区域）
const BATTLE_SCENE: String = "res://scenes/battle/battle_root.tscn"
const CONFIG_EDITOR_SCENE: String = "res://tools/config_editor.tscn"   ## 第五阶段：教学与解锁配置器（开发工具）
const SETTINGS_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/settings_overlay.tscn")
const SETTINGS_LAYER: int = 100
const FADE_SECONDS: float = 0.25

var _fade: ColorRect
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
	_settings_layer = CanvasLayer.new()
	_settings_layer.layer = SETTINGS_LAYER
	add_child(_settings_layer)
	_settings = SETTINGS_OVERLAY_SCENE.instantiate() as SettingsOverlay
	_settings_layer.add_child(_settings)
	_settings.closed.connect(func() -> void: settings_closed.emit())
	_apply_hdr.call_deferred()


## 当前场景为战斗时开启 HDR 2D，否则关闭
func _apply_hdr() -> void:
	var scene: Node = get_tree().current_scene
	get_tree().root.use_hdr_2d = scene != null and scene.scene_file_path == BATTLE_SCENE


func goto_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func goto_level_select() -> void:
	_change_scene(LEVEL_SELECT_SCENE)


## 一级地图（选区域）；没有带一级地图的章节时直接进选关
func goto_world_map() -> void:
	_change_scene(WORLD_MAP_SCENE if DataRegistry.world_chapter() != null else LEVEL_SELECT_SCENE)


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


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	if is_settings_open():
		close_settings()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	await tween_out.finished
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[SceneRouter] change_scene_to_file failed (%d): %s" % [err, path])
	get_tree().root.use_hdr_2d = path == BATTLE_SCENE
	var tween_in: Tween = create_tween()
	tween_in.tween_property(_fade, "modulate:a", 0.0, FADE_SECONDS)
	await tween_in.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
