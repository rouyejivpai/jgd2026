extends GutTest
## 结算面板（2026-10-20 03.zip 换皮）：胜负共用一张框、标题两字一行、得分圆环、按钮字烘在切图上；
## 回归：没有解锁（奖励为空）的关卡胜利时，正文只剩计分区，原来不计入正文高度 → 框体不加高、计分被截掉一截。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")

var _saved_data: Dictionary
var _saved_level_id: String
var _saved_motion: bool
var _saved_unlocks: Dictionary


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_motion = UiKit.motion_enabled
	UiKit.motion_enabled = false          # 只查终态摆放
	_saved_unlocks = GameState.unlocks
	var cat: CommandCatalog = DataRegistry.get_commands()
	var all: Dictionary = { "forms": DataRegistry.get_units().keys(), "presets": cat.unlock_keys() }
	for kind: String in ["conditions", "selectors", "actions"]:
		all[kind] = cat.ids(kind)
	GameState.unlocks = all              # 推荐阵型用到的形态 / 指令全部可用


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	UiKit.motion_enabled = _saved_motion
	GameState.unlocks = _saved_unlocks


## 推荐阵型跑完（胜利）或空指令跑一段后按失败展示，返回结算面板
func _finish(level_id: String, won: bool) -> Control:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	c.persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	await wait_process_frames(2)
	assert_true(c.apply_recommended(), "推荐阵型可摆放")
	if not won:
		for uid: String in c.uids():
			c.set_rules(uid, [] as Array[RuleDef])
	assert_true(c.start())
	while c.phase == SimTypes.Phase.RUNNING and (won or c.world.clock.time < 5.0):
		c.advance_tick()
	if c.phase == SimTypes.Phase.RUNNING:
		c.pause()
	if won:
		assert_eq(c.world.result, SimTypes.BattleResult.WIN, "%s 推荐阵型胜利" % level_id)
	root.find_child("HUD", true, false).call("show_result", SimTypes.BattleResult.WIN if won else SimTypes.BattleResult.LOSE, 0.0)
	(root.find_child("DialogueOverlay", true, false) as StoryPlayer).close()      # 结束剧情播完才弹结算
	await wait_process_frames(3)
	return root.find_child("ResultPanel", true, false) as Control


func _assert_on_screen(panel: Control, c: Control, what: String) -> void:
	var vp: Rect2 = panel.get_viewport_rect()
	assert_true(vp.encloses(c.get_global_rect()), "%s 在视口内：%s" % [what, c.get_global_rect()])


func test_win_without_unlocks_shows_whole_score() -> void:
	assert_true((DataRegistry.get_level("level_c05").rewards.get("unlock_forms", []) as Array).is_empty(), "第 5 关没有解锁内容")
	var p: Control = await _finish("level_c05", true)
	assert_true(p.visible)
	var body: ScrollText = p.get("_body_scroll") as ScrollText
	var block: Control = p.get("_score_block") as Control
	assert_true(block.visible, "胜利显示计分区")
	assert_false((p.get("_reward_head") as Label).visible, "无解锁时不显示「解锁」")
	assert_eq(body.overflow(), 0.0, "计分区完整放在正文区里，不被截断")
	assert_true(body.size.y >= block.custom_minimum_size.y, "正文区高度容得下计分四行")
	var ring: Control = p.get("_stamp") as Control
	assert_true(ring.visible, "得分圆环可见")
	_assert_on_screen(p, ring, "得分圆环")
	assert_ne((p.get("_stamp_total") as Label).text, "", "圆环里有综合分")


func test_win_with_unlocks_fits() -> void:
	var p: Control = await _finish("level_02", true)
	var body: ScrollText = p.get("_body_scroll") as ScrollText
	assert_true((p.get("_reward_head") as Label).visible, "有解锁时显示「解锁」")
	assert_eq(body.overflow(), 0.0, "计分 + 多行解锁全部放下")


func test_title_and_baked_buttons() -> void:
	var p: Control = await _finish("level_c05", true)
	assert_eq((p.get("_title") as Label).text, "战斗\n胜利", "标题两字一行")
	for n: String in ["_retry", "_back"]:
		var b: Button = p.get(n) as Button
		assert_true(b.visible)
		assert_eq(b.text, "", "%s 的字在切图上，程序不写字" % n)
		_assert_on_screen(p, b, n)


func test_lose_layout() -> void:
	var p: Control = await _finish("level_c03", false)
	assert_eq((p.get("_title") as Label).text, "战斗\n失败")
	assert_false((p.get("_stamp") as Control).visible, "失败不显示得分圆环")
	assert_false((p.get("_next") as Button).visible, "失败无下一关")
	assert_eq((p.get("_body_scroll") as ScrollText).overflow(), 0.0, "失败原因全部放下")
	for n: String in ["_retry", "_back"]:
		_assert_on_screen(p, p.get(n) as Control, n)


## 直接验修复点：正文里只有计分区（无解锁文字）且正文区不够高时，应返回加高量（原来恒为 0）
func test_fit_body_counts_score_block_without_text() -> void:
	var p: Control = await _finish("level_c05", true)
	var block_h: float = (p.get("_score_block") as Control).custom_minimum_size.y
	assert_eq(float(p.call("_fit_body", 354.0, block_h - 50.0, 500.0)), 50.0, "缺 50 像素 → 加高 50")
	assert_eq(float(p.call("_fit_body", 354.0, block_h - 50.0, 20.0)), 20.0, "加高不超过可用空间")
