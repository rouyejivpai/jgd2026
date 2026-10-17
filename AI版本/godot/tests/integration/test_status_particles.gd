extends GutTest
## 第五阶段：异常状态粒子（data/status_fx.json + StatusParticles + status_overlay.sync_particles）——
## 有状态即发射并跟随单位、状态结束停止发射、动效总闸关闭不发射；参数映射到 CPUParticles2D。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")

var _saved_level_id: String
var _saved_motion: bool


func before_each() -> void:
	_saved_level_id = GameState.current_level_id
	_saved_motion = UiKit.motion_enabled
	GameState.tutorials_enabled = false


func after_each() -> void:
	GameState.current_level_id = _saved_level_id
	UiKit.motion_enabled = _saved_motion
	GameState.tutorials_enabled = true


func test_spec_maps_to_particles() -> void:
	var specs: Dictionary = DataRegistry.get_status_fx()["statuses"] as Dictionary
	assert_eq_deep(specs.keys(), ["vulnerable", "paralysis", "slow"])
	var p: CPUParticles2D = StatusParticles.make(specs["paralysis"] as Dictionary)
	autofree(p)
	assert_eq(p.amount, int((specs["paralysis"] as Dictionary)["amount"]))
	assert_eq(p.emission_shape, CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE, "ring = 圆周发射（电火花绕身）")
	assert_true(p.local_coords, "粒子随单位与镜头移动")
	assert_not_null(p.texture, "运行时生成的圆点贴图")
	var base := Color(str((specs["paralysis"] as Dictionary)["color"]))
	var energy: float = float((specs["paralysis"] as Dictionary)["energy"])
	assert_almost_eq(p.color_ramp.get_color(0).r, base.r * energy, 0.001, "起始色 × 亮度倍数（HDR）")
	assert_almost_eq(p.color_ramp.get_color(1).a, 0.0, 0.001, "末端淡出")
	var slow: CPUParticles2D = StatusParticles.make(specs["slow"] as Dictionary)
	autofree(slow)
	assert_gt(slow.direction.y, 0.0, "减速：向下沉")


func test_overlay_emits_while_status_lasts() -> void:
	GameState.current_level_id = "level_01"
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	await wait_process_frames(2)
	var overlay: Node2D = root.get_node("StatusOverlay") as Node2D
	var c: BattleController = root.get_node("BattleController") as BattleController
	var enemy: SimUnit = null
	for u: SimUnit in c.world.units:
		if u.faction == SimTypes.Faction.ENEMY:
			enemy = u
	enemy.add_status("vulnerable", 2.0)
	enemy.add_status("slow", 2.0)
	overlay.call("sync_particles")
	var keys: Array = overlay.call("active_fx") as Array
	assert_true(keys.has("%d:vulnerable" % enemy.id))
	assert_true(keys.has("%d:slow" % enemy.id))
	var e: CPUParticles2D = overlay.get_node("StatusFx_%d_vulnerable" % enemy.id) as CPUParticles2D
	assert_true(e.emitting)
	var spec: Dictionary = (DataRegistry.get_status_fx()["statuses"] as Dictionary)["vulnerable"] as Dictionary
	assert_eq(e.position, SimTypes.sim_to_screen(enemy.pos, c.level.height) + StatusParticles.offset_px(spec), "跟随单位")
	enemy.statuses.erase("slow")
	overlay.call("sync_particles")
	assert_false((overlay.call("active_fx") as Array).has("%d:slow" % enemy.id), "状态结束停止")
	UiKit.motion_enabled = false
	overlay.call("sync_particles")
	assert_eq((overlay.call("active_fx") as Array).size(), 0, "动效总闸关闭：不发射")
