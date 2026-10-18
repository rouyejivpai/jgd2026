extends Node2D
## MapLayer：以玩法矩形裁剪全部地面类子层（Ground、FloorHighlight、Grid、DeployZone、Beacon）。
## 本节点只画一张矩形作为遮罩（clip_children = 仅裁剪），自身不显示。坐标为局部（每格 TILE_SIZE）。
## 2026-10-18：遮罩向外放宽 GlowLines 的最大越出长度，让格线越出玩法矩形后的淡出部分可见（输入判定仍按玩法矩形）。

var level: LevelDefinition = null


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var t: float = float(SimTypes.TILE_SIZE)
	var margin: float = GlowLines.OVERSHOOT_CELLS * 1.2 * t
	draw_rect(Rect2(0.0, 0.0, level.width * t, level.height * t).grow(margin), Color.WHITE)
