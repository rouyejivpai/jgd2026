extends GutTest
## 10 §6.4 鼠标触边横向移动：无选中不平移；有选中且侧栏可见时触边 pan_x 单调增长到上限（PAN_MAX = 侧栏宽）；
## 只有横向；取消选中回 0；开始战斗回 0；backdrop 绘制宽 = 视口宽 + 2·PAN_MAX，偏移到上限也不露底（P7 起有 R4 对齐底图的关卡改为 1:1 同步平移）。
## 第四阶段：详情改为停靠一侧的侧栏，鼠标在侧栏上不触边平移（单位在左 → 侧栏在右 → 只有左边缘触发）；
## 滚轮以鼠标处为中心缩放（鼠标下的地图点不动）、中键 / 左键拖空地两个方向平移，动过镜头后取消选中不自动回正；
## 拖出平移范围走橡皮筋（渐近视口 1/8）、松手弹回范围内（同选关）；左键点选松开才生效、拖过不算点击。
## （镜头不碰模拟由 run_playtests -- --check 哈希全等证明。）

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
	"presets": [],
}
const DT: float = 1.0 / 60.0

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


func _pan(root: Node2D) -> float:
	return float(root.get("pan_x"))


func _until_zero(root: Node2D) -> void:
	for i: int in 240:
		if is_zero_approx(_pan(root)):
			return
		await wait_process_frames(1)


func test_no_selection_no_pan() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var w: float = root.get_viewport_rect().size.x
	EventBus.unit_selected.emit(-1)
	for i: int in 30:
		root.call("edge_pan_step", Vector2(w - 2.0, 500.0), DT)
	assert_eq(_pan(root), 0.0, "无选中单位不平移")


func test_edge_pan_grows_to_limit_then_recenters() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	EventBus.unit_selected.emit(c.unit_id_of_slot("u1"))
	await wait_process_frames(2)
	assert_true(bool(root.call("pan_enabled")), "有选中且侧栏可见")
	var hud: Control = root.get_node("UI/HUD") as Control
	assert_true(bool(hud.call("side_on_right")), "单位在左半屏：侧栏停靠右侧")
	var w: float = root.get_viewport_rect().size.x
	for i: int in 10:
		root.call("edge_pan_step", Vector2(w - 2.0, 500.0), DT)
	assert_eq(_pan(root), 0.0, "鼠标在侧栏上（右边缘）不平移")
	root.call("edge_pan_step", Vector2(w * 0.5, 500.0), DT)
	assert_eq(_pan(root), 0.0, "不在边缘不平移")
	root.call("edge_pan_step", Vector2(UiKit.PAN_EDGE_PX + 1.0, 500.0), DT)
	assert_eq(_pan(root), 0.0, "距边 ≥ 24 px 不触发")
	var last: float = 0.0
	var steps: int = 0
	while _pan(root) > -UiKit.PAN_MAX and steps < 1000:
		root.call("edge_pan_step", Vector2(2.0, 500.0), DT)
		assert_lt(_pan(root), last, "单调变化")
		last = _pan(root)
		steps += 1
	assert_eq(_pan(root), -UiKit.PAN_MAX, "到上限 PAN_MAX")
	assert_almost_eq(float(steps), UiKit.PAN_MAX / (UiKit.PAN_SPEED * DT), 1.0, "速度 600 px/s")
	root.call("edge_pan_step", Vector2(2.0, 500.0), DT)
	assert_eq(_pan(root), -UiKit.PAN_MAX, "不越过上限")
	var map_layer: Node2D = root.get_node("MapLayer") as Node2D
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	assert_almost_eq(map_layer.position.x, rect.position.x + UiKit.PAN_MAX, 0.01, "地图层整体平移")
	assert_almost_eq(map_layer.position.y, rect.position.y, 0.01, "只有横向")
	var unit_layer: Node2D = root.get_node("UnitLayer") as Node2D
	assert_eq(unit_layer.position, map_layer.position, "单位层同步平移")
	var backdrop: Sprite2D = root.get_node("BackdropLayer") as Sprite2D
	var lv: LevelDefinition = root.get("level") as LevelDefinition
	if backdrop.texture != null and lv.scene_obstacles != "":
		var br2: Rect2 = backdrop.call("drawn_rect") as Rect2
		var vp: Vector2 = root.get_viewport_rect().size
		assert_almost_eq(br2.size.y, Playfield.DESIGN_SIZE.y, 0.5, "对齐底图按设计高 1:1")
		assert_almost_eq(br2.get_center().x, vp.x * 0.5 + UiKit.PAN_MAX, 0.5, "对齐底图与地图层同步平移")
	elif backdrop.texture != null:
		var br: Rect2 = backdrop.call("drawn_rect") as Rect2
		assert_lte(br.position.x, 0.5, "偏移到上限 backdrop 左侧不露底")
		assert_gte(br.end.x, w - 0.5, "右侧不露底")
	EventBus.unit_selected.emit(-1)
	await _until_zero(root)
	assert_eq(_pan(root), 0.0, "取消选中回 0")


func test_wheel_zoom_keeps_point_under_cursor_and_drag_pans() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var m: Vector2 = rect.position + rect.size * Vector2(0.3, 0.6)
	var before: Vector2 = root.call("screen_to_sim", m) as Vector2
	root.call("zoom_at", m, 1)
	root.call("zoom_at", m, 1)
	assert_gt(float(root.get("cam_zoom")), 1.2, "放大两档")
	var after: Vector2 = root.call("screen_to_sim", m) as Vector2
	assert_almost_eq(after.distance_to(before), 0.0, 0.01, "鼠标下的地图点不动")
	var map_layer: Node2D = root.get_node("MapLayer") as Node2D
	assert_almost_eq(map_layer.scale.x, float(int(root.get("cell_px"))) / SimTypes.TILE_SIZE * float(root.get("cam_zoom")), 0.0001, "地图层随缩放")
	assert_almost_eq((root.get_node("UnitLayer") as Node2D).scale.x, map_layer.scale.x, 0.0001, "单位层同步缩放")
	var p0: Vector2 = map_layer.position
	root.call("pan_by", Vector2(40.0, -25.0))
	assert_almost_eq(map_layer.position.x - p0.x, 40.0, 0.01, "拖动：地图跟手（横）")
	assert_almost_eq(map_layer.position.y - p0.y, -25.0, 0.01, "拖动：地图跟手（纵）")
	var sim: Vector2 = root.call("screen_to_sim", m) as Vector2
	var cell: Vector2i = root.call("screen_to_cell", m) as Vector2i
	assert_eq(cell, SimTypes.pos_to_cell(sim), "屏幕 → 格 与缩放一致")
	assert_true(bool(root.call("in_playfield", m)) == Rect2(Vector2.ZERO, Vector2((root.get("level") as LevelDefinition).width, (root.get("level") as LevelDefinition).height)).has_point(sim), "玩法矩形判定随缩放 / 平移")
	for i: int in 30:
		root.call("zoom_at", m, -1)
	assert_almost_eq(float(root.get("cam_zoom")), UiKit.ZOOM_MIN, 0.0001, "缩小到下限")
	EventBus.unit_selected.emit(-1)
	await wait_process_frames(20)
	assert_almost_eq(float(root.get("cam_zoom")), UiKit.ZOOM_MIN, 0.0001, "动过镜头：取消选中不回正")


func _mouse(mi: Control, button: int, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.global_position = pos
	e.position = mi.get_global_transform().affine_inverse() * pos
	mi.call("_gui_input", e)


func _move(mi: Control, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.global_position = pos
	e.position = mi.get_global_transform().affine_inverse() * pos
	mi.call("_gui_input", e)


func test_drag_overscroll_rubbers_then_springs_back() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var lim: Vector2 = root.call("pan_limit") as Vector2
	var over: float = root.get_viewport_rect().size.x * 0.125
	root.call("begin_cam_drag", Vector2(500.0, 400.0))
	root.call("cam_drag_to", Vector2(400.0, 400.0))
	assert_almost_eq(_pan(root), 100.0, 0.01, "范围内一比一跟手")
	root.call("cam_drag_to", Vector2(500.0 - lim.x - 5000.0, 400.0))
	assert_gt(_pan(root), lim.x + over * 0.9, "拖出很远：接近 上限 + 视口 1/8")
	assert_lt(_pan(root), lim.x + over, "橡皮筋不超过 视口 1/8")
	root.call("end_cam_drag")
	for i: int in 60:
		await wait_process_frames(1)
	assert_almost_eq(_pan(root), lim.x, 0.5, "松手弹回上限")
	assert_false(bool(root.call("cam_dragging")))


func test_middle_and_left_drag_pan_and_wheel_zooms_via_input() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var mi: Control = root.find_child("MapInput", true, false) as Control
	assert_not_null(mi)
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var m: Vector2 = rect.get_center()
	_mouse(mi, MOUSE_BUTTON_WHEEL_UP, true, m)
	assert_gt(float(root.get("cam_zoom")), 1.0, "滚轮（无修饰键）放大")
	var y0: float = float(root.get("pan_y"))
	_mouse(mi, MOUSE_BUTTON_MIDDLE, true, m)
	_move(mi, m + Vector2(-30.0, -20.0))
	assert_almost_eq(_pan(root), 30.0, 0.01, "中键拖动：横")
	assert_almost_eq(float(root.get("pan_y")) - y0, 20.0, 0.01, "中键拖动：纵")
	_mouse(mi, MOUSE_BUTTON_MIDDLE, false, m + Vector2(-30.0, -20.0))
	assert_false(bool(root.call("cam_dragging")), "松开中键结束")
	watch_signals(EventBus)
	var empty: Vector2 = Vector2(rect.end.x - 4.0, rect.position.y + 4.0)
	_mouse(mi, MOUSE_BUTTON_LEFT, true, empty)
	_move(mi, empty + Vector2(40.0, 0.0))
	assert_true(bool(root.call("cam_dragging")), "左键拖空地超过阈值 = 拖镜头")
	assert_almost_eq(_pan(root), -10.0, 0.01, "左键拖动跟手")
	_mouse(mi, MOUSE_BUTTON_LEFT, false, empty + Vector2(40.0, 0.0))
	assert_false(bool(root.call("cam_dragging")))
	assert_signal_not_emitted(EventBus, "unit_selected", "拖过不算点击")
	_mouse(mi, MOUSE_BUTTON_LEFT, true, empty)
	_mouse(mi, MOUSE_BUTTON_LEFT, false, empty)
	assert_signal_emitted(EventBus, "unit_selected", "没拖动 = 点击")


func test_left_edge_and_start_battle_recenters() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	EventBus.unit_selected.emit(c.unit_id_of_slot("u2"))
	await wait_process_frames(2)
	for i: int in 20:
		root.call("edge_pan_step", Vector2(1.0, 500.0), DT)
	assert_lt(_pan(root), 0.0, "左边缘向左平移")
	assert_gte(_pan(root), -UiKit.PAN_MAX)
	assert_true(c.start())
	await _until_zero(root)
	assert_eq(_pan(root), 0.0, "开始战斗回 0")
