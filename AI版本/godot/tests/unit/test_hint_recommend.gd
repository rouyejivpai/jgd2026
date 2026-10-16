extends GutTest
## 07 §2「推荐阵型」：提示 4 层看完前不可用、之后可用；应用后部署与指令等于关卡 recommended；存档往返。

const SaveManagerScript: GDScript = preload("res://scripts/autoloads/save_manager.gd")
const HINT_PANEL_SCENE: PackedScene = preload("res://scenes/ui/hint_panel.tscn")
const LEVEL_ID: String = "level_02"
const TEST_PATH: String = "user://test_tmp/save_hint_recommend.json"
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
}

var _saved_data: Dictionary
var _saved_unlocks: Dictionary
var _level: LevelDefinition
var _c: BattleController
var _panel: HintPanel


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	SaveManager.set_hints_seen(LEVEL_ID, 0)
	SaveManager.set_recommend_used(LEVEL_ID, false)
	_level = DataRegistry.get_level(LEVEL_ID)
	_c = BattleController.new()
	add_child_autofree(_c)
	_c.setup(_level)
	_panel = HINT_PANEL_SCENE.instantiate() as HintPanel
	add_child_autofree(_panel)
	_panel.setup(_level, _c)


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.unlocks = _saved_unlocks
	for p: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 揭示下一层（绕过连点保护的时间窗）
func _reveal() -> void:
	_panel.set("_last_reveal_ms", -100000)
	_panel.press()


## free 关：推荐阵型按顺序摆放为 u1、u2…，形态 = recommended.form
func _assert_config_is_recommended(c: BattleController) -> void:
	assert_eq(c.placements.size(), _level.recommended_units.size(), "推荐单位全部部署")
	for i: int in _level.recommended_units.size():
		var ru: RecommendedUnitDef = _level.recommended_units[i]
		var uid: String = "u%d" % (i + 1)
		assert_eq(c.form_of(uid), ru.form)
		assert_eq(c.placements.get(uid, Vector2i(-1, -1)), ru.pos, "%s 位置 = recommended" % uid)
		assert_eq_deep(RuleDef.to_array(c.get_rules(uid)), RuleDef.to_array(BattleController.enabled_only(ru.rules)))   # 略去停用条目（Q-059）


func test_new_unit_rules_are_empty() -> void:
	var uid: String = _c.add_unit("bulwark", Vector2i(3, 3))
	assert_ne(uid, "")
	assert_eq(_c.get_rules(uid).size(), 0, "新放置单位指令为空")
	var problems: Array[Dictionary] = DeploymentValidator.validate(_level, _c.build_config(), GameState.unlocks, DataRegistry.get_units())
	var empty: Array[Dictionary] = []
	for p: Dictionary in problems:
		if str(p["code"]) == "EMPTY_RULES" and str(p["slot"]) == uid:
			empty.append(p)
	assert_eq(empty.size(), 1, "空指令给出 EMPTY_RULES 提醒")
	assert_false(bool(empty[0]["blocking"]), "EMPTY_RULES 不阻止开始")


func test_unavailable_before_tier_4() -> void:
	for tier: int in 4:
		assert_eq(_panel.seen(), tier)
		assert_false(_panel.recommend_available(), "看完 %d 层时不可用" % tier)
		assert_ne(_panel.button_text(), DataRegistry.get_string("ui.recommend_formation"))
		assert_false(_panel.confirm_recommended(), "不可用时确认无效")
		assert_eq(_c.placements.size(), 0)
		_reveal()
	assert_eq(_panel.seen(), 4)


func test_available_after_tier_4() -> void:
	for i: int in 4:
		_reveal()
	assert_true(_panel.recommend_available())
	assert_eq(_panel.button_text(), DataRegistry.get_string("ui.recommend_formation"), "第 4 层后按钮文字变为「推荐阵型」")
	_panel.press()
	assert_eq(_panel.seen(), 4, "继续按下不再增加层数")
	assert_true(_panel.visible)
	assert_true((_panel.get("_confirm_box") as Control).visible, "按下「推荐阵型」先请求确认")
	assert_eq(_c.placements.size(), 0, "确认前不改动部署")


func test_apply_overrides_config_with_recommended() -> void:
	# 先放一个与推荐不同的部署和指令，确认后应被整体覆盖
	var extra: String = _c.add_unit("striker", Vector2i(2, 5))
	assert_true(_c.set_rules(extra, SimFactory.to_rules([SimFactory.r_idle()])))
	SaveManager.set_hints_seen(LEVEL_ID, 4)
	_panel.press()
	watch_signals(_panel)
	assert_true(_panel.confirm_recommended())
	_assert_config_is_recommended(_c)
	assert_false(DeploymentValidator.has_blocking(_c.last_problems), "应用后已校验且可开始")
	assert_signal_emitted(_panel, "recommended_applied")
	assert_true(SaveManager.get_recommend_used(LEVEL_ID))
	assert_false(_panel.visible, "确认后关闭面板")


func test_apply_rejected_outside_deploy() -> void:
	SaveManager.set_hints_seen(LEVEL_ID, 4)
	assert_true(_c.apply_recommended())
	assert_true(_c.start())
	assert_false(_panel.confirm_recommended(), "运行中不可摆放")
	_panel.open_recommend()
	assert_true((_panel.get("_apply_button") as Button).disabled, "运行中确认按钮禁用")


func test_reset_keeps_hint_state() -> void:
	SaveManager.set_hints_seen(LEVEL_ID, 4)
	assert_true(_panel.confirm_recommended())
	assert_true(_c.start())
	_c.reset()
	assert_eq(_panel.seen(), 4, "重置不清除已看层数")
	assert_true(SaveManager.get_recommend_used(LEVEL_ID), "重置不清除推荐阵型已使用")
	_assert_config_is_recommended(_c)


func test_save_roundtrip() -> void:
	SaveManager.set_hints_seen(LEVEL_ID, 4)
	assert_true(_panel.confirm_recommended())
	# 存档内容：已看层数、已使用标记、关卡配置
	var sm: Node = SaveManagerScript.new()
	var d: Dictionary = SaveManagerScript.call("new_save", DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels()) as Dictionary
	(d["hints_seen"] as Dictionary)[LEVEL_ID] = SaveManager.get_hints_seen(LEVEL_ID)
	(d["recommend_used"] as Dictionary)[LEVEL_ID] = SaveManager.get_recommend_used(LEVEL_ID)
	(d["level_configs"] as Dictionary)[LEVEL_ID] = _c.config_to_raw()
	assert_eq(int(sm.call("save_to", d, TEST_PATH)), OK)
	var loaded: Dictionary = sm.call("load_from", TEST_PATH) as Dictionary
	sm.free()
	assert_eq(int((loaded["hints_seen"] as Dictionary)[LEVEL_ID]), 4)
	assert_true(bool((loaded["recommend_used"] as Dictionary)[LEVEL_ID]))
	var c2 := BattleController.new()
	add_child_autofree(c2)
	c2.setup(_level, (loaded["level_configs"] as Dictionary)[LEVEL_ID] as Dictionary)
	_assert_config_is_recommended(c2)
	assert_eq(c2.load_problems.size(), 0)


func test_old_save_migrates_recommend_used() -> void:
	var sm: Node = SaveManagerScript.new()
	var old: Dictionary = { "version": 1, "progress": {}, "unlocks": {}, "level_configs": {}, "hints_seen": { LEVEL_ID: 2 }, "settings": {} }
	var migrated: Dictionary = sm.call("migrate", old) as Dictionary
	sm.free()
	assert_true(migrated.has("recommend_used"), "旧存档补齐 recommend_used")
	assert_eq(int((migrated["hints_seen"] as Dictionary)[LEVEL_ID]), 2)


## P6 ui_09：确认态按批准整图版式——第 3 关四层提示全部放得下（不需滚动），段距（相邻提示顶差）= 整图
func test_recommend_layout_fits_reference() -> void:
	SaveManager.set_hints_seen(LEVEL_ID, 4)
	_panel.open_recommend()
	await wait_process_frames(3)
	var list: VBoxContainer = _panel.get("_list") as VBoxContainer
	var d: Vector2 = UiKit.design_size("battle_hud")
	var pitch_ref: float = UiKit.layout_rect("battle_hud", "rec_hint2", d).position.y - UiKit.layout_rect("battle_hud", "rec_hint1", d).position.y
	var a: Control = list.get_child(0) as Control
	var b: Control = list.get_child(1) as Control
	assert_almost_eq(b.position.y - a.position.y, pitch_ref, 2.0, "段距 = 整图")
	assert_eq((list.get_parent() as ScrollText).overflow(), 0.0, "四层提示全部可见")
	var last: Control = list.get_child(3) as Control
	assert_lte(last.position.y + last.size.y, (list.get_parent() as Control).size.y + 0.5, "第 4 层（推荐部署）在可见区内")
