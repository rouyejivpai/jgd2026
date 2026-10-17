extends GutTest
## 第四阶段（用户 2026-10-08 修改意见 1、2、4）：
## 1 部署阶段按下已放置单位不弹出详情：松开未拖动 = 选中；拖动 = 移动，虚影吸附到最近地块，放下后不弹出；
## 2 信标模式：数字键（第 n 个已部署单位）/ 详情「信标」进入；左键点地块追加信标、右键撤销最后一个；
##   底部边栏设置移动方式（沿路径 / 循环 / 往返写入「沿我的信标」指令，没有则追加一条）；自动寻路待定（禁用）；Esc /「完成」退出；
## 4 撤离时显示位置平滑 + 残影（只碰表现）。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
	"presets": [],
}

var _saved_data: Dictionary
var _saved_level_id: String
var _saved_unlocks: Dictionary
var _selected: Array[int] = []


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	_selected.clear()
	EventBus.unit_selected.connect(_on_selected)


func after_each() -> void:
	EventBus.unit_selected.disconnect(_on_selected)
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks


func _on_selected(id: int) -> void:
	_selected.append(id)


func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func _cell_screen(root: Node2D, cell: Vector2i) -> Vector2:
	var lv: LevelDefinition = root.get("level") as LevelDefinition
	var local: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), lv.height)
	return (root.get_node("MapLayer") as Node2D).get_global_transform_with_canvas() * local


func _click(map_input: Control, screen: Vector2, button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.global_position = screen
	e.position = map_input.get_global_transform().affine_inverse() * screen
	map_input.call("_gui_input", e)


func test_press_release_selects_but_press_alone_does_not() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	var mi: Control = root.find_child("MapInput", true, false) as Control
	var cell: Vector2i = c.placements["u1"] as Vector2i
	_selected.clear()
	_click(mi, _cell_screen(root, cell), MOUSE_BUTTON_LEFT, true)
	assert_eq(_selected, [] as Array[int], "按下不打开详情")
	_click(mi, _cell_screen(root, cell), MOUSE_BUTTON_LEFT, false)
	assert_eq(_selected, [c.unit_id_of_slot("u1")] as Array[int], "松开（未拖动）才选中")


func test_drag_from_map_moves_with_snapped_ghost_and_no_popup() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	var mi: Control = root.find_child("MapInput", true, false) as Control
	var lv: LevelDefinition = root.get("level") as LevelDefinition
	var to: Vector2i = Vector2i(-1, -1)
	for dc: Vector2i in lv.deploy_cells:
		if c.slot_at(dc) == "" and c.can_place("u1", dc):
			to = dc
			break
	assert_ne(to, Vector2i(-1, -1))
	# （真实拖动由引擎的拖放触发 _get_drag_data；这里直接给出同样的拖拽数据与"原位置变淡"）
	var data: Dictionary = { "slot_id": "u1", "from_map": true }
	root.call("set_drag_source", c.unit_id_of_slot("u1"))
	var unit_view: Node2D = null
	for v: Node in root.get_node("UnitLayer").get_children():
		if v is UnitView and (v as UnitView).unit.id == c.unit_id_of_slot("u1"):
			unit_view = v as Node2D
	assert_almost_eq(unit_view.modulate.a, float((root.get_script() as GDScript).get_script_constant_map()["DRAG_SOURCE_ALPHA"]), 0.001, "原位置单位变淡")
	# 悬停在目标格附近（偏离格中心 0.3 格）：虚影吸附到该格
	var near: Vector2 = _cell_screen(root, to) + Vector2(0.3, -0.2) * float(root.call("cell_screen_px"))
	assert_true(bool(mi.call("_can_drop_data", mi.get_global_transform().affine_inverse() * near, data)))
	var dz: Node2D = root.get_node("MapLayer/DeployZone") as Node2D
	assert_eq(dz.get("hover_cell"), to, "吸附到最近的地块")
	assert_not_null(dz.get("hover_ghost"), "显示单位虚影")
	_selected.clear()
	mi.call("_drop_data", mi.get_global_transform().affine_inverse() * near, data)
	mi.notification(Control.NOTIFICATION_DRAG_END)
	assert_eq(c.placements["u1"], to, "已移动")
	assert_eq(_selected, [] as Array[int], "移动后不弹出详情")
	await wait_process_frames(1)
	for v: Node in root.get_node("UnitLayer").get_children():
		if v is UnitView and not (v as UnitView).is_queued_for_deletion() and (v as UnitView).unit.id == c.unit_id_of_slot("u1"):
			assert_almost_eq((v as Node2D).modulate.a, 1.0, 0.001, "放下后恢复不透明")


func test_beacon_mode_by_number_key_places_and_undoes() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	var hud: Control = root.get_node("UI/HUD") as Control
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.keycode = KEY_2
	key.pressed = true
	root.call("_input", key)
	var second: String = c.deployed_uids()[1]
	assert_eq(str(hud.call("beacon_mode_slot")), second, "数字键 2 = 第 2 个已部署单位进入信标模式")
	assert_eq(int(root.get("selected_id")), c.unit_id_of_slot(second), "并选中该单位（侧栏打开）")
	var bar: Control = hud.get_node("BeaconBar") as Control
	assert_true(bar.visible, "底部信标边栏")
	assert_false((hud.find_child("CardList", true, false) as Control).visible, "边栏替换出场卡")
	var mi: Control = root.find_child("MapInput", true, false) as Control
	var before: int = c.get_beacons(second).size()
	_click(mi, _cell_screen(root, Vector2i(6, 3)), MOUSE_BUTTON_LEFT, true)
	_click(mi, _cell_screen(root, Vector2i(6, 3)), MOUSE_BUTTON_LEFT, false)
	_click(mi, _cell_screen(root, Vector2i(8, 3)), MOUSE_BUTTON_LEFT, true)
	assert_eq(c.get_beacons(second).size(), before + 2, "左键点地块追加信标")
	assert_eq(c.get_beacons(second)[before + 1]["cell"], Vector2i(8, 3))
	_click(mi, _cell_screen(root, Vector2i(1, 1)), MOUSE_BUTTON_RIGHT, true)
	assert_eq(c.get_beacons(second).size(), before + 1, "右键撤销最后一个")
	# 移动方式：循环 → 写进「沿我的信标」指令
	(bar.find_child("Beacon_beacon_mode_loop", true, false) as Button).pressed.emit()
	assert_eq(c.beacon_follow_mode(second), SimTypes.BeaconMode.LOOP, "循环写入指令")
	assert_true((bar.find_child("Beacon_beacon_mode_loop", true, false) as Button).button_pressed, "当前方式为按下态")
	assert_true((bar.find_child("Beacon_beacon_mode_auto", true, false) as Button).disabled, "自动寻路待定")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	hud.call("_unhandled_input", esc)
	assert_eq(str(hud.call("beacon_mode_slot")), "", "Esc 退出信标模式")
	assert_false(bar.visible)
	assert_true((hud.find_child("CardList", true, false) as Control).visible, "出场卡恢复")


func test_set_beacon_follow_mode_appends_rule_when_missing() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var uid: String = c.add_unit("striker", (root.get("level") as LevelDefinition).deploy_cells[0])
	assert_ne(uid, "")
	assert_eq(c.beacon_follow_mode(uid), SimTypes.BeaconMode.ONCE, "第五阶段：新单位预填「始终 → 沿信标移动」")
	assert_true(c.set_rules(uid, [] as Array[RuleDef]))
	assert_eq(c.beacon_follow_mode(uid), -1)
	c.add_beacon(uid, Vector2i(5, 2))
	assert_true(c.set_beacon_follow_mode(uid, SimTypes.BeaconMode.ONCE))
	var rules: Array[RuleDef] = c.get_rules(uid)
	assert_eq(rules.back().action.type, SimTypes.ActionType.FOLLOW_BEACONS, "末尾追加「始终 → 沿我的信标」")
	assert_eq(rules.back().action.from, "1")
	assert_eq(c.beacon_follow_mode(uid), SimTypes.BeaconMode.ONCE)
	assert_true(c.set_beacon_follow_mode(uid, SimTypes.BeaconMode.PINGPONG))
	assert_eq(c.get_rules(uid).size(), rules.size(), "已有时只改方式，不重复追加")


func test_retreat_leaves_afterimages() -> void:
	var root: Node2D = _battle("level_04")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	assert_true(c.start())
	var found: bool = false
	for i: int in 600:
		await wait_process_frames(1)
		for v: Node in root.get_node("UnitLayer").get_children():
			if v.name.begins_with("Afterimage"):
				found = true
		if found or c.phase != SimTypes.Phase.RUNNING:
			break
	assert_true(found, "撤离中留下残影（第四关猎犬撤离）")
