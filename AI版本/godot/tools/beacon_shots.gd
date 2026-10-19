extends SceneTree
## 信标 / 行动线截图（开窗口渲染）：部署阶段选中带信标的单位、未选中时的浅印记；开战后连拍（当前前往的信标闪烁、其余半透明）。
## 输出到 -- --out=<目录>（默认 ../docs/screenshots/beacons）；--level=<关卡 id>（默认 level_c06，推荐阵型带信标）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/beacon_shots.gd -- --out=<目录>


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/beacon_shots_impl.gd") as GDScript).new() as Object
	await impl.call("run", self)
	quit(0)
