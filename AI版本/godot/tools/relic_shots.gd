extends SceneTree
## 遗物 / 精英关截图（开窗口渲染）：局内遗物栏 + 地块 + 点选目标 + 生效特效，区域地图上的精英节点。输出到 -- --out=<目录>（默认 ../docs/screenshots/relics）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/relic_shots.gd -- --out=<目录>
## 运行前后原样保留本机存档文件（截图时临时改的进度不写盘）。


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/relic_shots_impl.gd") as GDScript).new() as Object
	await impl.call("run", self)
	quit(0)
