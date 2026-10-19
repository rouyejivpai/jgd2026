extends RefCounted
## beacon_shots.gd 的实现（运行时加载，可引用自动加载）。不改本机存档文件（关卡配置只在内存里改）。

const LOAD_FRAMES: int = 90
const Shots: GDScript = preload("res://tools/take_screenshots_impl.gd")
const Probe: GDScript = preload("res://tools/elite_probe_impl.gd")

var _tree: SceneTree = null
var _out: String = ""
var _shooter: Object = null


func run(tree: SceneTree) -> void:
	_tree = tree
	_out = ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/beacons").simplify_path()
	var level_id: String = "level_c06"
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
	_shooter = Shots.new()

	var root: Node2D = await _battle(level_id)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var with_beacons: int = -1
	for uid: String in c.deployed_uids():
		if not c.get_beacons(uid).is_empty():
			with_beacons = c.unit_id_of_slot(uid)
			break
	print("[beacon_shots] unit with beacons = %d" % with_beacons)

	await _wait(0.4)
	_shot("01_deploy_unselected.png")
	EventBus.unit_selected.emit(with_beacons)
	await _wait(0.4)
	_shot("02_deploy_selected.png")
	await _wait(0.37)
	_shot("03_deploy_selected_b.png")
	EventBus.unit_selected.emit(-1)
	await _wait(0.2)

	c.start()
	for i: int in 6:
		await _wait(0.23)
		_shot("10_running_%02d.png" % i)
	EventBus.unit_selected.emit(with_beacons)
	for i: int in 4:
		await _wait(0.23)
		_shot("20_running_selected_%02d.png" % i)

	if save_bytes.is_empty():
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	else:
		var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	print("[beacon_shots] done -> %s" % _out)


func _battle(lid: String) -> Node2D:
	SaveManager.set_level_config(lid, {})
	SceneRouter.goto_battle(lid)
	for i: int in LOAD_FRAMES:
		await _tree.process_frame
	var c: BattleController = _tree.current_scene.get_node("BattleController") as BattleController
	c.persist = false
	var dialogue: Node = _tree.current_scene.find_child("DialogueOverlay", true, false)
	if dialogue != null:
		(dialogue as CanvasItem).visible = false
	c.apply_recommended()
	for i: int in 10:
		await _tree.process_frame
	return _tree.current_scene as Node2D


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout


func _shot(file_name: String) -> void:
	_shooter.call("_save_shot", _tree, _out.path_join(file_name))
