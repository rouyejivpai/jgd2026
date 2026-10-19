extends RefCounted
## tutorial_shots.gd 的实现（运行时加载，可引用自动加载）。

const LOAD_FRAMES: int = 90
const MAX_STEPS: int = 40

var _tree: SceneTree = null
var _out: String = ""
var _restored: bool = false


func run(tree: SceneTree) -> void:
	_tree = tree
	_out = ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/tutorial").simplify_path()
	var levels: PackedStringArray = ["level_c01", "level_c02", "level_c03", "level_c04", "level_c05", "level_c06"]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--levels="):
			levels = a.trim_prefix("--levels=").split(",", false)
		elif a == "--restored":
			_restored = true
	DirAccess.make_dir_recursive_absolute(_out)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else PackedByteArray()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await tree.process_frame
	# 与玩家按顺序打到第 5 关时一致（同 tests/integration/test_tutorial.gd）
	GameState.unlocks = DataRegistry.get_initial_unlocks()
	(GameState.unlocks["forms"] as Array).append_array(["bulwark", "swift"])
	(GameState.unlocks["actions"] as Array).append_array(["follow_beacons", "chase"])
	(GameState.unlocks["selectors"] as Array).append("farthest")
	(GameState.unlocks["presets"] as Array).append_array(["preset.follow_route", "preset.attack_farthest_in_range"])
	GameState.tutorials_enabled = true
	for lid: String in levels:
		await _level(lid)
	if save_bytes.is_empty():
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	else:
		var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	print("[tutorial_shots] done -> %s" % _out)


func _level(lid: String) -> void:
	SaveManager.set_level_config(lid, {})
	if _restored:                           # 先进一次关放下一名单位（写入关卡配置），再重进：开场即恢复部署
		SceneRouter.goto_battle(lid)
		for i: int in LOAD_FRAMES:
			await _tree.process_frame
		var c0: BattleController = _tree.current_scene.get_node("BattleController") as BattleController
		c0.add_unit(c0.card_forms()[0], c0.level.deploy_cells[0])
		SaveManager.set_level_config(lid, c0.config_to_raw())     # 只写内存，结束时整份存档还原
		await _tree.process_frame
	SceneRouter.goto_battle(lid)
	for i: int in LOAD_FRAMES:
		await _tree.process_frame
	var root: Node2D = _tree.current_scene as Node2D
	var c: BattleController = root.get_node("BattleController") as BattleController
	c.persist = false
	var hud: Control = root.get_node("UI/HUD") as Control
	var dialogue: Node = root.find_child("DialogueOverlay", true, false)
	if dialogue != null:
		(dialogue as CanvasItem).visible = false
	var d: TutorialDirector = root.get("tutorial") as TutorialDirector
	if d == null or not d.active():
		print("[tutorial_shots] %s: no tutorial" % lid)
		return
	if _restored:
		print("[tutorial_shots] %s restored: placements=%d side=%s" % [lid, c.placements.size(), str(hud.call("side_visible"))])
	var shot: int = 0
	var last: int = -1
	var same: int = 0
	while d.active() and shot < MAX_STEPS:
		for i: int in 30:
			await _tree.process_frame
			if d.overlay.visible:
				break
		await _wait(0.45)                     # 侧栏滑入、出场卡放大等动画放完
		var step: Dictionary = d.current()
		if step.is_empty():
			break
		same = same + 1 if d.index == last else 0
		last = d.index
		if same > 2:
			print("[tutorial_shots] %s: stuck at step %d「%s」" % [lid, d.index + 1, str(step["title"])])
			break
		var name: String = "%s_%02d_%s%s.png" % [lid, shot, str(step["title"]), "_restored" if _restored else ""]
		_tree.root.get_texture().get_image().save_png(_out.path_join(name))
		var side: String = str(hud.call("side_rect")) if bool(hud.call("side_visible")) else "closed"
		var shown: String = (d.overlay.find_child("StepLabel", true, false) as Label).text.strip_edges()
		print("[tutorial_shots] %s #%d「%s」 shown=%s holes=%s side=%s" % [lid, shot, str(step["title"]), shown, str(d.target_rects(step)), side])
		shot += 1
		if str(step["advance"]) == "event" and str(step["event"]) == "battle_started":
			break
		_act(root, c, hud, d, step)
	root.queue_free()
	for i: int in 5:
		await _tree.process_frame


## 按这一步要求的操作推进
func _act(root: Node2D, c: BattleController, hud: Control, d: TutorialDirector, step: Dictionary) -> void:
	var targets: Array[Dictionary] = step["targets"] as Array[Dictionary]
	match str(step["advance"]):
		"tap", "next", "click":
			d._advance_from(d.index)
			return
	match str(step["event"]):
		"drag_started", "rules_changed":
			d._fire(str(step["event"]))
		"deployed":
			var form: String = ""
			for t: Dictionary in targets:
				if str(t["kind"]) == "ui" and str(t["node"]).begins_with("Card_"):
					form = str(t["node"]).trim_prefix("Card_").get_slice("/", 0)
					break
			_deploy(c, d, form)
		"beacon_mode":
			hud.call("enter_beacon_mode", c.deployed_uids()[0])
		"beacon_mode_exit":
			hud.call("exit_beacon_mode")
		"beacon_placed", "beacon_in_area":
			for t: Dictionary in targets:
				for cell: Vector2i in t.get("cells", []) as Array:
					if c.add_beacon(c.deployed_uids()[0], cell) != "":
						return
		"ally_selected":
			EventBus.unit_selected.emit(c.unit_id_of_slot(c.deployed_uids()[0]))
		"enemy_selected":
			for t: Dictionary in targets:
				if str(t["kind"]) == "unit":
					EventBus.unit_selected.emit(c.world.get_spawn(str(t["spawn"])).id)
		"panel_closed":
			hud.call("hide_side")


## 放下一名单位并像 MapInput 那样自动选中（打开指令界面）
func _deploy(c: BattleController, d: TutorialDirector, form: String) -> void:
	if form == "" or not c.card_forms().has(form):
		form = c.card_forms()[0]
	for cell: Vector2i in c.level.deploy_cells:
		var uid: String = c.add_unit(form, cell)
		if uid != "":
			EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
			return
	print("[tutorial_shots] cannot deploy %s" % form)


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout
