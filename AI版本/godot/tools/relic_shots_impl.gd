extends RefCounted
## relic_shots.gd 的实现（运行时加载，可引用自动加载）。

const LOAD_FRAMES: int = 90
const SETTLE_FRAMES: int = 20
const Shots: GDScript = preload("res://tools/take_screenshots_impl.gd")
const Probe: GDScript = preload("res://tools/elite_probe_impl.gd")


func run(tree: SceneTree) -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/relics").simplify_path()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var save_path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else PackedByteArray()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await tree.process_frame
	var unlocks: Dictionary = (Probe.ALL_UNLOCKED as Dictionary).duplicate(true)
	unlocks["relics"] = DataRegistry.get_relic_ids()
	GameState.unlocks = unlocks
	GameState.set("tutorials_enabled", false)
	var shooter: Object = Shots.new()

	# 1. 断臂回廊部署阶段：推荐阵型 + 骨臂地块（其余遗物本场锁定），鼠标悬停提灯说明
	var c: BattleController = await _battle(tree, "level_e04")
	c.place_relic_tile("bone_arm", Vector2i(13, 5))
	await _settle(tree)
	shooter.call("_save_shot", tree, out_dir.path_join("relic_deploy_tile.png"))

	# 2. 剔骨坊战斗中：骨刃进入点选（敌人脚下脉动圈），暂停截图；再砍一刀看飘字
	c = await _battle(tree, "level_e01")
	c.start()
	for i: int in 150:
		await tree.physics_frame
	c.pause()
	var hud: Node = tree.current_scene.find_child("HUD", true, false)
	hud.call("arm_relic", "bone_blade")
	tree.current_scene.call("set_relic_target_hover", "bone_blade", c.world.get_spawn("S1").id)
	await _settle(tree)
	shooter.call("_save_shot", tree, out_dir.path_join("relic_blade_armed.png"))
	c.use_relic_on("bone_blade", c.world.get_spawn("S1").id)
	hud.call("disarm_relic")
	for i: int in 12:
		await tree.process_frame
	shooter.call("_save_shot", tree, out_dir.path_join("relic_blade_used.png"))

	# 3. 区域地图：人偶工坊全部通关，选中精英节点「剔骨坊」
	var completed: Array = []
	for i: int in range(1, 7):
		completed.append("level_c%02d" % i)
	SaveManager.data["progress"] = { "completed": completed, "unlocked_levels": [] }
	GameState.sync_from_save()
	GameState.unlocks = unlocks
	GameState.current_region_id = "bone_workshop"
	SceneRouter.goto_region("bone_workshop")
	for i: int in LOAD_FRAMES:
		await tree.process_frame
	var sel: Node = tree.current_scene
	sel.call("select_node", "level_e01")
	await _settle(tree)
	shooter.call("_save_shot", tree, out_dir.path_join("elite_node.png"))

	# 恢复本机存档文件
	if save_bytes.is_empty():
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(save_path)
	else:
		var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	print("[relic_shots] done -> %s" % out_dir)


func _battle(tree: SceneTree, lid: String) -> BattleController:
	SaveManager.set_level_config(lid, {})
	SceneRouter.goto_battle(lid)
	for i: int in LOAD_FRAMES:
		await tree.process_frame
	var c: BattleController = tree.current_scene.get_node("BattleController") as BattleController
	c.persist = false
	var dialogue: Node = tree.current_scene.find_child("DialogueOverlay", true, false)
	if dialogue != null:
		(dialogue as CanvasItem).visible = false
	c.apply_recommended()
	return c


func _settle(tree: SceneTree) -> void:
	for i: int in SETTLE_FRAMES:
		await tree.process_frame
