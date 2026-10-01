extends Control
## 主菜单。整个游戏的入口（project.godot 里的 run/main_scene）。
##
## 「继续游戏」只有在存在存档时才可点。

const GAME_SCENE := "res://scenes/game/game_scene.tscn"

@onready var _continue: Button = $Center/VBox/ContinueButton
@onready var _settings: Control = $SettingsMenu

func _ready() -> void:
	# 套用上次保存的窗口设置（音频在 AudioManager._ready() 里已经套过了）
	Save.apply_display_settings()

	_settings.hide()
	_settings.closed.connect(_on_settings_closed)
	_continue.disabled = not Save.has_save()
	_continue.pressed.connect(_on_continue)
	$Center/VBox/NewGameButton.pressed.connect(_on_new_game)
	$Center/VBox/SettingsButton.pressed.connect(_open_settings)
	$Center/VBox/QuitButton.pressed.connect(_on_quit)

	# 让键盘 / 手柄一进来就有焦点，不然方向键不动
	var first: Button = $Center/VBox/NewGameButton if _continue.disabled else _continue
	first.grab_focus()

func _on_continue() -> void:
	Save.load_data()
	SceneLoader.goto(GAME_SCENE)

func _on_new_game() -> void:
	Save.clear_save()
	Game.new_run()
	SceneLoader.goto(GAME_SCENE)

func _open_settings() -> void:
	_settings.open()

func _on_settings_closed() -> void:
	$Center/VBox/SettingsButton.grab_focus()

func _on_quit() -> void:
	# 桌面端直接退；Web 端这行没有效果，属于预期行为
	get_tree().quit()
