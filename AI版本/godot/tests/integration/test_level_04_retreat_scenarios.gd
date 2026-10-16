extends GutTest
## 第四关撤离算法场景（03 §5【待验证算法】：角落停滞、方向抵消、绕障碍）。
## 在第四关地图（12×12，四根骨桩）上用脚本复现各场景，打印指标供试玩记录（docs/playtests/level_04_retreat.md），
## 并断言：确定性、不进入障碍格、无高频抖动。

const SECONDS: float = 30.0
const MAX_REVERSALS: int = 10     ## 30 秒内移动方向反转（点积 < -0.5）次数上限；超过视为抖动


## 运行场景，返回指标：result / time / reversals / blocked / hound_attacks / end / hash / trail
func _scenario(hound_cell: Vector2i, chasers: Array, rules: Array, chaser_def: String = "striker") -> Dictionary:
	var level: LevelDefinition = DataRegistry.get_level("level_04")
	var w: SimWorld = SimFactory.make_empty_world(level.width, level.height, level.blocked)
	w.routes = level.routes
	w.win_objectives.append(SimFactory.objective({ "id": "win", "type": "destroy", "targets": ["HOUND"] }, true))
	w.lose_objectives.append(SimFactory.objective({ "id": "lose", "type": "all_allies_dead" }, false))
	for c: Variant in chasers:
		SimFactory.add(w, chaser_def, SimTypes.Faction.ALLY, c as Vector2i, rules)
	var hound: SimUnit = SimFactory.add(w, "hound", SimTypes.Faction.ENEMY, hound_cell, [], "HOUND")
	hound.rules = RuleDef.clone_array(DataRegistry.get_unit("hound").default_rules)
	var reversals: int = 0
	var blocked: int = 0
	var last_dir: Vector2 = Vector2.ZERO
	var prev: Vector2 = hound.pos
	var trail: PackedStringArray = PackedStringArray()
	for i: int in int(SECONDS / SimTypes.SIM_DT):
		if w.result != SimTypes.BattleResult.NONE:
			break
		w.step()
		if not w.grid.is_walkable(hound.cell()):
			blocked += 1
		var d: Vector2 = hound.pos - prev
		if d.length() > 1e-4:
			var nd: Vector2 = d.normalized()
			if last_dir != Vector2.ZERO and nd.dot(last_dir) < -0.5:
				reversals += 1
			last_dir = nd
		prev = hound.pos
		if i % 30 == 0:
			trail.append("(%d,%d)" % [hound.cell().x, hound.cell().y])
	var bites: int = 0
	for e: Dictionary in SimFactory.events_of(w, SimTypes.EventType.ATTACK_FIRED):
		if int(e["source"]) == hound.id:
			bites += 1
	return {
		"result": SimTypes.BattleResult.keys()[w.result], "time": w.clock.time, "reversals": reversals, "blocked": blocked,
		"bites": bites, "end": hound.pos, "hash": w.state_hash(), "trail": " ".join(trail),
	}


func _report(title: String, m: Dictionary) -> void:
	gut.p("%s：%s @ %.1fs，反转 %d，进入障碍 %d，反咬 %d，终点 (%.1f,%.1f)，轨迹(每秒) %s" % [
		title, m["result"], float(m["time"]), int(m["reversals"]), int(m["blocked"]), int(m["bites"]),
		(m["end"] as Vector2).x, (m["end"] as Vector2).y, m["trail"]])


func _chase() -> Array:
	return [SimFactory.r_attack_in_range("nearest", "unit"), SimFactory.r_chase_attack_visible("nearest", "unit"), SimFactory.r_idle()]


## 场景 1 角落停滞：近战追击者（快速形态）从西南逼近东北角的猎犬——猎犬不应贴角抖动或僵住
## （实测：只要沿墙仍有更远的格，它就沿围栏外圈逃跑；单名追击者无法把它钉死在角落）
func test_corner_stall() -> void:
	var m: Dictionary = _scenario(Vector2i(10, 10), [Vector2i(5, 5)], _chase(), "swift")
	_report("角落停滞（近战追击）", m)
	assert_eq(int(m["blocked"]), 0)
	assert_lte(int(m["reversals"]), MAX_REVERSALS, "无高频抖动")


## 场景 1c 角落被夹死：两名近战追击者沿两面墙同时逼近角落——无退路时 retreat_possible 不成立，猎犬反咬
func test_corner_pinned_bites_back() -> void:
	var m: Dictionary = _scenario(Vector2i(11, 11), [Vector2i(6, 11), Vector2i(11, 6)], _chase(), "swift")
	_report("角落被夹死（两侧近战）", m)
	assert_eq(int(m["blocked"]), 0)
	assert_lte(int(m["reversals"]), MAX_REVERSALS, "无高频抖动")
	assert_gt(int(m["bites"]), 0, "无退路时反咬")


## 场景 1b：远程追击者（射程 4）逼角——猎犬够不着（射程 1.5），按规则待机，在角落被远程击杀，不抖动
func test_corner_stall_ranged_chaser() -> void:
	var m: Dictionary = _scenario(Vector2i(10, 10), [Vector2i(5, 5)], _chase())
	_report("角落停滞（远程追击）", m)
	assert_eq(int(m["blocked"]), 0)
	assert_lte(int(m["reversals"]), MAX_REVERSALS, "无高频抖动")
	assert_eq(str(m["result"]), "WIN")


## 场景 2 方向抵消：两名追击者从正西、正东对称逼近——猎犬应选确定的垂直方向，两次运行完全一致
func test_direction_cancellation() -> void:
	var a: Dictionary = _scenario(Vector2i(5, 6), [Vector2i(1, 6), Vector2i(10, 6)], _chase())
	var b: Dictionary = _scenario(Vector2i(5, 6), [Vector2i(1, 6), Vector2i(10, 6)], _chase())
	_report("方向抵消", a)
	assert_eq(int(a["hash"]), int(b["hash"]), "两次运行结果相同")
	assert_eq(int(a["blocked"]), 0)
	assert_lte(int(a["reversals"]), MAX_REVERSALS, "无高频抖动")


## 场景 3 绕障碍：追击者从骨桩另一侧斜向逼近——猎犬撤离路线绕过骨桩，不穿障碍、不卡在骨桩边来回
func test_around_obstacles() -> void:
	var m: Dictionary = _scenario(Vector2i(9, 9), [Vector2i(6, 6)], _chase())
	_report("绕障碍", m)
	assert_eq(int(m["blocked"]), 0, "不进入骨桩格")
	assert_lte(int(m["reversals"]), MAX_REVERSALS, "无高频抖动")


## 参考：推荐解（三面包围）同样打印指标
func test_three_side_encirclement_reference() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_04")
	var w: SimWorld = SimFactory.make_recommended_world("level_04")
	var result: int = SimFactory.run_until_end(w, SECONDS)
	gut.p("三面包围（推荐解）：%s @ %.1fs" % [SimTypes.BattleResult.keys()[result], w.clock.time])
	assert_eq(result, SimTypes.BattleResult.WIN)
	assert_eq(level.id, "level_04")
