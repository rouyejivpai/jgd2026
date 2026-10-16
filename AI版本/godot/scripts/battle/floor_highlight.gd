class_name FloorHighlight
extends Node2D
## 地板高亮（10 §7，取代第二阶段的 ObstacleHighlight）：部署阶段选中己方单位、拖拽单位或布 / 拖信标时，
## 玩法矩形内可行走格叠淡骨白、不可移动格（障碍）叠红（决策 ⑬：alpha 0.18 / 0.45，最终按 R5 贴片），常显直到取消选中 / 交互结束；
## 运行中不显示。部署阶段另在敌方初始位置画红色地面标记（删除预设路线显示后标识敌人从哪里来）。
## 只画地板，不改单位表现；坐标为 MapLayer 局部（每格 TILE_SIZE），受玩法矩形裁剪。只读关卡数据。

const WALKABLE_ALPHA: float = 0.18
const BLOCKED_ALPHA: float = 0.45
const ENEMY_MARK_FILL_ALPHA: float = 0.22
const ENEMY_MARK_RING_ALPHA: float = 0.75
const ENEMY_MARK_RADIUS: float = 0.42     ## 格
const ENEMY_MARK_SQUASH: float = 0.6      ## 3/4 视角椭圆（同单位底座）
const ENEMY_MARK_WIDTH: float = 3.0

var level: LevelDefinition = null
var deploy: bool = true                  ## 当前是否部署阶段
var selected: bool = false               ## 选中了己方单位
var dragging: bool = false               ## 正在拖拽单位（出场卡 / 地图上的单位）
var beacon_drag: bool = false            ## 正在拖动信标


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	queue_redraw()


func set_phase(phase: int) -> void:
	deploy = phase == SimTypes.Phase.DEPLOY
	queue_redraw()


func set_selected(on: bool) -> void:
	selected = on
	queue_redraw()


func set_beacon_drag(on: bool) -> void:
	beacon_drag = on
	queue_redraw()


## 是否正在显示可行走 / 不可移动高亮
func is_showing() -> bool:
	return level != null and deploy and (selected or dragging or beacon_drag)


## 某格的高亮颜色：障碍格红、其余淡骨白
func cell_color(cell: Vector2i) -> Color:
	return Color(Palette.WARN_RED, BLOCKED_ALPHA) if level.is_blocked(cell) else Color(Palette.BONE, WALKABLE_ALPHA)


## 敌方初始位置（部署阶段的红色地面标记）
func enemy_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if level == null:
		return out
	for s: SpawnDef in level.initial_units:
		if s.faction == SimTypes.Faction.ENEMY:
			out.append(s.pos)
	return out


## 拖拽单位开始 / 结束（任何携带 slot_id 或 form 的 GUI 拖拽）
func _notification(what: int) -> void:
	if level == null:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and ((data as Dictionary).has("slot_id") or (data as Dictionary).has("form")):
			dragging = true
			queue_redraw()
	elif what == NOTIFICATION_DRAG_END and dragging:
		dragging = false
		queue_redraw()


func _draw() -> void:
	if level == null or not deploy:
		return
	var t: float = float(SimTypes.TILE_SIZE)
	if is_showing():
		for y: int in level.height:
			for x: int in level.width:
				var cell := Vector2i(x, y)
				draw_rect(Rect2(SimTypes.sim_to_screen(Vector2(x, y + 1), level.height), Vector2(t, t)), cell_color(cell))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for cell: Vector2i in enemy_cells():
		var c: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), level.height)
		draw_set_transform(c, 0.0, Vector2(1.0, ENEMY_MARK_SQUASH))
		draw_circle(Vector2.ZERO, ENEMY_MARK_RADIUS * t, Color(Palette.WARN_RED, ENEMY_MARK_FILL_ALPHA))
		draw_arc(Vector2.ZERO, ENEMY_MARK_RADIUS * t, 0.0, TAU, 40, Color(Palette.WARN_RED, ENEMY_MARK_RING_ALPHA), ENEMY_MARK_WIDTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
