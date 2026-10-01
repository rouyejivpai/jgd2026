extends Node
## 端到端冒烟测试：把「主菜单 → 玩法 → 暂停 → 设置 → 回主菜单」整条闭环跑一遍。
##
## 用法：
##   godot --headless --path <项目目录> res://tools/smoke_test.tscn
## 退出码 0 = 全通过，1 = 有失败项。

const GAME_SCENE := "res://scenes/game/game_scene.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const PAUSE_MENU := "res://scenes/ui/pause_menu.tscn"

var _failures: Array[String] = []
var _last_score := -1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	# 把自己从「当前场景」挪到 /root 下，
	# 否则后面 SceneLoader.goto() 换场景时会被一起释放，await 就断了
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)

	print("\n========== 冒烟测试开始 ==========")

	# 看门狗：万一某个 await 卡住，8 秒后强制退出。
	# 没有它，一个写错的测试会让命令行永久挂死（这次就踩到了）。
	var watchdog := get_tree().create_timer(8.0, true, false, true)
	watchdog.timeout.connect(func() -> void:
		print("!! 冒烟测试超时（8s），有 await 卡住了")
		get_tree().quit(2))

	_check_autoloads()
	_check_audio_buses()
	_check_input_actions()
	_check_signal_bus()
	await _check_game_helpers()
	await _check_scene_loop()
	await _check_phantom_camera()
	await _check_main_menu()
	await _check_layout()
	await _check_pause_menu()
	_report_and_quit()

func _ok(condition: bool, what: String) -> void:
	if condition:
		print("  [PASS] ", what)
	else:
		print("  [FAIL] ", what)
		_failures.append(what)

# ---------- 检查项 ----------

func _check_autoloads() -> void:
	print("\n-- autoload --")
	for autoload_name: String in ["EventBus", "Game", "Audio", "Save", "SceneLoader", "PhantomCameraManager"]:
		_ok(get_node_or_null("/root/" + autoload_name) != null, "autoload %s 已注册" % autoload_name)

func _check_audio_buses() -> void:
	print("\n-- 音频总线 --")
	for bus_name: String in ["Master", "SFX", "Music"]:
		_ok(AudioServer.get_bus_index(bus_name) != -1, "总线 %s 存在" % bus_name)

	# AudioManager._ready() 会读 Save 里存的音量并套用。
	# 如果 autoload 顺序把 Audio 排在 Save 前面，这里会拿到总线默认的 1.0 而不是 0.8，
	# 也就是"设置没生效"这种很难查的静默 bug。
	var expected := float(Save.get_setting("master", 0.8))
	_ok(absf(Audio.get_bus_volume("Master") - expected) < 0.02,
		"启动时自动套用了保存的音量（证明 Audio 能访问到 Save，%.2f）" % expected)

func _check_input_actions() -> void:
	print("\n-- 输入映射 --")
	var actions := [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "attack", "dash", "interact", "pause", "restart",
	]
	for action: String in actions:
		_ok(InputMap.has_action(action), "动作 %s 存在" % action)

	var has_pad := false
	var has_key := false
	for ev: InputEvent in InputMap.action_get_events("jump"):
		if ev is InputEventJoypadButton:
			has_pad = true
		elif ev is InputEventKey:
			has_key = true
	_ok(has_key, "jump 有键盘绑定")
	_ok(has_pad, "jump 有手柄绑定")

func _check_signal_bus() -> void:
	print("\n-- 信号总线 / 全局状态 --")
	EventBus.score_changed.connect(_on_score_changed)
	Game.new_run()
	Game.add_score(42)
	_ok(Game.score == 42, "Game.add_score 累加正确")
	_ok(_last_score == 42, "EventBus.score_changed 已广播")
	EventBus.score_changed.disconnect(_on_score_changed)

	Game.set_combo(5)
	_ok(Game.combo == 5, "Game.set_combo 生效")

func _on_score_changed(score: int) -> void:
	_last_score = score

func _check_game_helpers() -> void:
	print("\n-- 顿帧 / 慢动作 --")
	Engine.time_scale = 1.0
	await Game.hitstop(0.05)
	_ok(is_equal_approx(Engine.time_scale, 1.0), "hitstop 结束后 time_scale 归位（不是永久卡死）")

func _check_scene_loop() -> void:
	print("\n-- 场景切换闭环 --")
	await SceneLoader.goto(GAME_SCENE, 0.0)
	await get_tree().process_frame
	var current := get_tree().current_scene
	_ok(current != null and current.name == "GameScene", "SceneLoader.goto 切到了玩法场景")

	var game := get_tree().current_scene
	_ok(game.get_node_or_null("Player") is CharacterBody2D, "玩法场景有 Player")
	_ok(game.get_node_or_null("PauseMenu") != null, "玩法场景挂了 PauseMenu")
	_ok(game.get_node_or_null("HUD/ScoreLabel") != null, "玩法场景有 HUD/ScoreLabel")

	# 玩法场景 _ready 里已经 new_run 过，分数应为 0
	_ok(Game.score == 0, "进入玩法场景时分数重置为 0")

	# 模拟一次命中：加分 + 顿帧 + 音效链路
	game._demo_hit()
	_ok(Game.score == 10, "命中加分走通")

func _check_phantom_camera() -> void:
	print("\n-- Phantom Camera 跟随 --")
	var current := get_tree().current_scene
	var player := current.get_node_or_null("Player") as Node2D
	var pcam := current.get_node_or_null("PhantomCamera2D")
	_ok(pcam != null, "场景里有 PhantomCamera2D 节点")

	if pcam == null or player == null:
		return
	# follow_target 是导出节点引用，能取到说明 tscn 里的 node_paths 写对了
	_ok(pcam.get("follow_target") != null, "PhantomCamera2D.follow_target 已解析到 Player")

	var cam := get_viewport().get_camera_2d()
	_ok(cam != null, "存在活动的 Camera2D（PhantomCameraHost 接管成功）")
	if cam == null:
		return

	var start := cam.global_position
	player.global_position = Vector2(1500.0, -1100.0)
	for i in 120:
		await get_tree().physics_frame
	var moved := cam.global_position.distance_to(start)
	var gap := cam.global_position.distance_to(player.global_position)
	_ok(moved > 500.0, "相机确实跟着玩家移动了（位移 %.0f）" % moved)
	_ok(gap < 400.0, "相机跟到了玩家附近（残差 %.0f）" % gap)

func _check_main_menu() -> void:
	print("\n-- 主菜单 / 设置菜单 --")
	await SceneLoader.goto(MAIN_MENU, 0.0)
	await get_tree().process_frame
	var menu := get_tree().current_scene
	_ok(menu != null and menu.name == "MainMenu", "SceneLoader.goto 切回了主菜单")

	var continue_button := menu.get_node_or_null("Center/VBox/ContinueButton") as Button
	_ok(continue_button != null, "主菜单有「继续游戏」按钮")
	var new_game := menu.get_node_or_null("Center/VBox/NewGameButton") as Button
	_ok(new_game != null, "主菜单有「新游戏」按钮")
	_ok(new_game.focus_mode == Control.FOCUS_ALL, "主菜单按钮可获得焦点（键盘/手柄可导航）")

	var settings := menu.get_node_or_null("SettingsMenu")
	_ok(settings != null, "主菜单里实例化了设置菜单")
	if settings == null:
		return

	settings.open()
	_ok(settings.is_open(), "设置菜单能打开")

	var slider := settings.get_node_or_null("Center/Panel/Margin/VBox/MasterRow/MasterSlider") as HSlider
	_ok(slider != null, "设置菜单有主音量滑条")
	if slider != null:
		slider.value = 0.35
		_ok(is_equal_approx(float(Save.get_setting("master", -1.0)), 0.35), "拖动滑条写入了设置")
		_ok(absf(Audio.get_bus_volume("Master") - 0.35) < 0.02, "主音量实时作用到 Master 总线")

	var option := settings.get_node_or_null("Center/Panel/Margin/VBox/ResRow/ResolutionOption") as OptionButton
	_ok(option != null and option.item_count == 3, "分辨率下拉有 3 个选项")

	settings.close()
	_ok(not settings.is_open(), "设置菜单能关闭")

	var closed_fired := [false]
	settings.closed.connect(func() -> void: closed_fired[0] = true)
	settings.open()
	settings.close()
	_ok(closed_fired[0], "关闭设置菜单会 emit closed（宿主才能还焦点）")

## 布局断言：不靠肉眼看图，用几何数值确认 .tscn 里的锚点/HBox/VBox 真的生效了。
## 全是相对断言（相对父容器尺寸），所以任何分辨率下都成立。
func _check_layout() -> void:
	print("\n-- 界面布局 --")
	var menu: Node = load(MAIN_MENU).instantiate()
	add_child(menu)
	await get_tree().process_frame

	# 诊断输出（不做判定）：确认 Control 的布局空间到底是谁给的
	var win := get_window()
	print("   [diag] viewport visible_rect = ", get_viewport().get_visible_rect())
	print("   [diag] window.size = ", win.size, " content_scale_size = ", win.content_scale_size)
	print("   [diag] MainMenu.size = ", (menu as Control).size)

	var background := menu.get_node_or_null("Background") as Control
	var vbox := menu.get_node_or_null("Center/VBox") as VBoxContainer
	_ok(background != null and background.size.x > 0.0 and background.size.y > 0.0,
		"主菜单背景尺寸非零 %s" % str(background.size if background else Vector2.ZERO))
	if vbox == null or background == null:
		menu.queue_free()
		return
	_ok(absf(vbox.get_global_rect().get_center().x - background.size.x * 0.5) < 2.0,
		"主菜单按钮列水平居中（CenterContainer 生效）")

	var buttons: Array[Button] = []
	for child in vbox.get_children():
		if child is Button:
			buttons.append(child)
	_ok(buttons.size() == 4, "主菜单有 4 个按钮，实际 %d" % buttons.size())

	var size_ok := true
	var order_ok := true
	var last_y := -1.0e20
	var widths: Array[float] = []
	for b: Button in buttons:
		# 高度必须严格 56；宽度会被 VBoxContainer 拉到最宽子项（标题）的宽度，
		# 所以只断言"不小于设定值"，这是容器的预期行为而不是 bug
		if not is_equal_approx(b.size.y, 56.0):
			size_ok = false
		if b.size.x < 360.0:
			size_ok = false
		widths.append(b.size.x)
		if b.global_position.y <= last_y:
			order_ok = false
		last_y = b.global_position.y
	_ok(size_ok, "按钮高度 56 且宽度不小于 360（实际宽 %.0f）" % (widths[0] if not widths.is_empty() else 0.0))
	_ok(order_ok, "按钮自上而下排列、没有重叠")

	var settings: Control = menu.get_node("SettingsMenu")
	settings.open()
	await get_tree().process_frame

	var panel := settings.get_node_or_null("Center/Panel") as Control
	var sdim := settings.get_node_or_null("Dim") as Control
	_ok(panel != null and panel.size.x > 400.0 and panel.size.y > 300.0,
		"设置面板尺寸合理 %s" % str(panel.size if panel else Vector2.ZERO))
	_ok(sdim != null and is_equal_approx(sdim.size.x, settings.size.x)
		and is_equal_approx(sdim.size.y, settings.size.y), "设置遮罩铺满父容器")
	if panel != null:
		_ok(absf(panel.get_global_rect().get_center().x - settings.size.x * 0.5) < 2.0,
			"设置面板水平居中")

	var rowname := settings.get_node_or_null("Center/Panel/Margin/VBox/MasterRow/Name") as Control
	var slider := settings.get_node_or_null("Center/Panel/Margin/VBox/MasterRow/MasterSlider") as Control
	_ok(rowname != null and slider != null and slider.global_position.x > rowname.global_position.x
		and slider.global_position.x > rowname.global_position.x + rowname.size.x - 1.0,
		"滑条排在标签右侧（HBoxContainer 生效）")

	var vbox_inner := settings.get_node_or_null("Center/Panel/Margin/VBox") as Control
	var back := settings.get_node_or_null("Center/Panel/Margin/VBox/BackButton") as Control
	_ok(vbox_inner != null and back != null and back.global_position.y >= vbox_inner.global_position.y,
		"返回按钮在 VBox 里（不是叠在面板左上角）")

	settings.close()
	menu.queue_free()
	await get_tree().process_frame

func _check_pause_menu() -> void:
	print("\n-- 暂停菜单 --")
	var pause: Node = load(PAUSE_MENU).instantiate()
	add_child(pause)
	await get_tree().process_frame

	pause.open()
	_ok(get_tree().paused, "暂停菜单打开后 tree 被暂停")
	_ok(pause.is_open(), "暂停菜单可见")

	pause.close()
	_ok(not get_tree().paused, "暂停菜单关闭后恢复运行")
	_ok(pause.process_mode == Node.PROCESS_MODE_ALWAYS, "暂停菜单是 PROCESS_MODE_ALWAYS（暂停后还能操作）")

	pause.queue_free()

func _report_and_quit() -> void:
	print("\n========== 冒烟测试结束 ==========")
	if _failures.is_empty():
		print("全部通过 ✅")
		get_tree().quit(0)
	else:
		print("失败 %d 项 ❌" % _failures.size())
		for f: String in _failures:
			print("  - ", f)
		get_tree().quit(1)
