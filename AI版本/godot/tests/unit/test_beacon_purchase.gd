extends GutTest
## 信标购买（roster.beacon_cost / beacon_bundle）：全场共用一个池，每 beacon_bundle 个一包、每包 beacon_cost Cost；
## 放置时按需自动买包（计入出场预算），删到整包用不着时自动退包；预算不够买新包时不能再放。
## 没写 beacon_cost 的关卡（c01、旧第一章 8 关）信标免费、不计入预算。

const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer", "hexer", "binder"],
	"presets": [],
}

var _saved_unlocks: Dictionary


func before_each() -> void:
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED


func after_each() -> void:
	GameState.unlocks = _saved_unlocks


func _controller(level_id: String) -> BattleController:
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level(level_id))
	return c


## 在第 y 行从 x0 起依次放 n 个信标，返回成功个数
func _add_row(c: BattleController, uid: String, x0: int, y: int, n: int) -> int:
	var ok: int = 0
	for i: int in n:
		if c.add_beacon(uid, Vector2i(x0 + i, y)) != "":
			ok += 1
	return ok


func test_level_reads_beacon_price() -> void:
	var c02: LevelDefinition = DataRegistry.get_level("level_c02")
	assert_eq(c02.beacon_cost, 1)
	assert_eq(c02.beacon_bundle, 5)
	assert_true(c02.beacons_priced())
	assert_eq([c02.beacon_packs(0), c02.beacon_packs(1), c02.beacon_packs(5), c02.beacon_packs(6)], [0, 1, 1, 2])
	var c01: LevelDefinition = DataRegistry.get_level("level_c01")
	assert_false(c01.beacons_priced(), "c01 没写 beacon_cost：信标免费")
	assert_eq(c01.beacon_packs(12), 0)


## c02：预算 4，基础攻击形态 3 → 只够一包（5 个）
func test_auto_buy_and_refund() -> void:
	var c: BattleController = _controller("level_c02")
	var uid: String = c.add_unit("striker", Vector2i(1, 5))
	assert_ne(uid, "")
	assert_eq(c.budget_used(), 3)
	assert_eq(c.beacon_stock(), 0, "还没买包")
	assert_true(c.beacon_needs_pack())
	assert_true(c.can_afford_beacon())
	assert_ne(c.add_beacon(uid, Vector2i(7, 3)), "", "第 1 个信标：自动买一包")
	assert_eq(c.beacon_packs(), 1)
	assert_eq(c.beacon_stock(), 5)
	assert_eq(c.budget_used(), 4, "3 + 1 包")
	assert_eq(_add_row(c, uid, 8, 3, 4), 4, "同一包里再放 4 个不再扣费")
	assert_eq(c.budget_used(), 4)
	assert_true(c.beacon_needs_pack(), "5/5：再放要买第二包")
	assert_false(c.can_afford_beacon(), "4 + 1 > 4")
	assert_eq(c.add_beacon(uid, Vector2i(7, 4)), "", "预算不够买第二包：拒绝放置")
	assert_eq(c.beacon_total(), 5)
	assert_true(c.remove_beacon(uid, "5"))
	assert_eq(c.budget_used(), 4, "还剩 4 个，包不退")
	for id: String in ["1", "2", "3", "4"]:
		c.remove_beacon(uid, id)
	assert_eq(c.beacon_total(), 0)
	assert_eq(c.budget_used(), 3, "信标删光：整包退回")


## 池全场共用：两名单位的信标合计计包；收回单位时它的信标一起退
func test_pool_shared_between_units() -> void:
	var c: BattleController = _controller("level_c04")         # 预算 10，人数上限 2
	var a: String = c.add_unit("striker", Vector2i(0, 4))
	var b: String = c.add_unit("striker", Vector2i(0, 6))
	assert_eq(c.budget_used(), 6)
	var cells: Array[Vector2i] = _walkable(c.level, 6)
	for k: int in 6:
		assert_ne(c.add_beacon(a if k < 3 else b, cells[k]), "")
	assert_eq(c.beacon_total(), 6)
	assert_eq(c.beacon_packs(), 2, "3 + 3 = 6 个 → 2 包")
	assert_eq(c.budget_used(), 8)
	assert_true(c.remove_unit(b))
	assert_eq(c.beacon_total(), 3)
	assert_eq(c.budget_used(), 3 + 1, "收回单位：它的形态 Cost 与多出来的那包一起退")


## 信标包占用预算后，新单位按总 Cost 判断能否出场
func test_beacon_packs_limit_new_units() -> void:
	var c: BattleController = _controller("level_c04")
	var a: String = c.add_unit("striker", Vector2i(0, 4))
	for cell: Vector2i in _walkable(c.level, 16):
		assert_ne(c.add_beacon(a, cell), "")
	assert_eq(c.budget_used(), 3 + 4, "16 个 = 4 包")
	assert_eq(c.place_problem("bulwark", Vector2i(0, 6)), DeploymentValidator.BUDGET_EXCEEDED, "7 + 4 > 10")
	assert_false(c.can_add_form("bulwark"))
	c.remove_beacon(a, "16")
	assert_eq(c.budget_used(), 3 + 3, "15 个 = 3 包")
	assert_eq(c.place_problem("bulwark", Vector2i(0, 6)), "", "6 + 4 = 10 ≤ 10")


## 免费关：信标不计包、不占预算
func test_free_level_beacons_cost_nothing() -> void:
	var c: BattleController = _controller("level_c01")
	var uid: String = c.add_unit("striker", Vector2i(c.level.deploy_cells[0].x, c.level.deploy_cells[0].y))
	assert_ne(uid, "")
	var before: int = c.budget_used()
	var placed: int = 0
	for cell: Vector2i in _walkable(c.level, 8):
		if c.add_beacon(uid, cell) != "":
			placed += 1
	assert_eq(placed, 8)
	assert_eq(c.beacon_packs(), 0)
	assert_eq(c.beacon_stock(), 0)
	assert_false(c.beacon_needs_pack())
	assert_eq(c.budget_used(), before, "信标免费")


## 存档里信标超出预算：开始前校验报 BUDGET_EXCEEDED（含信标包）
func test_validator_counts_beacon_packs() -> void:
	var c: BattleController = _controller("level_c02")
	var uid: String = c.add_unit("striker", Vector2i(1, 5))
	var bs: Array[Dictionary] = []
	for i: int in 6:
		bs.append({ "id": str(i + 1), "cell": Vector2i(7 + i, 3) })
	c.slot_beacons[uid] = bs                        # 绕过放置检查，模拟旧存档
	assert_eq(DeploymentValidator.beacon_cost(c.level, c.build_config()), 2)
	assert_false(c.start(), "6 个 = 2 包，3 + 2 > 4")
	var codes: Array[String] = []
	for p: Dictionary in c.last_problems:
		codes.append("%s:%s" % [p["code"], p["what"]])
	assert_has(codes, "BUDGET_EXCEEDED:5/4")


## 30 关推荐解：算上信标包仍在预算内，且可以开始
func test_campaign_recommended_fits_with_beacon_packs() -> void:
	for i: int in range(1, 31):
		var lid: String = "level_c%02d" % i
		var c: BattleController = _controller(lid)
		assert_true(c.apply_recommended(), lid)
		var expect: int = c.level.beacon_packs(c.beacon_total()) * c.level.beacon_cost
		assert_eq(c.beacon_packs_cost(), expect, "%s 信标包 Cost" % lid)
		assert_true(c.budget_used() <= c.level.roster_budget, "%s 推荐解 %d ≤ 预算 %d（含 %d 包信标）" % [lid, c.budget_used(), c.level.roster_budget, c.beacon_packs()])
		for p: Dictionary in c.last_problems:
			assert_ne(str(p["code"]), DeploymentValidator.BUDGET_EXCEEDED, "%s 推荐解不超预算" % lid)


## Boss 换阶段暂停：第一阶段买下的包冻结；暂停中多买的包从增援预算里扣
func test_boss_pause_extra_packs_use_reinforce_budget() -> void:
	GameState.unlocks = _campaign_unlocks_before("level_c30")
	var c: BattleController = _controller("level_c30")
	c.apply_recommended()
	assert_eq(c.beacon_packs(), 1, "第一阶段 1 个信标 = 1 包")
	assert_true(c.start(), str(c.last_problems))
	for i: int in int(ceil(180.0 / SimTypes.SIM_DT)):
		c.advance_tick()
		if c.boss_pending:
			break
	assert_true(c.boss_pending, "Boss 血量过半时暂停")
	var used_before: int = c.budget_used()
	var alive: String = ""
	for uid: String in c.uids():
		if c._alive_in_world(uid):
			alive = uid
			break
	assert_ne(alive, "")
	assert_eq(c.reinforce_cost(), 0)
	var free_slots: int = c.beacon_stock() - c.beacon_total()
	var cells: Array[Vector2i] = _walkable(c.level, free_slots + 1, c.get_beacons(alive))
	for k: int in free_slots:
		assert_ne(c.add_beacon(alive, cells[k]), "", "第一阶段那包剩余的位置免费")
	assert_eq(c.reinforce_cost(), 0)
	assert_ne(c.add_beacon(alive, cells[free_slots]), "", "再放一个：用增援预算买一包")
	assert_eq(c.reinforce_cost(), c.level.beacon_cost)
	assert_eq(c.budget_used(), used_before, "第一阶段预算不变")
	c.reset()
	assert_eq(c.beacon_packs(), 1, "重开：信标还原为第一阶段")


## 进入 level_id 前的解锁：progression 初始 + 之前各战役关 rewards（同 test_campaign_levels.gd）
static func _campaign_unlocks_before(level_id: String) -> Dictionary:
	var u: Dictionary = DataRegistry.get_initial_unlocks().duplicate(true)
	for i: int in range(1, 31):
		var lid: String = "level_c%02d" % i
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


static func _walkable(level: LevelDefinition, n: int, avoid: Array[Dictionary] = []) -> Array[Vector2i]:
	var taken: Dictionary = {}
	for b: Dictionary in avoid:
		taken[b["cell"] as Vector2i] = true
	var out: Array[Vector2i] = []
	for y: int in level.height:
		for x: int in level.width:
			var cell := Vector2i(x, y)
			if out.size() < n and not level.is_blocked(cell) and not taken.has(cell):
				out.append(cell)
	return out
