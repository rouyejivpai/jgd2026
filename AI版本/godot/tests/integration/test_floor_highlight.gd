extends GutTest
## 10 §7 地板高亮（FloorHighlight，取代 ObstacleHighlight）：部署阶段选中己方单位时显示（可行走格淡骨白、障碍格红），
## 取消选中隐藏、运行中不显示；选中敌人不显示；敌方初始位置红色地面标记只在部署阶段；高亮不影响模拟。

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


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks


func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func test_select_shows_deselect_hides_running_hides() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var floor_hl: FloorHighlight = root.find_child("FloorHighlight", true, false) as FloorHighlight
	assert_not_null(floor_hl)
	assert_eq(floor_hl.get_parent().name, &"MapLayer", "位于受玩法矩形裁剪的 MapLayer 下")
	assert_true(c.apply_recommended())
	EventBus.unit_selected.emit(-1)
	assert_false(floor_hl.is_showing(), "未选中不显示")
	EventBus.unit_selected.emit(c.unit_id_of_slot("u1"))
	assert_true(floor_hl.is_showing(), "部署阶段选中己方单位显示")
	EventBus.unit_selected.emit(-1)
	assert_false(floor_hl.is_showing(), "取消选中隐藏")
	var enemy: int = c.world.get_spawn("W1").id
	EventBus.unit_selected.emit(enemy)
	assert_false(floor_hl.is_showing(), "选中敌人不显示")
	EventBus.unit_selected.emit(c.unit_id_of_slot("u1"))
	var hash_before: int = c.world.state_hash()
	assert_true(c.start())
	assert_false(floor_hl.is_showing(), "运行中不显示")
	assert_eq(c.world.state_hash(), hash_before, "高亮不改模拟")
	c.reset()
	assert_true(floor_hl.is_showing(), "重试回到部署阶段后仍选中则恢复显示")


func test_blocked_cells_red_walkable_bone() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var floor_hl: FloorHighlight = root.find_child("FloorHighlight", true, false) as FloorHighlight
	var blocked: Color = floor_hl.cell_color(Vector2i(5, 2))        # 哭墙
	var walk: Color = floor_hl.cell_color(Vector2i(5, 3))
	assert_eq(Color(blocked, 1.0), Palette.WARN_RED, "障碍格为红")
	assert_almost_eq(blocked.a, 0.45, 0.001, "决策 ⑬：不可移动 alpha 0.45")
	assert_eq(Color(walk, 1.0), Palette.BONE, "可行走格为骨白")
	assert_almost_eq(walk.a, 0.18, 0.001, "决策 ⑬：可行走 alpha 0.18")


func test_enemy_start_marks() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var floor_hl: FloorHighlight = root.find_child("FloorHighlight", true, false) as FloorHighlight
	var cells: Array[Vector2i] = floor_hl.enemy_cells()
	assert_eq(cells.size(), 3, "第三关敌方初始位置 3 处（含骸柱）")
	assert_has(cells, Vector2i(9, 8))      # 守卫 W1（2026-10-18 为直线移动不卡墙由 (9,4) 挪到 (9,8)）
	assert_true(floor_hl.deploy, "部署阶段绘制敌方初始位置标记")
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	assert_true(c.start())
	assert_false(floor_hl.deploy, "运行中不绘制")
