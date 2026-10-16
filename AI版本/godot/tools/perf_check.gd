extends SceneTree
## M8 性能与稳定性检查（05 §4.3）：1920×1080 窗口、关闭垂直同步；先测主界面动效帧率（P8），再测第八关 2× 全程帧率；随后连续重置 20 次记录对象/节点/内存。
## 用法（在 godot/ 目录，需要真实窗口，不要 --headless）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/perf_check.gd
## 不写存档（关闭 persist）；会写一份模拟日志以计入日志开销。


var _impl: Object = null     ## 持有实现对象，避免协程运行中被释放


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_impl = (load("res://tools/perf_check_impl.gd") as GDScript).new() as Object
	_impl.call("run", self)
