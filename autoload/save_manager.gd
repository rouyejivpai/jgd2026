extends Node
## 存档 + 设置。autoload 名：Save
##
## 用法：
##   Save.data["level"] = 3
##   Save.save_data()
##   Save.load_data()
##   Save.save_settings({"master": 0.8, "fullscreen": true})
##
## user:// 的真实路径：%APPDATA%\Godot\app_userdata\<项目名>\

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"

## 没有历史设置时的默认窗口尺寸
const DEFAULT_RESOLUTION_SIZE := Vector2i(1920, 1080)

## 想存什么就往这里塞，save_data() 会整体序列化
var data: Dictionary = {}
## 设置项的内存副本，设置菜单读写它
var settings: Dictionary = {}

# ---------- 存档 ----------

## 「已经自动弹过介绍的关卡」——FR-TUT-03 要求的是**每关首次进入时**弹出，
## 不是每次进关都弹。
##
## 【为什么放在这里】`play_scene` 每次进关都会重建，而"看过没有"必须
## **跨关卡、跨"返回主菜单再进来"**存活，所以只能放在全局单例上。
##
## 【会话内 + 尽量落盘】`user://` 在本环境不可写（见开发进度第 13 轮），
## 所以先用 `_intro_seen` 保证**同一次运行内**语义正确；
## 同时写进 `data` 并调 `save_data()`，在可写环境（玩家自己的机器）里能持久化。
## 也就是说：正常环境下"首次"是**每台机器一次**，本环境退化为**每次运行一次**。
var _intro_seen: Dictionary = {}


## 这一关是否已经自动弹过介绍
func has_seen_intro(level_id: String) -> bool:
	if level_id.is_empty():
		return false
	if _intro_seen.has(level_id):
		return true
	return (data.get("intro_seen", []) as Array).has(level_id)


## 记下"这一关的介绍已弹过"
func mark_intro_seen(level_id: String) -> void:
	if level_id.is_empty():
		return
	_intro_seen[level_id] = true
	var arr: Array = data.get("intro_seen", [])
	if not arr.has(level_id):
		arr.append(level_id)
		data["intro_seen"] = arr
		save_data()          # 可写环境下持久化；不可写时静默失败（已有降级）


## 清掉记录（重置全部存档时用，也是测试的清理入口）
func clear_intro_seen() -> void:
	_intro_seen.clear()
	data.erase("intro_seen")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save: 打不开存档文件 " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))

func load_data() -> Dictionary:
	if not has_save():
		data = {}
		return data
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		data = {}
		return data
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	data = parsed if parsed is Dictionary else {}
	return data

func clear_save() -> void:
	data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# ---------- 设置 ----------

## 用 ConfigFile 而不是 JSON：自带类型，改设置更省事
func save_settings(values: Dictionary) -> void:
	settings.merge(values, true)
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("Save: 设置写入失败，错误码 %d" % err)

func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		settings = {}
		return settings
	var out: Dictionary = {}
	for key: String in cfg.get_section_keys("settings"):
		out[key] = cfg.get_value("settings", key)
	settings = out
	return settings

func get_setting(key: String, fallback: Variant) -> Variant:
	return settings.get(key, fallback)

# ---------- 套用显示设置 ----------

## 主菜单启动时调用一次。音频设置在 AudioManager._ready() 里自己套。
func apply_display_settings() -> void:
	var fullscreen := bool(get_setting("fullscreen", false))
	set_fullscreen(fullscreen)
	if not fullscreen:
		var stored: Variant = get_setting("resolution_size", DEFAULT_RESOLUTION_SIZE)
		apply_resolution(stored if stored is Vector2i else DEFAULT_RESOLUTION_SIZE)

func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

## 只在窗口模式下有意义；全屏时会被忽略（否则退出全屏尺寸会错）
func apply_resolution(size: Vector2i) -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var origin := DisplayServer.screen_get_position(screen)
	DisplayServer.window_set_position(origin + (screen_size - size) / 2)
