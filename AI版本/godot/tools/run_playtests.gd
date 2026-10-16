extends SceneTree
## M8 脚本化试玩：读取 tools/playtest_scenarios.json，经 BattleController 以 1× 运行每个场景并用 2× 复核一致性，
## 结果写入 ../docs/playtests/<level>_<kind>.json（关卡册 9.3 格式），并打印汇总表。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/run_playtests.gd
## 基线比对（第三阶段 P0）：…/run_playtests.gd -- --check（与 tools/playtest_baseline.json 不等则非零退出并逐行打印差异）；
## 有意改变结果后用 -- --update-baseline 重写基线。
## （-s 入口脚本编译时看不到自动加载，实际逻辑放在 run_playtests_impl.gd 中运行时加载。）


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var impl: Object = (load("res://tools/run_playtests_impl.gd") as GDScript).new() as Object
	var code: int = int(impl.call("run"))
	quit(code)
