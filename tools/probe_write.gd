extends Node
## 探针：核实「Godot 到底能写哪里」——尤其是 `user://` 与"新建目录"。
##
## 【为什么要查】M4-7 的端到端存盘一直卡在"不能在 res:// 新建文件"。
## 但早期我把 `Image.save_png` 的 err=12 误读成"权限拒绝"，
## 后来发现那其实是"目录不存在"。所以 `user://` 也要按"目录是否存在"分情况重测，
## 不能沿用旧结论。

const PROBE_DIR := "user://levels"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("PROBE user:// 实际路径 = ", ProjectSettings.globalize_path("user://"))
	print("PROBE res:// 实际路径  = ", ProjectSettings.globalize_path("res://"))

	# 1) user:// 根目录本身可写吗
	_write_case("user://__probe_root.txt")

	# 2) 建目录（新建目录是否被允许）
	var mk: int = DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	print("PROBE make_dir_recursive(user://levels) -> ", mk, " (0=OK/已存在)")
	print("PROBE 目录是否存在: ", DirAccess.dir_exists_absolute(PROBE_DIR))

	# 3) 目录建好后再写文件
	_write_case(PROBE_DIR + "/__probe.txt")

	# 4) res:// 下新建目录 + 新文件
	var res_dir := "res://data/levels/__probe_dir"
	var mk2: int = DirAccess.make_dir_recursive_absolute(res_dir)
	print("PROBE make_dir_recursive(res://...__probe_dir) -> ", mk2)
	_write_case(res_dir + "/__probe.txt")

	# 5) res:// 覆盖一个**已存在**的文件（应当可以——这是编辑器保存真实关卡的路径）
	var existing := "res://data/levels/manifest.json"
	var f := FileAccess.open(existing, FileAccess.READ)
	var original := f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	var w := FileAccess.open(existing, FileAccess.WRITE)
	if w == null:
		print("PROBE 覆盖已存在文件: ❌ 打不开")
	else:
		w.store_string(original)          # 原样写回，不留改动
		w.close()
		print("PROBE 覆盖已存在文件: ✅ 可以（manifest 原样写回）")
	# 确认写回后内容未变
	var f2 := FileAccess.open(existing, FileAccess.READ)
	var after := f2.get_as_text() if f2 != null else ""
	if f2 != null:
		f2.close()
	print("PROBE manifest 内容未被破坏: ", after == original)

	print("PROBE 完成")
	get_tree().quit()


func _write_case(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("PROBE 写 %s -> ❌ 打不开（%s）" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string("probe")
	f.close()
	var back := FileAccess.open(path, FileAccess.READ)
	var ok := back != null and back.get_as_text() == "probe"
	if back != null:
		back.close()
	print("PROBE 写 %s -> ✅ %s（默认可读回：%s）" % [path, "成功", str(ok)])
