extends CanvasLayer
## 暂停菜单。挂在玩法场景里，按 pause 键（ESC / 手柄 Start）开合。
##
## 根节点必须是 PROCESS_MODE_ALWAYS，否则 get_tree().paused = true 之后
## 它自己也会被暂停，就再也关不掉了。

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

## 【为什么要发信号而不是自己跳场景】本菜单是被**玩法场景**实例化的，
## 而"重置关卡"在玩法场景里有明确语义（调 session.reset()，保留玩家的指令与信标）。
## 菜单自己调 SceneLoader.reload() 会**丢掉关卡 id**（玩法场景是带 id 实例化出来的，
## 重载场景拿不回来）。所以由玩法场景决定行为，菜单只负责表达意图。
signal resume_requested
signal restart_requested
signal main_menu_requested

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
	resume_requested.emit()

func is_open() -> bool:
	return visible

# ---------- 内部 ----------

func _open_settings() -> void:
	_settings.open()

func _on_settings_closed() -> void:
	$Center/VBox/SettingsButton.grab_focus()

func _on_restart() -> void:
	close()
	restart_requested.emit()
	# 没有监听者时才退回模板的整场景重载（玩法场景已接入监听，正常不会走到这里）
	if restart_requested.get_connections().is_empty():
		SceneLoader.reload()

func _on_main_menu() -> void:
	close()
	main_menu_requested.emit()
	if main_menu_requested.get_connections().is_empty():
		SceneLoader.goto(MAIN_MENU)
