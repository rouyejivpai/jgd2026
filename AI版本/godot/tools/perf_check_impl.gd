extends RefCounted
## perf_check.gd 的实现（运行时加载，可引用自动加载）。

const LEVEL_ID: String = "level_08"
const RESETS: int = 20
const FRAMES_PER_RUN: int = 60
const RunPlaytests: GDScript = preload("res://tools/run_playtests_impl.gd")
const MENU_SECONDS: int = 6                 ## P8 主界面动效帧率采样时长
const MENU_HOVER_SECONDS: float = 0.5       ## 鼠标在三个按钮间轮换的间隔


func run(tree: SceneTree) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[perf] adapter=%s / %s  window=%s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), str(DisplayServer.window_get_size())])
	await _main_menu(tree)
	GameState.unlocks = RunPlaytests.ALL_UNLOCKED      # 与 run_playtests 相同，不依赖本机存档进度（否则第八关形态未解锁、开始被校验挡住）
	SceneRouter.goto_battle(LEVEL_ID)
	for i: int in 30:
		await tree.process_frame
	while tree.current_scene == null or not tree.current_scene.has_node("BattleController"):     # 从主界面切过来有淡出淡入
		await tree.process_frame
	var root: Node = tree.current_scene
	var c: BattleController = root.get_node("BattleController") as BattleController
	c.persist = false
	var dialogue: Node = root.find_child("DialogueOverlay", true, false)
	if dialogue != null:
		(dialogue as CanvasItem).visible = false
	c.apply_recommended()
	for i: int in 10:
		await tree.process_frame

	# ---- 1. 第八关 2× 全程帧率 ----
	c.set_speed(2)
	c.start()
	DebugLog.begin(LEVEL_ID)
	var deltas: PackedFloat64Array = PackedFloat64Array()
	var slow: PackedStringArray = PackedStringArray()     ## 超过 1/60 s 的帧：模拟时间@毫秒
	var max_lights: int = 0
	var last: int = Time.get_ticks_usec()
	while c.phase == SimTypes.Phase.RUNNING:
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000000.0)
		if deltas[deltas.size() - 1] > 1.0 / 60.0:
			slow.append("%.2f@%.0fms" % [c.world.clock.time, deltas[deltas.size() - 1] * 1000.0])
		last = now
		max_lights = maxi(max_lights, root.find_children("*", "PointLight2D", true, false).size())
	DebugLog.end("perf")
	var sorted: PackedFloat64Array = deltas.duplicate()
	sorted.sort()
	var total: float = 0.0
	for d: float in deltas:
		total += d
	var p99: float = sorted[int(floor(float(sorted.size()) * 0.99)) - 1]
	print("[perf] level_08 2x: sim %.2fs result=%s | frames=%d real=%.2fs avg=%.1f fps | 1%% low=%.1f fps | worst=%.1f fps | max PointLight2D=%d" % [
		c.world.clock.time, SimTypes.BattleResult.keys()[c.world.result], deltas.size(), total, float(deltas.size()) / total,
		1.0 / p99, 1.0 / sorted[sorted.size() - 1], max_lights])

	print("[perf] frames slower than 60 fps: %d %s" % [slow.size(), str(slow)])

	# ---- 2. 连续重置 20 次 ----
	var samples: Array[Dictionary] = []
	for r: int in RESETS + 1:
		c.reset()
		for i: int in 5:
			await tree.process_frame
		samples.append(_sample())
		if r == RESETS:
			break
		c.start()
		for i: int in FRAMES_PER_RUN:
			await tree.process_frame
	var first: Dictionary = samples[1]          # 第 1 次重置后（首次战斗已建立缓存）
	var lastd: Dictionary = samples[samples.size() - 1]
	for k: String in first.keys():
		print("[perf] reset x%d %-14s first=%-12s last=%-12s delta=%s" % [RESETS, k, str(first[k]), str(lastd[k]), str(float(lastd[k]) - float(first[k]))])
	var line: PackedStringArray = PackedStringArray()
	for s: Dictionary in samples:
		line.append(str(int(s["objects"])))
	print("[perf] objects per reset: %s" % ", ".join(line))
	tree.quit(0)


## P8（10 §1.5 约束 4）：主界面全部动效开启（默认焦点呼吸 + 鼠标在三个按钮间轮换触发 hover / 光带 / 按下）时的帧率
func _main_menu(tree: SceneTree) -> void:
	SceneRouter.goto_main_menu()
	for i: int in 30:
		await tree.process_frame
	var nodes: Dictionary = tree.current_scene.get("nodes") as Dictionary
	var ids: Array[String] = ["btn_start", "btn_settings", "btn_quit"]
	var deltas: PackedFloat64Array = PackedFloat64Array()
	var last: int = Time.get_ticks_usec()
	var start: int = last
	var hovered: int = -1
	while Time.get_ticks_usec() - start < MENU_SECONDS * 1000000:
		var slot: int = int(float(Time.get_ticks_usec() - start) / (MENU_HOVER_SECONDS * 1000000.0)) % ids.size()
		if slot != hovered:
			hovered = slot
			var m := InputEventMouseMotion.new()
			m.position = ((nodes[ids[slot]] as Control).get_global_rect().get_center())
			m.global_position = m.position
			tree.root.push_input(m)
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000000.0)
		last = now
	var sorted: PackedFloat64Array = deltas.duplicate()
	sorted.sort()
	var total: float = 0.0
	for d: float in deltas:
		total += d
	print("[perf] main_menu motion: frames=%d real=%.2fs avg=%.1f fps | 1%% low=%.1f fps | worst=%.1f fps" % [
		deltas.size(), total, float(deltas.size()) / total, 1.0 / sorted[int(floor(float(sorted.size()) * 0.99)) - 1], 1.0 / sorted[sorted.size() - 1]])


func _sample() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
	}
