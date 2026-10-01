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

func _ready() -> void:
	# 切换过程不能被上一局的暂停状态卡住
	process_mode = Node.PROCESS_MODE_ALWAYS

## 淡出 → 换场景 → 淡入。切换中重复调用会被忽略。
func goto(path: String, fade_time := 0.2) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	await _set_alpha(1.0, fade_time)
	get_tree().change_scene_to_file(path)
	# 等新场景真正挂进树，否则会闪一帧旧画面
	await get_tree().process_frame
	await get_tree().process_frame
	await _set_alpha(0.0, fade_time)
	_busy = false

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
