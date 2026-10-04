extends CanvasLayer
## 带淡入淡出的场景切换。autoload 名：SceneLoader
##
## 用法：
##   SceneLoader.goto("res://scenes/game/game_scene.tscn")
##   SceneLoader.reload()
##
## 场景结构（见 scene_loader.tscn）：
##   SceneLoader (CanvasLayer, layer=100)
##     └── Fade (ColorRect 全屏, 黑, modulate.a=0, mouse_filter=IGNORE)

@onready var _fade_rect: ColorRect = $Fade

var _busy := false
## 切换过程中又收到的请求（**最后一次胜出**）。见 `goto()` 里的说明。
var _pending_path := ""
var _pending_fade := 0.2

func _ready() -> void:
	# 切换过程不能被上一局的暂停状态卡住
	process_mode = Node.PROCESS_MODE_ALWAYS

## 淡出 → 换场景 → 淡入。
##
## 【切换期间的请求不再被丢弃】原来是 `if _busy: return` —— **直接丢掉**。
## 后果有两层：
## · 玩家在淡入淡出那约 0.4 秒里点菜单会**毫无反应**（看起来像卡住）；
## · 调用方 `await SceneLoader.goto(...)` 会**立刻返回**，以为切换成功了。
## 现在改成**记住最后一次请求**，等当前切换做完再接着执行（最后请求胜出）。
## 这条也是被一个**偶发失败**的用例逼出来的：3 次里失败 1 次，原因就是
## "点开始游戏"恰好落在上一次切换的淡出窗口里、请求被丢掉。
func goto(path: String, fade_time := 0.2) -> void:
	if _busy:
		_pending_path = path
		_pending_fade = fade_time
		return
	_busy = true
	await _transition(path, fade_time)
	# 切换途中又有人请求导航 → 接着做完（最后请求胜出，点击不丢）
	while not _pending_path.is_empty():
		var next_path := _pending_path
		var next_fade := _pending_fade
		_pending_path = ""
		await _transition(next_path, next_fade)
	_busy = false


## 真正做一次切换（淡出 → 换场景 → 淡入）
func _transition(path: String, fade_time: float) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	await _set_alpha(1.0, fade_time)
	get_tree().change_scene_to_file(path)
	# 等新场景真正挂进树，否则会闪一帧旧画面
	await get_tree().process_frame
	await get_tree().process_frame
	await _set_alpha(0.0, fade_time)

## 重开当前场景
func reload(fade_time := 0.2) -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var path := current.scene_file_path
	if path.is_empty():
		push_error("SceneLoader: 当前场景没有保存过，无法 reload")
		return
	await goto(path, fade_time)

func _set_alpha(target: float, dur: float) -> void:
	if dur <= 0.0:
		_fade_rect.modulate.a = target
		return
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_fade_rect, "modulate:a", target, dur)
	await t.finished
