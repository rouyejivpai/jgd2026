extends GutTest
## 开场工作室标志：时间轴分出现 / 停留 / 消失；左键在出现中直接完整显示、在停留中直接开始消失，消失动画不可跳过；
## 播完只切一次场景。测试期间拦住场景切换（SceneRouter._busy），并关掉 _process 由测试手动推进。

const LOGO_SCENE: PackedScene = preload("res://scenes/screens/studio_logo.tscn")
const StudioLogo := preload("res://scripts/screens/studio_logo.gd")

var _saved_busy: bool
var _logo: Control


func before_each() -> void:
	_saved_busy = bool(SceneRouter.get("_busy"))
	SceneRouter.set("_busy", true)
	_logo = LOGO_SCENE.instantiate() as Control
	add_child_autofree(_logo)
	_logo.set_process(false)
	_logo.set("_finished", false)          # 无动效环境下 _ready 会排队直接结束，这里撤销
	_logo.set("_t", 0.0)


func after_each() -> void:
	SceneRouter.set("_busy", _saved_busy)


func _click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_logo.call("_gui_input", ev)


func test_timeline_phases() -> void:
	assert_eq(_logo.call("phase"), StudioLogo.Phase.INTRO)
	_logo.call("step", StudioLogo.INTRO_END + 0.01)
	assert_eq(_logo.call("phase"), StudioLogo.Phase.HOLD)
	_logo.call("step", StudioLogo.HOLD_SECONDS)
	assert_eq(_logo.call("phase"), StudioLogo.Phase.FADE)


func test_click_during_intro_shows_logo_immediately() -> void:
	_logo.call("step", 0.5)
	_click()
	assert_almost_eq(float(_logo.get("_t")), StudioLogo.INTRO_END, 0.0001)
	assert_eq(_logo.call("phase"), StudioLogo.Phase.HOLD)


func test_click_during_hold_starts_fade() -> void:
	_logo.call("step", StudioLogo.INTRO_END + 0.3)
	_click()
	assert_almost_eq(float(_logo.get("_t")), StudioLogo.HOLD_END, 0.0001)
	assert_eq(_logo.call("phase"), StudioLogo.Phase.FADE)


func test_click_during_fade_keeps_animation() -> void:
	_logo.call("step", StudioLogo.HOLD_END + 0.2)
	var t: float = float(_logo.get("_t"))
	_click()
	assert_almost_eq(float(_logo.get("_t")), t, 0.0001)


func test_right_click_ignored() -> void:
	_logo.call("step", 0.5)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	_logo.call("_gui_input", ev)
	assert_almost_eq(float(_logo.get("_t")), 0.5, 0.0001)


func test_finishes_once_after_fade() -> void:
	for i: int in 300:
		_logo.call("step", 1.0 / 30.0)
	assert_true(bool(_logo.get("_finished")))
	assert_eq(_logo.call("phase"), StudioLogo.Phase.DONE)
