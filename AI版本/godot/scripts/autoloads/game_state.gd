extends Node
## 运行时全局状态（01 §4、§10）。unlocks / progress / settings 直接引用 SaveManager.data 中的字典，
## 修改即进入存档内容，由 SaveManager.save() 写盘。

## 当前解锁：forms / actions / conditions / selectors / presets（unlocks.slots 第二阶段废弃，07 §4.3）
var unlocks: Dictionary = {}
## 关卡进度：completed / unlocked_levels
var progress: Dictionary = {}
## 当前选择的关卡 id
var current_level_id: String = ""
## 设置项：master / music / sfx / fullscreen / target_lines / font_scale / sim_log
var settings: Dictionary = {}
## 主题中各字号的原始值（type -> { name: size }，"" 键为 default_font_size），字体缩放以此为基准
var _base_font_sizes: Dictionary = {}
## 本次运行中各关失败次数（第二关首败高亮目标连线用，不存档）
var fail_counts: Dictionary = {}


func _ready() -> void:
	sync_from_save()
	apply_display_settings()


## 重新指向 SaveManager.data 中的字典（读档 / 新建存档后调用）
func sync_from_save() -> void:
	unlocks = SaveManager.data.get("unlocks", {}) as Dictionary
	progress = SaveManager.data.get("progress", {}) as Dictionary
	settings = SaveManager.data.get("settings", {}) as Dictionary


## 07 §10.1：在章节中的关卡按"存在一条已完成的前驱连线"解锁（没有前驱的节点看初始关卡）；不在任何章节的关卡沿用存档解锁列表
func is_level_unlocked(level_id: String) -> bool:
	var ch: ChapterDef = DataRegistry.chapter_of(level_id)
	if ch != null:
		return ch.is_unlocked(level_id, progress.get("completed", []) as Array, DataRegistry.get_initial_levels())
	return (progress.get("unlocked_levels", []) as Array).has(level_id)


func is_level_completed(level_id: String) -> bool:
	return (progress.get("completed", []) as Array).has(level_id)


func is_unlocked(kind: String, value: String) -> bool:
	return (unlocks.get(kind, []) as Array).has(value)


func setting_bool(key: String) -> bool:
	return bool(settings.get(key, true))


func record_fail(level_id: String) -> int:
	var n: int = int(fail_counts.get(level_id, 0)) + 1
	fail_counts[level_id] = n
	return n


func setting_float(key: String, fallback: float) -> float:
	return float(settings.get(key, fallback))


## 全屏 / 字体缩放（设置页修改后、启动时调用）。音量由 AudioManager.apply_volumes() 负责。
func apply_display_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var full: bool = setting_bool("fullscreen")
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_MAXIMIZED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	apply_font_scale(setting_float("font_scale", 1.0))


## 按倍率缩放项目主题的全部字号（默认字号与各类型变体）；以首次调用时的主题字号为基准
func apply_font_scale(scale: float) -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return
	if _base_font_sizes.is_empty():
		_base_font_sizes[""] = { "": theme.default_font_size }
		for type_name: String in theme.get_font_size_type_list():
			var sizes: Dictionary = {}
			for size_name: String in theme.get_font_size_list(type_name):
				sizes[size_name] = theme.get_font_size(size_name, type_name)
			_base_font_sizes[type_name] = sizes
	for type_name: String in _base_font_sizes.keys():
		var sizes: Dictionary = _base_font_sizes[type_name] as Dictionary
		for size_name: String in sizes.keys():
			var v: int = roundi(float(int(sizes[size_name])) * scale)
			if type_name == "":
				theme.default_font_size = v
			else:
				theme.set_font_size(size_name, type_name, v)
