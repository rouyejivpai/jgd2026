extends Control
## 主菜单（01 §9；第三阶段 P5 按 R1 设计换皮，10 §1）：节点、位置、贴图、字体全部来自
## data/ui_layout/main_menu.json 与 assets/themes/ui_main_menu.tres（tools/apply_ui_manifest.py 由 assets/ui/main_menu/manifest.json 生成），
## 本脚本只负责文字绑定与功能接线：继续游戏 → 一级地图（无进度时禁用）、新游戏 → 有进度时先弹确认框，确认后清空全部存档
## （保留设置）再进一级地图、设置 → 设置浮窗、退出；数据有错误时显示错误条并禁用继续 / 新游戏（error_manifest 的元素）。
## 第一个可用按钮默认取焦点，焦点复用 hover 贴图（设计图状态）。菜单音乐。
## 节点名沿用：btn_start / StartButton 现为「新游戏」，其上新增 btn_continue / ContinueButton「继续游戏」。
## P8（10 §1.5）：菜单按钮挂菜单大按钮档的动效（data/ui_motion.json 的 button_menu；总闸关闭时不挂）；
## 该档悬停即取焦点（焦点跟随鼠标，Q-072），避免默认焦点的「开始」与鼠标悬停的按钮同时亮起。

const SCREEN: String = "main_menu"
const MENU_BGM: String = "menu_main"
const MOTION_BUTTONS: Array[String] = ["btn_continue", "btn_start", "btn_settings", "btn_quit"]
const LevelSelectScript := preload("res://scripts/screens/level_select.gd")
const KEY_NAV_ACTIONS: Array[String] = ["ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]
const MOTION_PROFILE: String = "button_menu"      ## ui_motion.json 的菜单大按钮档（含焦点跟随鼠标）
## 元素 id → 节点名（保持第二阶段的节点名，供测试与工具查找）
const NODE_NAMES: Dictionary = {
	"bg": "Background", "game_title_art": "Title", "subtitle": "Subtitle",
	"btn_continue": "ContinueButton", "btn_start": "StartButton", "btn_settings": "SettingsButton", "btn_quit": "QuitButton",
	"error_bar": "ErrorBar", "error_text": "ErrorLabel",
}

var nodes: Dictionary = {}               ## 元素 id → Control
static var _opened_editor_once: bool = false   ## 命令行 --config-editor 只在启动时跳转一次
var save_path: String = SaveManager.SAVE_PATH    ## 新游戏清档写入的存档路径（测试可改为临时路径）
var _confirm: ConfirmDialog


func _ready() -> void:
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	nodes = UiKit.build_from_layout(self, SCREEN, NODE_NAMES)
	_build_error_state()
	(nodes["subtitle"] as Label).text = DataRegistry.get_string("ui.game_subtitle")
	var cont: Button = nodes["btn_continue"] as Button
	cont.disabled = DataRegistry.has_errors or not SaveManager.has_progress()
	cont.pressed.connect(_on_continue_pressed)
	var start: Button = nodes["btn_start"] as Button
	start.disabled = DataRegistry.has_errors
	start.pressed.connect(_on_start_pressed)
	(nodes["btn_settings"] as Button).pressed.connect(_on_settings_pressed)
	(nodes["btn_quit"] as Button).pressed.connect(_on_quit_pressed)
	resized.connect(_layout)
	_layout()
	ArtText.fill(nodes["game_title_art"] as Control, SCREEN + ".game_title_art")     # P8：标题艺术字（R6a：光晕 + 扫光，静止态 = 原标题图）
	for id: String in MOTION_BUTTONS:
		UiKit.attach_button_motion(nodes[id] as Button, MOTION_PROFILE)
	_confirm = ConfirmDialog.new()
	_confirm.name = "NewGameConfirm"
	add_child(_confirm)
	_confirm.confirmed.connect(_start_new_game)
	_confirm.cancelled.connect(_focus_first)
	_focus_first()
	if OS.get_cmdline_user_args().has("--config-editor") and ResourceLoader.exists(SceneRouter.CONFIG_EDITOR_SCENE) and not _opened_editor_once:
		_opened_editor_once = true
		SceneRouter.goto_config_editor.call_deferred()


## 默认焦点：有进度时为「继续游戏」，否则「新游戏」；数据出错（两者都禁用）时不取焦点
func _focus_first() -> void:
	var b: Button = first_enabled_button()
	if b == nodes["btn_continue"] or b == nodes["btn_start"]:
		b.grab_focus()


func first_enabled_button() -> Button:
	for id: String in MOTION_BUTTONS:
		var b: Button = nodes[id] as Button
		if not b.disabled:
			return b
	return null


## 键盘导航：鼠标离开按钮会交还焦点（焦点跟随鼠标），此时按上 / 下 / Tab 先回到第一个可用按钮
## 第五阶段：F10 打开教学与解锁配置器（开发工具，导出包内不存在时忽略）
func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_F10 and ResourceLoader.exists(SceneRouter.CONFIG_EDITOR_SCENE):
		get_viewport().set_input_as_handled()
		SceneRouter.goto_config_editor()
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action: String in KEY_NAV_ACTIONS:
		if event.is_action_pressed(action):
			var b: Button = _confirm.nodes["btn_cancel"] as Button if _confirm.is_open() else first_enabled_button()
			if b != null:
				b.grab_focus()
				get_viewport().set_input_as_handled()
			return


## 错误态元素（error_only：错误条与文字）只在 DataRegistry.has_errors 时建出
func _build_error_state() -> void:
	if not DataRegistry.has_errors:
		return
	for e: Dictionary in UiKit.layout_elements(SCREEN):
		if not bool(e.get("error_only", false)):
			continue
		var id: String = str(e["id"])
		var c: Control = UiKit.node_for(e)
		c.name = str(NODE_NAMES.get(id, id))
		add_child(c)
		nodes[id] = c


func _layout() -> void:
	UiKit.relayout(SCREEN, nodes, size)


func _on_continue_pressed() -> void:
	SceneRouter.goto_world_map()          # 2026-10-18：先选区域


## 新游戏：已有进度时先确认（会清空全部存档）；没有进度时直接开始
func _on_start_pressed() -> void:
	if SaveManager.has_progress():
		_confirm.open("ui.new_game_confirm_title", "ui.new_game_confirm_body", "ui.new_game_confirm_ok", "ui.new_game_confirm_cancel")
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.start_new_game(save_path)
	LevelSelectScript.chapter_index = -1     # 章节地图回到默认章节
	SceneRouter.goto_world_map()          # 2026-10-18：先选区域


func _on_settings_pressed() -> void:
	SceneRouter.open_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()
