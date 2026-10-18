class_name FloorHighlight
extends Node2D
## 地板高亮（10 §7，取代第二阶段的 ObstacleHighlight）：部署阶段选中己方单位、拖拽单位或布 / 拖信标时，
## 玩法矩形内可行走格的格线加骨白光晕、不可移动格（障碍）画红色发光边线（决策 ⑬ 的 alpha 0.18 / 0.45 换算为光晕强度；格内不填色），常显直到取消选中 / 交互结束；
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
	if is_showing():                     # 2026-10-18：不填色，只给格线加光晕（可行走骨白、障碍红色发光边线）
		var walk: Dictionary = {}
		for y: int in level.height:
			for x: int in level.width:
				if not level.is_blocked(Vector2i(x, y)):
					walk[Vector2i(x, y)] = true
		GlowLines.draw_cells(self, walk, level.height, Palette.BONE, WALKABLE_ALPHA * 12.0, false)
		GlowLines.draw_cells(self, GlowLines.cell_set(level.blocked), level.height, Palette.WARN_RED, BLOCKED_ALPHA * 6.0, true, 0.15)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for cell: Vector2i in enemy_cells():
		var c: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), level.height)
		draw_set_transform(c, 0.0, Vector2(1.0, ENEMY_MARK_SQUASH))
		draw_circle(Vector2.ZERO, ENEMY_MARK_RADIUS * t, Color(Palette.WARN_RED, ENEMY_MARK_FILL_ALPHA))
		draw_arc(Vector2.ZERO, ENEMY_MARK_RADIUS * t, 0.0, TAU, 40, Color(Palette.WARN_RED, ENEMY_MARK_RING_ALPHA), ENEMY_MARK_WIDTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
