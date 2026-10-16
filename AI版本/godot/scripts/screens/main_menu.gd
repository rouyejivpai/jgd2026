extends Control
## 主菜单（01 §9；第三阶段 P5 按 R1 设计换皮，10 §1）：节点、位置、贴图、字体全部来自
## data/ui_layout/main_menu.json 与 assets/themes/ui_main_menu.tres（tools/apply_ui_manifest.py 由 assets/ui/main_menu/manifest.json 生成），
## 本脚本只负责文字绑定与功能接线：开始 → 章节地图、设置 → 设置浮窗、退出；数据有错误时显示错误条并禁用开始（error_manifest 的元素）。
## 首项默认取焦点，焦点复用 hover 贴图（设计图状态）。菜单音乐。
## P8（10 §1.5）：三个按钮挂菜单大按钮档的动效（data/ui_motion.json 的 button_menu；总闸关闭时不挂）；
## 该档悬停即取焦点（焦点跟随鼠标，Q-072），避免默认焦点的「开始」与鼠标悬停的按钮同时亮起。

const SCREEN: String = "main_menu"
const MENU_BGM: String = "menu_main"
const MOTION_BUTTONS: Array[String] = ["btn_start", "btn_settings", "btn_quit"]
const KEY_NAV_ACTIONS: Array[String] = ["ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]
const MOTION_PROFILE: String = "button_menu"      ## ui_motion.json 的菜单大按钮档（含焦点跟随鼠标）
## 元素 id → 节点名（保持第二阶段的节点名，供测试与工具查找）
const NODE_NAMES: Dictionary = {
	"bg": "Background", "game_title_art": "Title", "subtitle": "Subtitle",
	"btn_start": "StartButton", "btn_settings": "SettingsButton", "btn_quit": "QuitButton",
	"error_bar": "ErrorBar", "error_text": "ErrorLabel",
}

var nodes: Dictionary = {}               ## 元素 id → Control


func _ready() -> void:
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	nodes = UiKit.build_from_layout(self, SCREEN, NODE_NAMES)
	_build_error_state()
	(nodes["subtitle"] as Label).text = DataRegistry.get_string("ui.game_subtitle")
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
	if not start.disabled:
		start.grab_focus()


## 键盘导航：鼠标离开按钮会交还焦点（焦点跟随鼠标），此时按上 / 下 / Tab 先回到第一个可用按钮
func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action: String in KEY_NAV_ACTIONS:
		if event.is_action_pressed(action):
			for id: String in MOTION_BUTTONS:
				var b: Button = nodes[id] as Button
				if not b.disabled:
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


func _on_start_pressed() -> void:
	SceneRouter.goto_level_select()


func _on_settings_pressed() -> void:
	SceneRouter.open_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()
