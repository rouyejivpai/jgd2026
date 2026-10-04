extends Control
## 《人工神灵》主菜单。整个游戏的入口（project.godot 里的 run/main_scene）。
##
## 【为什么改造了模板菜单】模板自带「继续游戏 / 新游戏」两个按钮，它们指向
## `scenes/game/game_scene.tscn` —— 那是**模板留下的 WASD 平台跳跃示例**。
## 用户实测点进去一脸懵：「似乎会打开一个用 wasd 移动的游戏」。
## 本作是关卡制的实时战术解谜，既不用「新游戏」也不需要那套存档流程，
## 所以把这两个入口**隐藏**（而不是删除节点：保留 .tscn 结构，
## 避免后续与模板同步时冲突），只留「开始游戏 / 设置 / 退出」。
##
## 隐藏而不是 queue_free：万一以后要做「继续上一关」，节点还在、接线也在。

const LEVEL_SELECT_SCENE := "res://src/ui/level_select.tscn"
const EDITOR_SCENE := "res://src/editor/editor_scene.tscn"

@onready var _continue: Button = $Center/VBox/ContinueButton
@onready var _settings: Control = $SettingsMenu


func _ready() -> void:
	Save.apply_display_settings()
	_settings.hide()
	_settings.closed.connect(_on_settings_closed)

	# 隐藏模板遗留的两个入口（它们会进入 WASD 平台跳跃示例场景）
	_hide_template_entries()

	$Center/VBox/SettingsButton.pressed.connect(_open_settings)
	$Center/VBox/QuitButton.pressed.connect(_on_quit)

	# 《人工神灵》的入口：开始游戏 + 关卡编辑器
	#
	# 【插到哪里】VBox 的顺序是：
	#   Title(0) Subtitle(1) Spacer(2) ContinueButton(3) NewGameButton(4) SettingsButton(5) QuitButton(6)
	# 入口按钮要落在 **标题与副标题之下**、其余按钮之上 ——
	# 也就是原来「继续游戏」那一格（那个按钮是模板遗留、已被隐藏）。
	#
	# 我第一版写的是 `move_child(start, 0)` / `move_child(editor, 1)`，
	# 把两个按钮插到了 **Title 之前**（start 在索引 0、editor 在 Title 与 Subtitle 之间），
	# 于是**两个入口都跑到了标题上方** —— 用户实测报出来的。
	# 教训：**往容器里插节点不能用"我以为是第几个"的魔法下标**，
	# 要用一个**有名字的参照节点**算位置。
	var box: VBoxContainer = $Center/VBox
	var anchor := _entry_anchor_index(box)
	var start := _make_start_button()
	box.add_child(start)
	box.move_child(start, anchor)
	var editor_btn := _make_editor_button()
	box.add_child(editor_btn)
	box.move_child(editor_btn, anchor + 1)

	start.grab_focus()


## 「开始游戏 / 关卡编辑器」应该插入的下标：**标题区之后、其余按钮之前**。
##
## 优先用模板里那个被隐藏的「继续游戏」当参照（它天生就在正确的位置）；
## 万一以后模板变了、找不到它，就退回"最后一个标题类节点之后"。
func _entry_anchor_index(box: VBoxContainer) -> int:
	var ref := box.get_node_or_null("ContinueButton")
	if ref != null:
		return ref.get_index()
	# 退路：跳过开头的标题类节点（Label 与 Spacer），插在第一个按钮之前
	var idx := 0
	for child in box.get_children():
		if child is Button:
			break
		idx += 1
	return idx


## 隐藏模板自带的入口，并把标题/副标题/操作提示改成本作的名字
func _hide_template_entries() -> void:
	for n in ["ContinueButton", "NewGameButton"]:
		var b := $Center/VBox.get_node_or_null(n)
		if b != null:
			(b as Control).visible = false

	# 标题与副标题：模板里写的是 "JGD 2026" 与「Godot 启动模板」，必须换掉
	var title := $Center/VBox.get_node_or_null("Title")
	if title is Label:
		(title as Label).text = "人工神灵"
	var sub := $Center/VBox.get_node_or_null("Subtitle")
	if sub is Label:
		(sub as Label).text = "写「如果 / 则」指令，让它自己行动"

	# 底部操作提示也是模板文案（提的是平台跳跃的操作）
	var hint := get_node_or_null("Hint")
	if hint is Label:
		(hint as Label).text = "方向键 / 摇杆 选择 · Enter / A 确认 · Esc 暂停"


func _make_start_button() -> Button:
	var b := Button.new()
	b.name = "GodEntryButton"
	b.text = "开始游戏"
	b.custom_minimum_size = Vector2(360, 56)
	b.pressed.connect(_on_start_game)
	return b


## 关卡编辑器入口。详设 10 的 2.1 明确要求"主菜单新增关卡编辑器入口"。
## 尺寸与既有按钮一致（56 高）—— 我第一版随手写了 48，被布局用例报出来了。
func _make_editor_button() -> Button:
	var b := Button.new()
	b.name = "EditorEntryButton"
	b.text = "关卡编辑器"
	b.custom_minimum_size = Vector2(360, 56)
	b.pressed.connect(_on_open_editor)
	return b


func _on_start_game() -> void:
	SceneLoader.goto(LEVEL_SELECT_SCENE)


func _on_open_editor() -> void:
	SceneLoader.goto(EDITOR_SCENE)


func _open_settings() -> void:
	_settings.open()


func _on_settings_closed() -> void:
	var start := $Center/VBox.get_node_or_null("GodEntryButton")
	if start != null:
		(start as Button).grab_focus()
	elif $Center/VBox.get_node_or_null("EditorEntryButton") != null:
		($Center/VBox.get_node("EditorEntryButton") as Button).grab_focus()
	else:
		$Center/VBox/SettingsButton.grab_focus()


func _on_quit() -> void:
	# 桌面端直接退；Web 端这行没有效果，属于预期行为
	get_tree().quit()
