extends RefCounted
## soul_burst_shots.gd 的实现（运行时加载，可引用自动加载）。不改本机存档文件（关卡配置只在内存里改，结束时还原存档）。

const LOAD_FRAMES: int = 90
const Probe: GDScript = preload("res://tools/elite_probe_impl.gd")
const TIMES: Array[float] = [0.0, 0.03, 0.06, 0.1, 0.16, 0.24, 0.34, 0.46, 0.6, 0.75, 0.95]

var _tree: SceneTree = null
var _out: String = ""


func run(tree: SceneTree) -> void:
	_tree = tree
	_out = ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/soul_burst").simplify_path()
	var level_id: String = "level_03"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--level="):
			level_id = a.trim_prefix("--level=")
	DirAccess.make_dir_recursive_absolute(_out)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else PackedByteArray()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await tree.process_frame
	GameState.unlocks = (Probe.ALL_UNLOCKED as Dictionary).duplicate(true)
	GameState.set("tutorials_enabled", false)

	SaveManager.set_level_config(level_id, {})
	SceneRouter.goto_battle(level_id)
	for i: int in LOAD_FRAMES:
		await tree.process_frame
	var c: BattleController = tree.current_scene.get_node("BattleController") as BattleController
	c.persist = false
	var dialogue: Node = tree.current_scene.find_child("DialogueOverlay", true, false)
	if dialogue != null:
		(dialogue as CanvasItem).visible = false
	var label: Label = tree.current_scene.find_child("BudgetLabel", true, false) as Label
	await _wait(0.3)
	_full("00_before_full.png")
	_crop(label, "00_before.png")
	print("[soul_burst] before: %s" % label.text)

	# 消耗：推荐阵型（一次性部署，可能连续多次扣 Cost → 连续演出）
	c.apply_recommended()
	print("[soul_burst] after: %s" % label.text)
	var t0: float = Time.get_ticks_msec() / 1000.0
	var handoff: Image = null
	var before_handoff: Image = null
	for t: float in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			await tree.process_frame
		var img: Image = _crop(label, "t%03d.png" % int(t * 100.0))
		if is_equal_approx(t, 0.46):
			_full("t046_full.png")
		if is_equal_approx(t, 0.6):
			before_handoff = img
		elif is_equal_approx(t, 0.95):
			handoff = img

	# 单个单位消耗：清空后再加一名（单场演出、不被连续扣费打断）
	c.clear_units()
	await _wait(1.2)
	print("[soul_burst] cleared: %s" % label.text)
	_crop(label, "s_before.png")
	var forms: Array[String] = c.card_forms()
	var added: String = ""
	for cell: Vector2i in _deploy_cells(c):
		added = c.add_unit(forms[0], cell)
		if added != "":
			break
	print("[soul_burst] single add=%s -> %s" % [added, label.text])
	# 按演出自身的时钟取帧（截图回读会卡帧，按墙钟取会错过开头）
	var burst: Node = tree.current_scene.find_child("HUD", true, false).get("_soul_burst") as Node
	for t: float in TIMES:
		while is_instance_valid(burst) and float(burst.get("_t")) < t:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		var bt: float = float(burst.get("_t")) if is_instance_valid(burst) else -1.0
		_crop(label, "s_t%03d.png" % int(t * 100.0))
		print("[soul_burst] single t=%.2f burst_t=%.3f" % [t, bt])

	if before_handoff != null and handoff != null:
		var diff: int = 0
		for y: int in before_handoff.get_height():
			for x: int in before_handoff.get_width():
				var d: float = absf(before_handoff.get_pixel(x, y).get_luminance() - handoff.get_pixel(x, y).get_luminance())
				if d > 0.12:
					diff += 1
		var f: FileAccess = FileAccess.open(_out.path_join("handoff_diff.txt"), FileAccess.WRITE)
		f.store_line("pixels differing (>0.12 luminance) between t=0.60 (self-drawn) and t=0.95 (Label): %d of %d" % [diff, before_handoff.get_width() * before_handoff.get_height()])
		f.close()
		print("[soul_burst] handoff diff pixels: %d" % diff)

	if save_bytes.is_empty():
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	else:
		var sf: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		sf.store_buffer(save_bytes)
		sf.close()
	print("[soul_burst] done -> %s" % _out)


func _deploy_cells(c: BattleController) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(0, 20):
		for x: int in range(0, 30):
			if c.place_problem(c.card_forms()[0], Vector2i(x, y)) == "":
				cells.append(Vector2i(x, y))
	return cells


func _crop(label: Label, name: String) -> Image:
	var img: Image = _tree.root.get_viewport().get_texture().get_image()
	var vp: Vector2 = Vector2(img.get_size())
	var k: Vector2 = vp / _tree.root.get_visible_rect().size
	var r: Rect2 = label.get_global_rect().grow_individual(90.0, 70.0, 90.0, 50.0)
	var ri: Rect2i = Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var out: Image = img.get_region(ri)
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png(_out.path_join(name))
	return out


func _full(name: String) -> void:
	_tree.root.get_viewport().get_texture().get_image().save_png(_out.path_join(name))


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout
