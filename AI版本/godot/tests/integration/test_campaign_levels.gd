extends GutTest
## 30 关战役（level_c01…c30，chapter_02）整关 headless 测试：
## - 每关经 BattleController 摆放推荐阵型 → 开始前校验 → 跑到结束，期望胜利；
## - 解锁按战役奖励链累积（第一章初始解锁 + c01…c(N-1) 的 rewards），顺带验证奖励链能让每关的推荐解摆得出来；
## - 第 30 关 Boss：到 50% 血暂停，按 recommended.phase2 重新编程 + 增援后「继续」。
## 推荐解与反例的完整对照见 output/关卡完善_20261014（98 个用例）。

const SECONDS: float = 180.0
const CAMPAIGN_SIZE: int = 30


func _campaign_ids() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(1, CAMPAIGN_SIZE + 1):
		out.append("level_c%02d" % i)
	return out


## 进入 level_id 之前玩家应有的解锁：progression 初始 + 之前各关 rewards
func _unlocks_before(level_id: String) -> Dictionary:
	var u: Dictionary = DataRegistry.get_initial_unlocks().duplicate(true)
	for lid: String in _campaign_ids():
		if lid == level_id:
			break
		var rw: Dictionary = DataRegistry.get_level(lid).rewards
		for k: String in ["forms", "presets", "conditions", "selectors", "actions"]:
			var have: Array = u.get(k, []) as Array
			for v: Variant in rw.get("unlock_" + k, []) as Array:
				if not have.has(v):
					have.append(v)
			u[k] = have
	return u


func _run(level_id: String) -> BattleController:
	var level: LevelDefinition = DataRegistry.get_level(level_id)
	var saved: Dictionary = GameState.unlocks
	GameState.unlocks = _unlocks_before(level_id)
	var c := BattleController.new()
	c.setup(level)
	assert_true(c.apply_recommended(), "%s 可摆放推荐阵型" % level_id)
	assert_eq(c.placements.size(), level.recommended_units.size(), "%s 推荐位置全部可放置" % level_id)
	assert_true(c.start(), "%s 推荐部署通过开始前校验：%s" % [level_id, str(c.last_problems)])
	var steps: int = int(ceil(SECONDS / SimTypes.SIM_DT))
	for i: int in steps:
		if c.phase == SimTypes.Phase.PAUSED and c.boss_pending:
			assert_true(c.apply_recommended(), "%s 换阶段暂停时可摆放第二阶段推荐" % level_id)
			c.resume()
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
	GameState.unlocks = saved
	return c


func test_campaign_registered() -> void:
	var ch: ChapterDef = DataRegistry.get_chapter("chapter_02")
	assert_not_null(ch, "chapter_02 存在")
	for lid: String in _campaign_ids():
		assert_not_null(DataRegistry.get_level(lid), "%s 已加载" % lid)
		assert_eq(DataRegistry.chapter_of(lid), ch, "%s 属于 chapter_02" % lid)
	assert_true(DataRegistry.get_initial_levels().has("level_c01"), "战役第一关初始解锁")


func test_campaign_recommended_all_win() -> void:
	for lid: String in _campaign_ids():
		var c: BattleController = _run(lid)
		assert_eq(c.world.result, SimTypes.BattleResult.WIN, "%s 推荐解应胜利（%.1fs）" % [lid, c.world.clock.time])
		gut.p("%s 推荐解：%s @ %.1fs" % [lid, SimTypes.BattleResult.keys()[c.world.result], c.world.clock.time])
		c.free()


func test_boss_pause_rules() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_c30")
	var saved: Dictionary = GameState.unlocks
	GameState.unlocks = _unlocks_before("level_c30")
	var c := BattleController.new()
	c.setup(level)
	c.apply_recommended()
	var phase1_rules: Dictionary = {}
	for uid: String in c.uids():
		phase1_rules[uid] = RuleDef.to_array(c.get_rules(uid))
	assert_true(c.start())
	var paused: bool = false
	for i: int in int(ceil(SECONDS / SimTypes.SIM_DT)):
		c.advance_tick()
		if c.boss_pending:
			paused = true
			break
	assert_true(paused, "Boss 血量过半时暂停")
	assert_eq(c.phase, SimTypes.Phase.PAUSED, "暂停阶段 = PAUSED")
	var t0: float = c.world.clock.time
	c.advance_tick()
	assert_eq(c.world.clock.time, t0, "暂停中时间不推进")
	var alive: String = ""
	for uid: String in c.uids():
		if c._alive_in_world(uid):
			alive = uid
			break
	assert_ne(alive, "", "有存活单位")
	assert_true(c.can_edit_rules(alive), "暂停中可改存活单位的指令")
	assert_false(c.place_unit(alive, Vector2i(2, 6)), "暂停中不能挪动已有单位")
	assert_ne(c.place_problem("lancer", Vector2i(10, 6)), "", "增援区外不能放增援")
	assert_eq(c.place_problem("striker", Vector2i(2, 6)), "", "增援区内可以放增援")
	var u1: String = c.add_unit("bulwark", Vector2i(2, 5))
	var u2: String = c.add_unit("bulwark", Vector2i(2, 7))
	assert_ne(u1, "", "第一名增援")
	assert_ne(u2, "", "第二名增援（4 + 4 ≤ 10）")
	assert_eq(c.add_unit("striker", Vector2i(2, 8)), "", "超过人数上限 / 预算不能再补")
	assert_not_null(c.world.get_unit(c.unit_id_of_slot(u1)), "增援立即出现在战场上")
	c.resume()
	assert_eq(c.world.phase, 2, "继续后进入第二阶段")
	assert_eq(c.phase, SimTypes.Phase.RUNNING)
	c.reset()
	assert_false(c.unit_index.has(u1), "重开后增援被删除")
	for uid: String in phase1_rules.keys():
		assert_eq(RuleDef.to_array(c.get_rules(uid)), phase1_rules[uid], "重开后 %s 恢复第一阶段指令" % uid)
	GameState.unlocks = saved
	c.free()


func test_all_levels_bgm_exists() -> void:
	for lid: String in DataRegistry.get_level_list():
		var bgm: String = DataRegistry.get_level(lid).bgm
		assert_ne(bgm, "", "%s 配置了 BGM" % lid)
		assert_true(ResourceLoader.exists(AudioManager.BGM_DIR + bgm + ".mp3"), "%s 的 BGM %s 存在" % [lid, bgm])
	for path: String in ["res://scripts/screens/main_menu.gd", "res://scripts/screens/level_select.gd"]:
		var menu_bgm: String = str((load(path) as GDScript).get_script_constant_map().get("MENU_BGM", ""))
		assert_true(ResourceLoader.exists(AudioManager.BGM_DIR + menu_bgm + ".mp3"), "%s 的 BGM %s 存在" % [path.get_file(), menu_bgm])
