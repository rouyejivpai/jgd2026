extends SceneTree
## 工程配置工具（可重复执行，幂等）。作用：
##   1. 写入输入映射（键盘 + 手柄）
##   2. 生成 default_bus_layout.tres（Master / SFX / Music 三条总线）
##
## 用法：
##   & "D:\Godot\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
##       --headless --path "D:\jgd2026\v0.0.1" --script res://tools/setup_project.gd
##
## 为什么不直接手写 project.godot 的 [input] 段：那一串 Object(InputEventKey, ...)
## 的序列化格式容易写错，交给引擎自己序列化最稳。

const BUS_LAYOUT_PATH := "res://default_bus_layout.tres"

func _initialize() -> void:
	print("== setup_project 开始 ==")
	_setup_input()
	_setup_audio_buses()
	var err := ProjectSettings.save()
	if err != OK:
		push_error("ProjectSettings.save() 失败，错误码 %d" % err)
	else:
		print("project.godot 已写入")
	print("== setup_project 结束 ==")
	quit()

# ---------- 输入映射 ----------

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	# 用 physical_keycode：不受键盘布局影响，AZERTY 用户也不会按不出 WASD
	e.physical_keycode = code
	return e

func _mouse(btn: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	return e

func _pad(btn: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _set_action(action: String, events: Array, deadzone := 0.2) -> void:
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": deadzone,
		"events": events,
	})

func _setup_input() -> void:
	# 移动（摇杆用 0.2 死区，按键类用 0.5）
	_set_action("move_left", [
		_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0),
	], 0.2)
	_set_action("move_right", [
		_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0),
	], 0.2)
	_set_action("move_up", [
		_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0),
	], 0.2)
	_set_action("move_down", [
		_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0),
	], 0.2)

	_set_action("jump", [
		_key(KEY_SPACE), _pad(JOY_BUTTON_A),
	])
	_set_action("attack", [
		_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _pad(JOY_BUTTON_X),
	])
	_set_action("dash", [
		_key(KEY_SHIFT), _pad(JOY_BUTTON_B),
	])
	_set_action("interact", [
		_key(KEY_E), _pad(JOY_BUTTON_Y),
	])
	_set_action("pause", [
		_key(KEY_ESCAPE), _pad(JOY_BUTTON_START),
	])
	_set_action("restart", [
		_key(KEY_R), _pad(JOY_BUTTON_BACK),
	])
	print("输入映射已写入：move_* / jump / attack / dash / interact / pause / restart")

# ---------- 音频总线 ----------

func _setup_audio_buses() -> void:
	for bus_name: String in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		print("已创建音频总线：" + bus_name)

	var layout := AudioServer.generate_bus_layout()
	var err := ResourceSaver.save(layout, BUS_LAYOUT_PATH)
	if err != OK:
		push_error("音频总线布局保存失败，错误码 %d" % err)
	else:
		print("音频总线布局已保存：" + BUS_LAYOUT_PATH)
