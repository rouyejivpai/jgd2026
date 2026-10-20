extends SceneTree
## 片尾名单截图（开窗口渲染）：从战斗剧情之后的入口 SceneRouter.goto_credits() 进入，按主角走到的位置截几张，最后截结束卡。
## 输出到 -- --out=<目录>（默认 ../docs/screenshots/credits）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/credits_shots.gd -- --out=<目录>


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/credits_shots_impl.gd") as GDScript).new() as Object
	await impl.call("run", self)
	quit(0)
