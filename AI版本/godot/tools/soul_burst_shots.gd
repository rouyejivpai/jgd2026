extends SceneTree
## 灵魂储量消耗演出（SoulBurst）连拍：进关（空配置）→ 用推荐阵型消耗 Cost → 按时间点截预算铭牌附近（放大 2 倍）。
## 另存 handoff_diff.txt：交还 Label 前后两帧文字区的像素差（检查自绘文字与 Label 是否对齐）。
## 输出到 -- --out=<目录>（默认 ../docs/screenshots/soul_burst）；--level=<关卡 id>（默认 level_03）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/soul_burst_shots.gd -- --out=<目录>


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/soul_burst_shots_impl.gd") as GDScript).new() as Object
	await impl.call("run", self)
	quit(0)
