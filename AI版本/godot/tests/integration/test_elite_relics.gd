extends GutTest
## 精英关（level_e01…e04）与遗物（data/relics.json）：
## - 2026-10-20 精英关已从章节地图去掉、不再发遗物（文件保留作遗物测试场景，推荐解仍在「刚通关前驱关」的解锁下胜利）；遗物由剧情关掉落并写入存档；
## - 遗物：同一场只能启用一枚；地块遗物只能开战前放、骨刃 / 徽章只能战斗中用；地块对站在上面的敌人施加状态；伤害 / 治疗、次数与冷却；重开恢复次数、保留地块。
## 数值对照（推荐解 / 反例 / 遗物场景）见 tools/elite_scenarios.json（tools/elite_probe.gd）。

const SECONDS: float = 180.0
const ELITES: Dictionary = {   ## 精英关 -> [前驱关, 奖励遗物, 解锁时机 = 进入此关之前]
	"level_e01": ["level_c06", "bone_blade", "level_c07"],
	"level_e02": ["level_c14", "badge", "level_c15"],
	"level_e03": ["level_c22", "lantern", "level_c23"],
	"level_e04": ["level_c26", "bone_arm", "level_c27"],
}

const RELIC_SOURCES: Dictionary = {   ## 2026-10-20：遗物 -> 掉落的剧情关（骨刃 塞拉 / 徽章 骨者 / 提灯 地窖魂灯 / 骨臂 敲钟魔女）
	"bone_blade": "level_c10", "badge": "level_c14", "lantern": "level_c17", "bone_arm": "level_c18",
}

var _saved_unlocks: Dictionary = {}


func before_each() -> void:
	_saved_unlocks = GameState.unlocks


func after_each() -> void:
	GameState.unlocks = _saved_unlocks


## 进入 before_level 之前玩家应有的解锁：progression 初始 + 之前各战役关 rewards（同 test_campaign_levels）
func _unlocks_before(before_level: String, relics: Array = []) -> Dictionary:
	var u: Dictionary = DataRegistry.get_initial_unlocks().duplicate(true)
	for i: int in range(1, 31):
		var lid: String = "level_c%02d" % i
		if lid == before_level:
			break
		var rw: Dictionary = DataRegistry.get_level(lid).rewards
		for k: String in ["forms", "presets", "conditions", "selectors", "actions"]:
			var have: Array = u.get(k, []) as Array
			for v: Variant in rw.get("unlock_" + k, []) as Array:
				if not have.has(v):
					have.append(v)
			u[k] = have
	u["relics"] = relics.duplicate()
	return u


func _controller(level_id: String, relics: Array = []) -> BattleController:
	GameState.unlocks = _unlocks_before(str((ELITES.get(level_id, ["", "", "level_c30"]) as Array)[2]), relics)
	var c := BattleController.new()
	c.setup(DataRegistry.get_level(level_id))
	return c


func _run_to_end(c: BattleController) -> void:
	for i: int in int(ceil(SECONDS / SimTypes.SIM_DT)):
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()


func _advance_seconds(c: BattleController, seconds: float) -> void:
	for i: int in int(ceil(seconds / SimTypes.SIM_DT)):
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()


# ---- 精英关 ----
## 2026-10-20 用户：精英关去掉——不在章节地图上、不再发遗物；遗物改由剧情对应关掉落（RELIC_SOURCES）
func test_elites_retired_from_chapter() -> void:
	var ch: ChapterDef = DataRegistry.get_chapter("chapter_02")
	for lid: String in ELITES.keys():
		assert_not_null(DataRegistry.get_level(lid), "%s 仍可加载（遗物测试场景）" % lid)
		assert_true(ch.node_of_level(lid).is_empty(), "%s 不在章节地图上" % lid)
		assert_true(DataRegistry.get_level(lid).reward_relics().is_empty(), "%s 不再发遗物" % lid)
		var pre: String = str((ELITES[lid] as Array)[0])
		assert_eq(ch.region_progress(ch.region_of_level(pre), [pre]).x, 1, "%s 所在区域照常计数" % pre)


func test_elite_recommended_win() -> void:
	for lid: String in ELITES.keys():
		var c: BattleController = _controller(lid)
		assert_true(c.apply_recommended(), "%s 可摆放推荐阵型" % lid)
		assert_eq(c.placements.size(), c.level.recommended_units.size(), "%s 推荐位置全部可放置" % lid)
		assert_true(c.start(), "%s 推荐部署通过开始前校验：%s" % [lid, str(c.last_problems)])
		_run_to_end(c)
		assert_eq(c.world.result, SimTypes.BattleResult.WIN, "%s 推荐解应胜利（%.1fs）" % [lid, c.world.clock.time])
		gut.p("%s 推荐解：%s @ %.1fs" % [lid, SimTypes.BattleResult.keys()[c.world.result], c.world.clock.time])
		c.free()


func test_story_level_reward_grants_relic() -> void:
	var data: Dictionary = SaveManager.new_save(DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels())
	assert_eq((data["unlocks"] as Dictionary).get("relics", null), [], "新存档有空的遗物列表")
	SaveManager.apply_rewards(data, "level_c10", DataRegistry.get_level("level_c10").rewards)
	assert_eq((data["unlocks"] as Dictionary)["relics"], ["bone_blade"], "通关猎犬头目获得骨刃")
	SaveManager.apply_rewards(data, "level_c10", DataRegistry.get_level("level_c10").rewards)
	assert_eq((data["unlocks"] as Dictionary)["relics"], ["bone_blade"], "重复通关不重复发放")
	assert_true(((data["progress"] as Dictionary)["completed"] as Array).has("level_c10"), "记为已通关")


func test_relic_data() -> void:
	assert_eq(DataRegistry.get_relic_ids(), ["bone_blade", "badge", "lantern", "bone_arm"] as Array[String], "四枚遗物按顺序")
	for id: String in DataRegistry.get_relic_ids():
		var d: Dictionary = DataRegistry.get_relic(id)
		assert_true(ResourceLoader.exists(str(d["icon"])), "%s 图标存在" % id)
		assert_eq(DataRegistry.relic_source_level(id).id, str(RELIC_SOURCES[id]), "%s 由剧情对应关掉落" % id)


# ---- 遗物规则 ----
func test_relic_locked_and_phase_rules() -> void:
	var c: BattleController = _controller("level_e04", ["bone_blade", "bone_arm"])
	assert_eq(c.relic_problem("badge"), "locked", "未获得的遗物不可用")
	assert_eq(c.relic_problem("bone_blade"), "battle_only", "骨刃只能战斗中使用")
	assert_eq(c.relic_problem("bone_arm"), "", "骨臂开战前可用")
	assert_false(c.can_place_relic_tile("bone_arm", Vector2i(6, 3)), "障碍格放不了地块")
	assert_false(c.can_place_relic_tile("bone_arm", Vector2i(-1, 5)), "网格外放不了地块")
	c.apply_recommended()
	c.start()
	assert_eq(c.relic_problem("bone_arm"), "deploy_only", "开战后不能再放地块")
	assert_eq(c.relic_problem("bone_blade"), "", "开战后骨刃可用")
	c.free()


func test_only_one_relic_active() -> void:
	var c: BattleController = _controller("level_e04", ["bone_blade", "lantern", "bone_arm"])
	assert_true(c.place_relic_tile("bone_arm", Vector2i(14, 5)), "放下骨臂地块")
	assert_eq(c.relic_active, "bone_arm", "骨臂启用")
	assert_eq(c.relic_problem("lantern"), "other_active", "同场不能再放提灯")
	assert_eq(c.relic_problem("bone_blade"), "other_active", "同场不能再用骨刃")
	assert_false(c.place_relic_tile("lantern", Vector2i(10, 5)), "提灯被拒绝")
	assert_eq(c.relic_problem("bone_arm"), "placed", "骨臂已放下")
	assert_true(c.place_relic_tile("bone_arm", Vector2i(13, 5)), "已放下的地块可以挪位")
	assert_eq(c.relic_tile["cell"], Vector2i(13, 5))
	assert_true(c.remove_relic_tile(), "部署阶段可撤回")
	assert_eq(c.relic_active, "", "撤回后不再有启用的遗物")
	assert_eq(c.relic_problem("lantern"), "", "撤回后可改用提灯")
	c.free()


func test_tile_applies_status_to_enemies_only() -> void:
	var c: BattleController = _controller("level_e04", ["bone_arm"])
	assert_true(c.place_relic_tile("bone_arm", Vector2i(14, 5)))
	assert_eq(c.world.relic_tiles.size(), 9, "3×3 地块（无障碍）")
	c.apply_recommended()
	assert_eq(c.world.relic_tiles.size(), 9, "重建世界后地块仍在")
	c.start()
	c.advance_tick()
	var hulk: SimUnit = c.world.get_spawn("B1")
	assert_true(hulk.has_status("vulnerable"), "站在骨臂地块上的巨像获得易伤")
	for u: SimUnit in c.world.units:
		if u.faction == SimTypes.Faction.ALLY:
			assert_false(u.has_status("vulnerable"), "我方不受遗物地块影响")
	c.free()


func test_lantern_slows_enemy() -> void:
	var c: BattleController = _controller("level_e03", ["lantern"])
	assert_true(c.place_relic_tile("lantern", Vector2i(11, 5)))
	c.apply_recommended()
	c.start()
	c.advance_tick()
	var hound: SimUnit = c.world.get_spawn("D3")
	assert_true(hound.has_status("slow"), "站在提灯地块上的猎犬被减速")
	assert_almost_eq(StatusSystem.speed_mult(c.world, hound), 0.6, 0.001, "移速 ×0.6")
	c.free()


func test_blade_strike_charges_and_cooldown() -> void:
	var c: BattleController = _controller("level_e01", ["bone_blade"])
	c.apply_recommended()
	c.start()
	c.advance_tick()
	var spitter: SimUnit = c.world.get_spawn("S1")
	var hp0: float = spitter.hp
	assert_eq(c.use_relic_on("bone_blade", c.unit_id_of_slot(c.deployed_uids()[0])), -1.0, "骨刃不能砍自己人")
	assert_almost_eq(c.use_relic_on("bone_blade", spitter.id), 50.0, 0.001, "骨刃造成 50 伤害")
	assert_almost_eq(spitter.hp, hp0 - 50.0, 0.001)
	assert_eq(c.relic_charges_left("bone_blade"), 1, "剩 1 次")
	assert_eq(c.relic_problem("bone_blade"), "cooldown", "冷却中")
	_advance_seconds(c, 6.1)
	assert_eq(c.relic_problem("bone_blade"), "", "冷却结束")
	assert_true(c.use_relic_on("bone_blade", spitter.id) > 0.0, "第二刀")
	_advance_seconds(c, 6.1)
	assert_eq(c.relic_problem("bone_blade"), "no_charges", "每场 2 次")
	c.reset()
	assert_eq(c.relic_charges_left("bone_blade"), 2, "重开恢复次数")
	assert_eq(c.relic_active, "", "重开后（无地块）不再锁定其他遗物")
	c.free()


func test_blade_kill_ends_battle() -> void:
	var c: BattleController = _controller("level_e01", ["bone_blade"])
	c.apply_recommended()
	c.start()
	c.advance_tick()
	for u: SimUnit in c.world.units:
		if u.faction == SimTypes.Faction.ENEMY and u.spawn_id != "S1":
			u.hp = 0.0
			u.alive = false
	c.world.get_spawn("S1").hp = 10.0
	c.use_relic_on("bone_blade", c.world.get_spawn("S1").id)
	assert_eq(c.world.result, SimTypes.BattleResult.WIN, "骨刃补掉最后一个敌人即胜利")
	assert_eq(c.phase, SimTypes.Phase.ENDED, "战斗结束")
	c.free()


func test_badge_heal_clamps() -> void:
	var c: BattleController = _controller("level_e02", ["badge"])
	c.apply_recommended()
	c.start()
	c.advance_tick()
	var ally: SimUnit = c.world.get_unit(c.unit_id_of_slot(c.deployed_uids()[0]))
	assert_false(c.relic_target_ok("badge", ally.id), "满血单位不能作为徽章目标")
	ally.hp = ally.max_hp - 20.0
	assert_almost_eq(c.use_relic_on("badge", ally.id), 20.0, 0.001, "回复不超过上限")
	assert_almost_eq(ally.hp, ally.max_hp, 0.001)
	assert_eq(c.use_relic_on("badge", c.world.get_spawn("M1").id), -1.0, "徽章不能治疗敌人")
	c.free()


func test_tile_kept_on_reset() -> void:
	var c: BattleController = _controller("level_e04", ["bone_arm"])
	c.place_relic_tile("bone_arm", Vector2i(14, 5))
	c.apply_recommended()
	c.start()
	_advance_seconds(c, 1.0)
	c.reset()
	assert_eq(c.relic_active, "bone_arm", "重开后地块仍在、仍为本场遗物")
	assert_eq(c.world.relic_tiles.size(), 9)
	c.free()
