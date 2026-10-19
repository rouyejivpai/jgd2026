extends SceneTree
## 教程关引导逐步截图：第 1–6 关按引导一步步操作（放单位 / 进出信标模式 / 放信标 / 点单位 / 关侧栏…），每步截一张整屏，
## 并打印该步高亮矩形与侧栏状态（检查高亮是否对准、是否被指令界面挡住）。不改本机存档文件。
## 输出到 -- --out=<目录>（默认 ../docs/screenshots/tutorial）；--levels=level_c01,level_c05（默认第 1–6 关）；
## --restored：进关前先放好一名单位（模拟重进关卡时恢复上次的部署，开场即打开指令界面）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/tutorial_shots.gd -- --out=<目录>


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/tutorial_shots_impl.gd") as GDScript).new() as Object
	await impl.call("run", self)
	quit(0)
