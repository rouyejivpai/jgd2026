class_name LevelLoader
extends RefCounted
## 详细设计：[docs/design/06-关卡数据与胜负条件.md](../../docs/design/06-关卡数据与胜负条件.md) 3.1 / 4.1
## 详细设计：[docs/design/11-数据配置.md](../../docs/design/11-数据配置.md) 3.3
##
## 关卡文件的发现与载入。
##
## 【两个查找位置】先查 `user://levels/`，再查 `res://data/levels/`（详设 07 的 4.4）：
## 导出后的构建里 `res://` 是只读的，编辑器保存会回退到 `user://levels/`，
## 因此同名关卡以 user:// 优先，玩家自制的版本才能覆盖内置关卡。
##
## 【不缓存关卡】刻意如此：编辑器保存后立刻试玩必须读到新文件（详设 11 的 4.5）。

## 跨文件引用走 preload（class_name 在本沙箱不可用，见 tools/smoke_test.gd 顶部）
const LevelDataScript := preload("res://src/core/level/level_data.gd")
const RES_DIR := "res://data/levels/"
const USER_DIR := "user://levels/"
const MANIFEST := "manifest.json"


## 列出所有可用的关卡 id。
## 优先按 manifest.json 的顺序；缺失时回退为扫描目录。
func list_level_ids() -> Array[String]:
	var manifest := _read_manifest()
	if not manifest.is_empty():
		return manifest

	# 回退：扫描两个目录下所有 .json（排除 manifest 自身）
	var found: Array[String] = []
	for dir in [USER_DIR, RES_DIR]:
		for f in _list_json_files(dir):
			var lid := f.get_basename()
			if not found.has(lid):
				found.append(lid)
	return found


## manifest.json 里的关卡顺序；读不到返回空数组
func _read_manifest() -> Array[String]:
	for dir in [USER_DIR, RES_DIR]:
		var path: String = dir + MANIFEST
		# manifest 读失败不阻断（回退到"扫描目录"那条路），所以错误信息丢弃
		var ignored: Array[String] = []
		var parsed = _read_json(path, ignored)
		if parsed is Dictionary:
			var ids = (parsed as Dictionary).get("levels", [])
			if ids is Array:
				var out: Array[String] = []
				for x in ids:
					out.append(str(x))
				return out
	return []


func _list_json_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.get_extension().to_lower() == "json" and fname != MANIFEST:
			out.append(fname)
		fname = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


## 关卡文件的完整路径（user:// 优先）；都找不到返回空串
func resolve_path(level_id: String) -> String:
	for dir in [USER_DIR, RES_DIR]:
		var p: String = dir + level_id + ".json"
		if FileAccess.file_exists(p):
			return p
	return ""


## 载入并校验一个关卡。
## 返回 { ok: bool, level: RefCounted|null, errors: Array[String], path: String }
func load_level(level_id: String, known_unit_types: Array = []) -> Dictionary:
	var path := resolve_path(level_id)
	if path.is_empty():
		return {"ok": false, "level": null, "path": "",
			"errors": ["关卡 \"%s\" 未找到（已在 user://levels/ 与 res://data/levels/ 查找）" % level_id]}

	var read_errs: Array[String] = []
	var parsed = _read_json(path, read_errs)
	if not read_errs.is_empty():
		return {"ok": false, "level": null, "path": path, "errors": read_errs}
	if not (parsed is Dictionary):
		return {"ok": false, "level": null, "path": path,
			"errors": ["%s: 顶层应为对象" % path]}

	var level: RefCounted = LevelDataScript.from_dict(parsed)
	var errors: Array = level.call("validate", known_unit_types)
	if not errors.is_empty():
		return {"ok": false, "level": level, "path": path, "errors": errors}
	return {"ok": true, "level": level, "path": path, "errors": []}


## 读并解析一个 JSON 文件。语法错误会**写明行号**并塞进 errs。
##
## 【为什么不用 `JSON.parse_string`】它是静态便捷方法，**拿不到错误行列号**，
## 只能报"语法错误或文件为空" —— 关卡作者根本不知道错在第几行。
## 用 `JSON.new()` 实例才有 `get_error_line()` / `get_error_message()`，
## 与 `DataLoader.parse_json_text` 保持同一口径（FR-UNIT-03 要求提示行号）。
func _read_json(path: String, errs: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errs.append("%s: 文件不存在" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errs.append("%s: 打不开（权限或占用）" % path)
		return null
	var text := f.get_as_text()
	f.close()
	if text.strip_edges().is_empty():
		errs.append("%s: 文件为空" % path)
		return null
	var parser := JSON.new()
	var err := parser.parse(text)
	if err != OK:
		errs.append("%s: JSON 语法错误（第 %d 行：%s）"
			% [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data


## 载入全部关卡（跳过载入失败的），按 manifest 顺序返回
func load_all(known_unit_types: Array = []) -> Array:
	var out: Array = []
	for lid in list_level_ids():
		var r := load_level(lid, known_unit_types)
		if bool(r["ok"]):
			out.append(r["level"])
	return out
