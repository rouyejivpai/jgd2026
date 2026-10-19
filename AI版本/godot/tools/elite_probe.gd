extends SceneTree
## 精英关试玩探针：读取 tools/elite_scenarios.json，经 BattleController 跑每个场景（可带遗物地块 / 定时使用遗物），打印结果、用时、
## 存活单位血量。用于精英关调数值与回归（推荐解应胜、反例应败、遗物场景对照）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/elite_probe.gd [-- <level_id> ...]
## （-s 入口脚本编译时看不到自动加载，实际逻辑放在 elite_probe_impl.gd 中运行时加载。）


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/elite_probe_impl.gd") as GDScript).new() as Object
	quit(int(impl.call("run")))
