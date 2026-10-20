extends GutTest
## 开场动画播放时机（2026-10-20）：只在第一次启动时由工作室标志接入（settings.opening_seen）；
## 主菜单挂机（没有点按，鼠标移动不算）1 分钟播放，挂机触发的那次播完后等 5 分钟，任何点按复位为 1 分钟；播放中按任意键才出现「长按 Esc 跳过」提示。
## 测试拦住场景切换（SceneRouter._busy），结束后恢复存档内容与 GameState 的挂机状态。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const OPENING_SCENE: PackedScene = preload("res://scenes/screens/opening.tscn")
const Opening := preload("res://scripts/screens/opening.gd")

var _saved_settings: Dictionary
var _saved_wait: float
var _saved_from_idle: bool
var _saved_busy: bool


func before_each() -> void:
	_saved_settings = GameState.settings.duplicate(true)
	_saved_wait = GameState.opening_idle_wait
	_saved_from_idle = GameState.opening_from_idle
	_saved_busy = bool(SceneRouter.get("_busy"))
	SceneRouter.set("_busy", true)


func after_each() -> void:
	GameState.settings.clear()
	GameState.settings.merge(_saved_settings)
	GameState.opening_idle_wait = _saved_wait
	GameState.opening_from_idle = _saved_from_idle
	SceneRouter.set("_busy", _saved_busy)


func _menu() -> Control:
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	menu.set_process(false)
	return menu


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	return ev


func test_seen_flag_controls_first_launch() -> void:
	GameState.settings.erase(Opening.SEEN_KEY)
	assert_false(Opening.is_seen())
	GameState.settings[Opening.SEEN_KEY] = true
	assert_true(Opening.is_seen())


func test_idle_one_minute_triggers() -> void:
	GameState.opening_idle_wait = Opening.IDLE_FIRST_SECONDS
	var menu: Control = _menu()
	assert_false(bool(menu.call("idle_step", 59.0)))
	assert_true(bool(menu.call("idle_step", 1.5)))
	assert_almost_eq(float(menu.get("idle_seconds")), 0.0, 0.0001)


func test_after_idle_playback_waits_five_minutes() -> void:
	GameState.opening_idle_wait = Opening.IDLE_REPEAT_SECONDS
	var menu: Control = _menu()
	assert_false(bool(menu.call("idle_step", 120.0)))
	assert_false(bool(menu.call("idle_step", 170.0)))
	assert_true(bool(menu.call("idle_step", 11.0)))


func test_any_input_resets_idle_and_wait() -> void:
	GameState.opening_idle_wait = Opening.IDLE_REPEAT_SECONDS
	var menu: Control = _menu()
	menu.call("idle_step", 200.0)
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(3, 0)
	menu.call("_input", mv)                     # 只移动鼠标不算操作
	assert_almost_eq(float(menu.get("idle_seconds")), 200.0, 0.0001)
	assert_eq(GameState.opening_idle_wait, Opening.IDLE_REPEAT_SECONDS)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu.call("_input", click)
	assert_almost_eq(float(menu.get("idle_seconds")), 0.0, 0.0001)
	assert_eq(GameState.opening_idle_wait, Opening.IDLE_FIRST_SECONDS)
	menu.call("idle_step", 30.0)
	menu.call("_input", _key(KEY_A))
	assert_almost_eq(float(menu.get("idle_seconds")), 0.0, 0.0001)


func test_hint_appears_only_after_a_key() -> void:
	var op: Control = OPENING_SCENE.instantiate() as Control
	op.set("auto_reveal", false)
	add_child_autofree(op)
	op.set_process(false)
	op.set("_finished", false)
	op.call("_enter_panel", 0)
	op.call("step", 0.5)
	assert_almost_eq(float(op.get("_hint_t")), 0.0, 0.0001)
	op.call("_input", _key(KEY_SPACE))
	assert_gt(float(op.get("_hint_t")), 0.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	op.set("_hint_t", 0.0)
	op.call("_input", click)
	assert_gt(float(op.get("_hint_t")), 0.0)
	op.call("_input", _key(KEY_ESCAPE))
	op.call("step", 0.4)
	assert_gt(float(op.get("_esc_held")), 0.3)
	assert_false(bool(op.get("_skipping")))
	op.call("_input", _key(KEY_ESCAPE, false))
	assert_almost_eq(float(op.get("_esc_held")), 0.0, 0.0001)
