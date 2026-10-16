extends SceneTree
## 实机截图：按关卡摆放「推荐阵型」并开始战斗，运行到指定模拟时间后截图（需要真实窗口，不要 --headless）。
## 用法（在 godot/ 目录）：
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/take_screenshots.gd -- [--out=../docs/screenshots] [--size=1920x1080] [--levels=level_01,level_03] [--time=3.0] [--phase=running|deploy] [--select=ally|enemy|enemy:<形态>|none] [--demo=two_conditions|overflow|validation|objectives|mechanics|hint|recommend|win|lose|add_action|beacons|wait|follow_beacons|feedback] [--screen=battle|chapter|main_menu|main_menu_error|settings_overlay|main_menu_motion] [--completed=3] [--pan=max|min|<px>] [--no-motion] [--text-layer] [--live]
##   main_menu_motion（P8 动效连续帧）须加引擎参数 --fixed-fps 60。
## 不写存档（关闭 persist，退出时恢复内存中的存档数据）。
## （-s 入口脚本编译时看不到自动加载，实际逻辑放在 take_screenshots_impl.gd 中运行时加载。）

var _impl: Object = null


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_impl = (load("res://tools/take_screenshots_impl.gd") as GDScript).new() as Object
	_impl.call("run", self)
