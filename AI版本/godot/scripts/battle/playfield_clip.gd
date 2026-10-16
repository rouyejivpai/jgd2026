extends Node2D
## MapLayer：以玩法矩形裁剪全部地面类子层（Ground、FloorHighlight、Grid、DeployZone、Beacon）。
## 本节点只画一张矩形作为遮罩（clip_children = 仅裁剪），自身不显示。坐标为局部（每格 TILE_SIZE）。

var level: LevelDefinition = null


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var t: float = float(SimTypes.TILE_SIZE)
	draw_rect(Rect2(0.0, 0.0, level.width * t, level.height * t), Color.WHITE)
