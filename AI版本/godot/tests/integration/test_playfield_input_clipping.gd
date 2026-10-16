extends GutTest
## 07 §1（A17）：玩法矩形计算（与 07 §1.2 表一致、三种窗口比例下居中且尺寸不变）；
## 地面类图层全部受玩法矩形裁剪；矩形外的点击 = 点击空地，拖起/放下无效。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
## 07 §1.2 表（1920×1080）：level -> [cell_px, x0, y0, x1, y1]
## 第三阶段 P6 起战场让出局内 HUD 的上下带（data/ui_layout/battle_hud.json reserved 203 / 261，用户 2026-10-05 选择缩小战场区）；
## 与 tools/print_playfield_rects.py 输出一致
const TABLE: Dictionary = {
	"level_01": [88, 476, 203, 1444, 819],
	"level_02": [88, 388, 203, 1532, 819],
	"level_03": [61, 472, 206, 1448, 816],
	"level_04": [51, 654, 205, 1266, 817],
	"level_05": [68, 416, 205, 1504, 817],
	"level_06": [68, 416, 205, 1504, 817],
	"level_07": [68, 518, 205, 1402, 817],
	"level_08": [56, 540, 203, 1380, 819],
}

var _saved_data: Dictionary
var _saved_level_id: String


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id


func _rect_of(entry: Array) -> Rect2:
	return Rect2(float(entry[1]), float(entry[2]), float(entry[3]) - float(entry[1]), float(entry[4]) - float(entry[2]))


func test_rects_match_spec_table() -> void:
	for lid: String in TABLE.keys():
		var pf: Dictionary = Playfield.compute(DataRegistry.get_level(lid))
		var e: Array = TABLE[lid] as Array
		assert_eq(int(pf["cell_px"]), int(e[0]), "%s cell_px" % lid)
		assert_eq(pf["rect"] as Rect2, _rect_of(e), "%s 玩法矩形" % lid)


func test_three_window_ratios_keep_rect_centered() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_01")
	var base: Rect2 = Playfield.compute(level, Vector2(1920, 1080))["rect"] as Rect2
	var tall: Dictionary = Playfield.compute(level, Vector2(1920, 1200))      # 16:10
	var wide: Dictionary = Playfield.compute(level, Vector2(2560, 1080))      # 21:9
	assert_eq(int(tall["cell_px"]), int(TABLE["level_01"][0]), "16:10 下格子尺寸不变")
	assert_eq(int(wide["cell_px"]), int(TABLE["level_01"][0]), "21:9 下格子尺寸不变")
	assert_eq((tall["rect"] as Rect2).size, base.size)
	assert_eq((wide["rect"] as Rect2).size, base.size)
	assert_eq((tall["rect"] as Rect2).get_center().x, 960.0, "16:10 水平居中")
	var b: Vector2 = Playfield.bands()
	assert_eq((tall["rect"] as Rect2).get_center().y, b.x + (1200.0 - b.x - b.y) * 0.5, "16:10 在 HUD 上下带之间居中")
	assert_eq((wide["rect"] as Rect2).get_center().x, 1280.0, "21:9 水平居中")
	assert_eq((wide["rect"] as Rect2).position.y, base.position.y)


func test_manual_playfield_rect_override() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_04.json")) as Dictionary
	(d["scene"] as Dictionary)["playfield_rect"] = [500, 100, 1400, 1000]
	var L: LevelDefinition = LevelDefinition.from_dict(d, "test")
	assert_true(L.has_playfield_rect)
	var pf: Dictionary = Playfield.compute(L)
	assert_eq(int(pf["cell_px"]), 75, "floor(min(900/12, 900/12))")
	assert_eq(pf["rect"] as Rect2, Rect2(500, 100, 900, 900))


func test_deprecated_background_field_is_error() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_01.json")) as Dictionary
	d["background"] = "res://assets/backgrounds/level_01.png"
	var before: int = DataReader.messages.size()
	LevelDefinition.from_dict(d, "test")
	var found: bool = false
	for i: int in range(before, DataReader.messages.size()):
		found = found or DataReader.messages[i].contains("DEPRECATED_FIELD background")
	assert_true(found, "旧 background 字段报 DEPRECATED_FIELD")
	for e: Object in get_errors():
		e.set("handled", true)


# ---- 场景级 ----
func _make_battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func test_battle_root_applies_playfield_transform() -> void:
	var root: Node2D = _make_battle("level_03")
	await wait_process_frames(2)
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var vp: Vector2 = root.get_viewport_rect().size
	var expect: Rect2 = Playfield.compute(DataRegistry.get_level("level_03"), vp)["rect"] as Rect2
	assert_eq(rect, expect)
	assert_eq(int(root.get("cell_px")), int(TABLE["level_03"][0]))
	var map_layer: Node2D = root.get_node("MapLayer") as Node2D
	assert_eq(map_layer.position, rect.position)
	assert_almost_eq(map_layer.scale.x, float(TABLE["level_03"][0]) / float(SimTypes.TILE_SIZE), 0.0001, "地图按 cell_px 缩放，镜头不缩放")
	assert_null(root.find_child("CameraRig", true, false), "不再有缩放地图的镜头")
	assert_null(root.find_child("Props", true, false), "竖立道具层已停用")
	assert_eq(map_layer.clip_children, CanvasItem.CLIP_CHILDREN_ONLY, "MapLayer 以玩法矩形裁剪子层")
	for n: String in ["GroundLayer", "FloorHighlight", "GridOverlay", "DeployZone", "BeaconLayer"]:
		assert_not_null(map_layer.get_node_or_null(n), "%s 位于受裁剪的 MapLayer 下" % n)
	assert_null(root.find_child("RouteLayer", true, false), "10 §7：预设路线显示已删除")
	assert_null(root.find_child("ObstacleHighlight", true, false), "10 §7：由 FloorHighlight 取代")
	# 网格角落 ↔ 屏幕矩形角落
	var t: float = 80.0
	assert_eq(root.call("screen_to_cell", rect.position + Vector2(t * 0.5, t * 0.5)), Vector2i(0, 9), "左上格")
	assert_eq(root.call("screen_to_cell", rect.end - Vector2(t * 0.5, t * 0.5)), Vector2i(15, 0), "右下格")


func test_clicks_outside_playfield_hit_nothing() -> void:
	var root: Node2D = _make_battle("level_01")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var t: float = float(int(root.get("cell_px")))
	# slot_striker_a 推荐位 (2,2)；构造紧贴矩形外侧、与某个单位同一水平线的点
	var unit_px: Vector2 = rect.position + Vector2(2.5 * t, (7.0 - 2.5) * t)
	assert_gt(int(root.call("unit_at_screen", unit_px)), -1, "矩形内点中单位")
	var outside_points: Array[Vector2] = [rect.position - Vector2(2, 2), Vector2(rect.position.x - 1.0, unit_px.y),
		Vector2(rect.end.x + 1.0, unit_px.y), Vector2(unit_px.x, rect.end.y + 1.0), Vector2(unit_px.x, rect.position.y - 1.0)]
	for p: Vector2 in outside_points:
		assert_false(bool(root.call("in_playfield", p)), "%s 在矩形外" % p)
		assert_eq(int(root.call("unit_at_screen", p)), -1, "矩形外点击 = 点击空地")
	var map_input: Control = root.find_child("MapInput", true, false) as Control
	var to_local: Transform2D = map_input.get_global_transform().affine_inverse()
	# 矩形外拖起无效；侧栏拖来的单位不能放在矩形外；地图上拖起的单位放到矩形外 = 收回
	assert_null(map_input.call("_get_drag_data", to_local * outside_points[1]))
	var a: String = c.recommended_uid("slot_striker_a")
	var b: String = c.recommended_uid("slot_striker_b")
	var from_card: Dictionary = { "form": "striker" }
	assert_false(bool(map_input.call("_can_drop_data", to_local * outside_points[1], from_card)), "出场卡不能放到矩形外")
	var from_map: Dictionary = { "slot_id": a, "from_map": true }
	map_input.call("_drop_data", to_local * outside_points[1], from_map)
	assert_false(c.placements.has(a), "拖出矩形 = 收回")
	assert_true(c.placements.has(b), "另一名单位不受影响")
	# 点击矩形外：发出"未选中"
	watch_signals(EventBus)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.global_position = outside_points[2]
	mb.position = to_local * outside_points[2]
	map_input.call("_gui_input", mb)
	assert_signal_emitted_with_parameters(EventBus, "unit_selected", [-1])


## 10 §6.4：镜头横移 pan_x 后，screen_to_cell / unit_at_screen 按偏移换算；平移后的矩形外点击仍无效
func test_coordinates_follow_camera_pan() -> void:
	var root: Node2D = _make_battle("level_01")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var t: float = float(int(root.get("cell_px")))
	var unit_px: Vector2 = rect.position + Vector2(2.5 * t, (7.0 - 2.5) * t)    # slot_striker_a 推荐位 (2,2)
	var id: int = int(root.call("unit_at_screen", unit_px))
	assert_gt(id, -1)
	for pan: float in [200.0, -350.0, UiKit.PAN_MAX]:
		root.call("set_pan", pan)
		var off := Vector2(pan, 0.0)
		assert_eq(root.call("screen_to_cell", unit_px - off), Vector2i(2, 2), "pan %s：屏幕点减去偏移后换算到同一格" % pan)
		assert_eq(int(root.call("unit_at_screen", unit_px - off)), id, "pan %s：点中同一单位" % pan)
		assert_almost_eq((root.call("unit_screen_pos", id) as Vector2).x, (unit_px - off).x, 1.0, "单位视图随镜头平移")
		assert_ne(int(root.call("unit_at_screen", unit_px)), id, "pan %s：原屏幕位置不再是该单位" % pan)
		assert_true(bool(root.call("in_playfield", rect.position - off + Vector2(1, 1))), "矩形随镜头平移")
		assert_false(bool(root.call("in_playfield", rect.position - off - Vector2(2, 2))), "平移后的矩形外仍是空地")
		assert_eq(int(root.call("unit_at_screen", Vector2(rect.position.x - pan - 1.0, unit_px.y))), -1, "矩形外点击无效")
	root.call("set_pan", 99999.0)
	assert_eq(float(root.get("pan_x")), UiKit.PAN_MAX, "clamp 到 PAN_MAX")
	root.call("set_pan", -99999.0)
	assert_eq(float(root.get("pan_x")), -UiKit.PAN_MAX)
