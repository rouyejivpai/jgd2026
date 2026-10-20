extends Control
## 主菜单（01 §9；第三阶段 P5 按 R1 设计换皮，10 §1）：节点、位置、贴图、字体全部来自
## data/ui_layout/main_menu.json 与 assets/themes/ui_main_menu.tres（tools/apply_ui_manifest.py 由 assets/ui/main_menu/manifest.json 生成），
## 本脚本只负责文字绑定与功能接线：继续游戏 → 一级地图（无进度时禁用）、新游戏 → 有进度时先弹确认框，确认后清空全部存档
## （保留设置）再进一级地图、设置 → 设置浮窗、退出；数据有错误时显示错误条并禁用继续 / 新游戏（error_manifest 的元素）。
## 进入时不取默认焦点（2026-10-20：否则「继续游戏」一进来就呈选中态）；按方向键 / Tab 时才落到第一个可用按钮，焦点复用 hover 贴图。菜单音乐。
## 节点名沿用：btn_start / StartButton 现为「新游戏」，其上新增 btn_continue / ContinueButton「继续游戏」。
## P8（10 §1.5）：菜单按钮挂菜单大按钮档的动效（data/ui_motion.json 的 button_menu；总闸关闭时不挂）；
## 该档悬停即取焦点（焦点跟随鼠标，Q-072），同一时刻只有一个按钮亮起。
## 2026-10-20 挂机播开场动画：没有点按任何东西（键盘按键 / 鼠标按键 / 手柄按键；只移动鼠标不算操作）累计 GameState.opening_idle_wait 秒
## （1 分钟；挂机触发的那次播完后为 5 分钟）→ SceneRouter.goto_opening()；任何点按把计时清零、等待时间复位为 1 分钟。
## 设置浮窗 / 确认框打开、转场中、动效总闸关闭时不计时。
## 2026-10-21（用户 04.zip）：「剧情」→ 剧情回顾图鉴（StorySelect）：第一页按主线章节关卡顺序列出看过至少一段剧情的关卡，
## 点关卡进第二页「开头剧情 / 结尾剧情」（没看过的锁定），点卡用 StoryPlayer 播放（不改 stories_seen），播完回到图鉴；
## 图鉴 / 剧情打开时挂机不计时。
## 2026-10-21：第一页最前加「原初」（播开场动画，初始解锁），最后加「致谢」（播片尾开发者名单，片尾名单的触发关 trigger_level 通关后解锁）；
## 两者都要换场景，播完回到主菜单时重开图鉴（GameState.story_gallery_return）。因「原初」常驻，「剧情」按钮只在数据有错误时禁用。
## 2026-10-21：通关最终关（同上 trigger_level）后主界面背景换成 bg 元素 data.cleared_file 的通关图。

const SCREEN: String = "main_menu"
const MENU_BGM: String = "menu_main"
const MOTION_BUTTONS: Array[String] = ["btn_continue", "btn_start", "btn_story", "btn_settings", "btn_quit"]
const LevelSelectScript := preload("res://scripts/screens/level_select.gd")
const STORY_PLAYER_SCENE: PackedScene = preload("res://scenes/ui/dialogue_overlay.tscn")
const BACKDROP_SHADER: Shader = preload("res://assets/shaders/magenta_backdrop.gdshader")
const Opening := preload("res://scripts/screens/opening.gd")
const KEY_NAV_ACTIONS: Array[String] = ["ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]
const MOTION_PROFILE: String = "button_menu"      ## ui_motion.json 的菜单大按钮档（含焦点跟随鼠标）
const QUIT_DELAY: float = 0.15                    ## 退出前留给点击音的时间
## 元素 id → 节点名（保持第二阶段的节点名，供测试与工具查找）
const NODE_NAMES: Dictionary = {
	"bg": "Background", "game_title_art": "Title", "subtitle": "Subtitle",
	"btn_continue": "ContinueButton", "btn_start": "StartButton", "btn_story": "StoryButton", "btn_settings": "SettingsButton", "btn_quit": "QuitButton",
	"error_bar": "ErrorBar", "error_text": "ErrorLabel",
}

var nodes: Dictionary = {}               ## 元素 id → Control
static var _opened_editor_once: bool = false   ## 命令行 --config-editor 只在启动时跳转一次
var save_path: String = SaveManager.SAVE_PATH    ## 新游戏清档写入的存档路径（测试可改为临时路径）
var _confirm: ConfirmDialog
var story_select: StorySelect = null     ## 剧情回顾图鉴
var _story: StoryPlayer = null
var _replaying: bool = false
var idle_seconds: float = 0.0            ## 已挂机的秒数


func _ready() -> void:
	AudioManager.play_bgm(MENU_BGM)
	AudioManager.stop_ambient()
	nodes = UiKit.build_from_layout(self, SCREEN, NODE_NAMES)
	_apply_cleared_background()
	_build_error_state()
	(nodes["subtitle"] as Label).text = DataRegistry.get_string("ui.game_subtitle")
	var cont: Button = nodes["btn_continue"] as Button
	cont.disabled = DataRegistry.has_errors or not SaveManager.has_progress()
	cont.pressed.connect(_on_continue_pressed)
	var start: Button = nodes["btn_start"] as Button
	start.disabled = DataRegistry.has_errors
	start.pressed.connect(_on_start_pressed)
	var story: Button = nodes["btn_story"] as Button
	story.disabled = DataRegistry.has_errors or gallery_entries().is_empty()
	story.pressed.connect(open_gallery)
	(nodes["btn_settings"] as Button).pressed.connect(_on_settings_pressed)
	(nodes["btn_quit"] as Button).pressed.connect(_on_quit_pressed)
	resized.connect(_layout)
	_layout()
	if not bool((UiKit.layout_element(SCREEN, "game_title_art").get("data", {}) as Dictionary).get("no_art_text", false)):     # 哥特换皮：标题画在背景图上
		ArtText.fill(nodes["game_title_art"] as Control, SCREEN + ".game_title_art")     # P8：标题艺术字（R6a：光晕 + 扫光，静止态 = 原标题图）
	for id: String in MOTION_BUTTONS:
		UiKit.attach_button_motion(nodes[id] as Button, MOTION_PROFILE)
	_confirm = ConfirmDialog.new()
	_confirm.name = "NewGameConfirm"
	add_child(_confirm)
	_confirm.confirmed.connect(_start_new_game)
	story_select = StorySelect.new()
	story_select.name = "StorySelect"
	add_child(story_select)
	story_select.entry_chosen.connect(_on_gallery_chosen)
	_story = STORY_PLAYER_SCENE.instantiate() as StoryPlayer
	add_child(_story)
	var bm := ShaderMaterial.new()           # 与选关回放相同：剧情背景下垫暗品红底光，不透出主界面
	bm.shader = BACKDROP_SHADER
	_story.set_base_material(bm)
	_story.finished.connect(_on_story_finished)
	if GameState.story_gallery_return:       # 从图鉴的「原初 / 致谢」回来：图鉴原样打开
		GameState.story_gallery_return = false
		if not story.disabled:
			open_gallery.call_deferred()
	if OS.get_cmdline_user_args().has("--config-editor") and ResourceLoader.exists(SceneRouter.CONFIG_EDITOR_SCENE) and not _opened_editor_once:
		_opened_editor_once = true
		SceneRouter.goto_config_editor.call_deferred()


## 是否已通关最终关（片尾名单的触发关 trigger_level）
static func is_game_cleared() -> bool:
	var lid: String = str(CreditsRoll.load_data().get("trigger_level", ""))
	return lid != "" and GameState.is_level_completed(lid)


## 通关后主界面换图：bg 元素 data.cleared_file（缺省或贴图不存在时保持原图）
func _apply_cleared_background() -> void:
	var file: String = str((UiKit.layout_element(SCREEN, "bg").get("data", {}) as Dictionary).get("cleared_file", ""))
	if file == "" or not is_game_cleared() or not ResourceLoader.exists(file):
		return
	(nodes["bg"] as TextureRect).texture = load(file) as Texture2D


## 挂机计时：返回 true = 到点该播开场动画（计时随即清零）
func idle_step(dt: float) -> bool:
	idle_seconds += dt
	if idle_seconds >= GameState.opening_idle_wait:
		idle_seconds = 0.0
		return true
	return false


func _process(delta: float) -> void:
	var blocked: bool = SceneRouter.is_settings_open() or bool(SceneRouter.get("_busy")) or (_confirm != null and _confirm.is_open()) 		or (story_select != null and story_select.visible) or _replaying
	if not UiKit.motion_enabled or blocked:
		idle_seconds = 0.0
		return
	if idle_step(delta):
		GameState.opening_from_idle = true
		SceneRouter.goto_opening()


## 任何点按：挂机计时清零、等待复位为 1 分钟（不拦截输入；鼠标移动 / 摇杆不算）
func _input(event: InputEvent) -> void:
	if Opening.is_any_press(event):
		idle_seconds = 0.0
		GameState.opening_idle_wait = Opening.IDLE_FIRST_SECONDS


func first_enabled_button() -> Button:
	for id: String in MOTION_BUTTONS:
		var b: Button = nodes[id] as Button
		if not b.disabled:
			return b
	return null


## 键盘导航：进入时及鼠标离开按钮后（焦点跟随鼠标）都没有焦点，此时按上 / 下 / Tab 先落到第一个可用按钮
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
				AudioManager.play_ui("ui_hover")
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
	AudioManager.play_ui("ui_error")


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


## 图鉴第一页：「原初」（开场动画）+ 主线章节（没有一级地图时取第一章）按关卡顺序，看过至少一段（开头 / 结尾）的关卡各一卡 + 「致谢」（片尾名单，通关后解锁）
func gallery_entries() -> Array:
	var out: Array = [{ "title": "00 " + DataRegistry.get_string("ui.story_gallery_opening"), "scene": "opening" }]
	var credits: Dictionary = { "title": "99 " + DataRegistry.get_string("ui.story_gallery_credits"), "scene": "credits",
		"locked": not is_game_cleared() }
	var ch: ChapterDef = DataRegistry.world_chapter()
	if ch == null and not DataRegistry.get_chapters().is_empty():
		ch = DataRegistry.get_chapters()[0]
	if ch == null:
		out.append(credits)
		return out
	for lid: String in ch.level_ids():
		var level: LevelDefinition = DataRegistry.get_level(lid)
		if level == null:
			continue
		var seen: bool = false
		for e: Dictionary in LevelSelectScript.replay_entries(lid):
			seen = seen or not bool(e["locked"])
		if seen:
			out.append({ "title": "%s %s" % [RuleText.level_no(level), level.title], "short_title": level.title,
				"heading": "%s  %s" % [RuleText.level_no(level), level.title], "level": lid })
	out.append(credits)
	return out


func open_gallery() -> void:
	story_select.open(DataRegistry.get_string("ui.story_gallery_title"), gallery_entries())


func _on_gallery_chosen(entry: Dictionary) -> void:
	if entry.has("level"):
		story_select.push(str(entry["heading"]), LevelSelectScript.replay_entries(str(entry["level"])))
		return
	if entry.has("scene"):                  # 原初 / 致谢：换场景播放，播完回主菜单重开图鉴
		if bool(SceneRouter.get("_busy")):
			return
		GameState.story_gallery_return = true
		if str(entry["scene"]) == "opening":
			SceneRouter.goto_opening()
		else:
			SceneRouter.goto_credits()
		return
	_replaying = true
	story_select.suspend()
	if not _story.play_story(str(entry.get("story", ""))):      # 回放不改 stories_seen
		_on_story_finished()


func _on_story_finished() -> void:
	if _replaying:
		_replaying = false
		story_select.resume()


func _on_settings_pressed() -> void:
	SceneRouter.open_settings()


## 退出：稍等 0.15 s 让点击音播出来
func _on_quit_pressed() -> void:
	get_tree().create_timer(QUIT_DELAY).timeout.connect(get_tree().quit)
