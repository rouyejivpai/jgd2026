extends RefCounted
## combat_fx_shots.gd 的实现（运行时加载，可引用自动加载）。不改本机存档文件（关卡配置只在内存里改）。

const LOAD_FRAMES: int = 90
const Shots: GDScript = preload("res://tools/take_screenshots_impl.gd")
const Probe: GDScript = preload("res://tools/elite_probe_impl.gd")

var _tree: SceneTree = null
var _out: String = ""
var _shooter: Object = null


func run(tree: SceneTree) -> void:
	_tree = tree
	_out = ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/combat_fx").simplify_path()
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
	_shooter = Shots.new()

	var root: Node2D = await _battle(level_id)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var fx: Node2D = root.get_node("FXLayer") as Node2D
	var views: Dictionary = root.get("_views") as Dictionary
	var ally: UnitView = null
	var enemies: Array[UnitView] = []
	for id: int in views.keys():
		var v: UnitView = views[id] as UnitView
		if v.unit.faction == SimTypes.Faction.ALLY and ally == null:
			ally = v
		elif v.unit.faction == SimTypes.Faction.ENEMY and not v.unit.is_structure():
			enemies.append(v)
	print("[fx_shots] ally=%s enemies=%d" % [ally.unit.def.id if ally != null else "-", enemies.size()])

	# 1. 三种射弹飞行中（己方金色 → 敌人；敌方暗红 → 己方）
	if ally != null and not enemies.is_empty():
		for s: int in 3:
			var e: UnitView = enemies[s % enemies.size()]
			fx.call("spawn_projectile", ally.chest_pos() + Vector2(0.0, (s - 1) * 40.0), e.chest_pos(), true, s, 1.0)
			fx.call("spawn_projectile", e.chest_pos(), ally.chest_pos() + Vector2(0.0, (s - 1) * 40.0), false, s, 1.0)
		await _wait(0.1)
		_shot("01_projectiles.png")
		await _wait(0.12)
		_shot("02_projectile_impact.png")
		await _wait(0.5)

	# 2. 三种斩击（金色 / 暗红各一组），扫到一半与化为粒子时
	if not enemies.is_empty():
		var target: UnitView = enemies[0]
		for k: int in 3:
			var at: Vector2 = target.chest_pos() + Vector2(-260.0 + 260.0 * k, -150.0)
			fx.add_child(CombatFx.Slash.make(at, true, 1.0, Vector2.RIGHT, k))
			fx.add_child(CombatFx.Slash.make(at + Vector2(0.0, 190.0), false, 1.0, Vector2.LEFT, k))
		await _wait(0.035)
		_shot("03a_slash_sweep.png")
		await _wait(0.035)
		_shot("03_slash_mid.png")
		await _wait(0.06)
		_shot("03b_slash_close.png")
		await _wait(0.08)
		_shot("04_slash_dissolve.png")
		await _wait(0.6)

	# 3. 受击碎屑：飞行中、落地后
	if ally != null and not enemies.is_empty():
		var e2: UnitView = enemies[0]
		root.call("_show_hit", { "target": e2.unit.id, "amount": 60.0 }, ally.position)
		await _wait(0.12)
		_shot("05_hit_debris_air.png")
		await _wait(0.5)
		_shot("06_hit_debris_ground.png")

	# 4. 延迟爆炸：预警（己方金色 / 敌方红色）与到期爆炸（临时往世界里塞两个爆炸，拍完移除）
	if not enemies.is_empty() and ally != null:
		var ids: Array[int] = [9001, 9002]
		var spots: Array[Vector2] = [ally.position + Vector2(220.0, -40.0), enemies[0].position + Vector2(-240.0, 60.0)]
		var blasts: Array[SimBlast] = []
		for i: int in 2:
			var bl := SimBlast.new()
			bl.id = ids[i]
			bl.remaining = 1.2
			bl.delay = 2.0
			c.world.blasts.append(bl)
			blasts.append(bl)
			fx.call("spawn_blast_marker", c.world, ids[i], spots[i], 1.5, 2.0, i == 0)
		await _wait(0.3)
		_shot("08_blast_preview.png")
		for bl: SimBlast in blasts:
			bl.remaining = 0.25
		await _wait(0.3)
		_shot("09_blast_preview_late.png")
		for i: int in 2:
			fx.call("detonate_marker", ids[i])
			c.world.blasts.erase(blasts[i])
		root.call("shake", 0.24)
		await _wait(0.06)
		_shot("10_blast_boom.png")
		await _wait(0.16)
		_shot("11_blast_boom_late.png")
		await _wait(0.8)

	# 5. 击败：震屏 → 击飞 → 灰化 → 灰烬
	print("[fx_shots] death victims=%d" % enemies.size())
	if not enemies.is_empty():
		var victim: UnitView = enemies[enemies.size() - 1]
		root.call("_show_death", { "unit": victim.unit.id }, victim.position + Vector2(-220.0, 30.0))
		for t: Array in [[0.05, "12_death_burst"], [0.25, "13_death_knock"], [0.3, "14_death_gray"], [0.35, "15_death_ash"], [0.4, "16_death_ash_late"]]:
			await _wait(float(t[0]))
			_shot("%s.png" % str(t[1]))
		await _wait(0.6)

	# 5b. 光柱：增援出场（己方 / 敌方）、部署落位、遗物骨刃 / 徽章
	if ally != null and not enemies.is_empty():
		fx.call("spawn_pillar", ally.position + Vector2(200.0, 0.0), true, 1.0, "spawn")
		fx.call("spawn_pillar", enemies[0].position + Vector2(-200.0, 0.0), false, 1.0, "spawn")
		fx.call("spawn_pillar", ally.position + Vector2(380.0, 0.0), true, 1.0, "place")
		fx.call("spawn_pillar", ally.position + Vector2(200.0, 200.0), true, 1.0, "strike")
		fx.call("spawn_pillar", ally.position + Vector2(380.0, 200.0), true, 1.0, "heal")
		await _wait(0.15)
		_shot("17_pillars.png")
		await _wait(1.2)

	# 6. 开战：脚印、目标锁定线、实战特效（连拍）
	c.start()
	var run_shots: int = 16
	var run_every: float = 0.3
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--run-every="):
			run_every = float(a.trim_prefix("--run-every="))
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--run-shots="):
			run_shots = int(a.trim_prefix("--run-shots="))
	for i: int in run_shots:
		await _wait(run_every)
		_shot("20_running_%02d.png" % i)

	if save_bytes.is_empty():
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	else:
		var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	print("[fx_shots] done -> %s" % _out)


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


func _shot(name: String) -> void:
	_shooter.call("_save_shot", _tree, _out.path_join(name))
