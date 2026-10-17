extends SceneTree
## 第五阶段：导出指令逐关解锁表（与配置器「导出解锁表」相同，写 ../docs/15_指令解锁表.md）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/export_unlock_table.gd
## （-s 入口脚本编译时看不到自动加载，配置器场景在运行时加载。）


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var ed: Node = (load("res://tools/config_editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	ed.call("export_unlock_table")
	print("[export_unlock_table] %s" % str((ed.get("_status") as Label).text))
	quit(0)
