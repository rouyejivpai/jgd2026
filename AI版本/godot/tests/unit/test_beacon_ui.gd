extends GutTest
## 07 §3.1 信标的配置与交互：编号分配（10 §6.3 数字编号，删除不重排）、防呆上限、合法格、移动、复制预设路线、存档往返、
## 推荐阵型带信标、旧字母兼容；地图右键布点/删点、拖动移动（仅部署阶段）；整句模板；指令下拉包含信标/等待类条目。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const RULE_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/rule_editor.tscn")
const REC_STRIKER: String = "slot_striker"   ## 推荐阵型条目名；free 关摆放后对应 uid 见 SLOT
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
}

var SLOT: String = ""
var _saved_unlocks: Dictionary
var _saved_data: Dictionary
var _saved_level_id: String
var _c: BattleController


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	_c = BattleController.new()
	add_child_autofree(_c)
	_c.setup(DataRegistry.get_level("level_03"))
	assert_true(_c.apply_recommended())
	SLOT = _c.recommended_uid(REC_STRIKER)


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks


func _ids() -> String:
	var out: PackedStringArray = PackedStringArray()
	for b: Dictionary in _c.get_beacons(SLOT):
		out.append(str(b["id"]))
	return " ".join(out)


func test_numbers_append_and_do_not_renumber() -> void:
	assert_eq(_c.add_beacon(SLOT, Vector2i(3, 1)), "1")
	assert_eq(_c.add_beacon(SLOT, Vector2i(6, 1)), "2")
	assert_eq(_c.add_beacon(SLOT, Vector2i(9, 1)), "3")
	assert_true(_c.remove_beacon(SLOT, "2"))
	assert_eq(_ids(), "1 3", "删除后编号不重排")
	assert_eq(_c.add_beacon(SLOT, Vector2i(12, 1)), "4", "新信标取当前最大编号 + 1")
	assert_eq(_ids(), "1 3 4")
	assert_true(_c.remove_beacon(SLOT, "4"))
	assert_eq(_c.add_beacon(SLOT, Vector2i(12, 1)), "4", "最大编号被删除后按现有最大编号 + 1")


func test_illegal_cells() -> void:
	assert_eq(_c.add_beacon(SLOT, Vector2i(5, 2)), "", "障碍格不能放")
	assert_eq(_c.add_beacon(SLOT, Vector2i(-1, 0)), "", "地图外不能放")
	assert_eq(_c.add_beacon(SLOT, Vector2i(10, 8)), "1", "部署区外的可行走格可以放")
	assert_eq(_c.add_beacon(SLOT, Vector2i(10, 8)), "", "同一单位的信标不重叠")


func test_no_eight_limit_and_soft_cap() -> void:
	var level: LevelDefinition = _c.level
	var placed: int = 0
	for y: int in level.height:
		for x: int in level.width:
			if placed < SimTypes.BEACON_SOFT_CAP and _c.add_beacon(SLOT, Vector2i(x, y)) != "":
				placed += 1
	assert_eq(placed, SimTypes.BEACON_SOFT_CAP, "取消 8 个上限，可放到防呆上限 64 个")
	assert_eq(str(_c.get_beacons(SLOT)[SimTypes.MAX_BEACONS]["id"]), "9", "第 9 个信标编号 9")
	assert_eq(_c.next_beacon_id(SLOT), "", "达到 BEACON_SOFT_CAP 后不再追加")
	assert_true(_c.remove_beacon(SLOT, "64"))
	assert_eq(_c.next_beacon_id(SLOT), "64")


func test_letter_ids_are_read_as_numbers() -> void:
	assert_eq(SimTypes.legacy_beacon_id("A"), "1")
	assert_eq(SimTypes.legacy_beacon_id("H"), "8")
	assert_eq(SimTypes.legacy_beacon_id("I"), "", "只兼容 A–H")
	assert_true(SimTypes.is_beacon_id("12"))
	assert_false(SimTypes.is_beacon_id("0"))
	assert_false(SimTypes.is_beacon_id("01"))
	assert_false(SimTypes.is_beacon_id("A"))
	var warnings_before: int = DataReader.warnings.size()
	var errors_before: int = DataReader.error_count
	var r: RuleDef = RuleDef.from_dict({ "conditions": [{ "type": "at_beacon", "beacon": "B" }], "action": { "type": "follow_beacons", "mode": "once", "from": "C" } }, "test_letters")
	assert_eq(r.conditions[0].beacon, "2", "at_beacon 字母 B → 2")
	assert_eq(r.action.from, "3", "follow_beacons 字母 C → 3")
	assert_eq(DataReader.error_count, errors_before, "旧字母不是错误")
	assert_eq(DataReader.warnings.size(), warnings_before + 2, "旧字母各报一条 DEPRECATED_FIELD 提醒")
	assert_string_contains(DataReader.warnings[DataReader.warnings.size() - 1], "DEPRECATED_FIELD")
	var parsed: Array[Dictionary] = DeploymentValidator.parse_beacons([{ "id": "A", "cell": [3, 1] }, { "id": "2", "cell": [4, 1] }], "test")
	assert_eq(str(parsed.map(func(b: Dictionary) -> String: return str(b["id"]))), str(["1", "2"]), "存档中的字母信标按数字读取")
	var bad_before: int = DataReader.error_count
	DataReader.silent = true
	RuleDef.from_dict({ "conditions": [{ "type": "at_beacon", "beacon": "0" }], "action": { "type": "idle" } }, "test_bad")
	DataReader.silent = false
	assert_eq(DataReader.error_count, bad_before + 1, "非正整数编号为数据错误")


func test_move_and_copy_route() -> void:
	_c.add_beacon(SLOT, Vector2i(3, 1))
	assert_true(_c.move_beacon(SLOT, "1", Vector2i(3, 0)))
	assert_eq(_c.get_beacons(SLOT)[0]["cell"], Vector2i(3, 0))
	assert_false(_c.move_beacon(SLOT, "1", Vector2i(6, 2)), "不能移到障碍格")
	assert_true(_c.copy_route_to_beacons(SLOT, "corridor"))
	assert_eq(_ids(), "1 2 3", "复制预设路线替换原有信标，编号从 1 起")
	assert_eq(_c.get_beacons(SLOT)[1]["cell"], Vector2i(13, 1))


func test_editing_only_in_deploy_and_save_roundtrip() -> void:
	assert_true(_c.apply_recommended())
	_c.add_beacon(SLOT, Vector2i(3, 1))
	_c.add_beacon(SLOT, Vector2i(13, 1))
	var raw: Dictionary = JSON.parse_string(JSON.stringify(_c.config_to_raw())) as Dictionary
	var c2 := BattleController.new()
	add_child_autofree(c2)
	c2.setup(DataRegistry.get_level("level_03"), raw)
	assert_eq(str(c2.get_beacons(SLOT)), str(_c.get_beacons(SLOT)), "信标存档往返")
	assert_true(_c.start())
	assert_eq(_c.add_beacon(SLOT, Vector2i(8, 1)), "", "运行中不允许改信标")
	assert_false(_c.remove_beacon(SLOT, "1"))
	var u: SimUnit = _c.world.get_spawn(SLOT)
	assert_eq(u.beacons.size(), 2, "信标进入模拟单位")


func test_recommended_formation_places_beacons() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/chapter1/levels/level_03.json")) as Dictionary
	var ru: Dictionary = ((d["recommended"] as Dictionary)["units"] as Array)[1] as Dictionary
	ru["beacons"] = [{ "id": "1", "cell": [2, 1] }, { "id": "2", "cell": [13, 1] }, { "id": "3", "cell": [14, 1] }]
	(ru["rules"] as Array)[1] = { "conditions": [], "action": { "type": "follow_beacons", "mode": "once", "from": "1" } }
	var L: LevelDefinition = LevelDefinition.from_dict(d, "test")
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(L)
	assert_true(c.apply_recommended())
	assert_eq(c.get_beacons(c.recommended_uid(REC_STRIKER)).size(), 3, "推荐阵型一并摆放信标")
	assert_false(DeploymentValidator.has_blocking(c.last_problems))


func test_sentence_templates() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_03")
	var wait_rule: RuleDef = SimFactory.rule({ "conditions": [{ "type": "at_beacon", "beacon": "2" }], "action": { "type": "wait", "seconds": 2.5 } })
	assert_eq(RuleText.rule_sentence(wait_rule, level), "到达信标 2 时，原地等待 2.5 秒")
	var follow: RuleDef = SimFactory.rule({ "conditions": [], "action": { "type": "follow_beacons", "mode": "pingpong", "from": "1" } })
	assert_eq(RuleText.rule_sentence(follow, level), "始终，从信标 1 起沿我的信标前进（往返）")


func test_editor_offers_beacon_items_on_any_level() -> void:
	var editor: RuleEditor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
	add_child_autofree(editor)
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level("level_01"))     # 第一关 allowed 里没有信标类
	editor.setup(c, DataRegistry.get_level("level_01"))
	editor.show_slot("slot_striker_a")
	var conds: PackedStringArray = PackedStringArray()
	for it: Array in editor.condition_items(""):
		conds.append(str(it[1]))
	var acts: PackedStringArray = PackedStringArray()
	for it: Array in editor.action_items(""):
		acts.append(str(it[1]))
	assert_has(conds, "at_beacon")
	assert_has(acts, "follow_beacons")
	assert_has(acts, "wait")
	assert_eq(editor.default_action(SimTypes.ActionType.WAIT).seconds, SimTypes.WAIT_MIN_SECONDS, "10 §5.4：等待秒数默认取 WAIT_MIN_SECONDS")


# ---- 地图交互 ----
func _right_click(map_input: Control, screen: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	mb.pressed = true
	mb.global_position = screen
	mb.position = map_input.get_global_transform().affine_inverse() * screen
	map_input.call("_gui_input", mb)


func _left(map_input: Control, screen: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.global_position = screen
	mb.position = map_input.get_global_transform().affine_inverse() * screen
	map_input.call("_gui_input", mb)


func _motion(map_input: Control, screen: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.global_position = screen
	mm.position = map_input.get_global_transform().affine_inverse() * screen
	map_input.call("_gui_input", mm)


func test_map_right_click_and_drag() -> void:
	GameState.current_level_id = "level_03"
	SaveManager.set_level_config("level_03", {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	c.persist = false
	assert_true(c.apply_recommended())
	SLOT = c.recommended_uid(REC_STRIKER)
	EventBus.unit_selected.emit(c.unit_id_of_slot(SLOT))
	var map_input: Control = root.find_child("MapInput", true, false) as Control
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var t: float = float(int(root.get("cell_px")))
	var cell_px := func(cell: Vector2i) -> Vector2: return rect.position + Vector2((cell.x + 0.5) * t, (10 - cell.y - 0.5) * t)
	_right_click(map_input, cell_px.call(Vector2i(6, 1)))
	_right_click(map_input, cell_px.call(Vector2i(10, 1)))
	assert_eq(str(c.get_beacons(SLOT).map(func(b: Dictionary) -> String: return str(b["id"]))), str(["1", "2"]), "右键可行走格追加信标")
	_right_click(map_input, cell_px.call(Vector2i(6, 2)))     # 哭墙
	assert_eq(c.get_beacons(SLOT).size(), 2, "右键障碍格不放置")
	_right_click(map_input, cell_px.call(Vector2i(6, 1)))
	assert_eq(str(c.get_beacons(SLOT).map(func(b: Dictionary) -> String: return str(b["id"]))), str(["2"]), "右键已有信标 = 删除")
	# 拖动 2 到 (12,0)：拖动中地板高亮（10 §7）
	var floor_hl: FloorHighlight = root.find_child("FloorHighlight", true, false) as FloorHighlight
	EventBus.unit_selected.emit(-1)
	assert_false(floor_hl.is_showing())
	EventBus.unit_selected.emit(c.unit_id_of_slot(SLOT))
	_left(map_input, cell_px.call(Vector2i(10, 1)), true)
	_motion(map_input, cell_px.call(Vector2i(12, 0)))
	assert_true(floor_hl.beacon_drag, "拖信标时地板高亮")
	_left(map_input, cell_px.call(Vector2i(12, 0)), false)
	assert_false(floor_hl.beacon_drag)
	assert_eq(c.get_beacons(SLOT)[0]["cell"], Vector2i(12, 0), "拖动移动信标")
	# 矩形外右键无效；运行中右键无效
	_right_click(map_input, rect.position - Vector2(5, 5))
	assert_eq(c.get_beacons(SLOT).size(), 1)
	assert_true(c.start())
	_right_click(map_input, cell_px.call(Vector2i(8, 1)))
	assert_eq(c.get_beacons(SLOT).size(), 1, "运行中不能布点")
