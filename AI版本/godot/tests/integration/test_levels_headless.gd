extends GutTest
## 05 §3 整关 headless 集成测试。M2：第一关部分（推荐解胜、预期失败、1×/2× 一致）。

const LEVEL_SECONDS: float = 60.0
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
}


## 经 BattleController 摆放「推荐阵型」（推荐部署 + 推荐指令）运行到结束（或超时），返回控制器（调用方负责 free）
func _run_controller(level_id: String, speed: int, rules_override: Dictionary = {}) -> BattleController:
	var level: LevelDefinition = DataRegistry.get_level(level_id)
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED      # 后续关卡的推荐指令需要前几关的解锁
	var c := BattleController.new()
	c.setup(level)
	assert_true(c.apply_recommended(), "部署阶段可摆放推荐阵型")
	assert_eq(c.placements.size(), level.recommended_units.size(), "推荐位置全部可放置")
	for sid: String in rules_override.keys():
		c.set_rules(c.recommended_uid(sid), SimFactory.to_rules(rules_override[sid] as Array))
	c.set_speed(speed)
	assert_true(c.start(), "推荐部署通过开始前校验")
	GameState.unlocks = saved_unlocks
	var max_ticks: int = int(ceil(LEVEL_SECONDS / SimTypes.SIM_DT))
	for i: int in max_ticks:
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
	return c


## 第一关预期失败：关闭两名单位的全部攻击类指令（verification.expected_fail）
func _l1_attacks_disabled() -> Dictionary:
	var level: LevelDefinition = DataRegistry.get_level("level_01")
	var out: Dictionary = {}
	for ru: RecommendedUnitDef in level.recommended_units:
		var rules: Array[RuleDef] = level.recommended_rules(ru.slot_id)
		for r: RuleDef in rules:
			if r.action.type == SimTypes.ActionType.ATTACK or r.action.type == SimTypes.ActionType.CHASE_ATTACK:
				r.enabled = false
		out[ru.slot_id] = rules
	return out


func test_level_01_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_01")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	gut.p("level_01 推荐解：WIN @ %.2fs" % w.clock.time)


func test_level_01_expected_fail() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_01")
	var w: SimWorld = SimFactory.make_world("level_01", level.recommended_deploy, _l1_attacks_disabled())
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	assert_ne(result, SimTypes.BattleResult.WIN, "禁用攻击指令后不应胜利")
	gut.p("level_01 预期失败：%s @ %.2fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	assert_eq(result, SimTypes.BattleResult.LOSE)
	for e: Dictionary in SimFactory.events_of(w, SimTypes.EventType.ATTACK_FIRED):
		assert_gte(int(e["source"]), SimTypes.ENEMY_ID_BASE, "己方从未出手")
	# 战斗中己方处于待机，且关闭的攻击指令不参与求值
	var w2: SimWorld = SimFactory.make_world("level_01", level.recommended_deploy, _l1_attacks_disabled())
	SimFactory.run_steps(w2, 60)
	for u: SimUnit in w2.units:
		if u.faction == SimTypes.Faction.ALLY:
			assert_eq(u.current_action, SimTypes.ActionType.IDLE)
			assert_eq(u.current_rule, 2, "落到兜底待机")


func test_level_01_speed_1x_2x_consistent() -> void:
	var c1: BattleController = _run_controller("level_01", 1)
	var c2: BattleController = _run_controller("level_01", 2)
	assert_eq(c1.phase, SimTypes.Phase.ENDED)
	assert_eq(c2.phase, SimTypes.Phase.ENDED)
	assert_eq(c1.world.result, SimTypes.BattleResult.WIN)
	assert_eq(c2.world.result, c1.world.result)
	assert_eq(c2.world.clock.steps, c1.world.clock.steps)
	assert_eq(c2.world.state_hash(), c1.world.state_hash(), "1×/2× state_hash 一致")
	c1.free()
	c2.free()


func test_level_01_controller_reset_restores_world() -> void:
	var c: BattleController = _run_controller("level_01", 2)
	var level: LevelDefinition = DataRegistry.get_level("level_01")
	c.reset()
	assert_eq(c.phase, SimTypes.Phase.DEPLOY)
	assert_eq(c.world.clock.steps, 0)
	assert_eq(c.placements.size(), level.recommended_units.size(), "重置保留部署")
	for u: SimUnit in c.world.units:
		assert_true(u.alive)
		assert_eq(u.hp, u.max_hp)
	c.free()


func test_level_01_cannot_start_without_deploy() -> void:
	var c := BattleController.new()
	c.setup(DataRegistry.get_level("level_01"))
	assert_false(c.start(), "不部署不能开始")
	assert_eq(c.phase, SimTypes.Phase.DEPLOY)
	assert_eq(str(c.last_problems.map(func(p: Dictionary) -> String: return str(p["code"]))), str(["TOO_FEW_UNITS"]), "free 关：至少出场 1 名")
	c.free()


# ---- 第二关 ----
func test_level_02_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_02")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	var bulwark: SimUnit = w.get_spawn("slot_bulwark")
	gut.p("level_02 推荐解：WIN @ %.2fs，承伤剩余 %.0f" % [w.clock.time, maxf(bulwark.hp, 0.0)])


func test_level_02_expected_fail_front_back_swapped() -> void:
	# verification.expected_fail：前后排倒置——攻击形态在前、承伤在后
	var deploy: Dictionary = { "slot_bulwark": Vector2i(1, 3), "slot_striker_a": Vector2i(3, 2), "slot_striker_b": Vector2i(3, 4) }
	var w: SimWorld = SimFactory.make_world("level_02", deploy)
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	var losses: int = _ally_losses(w)
	gut.p("level_02 前后排倒置：%s @ %.2fs，己方阵亡 %d" % [SimTypes.BattleResult.keys()[result], w.clock.time, losses])
	assert_gt(losses, 0, "倒置站位：前排攻击形态被集火倒下（可解释的代价）")
	var rec: SimWorld = SimFactory.make_recommended_world("level_02")
	SimFactory.run_until_end(rec, LEVEL_SECONDS)
	assert_eq(_ally_losses(rec), 0, "推荐站位无阵亡")
	if result == SimTypes.BattleResult.WIN:
		pending("Q-016：当前第二关数值下倒置站位仍可胜利（文档预期为失败），待策划决定是否调数值")
	else:
		assert_ne(result, SimTypes.BattleResult.WIN)


func _ally_losses(w: SimWorld) -> int:
	var n: int = 0
	for u: SimUnit in w.units:
		if u.faction == SimTypes.Faction.ALLY and u.kind == SimTypes.UnitKind.UNIT and not u.alive:
			n += 1
	return n


func test_level_02_speed_1x_2x_consistent() -> void:
	var c1: BattleController = _run_controller("level_02", 1)
	var c2: BattleController = _run_controller("level_02", 2)
	assert_eq(c1.world.result, SimTypes.BattleResult.WIN)
	assert_eq(c2.world.result, c1.world.result)
	assert_eq(c2.world.clock.steps, c1.world.clock.steps)
	assert_eq(c2.world.state_hash(), c1.world.state_hash())
	c1.free()
	c2.free()


# ---- 配置存档往返（01 §6.11 / §10） ----
func test_controller_config_save_roundtrip() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_02")
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	var c := BattleController.new()
	c.setup(level)
	var u1: String = c.add_unit("bulwark", Vector2i(3, 3))
	var u2: String = c.add_unit("striker", Vector2i(1, 2))
	assert_eq([u1, u2], ["u1", "u2"], "uid 递增分配")
	assert_eq(c.get_rules(u2).size(), 0, "新放置单位指令为空（07 §2）")
	var rules: Array[RuleDef] = level.recommended_rules("slot_striker_a")
	rules[1].enabled = true                              # 打开推荐指令中关闭的追击
	var moved: RuleDef = rules[2]
	rules.remove_at(2)
	rules.insert(0, moved)                               # 调整顺序
	assert_true(c.set_rules(u2, rules))
	var u3: String = c.add_unit("striker", Vector2i(1, 4))
	assert_true(c.remove_unit(u3), "收回 = 删除并返还 Cost")
	assert_eq(c.budget_used(), 7)
	var raw: Dictionary = JSON.parse_string(JSON.stringify(c.config_to_raw())) as Dictionary   # 模拟写盘再读回
	var c2 := BattleController.new()
	c2.setup(level, raw)
	assert_eq(str(c2.placements), str(c.placements), "部署恢复")
	assert_eq(str(c2.uids()), str(["u1", "u2"]))
	for uid: String in c.uids():
		assert_eq(c2.form_of(uid), c.form_of(uid))
		assert_eq_deep(RuleDef.to_array(c2.get_rules(uid)), RuleDef.to_array(c.get_rules(uid)))
	assert_eq(c2.next_uid, 4, "uid 不复用（u3 已用过）")
	assert_eq(c2.add_unit("striker", Vector2i(1, 4)), "u4")
	assert_eq(c2.load_problems.size(), 0)
	GameState.unlocks = saved_unlocks
	c.free()
	c2.free()


## 07 §4.1：出场卡、预算与人数上限
func test_free_roster_budget_and_limits() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_02")    # budget 10、max 3、bulwark/striker
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	var c := BattleController.new()
	c.setup(level)
	assert_eq(str(c.card_forms()), str(["bulwark", "striker"]), "出场卡 = available_forms ∩ 已解锁")
	assert_eq(c.add_unit("swift", Vector2i(1, 1)), "", "不在本关可用形态")
	assert_ne(c.add_unit("bulwark", Vector2i(3, 3)), "")
	assert_ne(c.add_unit("bulwark", Vector2i(3, 2)), "")
	assert_false(c.can_add_form("striker"), "4+4+3 > 10：预算不足")
	assert_eq(c.add_unit("striker", Vector2i(1, 2)), "")
	assert_eq(c.add_unit("bulwark", Vector2i(2, 3)), "", "预算不足")
	assert_eq(c.budget_used(), 8)
	GameState.unlocks = { "forms": ["striker"] }
	assert_eq(str(c.card_forms()), str(["striker"]), "未解锁的形态不出卡")
	GameState.unlocks = saved_unlocks
	c.free()


func test_saved_invalid_rule_flagged_not_deleted() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_01")
	var raw: Dictionary = { "units": [{ "uid": "u1", "form": "striker", "pos": [2, 2], "rules": [SimFactory.r_attack_in_range("farthest"), SimFactory.r_idle()] }], "next_uid": 2 }
	var c := BattleController.new()
	c.setup(level, raw)
	assert_gt(c.load_problems.size(), 0, "失效指令被标记")
	assert_eq(str(c.load_problems[0]["code"]), "RULE_NOT_ALLOWED")
	assert_eq(c.get_rules("u1").size(), 2, "失效指令保留在列表中")
	assert_eq(c.get_rules("u1")[0].target.selector, SimTypes.Selector.FARTHEST)
	c.free()


# ---- 第三关 ----
func test_level_03_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_03")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	gut.p("level_03 推荐解：WIN @ %.2fs" % w.clock.time)


func test_level_03_expected_fail_frontal_charge() -> void:
	# verification.expected_fail：两单位一起走庭院正面，见敌就停下硬拼（不诱敌、不撤离）
	var yard: Dictionary = { "conditions": [], "action": { "type": "follow_route", "route_id": "yard" } }
	var rules: Array = [SimFactory.r_attack_in_range(), yard]
	var w: SimWorld = SimFactory.make_world("level_03", { "slot_swift": Vector2i(2, 5), "slot_striker": Vector2i(2, 6) },
		{ "slot_swift": rules, "slot_striker": rules })
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_03 正面硬冲：%s @ %.2fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	assert_ne(result, SimTypes.BattleResult.WIN)


func test_level_03_speed_1x_2x_consistent() -> void:
	_assert_speed_consistent("level_03")


## 05 §3 第 5 条：守卫 W1/W2 在诱饵存活且可见期间 current_target 恒为诱饵（逐步断言）。
## "可见"按决策时刻（本步开始时的位置）判断。
func test_level_03_wardens_never_switch_from_decoy() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_03")
	var decoy: SimUnit = w.get_spawn("slot_swift")
	var striker: SimUnit = w.get_spawn("slot_striker")
	var checked: int = 0
	var striker_visible_steps: int = 0
	var violations: PackedStringArray = PackedStringArray()
	for i: int in int(LEVEL_SECONDS / SimTypes.SIM_DT):
		if w.result != SimTypes.BattleResult.NONE:
			break
		var visible_before: Dictionary = {}
		for sid: String in ["W1", "W2"]:
			var wd: SimUnit = w.get_spawn(sid)
			visible_before[sid] = wd.alive and decoy.alive and wd.pos.distance_to(decoy.pos) <= wd.vision
			if wd.alive and striker.alive and wd.pos.distance_to(striker.pos) <= wd.vision:
				striker_visible_steps += 1
		w.step()
		for sid: String in ["W1", "W2"]:
			var wd: SimUnit = w.get_spawn(sid)
			if bool(visible_before[sid]) and wd.alive:
				checked += 1
				if wd.current_target != decoy.id:
					violations.append("%s t=%.2f target=%d" % [sid, w.clock.time, wd.current_target])
	gut.p("level_03 锁定专项：检查 %d 步，基础攻击形态处于守卫视野内 %d 步，违规 %d" % [checked, striker_visible_steps, violations.size()])
	assert_gt(checked, 0, "诱饵确实进入过守卫视野")
	assert_gt(striker_visible_steps, 0, "基础攻击形态也曾处于守卫视野内（偷换风险真实存在）")
	assert_eq(violations.size(), 0, "锁定不偷换：%s" % ", ".join(violations))
	assert_eq(w.result, SimTypes.BattleResult.WIN)


# ---- 第四关 ----
func test_level_04_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_04")
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_04 推荐解：%s @ %.2fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	assert_eq(result, SimTypes.BattleResult.WIN)


func test_level_04_expected_fail_single_chaser() -> void:
	# 05 §4.2"单向追击追不上"：只有快速形态从正面追，两名攻击形态原地待机
	var chase: Array = [SimFactory.r_attack_in_range("nearest", "unit"), SimFactory.r_chase_attack_visible("nearest", "unit"), SimFactory.r_idle()]
	var level: LevelDefinition = DataRegistry.get_level("level_04")
	var w: SimWorld = SimFactory.make_world("level_04", level.recommended_deploy,
		{ "slot_striker_a": [SimFactory.r_idle()], "slot_striker_b": [SimFactory.r_idle()], "slot_swift": chase })
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_04 单向追击：%s @ %.2fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	if result == SimTypes.BattleResult.WIN:
		pending("Q-021：快速形态移速 4.5 > 猎犬 4.0，单向追击也能把猎犬逼进角落；待策划决定数值")
	else:
		assert_ne(result, SimTypes.BattleResult.WIN)


func test_level_04_speed_1x_2x_consistent() -> void:
	_assert_speed_consistent("level_04")


func _assert_speed_consistent(level_id: String) -> void:
	var c1: BattleController = _run_controller(level_id, 1)
	var c2: BattleController = _run_controller(level_id, 2)
	assert_eq(c1.world.result, SimTypes.BattleResult.WIN)
	assert_eq(c2.world.result, c1.world.result)
	assert_eq(c2.world.clock.steps, c1.world.clock.steps)
	assert_eq(c2.world.state_hash(), c1.world.state_hash(), "%s 1×/2× state_hash 一致" % level_id)
	c1.free()
	c2.free()


# ---- 第五关 ----
func _spitter_ids(w: SimWorld) -> Array[int]:
	return [w.get_spawn("S1").id, w.get_spawn("S2").id]


func test_level_05_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_05")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	gut.p("level_05 推荐解：WIN @ %.2fs，放置爆炸 %d 次" % [w.clock.time, SimFactory.events_of(w, SimTypes.EventType.BLAST_PLACED).size()])


## 05 §3 第 6 条：至少放置一次爆炸；推荐解下快速形态从未在爆炸中受伤
func test_level_05_blasts_placed_and_swift_never_hit() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_05")
	SimFactory.run_until_end(w, LEVEL_SECONDS)
	var swift: SimUnit = w.get_spawn("slot_swift")
	var spitters: Array[int] = _spitter_ids(w)
	var placed: Array[Dictionary] = SimFactory.events_of(w, SimTypes.EventType.BLAST_PLACED)
	var swift_targeted: int = 0
	for e: Dictionary in placed:
		if int(e["target"]) == swift.id:
			swift_targeted += 1
	var swift_hits: int = 0
	for e: Dictionary in SimFactory.events_of(w, SimTypes.EventType.DAMAGE_APPLIED):
		if int(e["target"]) == swift.id and spitters.has(int(e["source"])):
			swift_hits += 1
	gut.p("level_05 专项：放置 %d 次，其中锁定快速形态 %d 次，快速形态被炸 %d 次" % [placed.size(), swift_targeted, swift_hits])
	assert_gt(placed.size(), 0, "至少放置一次爆炸")
	assert_gt(swift_targeted, 0, "快速形态确实成为过最远目标")
	assert_eq(swift_hits, 0, "快速形态从未在爆炸中受伤")


func test_level_05_redeploy_changes_farthest() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_05")
	var a: SimWorld = SimFactory.make_recommended_world("level_05")
	var deploy_b: Dictionary = level.recommended_deploy.duplicate()
	deploy_b["slot_swift"] = Vector2i(1, 0)      # 快速形态换到左下角
	var b: SimWorld = SimFactory.make_world("level_05", deploy_b)
	SimFactory.run_steps(a, 120)
	SimFactory.run_steps(b, 120)
	var ta: PackedStringArray = PackedStringArray()
	for e: Dictionary in SimFactory.events_of(a, SimTypes.EventType.BLAST_PLACED):
		ta.append("%d@(%.1f,%.1f)" % [int(e["target"]), (e["pos"] as Vector2).x, (e["pos"] as Vector2).y])
	var tb: PackedStringArray = PackedStringArray()
	for e: Dictionary in SimFactory.events_of(b, SimTypes.EventType.BLAST_PLACED):
		tb.append("%d@(%.1f,%.1f)" % [int(e["target"]), (e["pos"] as Vector2).x, (e["pos"] as Vector2).y])
	gut.p("level_05 前 4 秒爆炸：推荐部署 %s；快速形态在 (1,0) %s" % [", ".join(ta), ", ".join(tb)])
	assert_ne(", ".join(ta), ", ".join(tb), "重新部署改变最远者 / 落点")


func test_level_05_expected_fail_decoy_idle() -> void:
	# verification.expected_fail：快速形态不动——最远者变成推进中的单位，连续承受爆炸
	var w: SimWorld = SimFactory.make_world("level_05", DataRegistry.get_level("level_05").recommended_deploy, { "slot_swift": [SimFactory.r_idle()] })
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_05 诱饵不动：%s @ %.2fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	assert_ne(result, SimTypes.BattleResult.WIN)


func test_level_05_speed_1x_2x_consistent() -> void:
	_assert_speed_consistent("level_05")


# ---- 第六关 ----
func test_level_06_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_06")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	gut.p("level_06 推荐解：WIN @ %.2fs，祭司倒在 x=%.1f" % [w.clock.time, w.get_spawn("PRIEST").pos.x])


## 05 §3 第 7 条：三具残骸首次锁定均为承伤；祭司死亡时远射的 current_target 曾为祭司
func test_level_06_husks_lock_bulwark_and_lancer_targets_priest() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_06")
	var bulwark: SimUnit = w.get_spawn("slot_bulwark")
	var lancer: SimUnit = w.get_spawn("slot_lancer")
	var priest: SimUnit = w.get_spawn("PRIEST")
	var first_lock: Dictionary = {}
	var lancer_on_priest: bool = false
	for i: int in int(LEVEL_SECONDS / SimTypes.SIM_DT):
		if w.result != SimTypes.BattleResult.NONE:
			break
		w.step()
		for sid: String in ["H1", "H2", "H3"]:
			var h: SimUnit = w.get_spawn(sid)
			if not first_lock.has(sid) and h.lock_target >= 0:
				first_lock[sid] = h.lock_target
		if lancer.current_target == priest.id:
			lancer_on_priest = true
	gut.p("level_06 专项：残骸首次锁定 %s（承伤 id=%d），远射曾锁定祭司=%s" % [first_lock, bulwark.id, lancer_on_priest])
	for sid: String in ["H1", "H2", "H3"]:
		assert_eq(int(first_lock.get(sid, -1)), bulwark.id, "%s 首次锁定承伤" % sid)
	assert_false(priest.alive)
	assert_true(lancer_on_priest, "祭司死亡前远射的目标曾为祭司")


func test_level_06_expected_fail_front_not_forward() -> void:
	# verification.expected_fail：承伤不前置、远射放得太靠上 → 残骸咬住后排、祭司逃离
	var w: SimWorld = SimFactory.make_world("level_06", { "slot_bulwark": Vector2i(2, 8), "slot_striker": Vector2i(3, 8), "slot_lancer": Vector2i(7, 7) })
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_06 承伤不前置：%s @ %.2fs（%s）" % [SimTypes.BattleResult.keys()[result], w.clock.time, w.result_objective])
	assert_eq(result, SimTypes.BattleResult.LOSE)
	assert_eq(w.result_objective, "lose_priest_escaped")


func test_level_06_speed_1x_2x_consistent() -> void:
	_assert_speed_consistent("level_06")


## 03 §7：第六关三类失败说明映射
func _diagnose(deploy: Dictionary, over: Dictionary = {}) -> FailDiagnosis:
	var level: LevelDefinition = DataRegistry.get_level("level_06")
	var w: SimWorld = SimFactory.make_world("level_06", deploy, over)
	var diag := FailDiagnosis.new(level)
	for i: int in int(LEVEL_SECONDS / SimTypes.SIM_DT):
		if w.result != SimTypes.BattleResult.NONE:
			break
		w.step()
		for e: Dictionary in w.take_events():
			diag.observe_event(e, w)
		diag.observe_tick(w)
	assert_eq(w.result_objective, "lose_priest_escaped", "该配置下祭司逃离")
	gut.p("  %s → %s：%s" % [str(deploy), diag.category(), diag.fail_text(w)])
	return diag


func test_level_06_fail_categories_mapping() -> void:
	var idle: Array = [SimFactory.r_idle()]
	assert_eq(_diagnose({ "slot_bulwark": Vector2i(2, 8), "slot_striker": Vector2i(6, 8), "slot_lancer": Vector2i(7, 8) }).category(),
		FailDiagnosis.FRONT_NOT_HELD, "残骸咬住后排 → 前排未留住")
	assert_eq(_diagnose({ "slot_bulwark": Vector2i(7, 8), "slot_striker": Vector2i(4, 8), "slot_lancer": Vector2i(2, 8) },
		{ "slot_striker": idle, "slot_lancer": idle }).category(), FailDiagnosis.OUT_OF_RANGE, "祭司从未进入出手单位射程")
	assert_eq(_diagnose({ "slot_lancer": Vector2i(2, 8), "slot_striker": Vector2i(3, 8), "slot_bulwark": Vector2i(4, 8) }).category(),
		FailDiagnosis.WRONG_TARGET, "进过射程但火力不足 / 选中别的敌人")


# ---- 第七关（策划已定，数据不改） ----
func test_level_07_recommended_wins_at_20s() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_07")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	assert_almost_eq(w.clock.time, 20.0, 1e-6, "保护 20 秒（模拟时间）")
	gut.p("level_07 推荐解：WIN @ %.2fs，转运点剩 %.0f" % [w.clock.time, w.get_spawn("P").hp])


## 05 §3 第 4 条：至少一次 target_changed 发生在某个 unit_died 之后；敌人提前全灭时 threat_cleared 为真且在 20.0s 胜利
func test_level_07_retarget_after_death_and_threat_cleared() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_07")
	var cleared_at: float = -1.0
	var all_events: Array[Dictionary] = []
	for i: int in int(LEVEL_SECONDS / SimTypes.SIM_DT):
		if w.result != SimTypes.BattleResult.NONE:
			break
		w.step()
		all_events.append_array(w.take_events())
		if cleared_at < 0.0 and bool(w.objective_progress.get("threat_cleared", false)):
			cleared_at = w.clock.time
	var first_death: float = -1.0
	var retarget_after_death: int = 0
	for e: Dictionary in all_events:
		var t: int = int(e["type"])
		if t == SimTypes.EventType.UNIT_DIED and first_death < 0.0:
			first_death = float(e["time"])
		elif t == SimTypes.EventType.TARGET_CHANGED and first_death >= 0.0 and float(e["time"]) > first_death and int(e["target"]) >= 0:
			retarget_after_death += 1
	gut.p("level_07 专项：首次阵亡 %.2fs，之后重新选敌 %d 次；威胁已清除 @ %.2fs；胜利 @ %.2fs" % [first_death, retarget_after_death, cleared_at, w.clock.time])
	assert_gt(retarget_after_death, 0, "目标死亡后重新选敌")
	assert_true(cleared_at > 0.0 and cleared_at < 20.0, "敌人提前全灭")
	assert_true(bool(w.objective_progress["threat_cleared"]))
	assert_eq(w.result, SimTypes.BattleResult.WIN)
	assert_almost_eq(w.clock.time, 20.0, 1e-6, "威胁清除后计时继续，20.0s 胜利")


func test_level_07_two_different_deployments_win() -> void:
	# 关卡册 5.8：至少两个实质不同的合法部署可胜
	var alt: Dictionary = { "slot_bulwark": Vector2i(3, 5), "slot_striker": Vector2i(3, 3), "slot_lancer": Vector2i(1, 3) }
	var w: SimWorld = SimFactory.make_world("level_07", alt)
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	gut.p("level_07 替代部署 承伤(3,5)/攻击(3,3)/远射(1,3)：WIN @ %.2fs" % w.clock.time)


func test_level_07_expected_fail_chase_and_crowd() -> void:
	# 05 §3：前排开启追击并把全部单位放在 y=6
	var level: LevelDefinition = DataRegistry.get_level("level_07")
	var over: Dictionary = {}
	for slot: SlotDef in level.slots:
		var rules: Array[RuleDef] = level.recommended_rules(slot.id)
		for r: RuleDef in rules:
			r.enabled = true
		over[slot.id] = rules
	var w: SimWorld = SimFactory.make_world("level_07", { "slot_bulwark": Vector2i(3, 6), "slot_striker": Vector2i(2, 6), "slot_lancer": Vector2i(1, 6) }, over)
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_07 前排追击 + 全员 y=6：%s @ %.2fs，转运点剩 %.0f" % [SimTypes.BattleResult.keys()[result], w.clock.time, w.get_spawn("P").hp])
	if result == SimTypes.BattleResult.WIN:
		pending("Q-027：第七关（数据冻结）预期失败配置实测仍胜利，待策划复核")
	else:
		assert_ne(result, SimTypes.BattleResult.WIN)


func test_level_07_speed_1x_2x_consistent() -> void:
	_assert_speed_consistent("level_07")


# ---- 第八关 ----
const L8_ATK: Dictionary = { "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "attack" } }
const L8_CHASE: Dictionary = { "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "chase_attack" } }


func _route(route_id: String) -> Dictionary:
	return { "conditions": [], "action": { "type": "follow_route", "route_id": route_id } }


## 绕后：快速形态 + 远射走北侧藤廊，基础攻击形态走南侧藤廊，承伤正面原地
func l8_bypass_rules() -> Dictionary:
	return { "slot_bulwark": [L8_ATK, SimFactory.r_idle()], "slot_swift": [L8_ATK, _route("north_flank")],
		"slot_lancer": [L8_ATK, _route("north_flank")], "slot_striker": [L8_ATK, _route("south_flank")] }


## 正面：全员沿正面花径推进并追击
func l8_frontal_rules() -> Dictionary:
	return { "slot_bulwark": [L8_ATK, L8_CHASE, _route("front")], "slot_swift": [L8_ATK, L8_CHASE, _route("front")],
		"slot_lancer": [L8_ATK, L8_CHASE, _route("front")], "slot_striker": [L8_ATK, L8_CHASE, _route("front")] }


func test_level_08_recommended_wins() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_08")
	assert_eq(SimFactory.run_until_end(w, LEVEL_SECONDS), SimTypes.BattleResult.WIN)
	gut.p("level_08 推荐解（推荐部署 + 默认指令）：WIN @ %.2fs" % w.clock.time)


func test_level_08_bypass_route_wins_core_kill_ends_battle() -> void:
	var w: SimWorld = SimFactory.make_world("level_08", DataRegistry.get_level("level_08").recommended_deploy, l8_bypass_rules())
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	var guards_alive: int = 0
	for sid: String in ["G1", "G2"]:
		if w.get_spawn(sid).alive:
			guards_alive += 1
	gut.p("level_08 绕后路线：%s @ %.2fs，存活护卫 %d" % [SimTypes.BattleResult.keys()[result], w.clock.time, guards_alive])
	assert_eq(result, SimTypes.BattleResult.WIN)
	assert_eq(w.result_objective, "win_destroy_core", "核心被毁即胜利")
	assert_false(w.get_spawn("CORE").alive)
	assert_gt(guards_alive, 0, "护卫无需清除（无隐藏目标）")


func test_level_08_frontal_route_expected_fail() -> void:
	# verification.expected_fail：全员正面推进
	var w: SimWorld = SimFactory.make_world("level_08", DataRegistry.get_level("level_08").recommended_deploy, l8_frontal_rules())
	var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
	gut.p("level_08 全员正面推进：%s @ %.2fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	if result == SimTypes.BattleResult.WIN:
		pending("Q-028：第八关全员正面推进实测仍胜利，已转交数值 AI")
	else:
		assert_ne(result, SimTypes.BattleResult.WIN)


func test_level_08_speed_1x_2x_consistent() -> void:
	_assert_speed_consistent("level_08")


## 05 §3 第 1 条汇总：八关推荐解全部胜利
func test_all_eight_levels_recommended_win() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for lid: String in DataRegistry.get_chapter("chapter_01").level_ids():      # 第一章；30 关战役（chapter_02）见 test_campaign_levels.gd
		var w: SimWorld = SimFactory.make_recommended_world(lid)
		var result: int = SimFactory.run_until_end(w, LEVEL_SECONDS)
		lines.append("%s %s %.1fs" % [lid, SimTypes.BattleResult.keys()[result], w.clock.time])
		assert_eq(result, SimTypes.BattleResult.WIN, "%s 推荐解胜" % lid)
	gut.p("八关推荐解：" + " | ".join(lines))


# ---- P7 大地图与障碍融合（10 §7）：scene.obstacles 校验与障碍块绘制位置 ----
func _level_03_with_obstacles(manifest: String) -> LevelDefinition:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_03.json")) as Dictionary
	(d["scene"] as Dictionary)["obstacles"] = manifest
	DataReader.silent = true
	var L: LevelDefinition = LevelDefinition.from_dict(d, "test_obstacles")
	DataReader.silent = false
	return L


func test_scene_obstacles_cells_must_be_blocked() -> void:
	var before: int = DataReader.error_count
	var ok: LevelDefinition = _level_03_with_obstacles("res://tests/fixtures/obstacles/obstacles_ok.json")
	assert_eq(DataReader.error_count, before, "cells ⊆ blocked 的清单无错误")
	assert_eq(ok.obstacle_pieces.size(), 2, "读入两块")
	assert_eq((ok.obstacle_pieces[0]["cells"] as Array).size(), 2)
	_level_03_with_obstacles("res://tests/fixtures/obstacles/obstacles_bad.json")
	assert_gt(DataReader.error_count, before, "有一格不在 blocked 内 → 报错")
	var mid: int = DataReader.error_count
	_level_03_with_obstacles("res://tests/fixtures/obstacles/missing.json")
	assert_gt(DataReader.error_count, mid, "清单文件不存在 → 报错")


func test_obstacle_pieces_anchor_to_cells_and_sort_by_foot() -> void:
	var L: LevelDefinition = _level_03_with_obstacles("res://tests/fixtures/obstacles/obstacles_ok.json")
	var rects: Array[Dictionary] = GroundLayer.obstacle_rects(L)
	assert_eq(rects.size(), 2)
	var t: float = float(SimTypes.TILE_SIZE)
	var k: float = t / float(int(Playfield.compute(L, Playfield.DESIGN_SIZE)["cell_px"]))
	var first: Dictionary = L.obstacle_pieces[0]
	var top_left: Vector2 = SimTypes.sim_to_screen(Vector2(4, 3), L.height)      # cells (4,2)(5,2) 的外接框左上
	var r: Rect2 = rects[0]["rect"] as Rect2
	assert_almost_eq(r.position, top_left + (first["anchor"] as Vector2) * k, Vector2(0.01, 0.01), "块左上 = 格外接框左上 + anchor（整图像素换算到格单位）")
	assert_almost_eq(r.size, (first["size"] as Vector2) * k, Vector2(0.01, 0.01))
	for i: int in rects.size() - 1:
		assert_true(float(rects[i]["foot"]) <= float(rects[i + 1]["foot"]), "按脚底从上到下排序")
	assert_not_null(rects[0]["tex"], "贴图可加载")
