extends Node2D
## 网格（01 §8 GridOverlay；07 §1 起只画在玩法矩形内）：可行走格细线；障碍格不再叠暗纹（由 GroundLayer 的地面标识表现，
## 规划态地板高亮见 FloorHighlight）；失败条件 reach_zone 的逃离区（暗红斜纹 + 红框）。

var level: LevelDefinition = null


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var t: float = float(SimTypes.TILE_SIZE)
	for y: int in level.height:
		for x: int in level.width:
			if level.is_blocked(Vector2i(x, y)):
				continue
			var top_left: Vector2 = SimTypes.sim_to_screen(Vector2(x, y + 1), level.height)
			draw_rect(Rect2(top_left, Vector2(t, t)), Palette.GRID_LINE, false, -1.0)   # 细线：缩放后仍为 1 像素
	_draw_escape_zones(t)
	_draw_goal_zones(t)


## 07 §9：胜利条件 reach_zone / escort 的目标区（金色框 + 淡金底）
func _draw_goal_zones(t: float) -> void:
	for o: ObjectiveDef in level.win:
		if o.type != SimTypes.ObjectiveType.REACH_ZONE and o.type != SimTypes.ObjectiveType.ESCORT:
			continue
		for c: Vector2i in o.cells:
			var rect := Rect2(SimTypes.sim_to_screen(Vector2(c.x, c.y + 1), level.height), Vector2(t, t))
			draw_rect(rect, Color(Palette.ALCHEMY_GOLD, 0.16))
			draw_rect(rect.grow(-2.0), Palette.ALCHEMY_GOLD, false, 2.0)


func _draw_escape_zones(t: float) -> void:
	for o: ObjectiveDef in level.lose:
		if o.type != SimTypes.ObjectiveType.REACH_ZONE:
			continue
		for c: Vector2i in o.cells:
			var rect := Rect2(SimTypes.sim_to_screen(Vector2(c.x, c.y + 1), level.height), Vector2(t, t))
			draw_rect(rect, Color(Palette.WARN_RED, 0.18))
			for k: int in range(1, 6):
				var f: float = float(k) / 6.0
				draw_line(rect.position + Vector2(t * f, 0.0), rect.position + Vector2(0.0, t * f), Color(Palette.WARN_RED, 0.45), 2.0)
				draw_line(rect.position + Vector2(t, t * f), rect.position + Vector2(t * f, t), Color(Palette.WARN_RED, 0.45), 2.0)
			draw_rect(rect.grow(-2.0), Palette.WARN_RED, false, 2.0)
