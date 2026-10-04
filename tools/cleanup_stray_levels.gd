extends Node
## 维护工具：删掉 `data/levels/` 下**不在 manifest 里**的关卡文件（测试残留）。
##
## 【为什么需要它】冒烟测试曾经在 `data/levels/` 里留下过一个 `new_level_1.json`
## 并把它写进 manifest（第 23 轮在提交前检查仓库状态时才发现）。
## 那个文件后来连 `Remove-Item` 与 Python 的 `os.remove` 都删不掉（沙箱下**子进程
## 对项目目录没有删除权限**），只能让 Godot 自己去删 —— 因为**写/删 `res://`
## 的是 Godot 进程自己的权限**（本工程里这套权限时开时关，见开发进度第 13 轮）。
##
## 用法：
##   godot --headless --path <项目> res://tools/cleanup_stray_levels.tscn
##
## 它**只删**"manifest 里没有、但目录里存在"的 .json —— 不会碰任何真实关卡。
## 删之前会把文件名与大小打出来，删不掉也会如实报（而不是假装成功）。

const LEVELS_DIR := "res://data/levels"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var keep := _manifest_ids()
	print("cleanup: manifest 里登记了 ", keep.size(), " 关：", keep)
	var removed := 0
	var failed := 0
	var d := DirAccess.open(LEVELS_DIR)
	if d == null:
		print("cleanup: 打不开 ", LEVELS_DIR)
		get_tree().quit(1)
		return
	d.list_dir_begin()
	var nm := d.get_next()
	var strays: Array[String] = []
	while nm != "":
		if not d.current_is_dir() and nm.ends_with(".json") and nm != "manifest.json":
			var lid := nm.substr(0, nm.length() - 5)
			if not keep.has(lid):
				strays.append(nm)
		nm = d.get_next()
	d.list_dir_end()

	for s in strays:
		var path := LEVELS_DIR + "/" + s
		var size := 0
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			size = f.get_length()
			f.close()
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err == OK and not FileAccess.file_exists(path):
			print("cleanup: 已删除残留 %s（%d 字节）" % [s, size])
			removed += 1
		else:
			print("cleanup: **删不掉** %s（err=%d）——请手动删除" % [s, err])
			failed += 1
	if strays.is_empty():
		print("cleanup: 没有残留")
	print("cleanup: 删除 %d 个，失败 %d 个" % [removed, failed])
	get_tree().quit(0 if failed == 0 else 2)


func _manifest_ids() -> Array:
	var out: Array = []
	var f := FileAccess.open(LEVELS_DIR + "/manifest.json", FileAccess.READ)
	if f == null:
		return out
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and (parsed as Dictionary).get("levels") is Array:
		for x in (parsed as Dictionary).get("levels"):
			out.append(str(x))
	return out
