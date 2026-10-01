extends CanvasLayer
## 暂停菜单。挂在玩法场景里，按 pause 键（ESC / 手柄 Start）开合。
##
## 根节点必须是 PROCESS_MODE_ALWAYS，否则 get_tree().paused = true 之后
## 它自己也会被暂停，就再也关不掉了。

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var _settings: Control = $SettingsMenu
@onready var _resume: Button = $Center/VBox/ResumeButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_settings.hide()
	_settings.closed.connect(_on_settings_closed)
	_resume.pressed.connect(close)
	$Center/VBox/RestartButton.pressed.connect(_on_restart)
	$Center/VBox/SettingsButton.pressed.connect(_open_settings)
	$Center/VBox/MainMenuButton.pressed.connect(_on_main_menu)

## 暂停时玩法场景已经被冻结，收不到输入，所以开合逻辑必须放在这里。
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _settings.is_open():
			_settings.close()
		else:
			close()

func open() -> void:
	_settings.hide()
	visible = true
	get_tree().paused = true
	_resume.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func is_open() -> bool:
	return visible

# ---------- 内部 ----------

func _open_settings() -> void:
	_settings.open()

func _on_settings_closed() -> void:
	$Center/VBox/SettingsButton.grab_focus()

func _on_restart() -> void:
	close()
	SceneLoader.reload()

func _on_main_menu() -> void:
	close()
	SceneLoader.goto(MAIN_MENU)
