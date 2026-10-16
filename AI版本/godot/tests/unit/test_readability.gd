extends GutTest
## 07 §6：朝向迟滞与背步（A04，FacingTracker）、特殊目标标记分类（A03）。仅表现层。
## （障碍规划态红纹已由第三阶段 FloorHighlight 取代，见 test_floor_highlight.gd。）

const DT: float = SimTypes.SIM_DT


func test_small_backward_move_is_backstep_not_flip() -> void:
	var f := FacingTracker.new(false)          # 面向右
	assert_false(f.update(-0.1, DT))
	assert_false(f.facing_left, "0.1 格后撤不翻转")
	assert_true(f.backstep, "视为背步")


func test_flip_after_half_cell() -> void:
	var f := FacingTracker.new(false)
	var flipped: bool = false
	var steps: int = 0
	while not flipped and steps < 100:
		flipped = f.update(-0.1, 0.01)            # 每步 0.1 格、时间很短，靠距离触发
		steps += 1
	assert_true(flipped)
	assert_eq(steps, 5, "累计 0.5 格时翻转")
	assert_true(f.facing_left)
	assert_false(f.backstep)


func test_flip_after_time() -> void:
	var f := FacingTracker.new(true)            # 面向左
	var flipped: bool = false
	var t: float = 0.0
	while not flipped and t < 2.0:
		flipped = f.update(0.01, DT)              # 很慢地向右挪，靠时间触发
		t += DT
	assert_true(flipped)
	assert_almost_eq(t, FacingTracker.FLIP_SECONDS, DT + 0.0001, "持续约 0.4 s 后翻转")
	assert_false(f.facing_left)


func test_forward_move_or_stop_resets_accumulation() -> void:
	var f := FacingTracker.new(false)
	for i: int in 4:
		f.update(-0.1, 0.01)                      # 0.4 格
	f.update(0.05, 0.01)                          # 向面向方向移动 → 清空
	assert_false(f.backstep)
	assert_false(f.update(-0.1, 0.01), "清空后重新累计")
	f.update(0.0, 0.01)                           # 停下 → 清空
	for i: int in 4:
		assert_false(f.update(-0.1, 0.01))
	assert_true(f.update(-0.1, 0.01), "停下后需要重新累计满 0.5 格")


func test_jitter_does_not_flip() -> void:
	var f := FacingTracker.new(false)
	var flips: int = 0
	for i: int in 200:
		if f.update(-0.08 if i % 2 == 0 else 0.08, DT):   # 左右抖动
			flips += 1
	assert_eq(flips, 0, "来回抖动不翻转")


func test_face_attack_target() -> void:
	var f := FacingTracker.new(false)
	f.update(-0.1, DT)
	assert_true(f.face(true), "攻击时直接面向目标")
	assert_true(f.facing_left)
	assert_false(f.backstep)
	assert_false(f.face(true), "已面向则不变")


func _kind(level_id: String, spawn_id: String) -> int:
	var level: LevelDefinition = DataRegistry.get_level(level_id)
	var w: SimWorld = SimFactory.make_recommended_world(level_id)
	return UnitView.objective_kind_for(level, w.get_spawn(spawn_id))


func test_objective_marker_kinds() -> void:
	assert_eq(_kind("level_03", "PILLAR"), UnitView.OBJ_DESTROY, "骸柱（建筑）= 裂纹")
	assert_eq(_kind("level_04", "HOUND"), UnitView.OBJ_KILL, "猎犬（单位）= 骷髅")
	assert_eq(_kind("level_06", "PRIEST"), UnitView.OBJ_KILL)
	assert_eq(_kind("level_07", "P"), UnitView.OBJ_PROTECT, "转运点（保护对象）= 盾")
	assert_eq(_kind("level_08", "CORE"), UnitView.OBJ_KILL, "骨花核心在数据中是 unit → 骷髅（Q-042）")
	assert_eq(_kind("level_01", "R1"), UnitView.OBJ_NONE, "全歼关的普通敌人无标记")

