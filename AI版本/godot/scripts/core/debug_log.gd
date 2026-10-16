class_name DebugLog
extends RefCounted
## 模拟事件日志（01 §11）：把 SimEvent 逐条写入 user://logs/sim_<yyyyMMdd_HHmmss>.log，
## 每行格式 `t=12.433 | rule_changed | unit=3 ...`。由 BattleController 在正式战斗中调用（设置 sim_log 可关）。
## 只保留最近 MAX_FILES 份日志。

const LOG_DIR: String = "user://logs"
const MAX_FILES: int = 30

static var _file: FileAccess = null
static var _path: String = ""


static func is_open() -> bool:
	return _file != null


static func current_path() -> String:
	return _path


## 开一份新日志（已有打开的先关闭）；返回路径，失败返回 ""
static func begin(level_id: String, dir: String = LOG_DIR) -> String:
	end("restarted")
	DirAccess.make_dir_recursive_absolute(dir)
	_prune(dir)
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var stamp: String = "%04d%02d%02d_%02d%02d%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"]),
		int(dt["hour"]), int(dt["minute"]), int(dt["second"])]
	var path: String = "%s/sim_%s.log" % [dir, stamp]
	var n: int = 2
	while FileAccess.file_exists(path):     # 同一秒内多次开始（重置后立刻再开）
		path = "%s/sim_%s_%d.log" % [dir, stamp, n]
		n += 1
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("[DebugLog] cannot write %s" % path)
		_path = ""
		return ""
	_path = path
	_file.store_line("# level=%s" % level_id)
	return path


static func write_event(e: Dictionary) -> void:
	if _file != null:
		_file.store_line(format_event(e))


## 结束并关闭；note 写在末行（win / lose / reset / exit 等）
static func end(note: String) -> void:
	if _file == null:
		return
	_file.store_line("# end=%s" % note)
	_file.close()
	_file = null


## `t=12.433 | rule_changed | unit=3 rule=1`：其余字段按键名排序
static func format_event(e: Dictionary) -> String:
	var type_name: String = str(SimTypes.EventType.keys()[int(e.get("type", 0))]).to_lower()
	var keys: Array = e.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		if str(k) == "type" or str(k) == "time":
			continue
		parts.append("%s=%s" % [str(k), str(e[k])])
	return "t=%.3f | %s | %s" % [float(e.get("time", 0.0)), type_name, " ".join(parts)]


static func _prune(dir: String) -> void:
	var files: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.begins_with("sim_") and f.ends_with(".log"):
			files.append(f)
	files.sort()        # 时间戳命名，字典序即时间序
	var excess: int = files.size() - (MAX_FILES - 1)
	for i: int in maxi(excess, 0):
		DirAccess.remove_absolute("%s/%s" % [dir, files[i]])
