extends SceneTree
## 战斗打击感截图（开窗口渲染）：射弹三种形状、斩击三种方向、受击碎屑、击败（震屏 / 击飞 / 灰化 / 灰烬）、脚印、目标锁定线。
## 输出到 -- --out=<目录>（默认 ../docs/screenshots/combat_fx）；--level=<关卡 id>（默认 level_03）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/combat_fx_shots.gd -- --out=<目录>


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/combat_fx_shots_impl.gd") as GDScript).new() as Object
	await impl.call("run", self)
	quit(0)
