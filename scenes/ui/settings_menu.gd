extends Control
## 设置菜单：音量 / 全屏 / 分辨率。
## 改动立即生效，并写入 user://settings.cfg，下次启动自动套用。
##
## 主菜单和暂停菜单都实例化同一份场景。关闭时会 emit closed，
## 宿主决定要不要把焦点还给原来的按钮。

signal closed

## 窗口模式下的可选分辨率。显示名会自动生成，加一条就会多一个下拉项。
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const DEFAULT_INDEX := 2

@onready var _master: HSlider = $Center/Panel/Margin/VBox/MasterRow/MasterSlider
@onready var _sfx: HSlider = $Center/Panel/Margin/VBox/SfxRow/SfxSlider
@onready var _music: HSlider = $Center/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var _fullscreen: CheckButton = $Center/Panel/Margin/VBox/FullscreenRow/FullscreenCheck
@onready var _resolution: OptionButton = $Center/Panel/Margin/VBox/ResRow/ResolutionOption
@onready var _back: Button = $Center/Panel/Margin/VBox/BackButton

## 防止 _load_into_ui() 赋值时触发信号、把设置又写一遍
var _loading := false

func _ready() -> void:
	hide()
	for res: Vector2i in RESOLUTIONS:
		_resolution.add_item("%d × %d" % [res.x, res.y])
	_master.value_changed.connect(_on_master_changed)
	_sfx.value_changed.connect(_on_sfx_changed)
	_music.value_changed.connect(_on_music_changed)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_resolution.item_selected.connect(_on_resolution_selected)
	_back.pressed.connect(close)

func open() -> void:
	_load_into_ui()
	show()
	_back.grab_focus()

func close() -> void:
	hide()
	closed.emit()

func is_open() -> bool:
	return visible

# ---------- 内部 ----------

func _load_into_ui() -> void:
	_loading = true
	Save.load_settings()
	_master.value = float(Save.get_setting("master", 0.8))
	_sfx.value = float(Save.get_setting("sfx", 0.8))
	_music.value = float(Save.get_setting("music", 0.6))

	var fullscreen := bool(Save.get_setting("fullscreen", false))
	_fullscreen.button_pressed = fullscreen
	_resolution.disabled = fullscreen

	var stored: Variant = Save.get_setting("resolution_size", RESOLUTIONS[DEFAULT_INDEX])
	var idx := RESOLUTIONS.find(stored if stored is Vector2i else RESOLUTIONS[DEFAULT_INDEX])
	_resolution.selected = idx if idx >= 0 else DEFAULT_INDEX
	_loading = false

	_refresh_value_labels()

func _refresh_value_labels() -> void:
	_update_label("MasterRow", _master)
	_update_label("SfxRow", _sfx)
	_update_label("MusicRow", _music)

func _update_label(row: String, slider: HSlider) -> void:
	var label := get_node_or_null("Center/Panel/Margin/VBox/%s/ValueLabel" % row) as Label
	if label:
		label.text = "%d%%" % roundi(slider.value * 100.0)

func _apply_and_persist() -> void:
	Audio.set_bus_volume("Master", _master.value)
	Audio.set_bus_volume("SFX", _sfx.value)
	Audio.set_bus_volume("Music", _music.value)
	Save.save_settings({
		"master": _master.value,
		"sfx": _sfx.value,
		"music": _music.value,
		"fullscreen": _fullscreen.button_pressed,
		"resolution_size": RESOLUTIONS[_resolution.selected],
	})

func _on_master_changed(_value: float) -> void:
	if _loading:
		return
	_update_label("MasterRow", _master)
	_apply_and_persist()

func _on_sfx_changed(_value: float) -> void:
	if _loading:
		return
	_update_label("SfxRow", _sfx)
	_apply_and_persist()

func _on_music_changed(_value: float) -> void:
	if _loading:
		return
	_update_label("MusicRow", _music)
	_apply_and_persist()

func _on_fullscreen_toggled(on: bool) -> void:
	if _loading:
		return
	Save.set_fullscreen(on)
	_resolution.disabled = on
	_apply_and_persist()

func _on_resolution_selected(index: int) -> void:
	if _loading:
		return
	Save.apply_resolution(RESOLUTIONS[index])
	_apply_and_persist()
