class_name Playfield
extends RefCounted
## 玩法矩形（07 §1.2，程序与资源共用；tools/print_playfield_rects.py 为同一公式的 Python 版）：
## 战场可视区 y∈[上带, 视口高 - 下带]，玩法区最大 AREA_MAX（高不超过可视区），居中于该区域；
## cell_px = floor(min(area.x / W, area.y / H))，矩形 = 以中心为准的 W*cell_px × H*cell_px。
## 上下带 = 局内 HUD 布局 data/ui_layout/battle_hud.json 的 reserved（P6 按批准整图换皮，用户 2026-10-05 选择缩小战场区）；
## 没有该布局时退回第二阶段的 TOP_BAR / BOTTOM_BAR。
## 关卡 scene.playfield_rect 给出时按设计分辨率（1920×1080）使用该像素矩形，视口比例变化时随中心平移。

const DESIGN_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const TOP_BAR: float = 64.0                  ## 无 HUD 布局时的退路
const BOTTOM_BAR: float = 120.0
const AREA_MAX: Vector2 = Vector2(1600.0, 800.0)
const HUD_LAYOUT: String = "battle_hud"


## 局内 HUD 让出的上下带（设计像素）：Vector2(上, 下)
static func bands() -> Vector2:
	var r: Dictionary = UiKit.ui_layout(HUD_LAYOUT).get("reserved", {}) as Dictionary
	return Vector2(float(r.get("top", TOP_BAR)), float(r.get("bottom", BOTTOM_BAR)))


## 返回 { "rect": Rect2（视口像素）, "cell_px": int }
static func compute(level: LevelDefinition, viewport_size: Vector2 = DESIGN_SIZE) -> Dictionary:
	var b: Vector2 = bands()
	var center := Vector2(viewport_size.x * 0.5, b.x + (viewport_size.y - b.x - b.y) * 0.5)
	if level.has_playfield_rect:
		var r: Rect2i = level.playfield_rect
		var px: int = int(floor(minf(float(r.size.x) / float(level.width), float(r.size.y) / float(level.height))))
		var design_center := Vector2(DESIGN_SIZE.x * 0.5, b.x + (DESIGN_SIZE.y - b.x - b.y) * 0.5)
		var size := Vector2(level.width * px, level.height * px)
		var pos: Vector2 = Vector2(r.position) + (Vector2(r.size) - size) * 0.5 + (center - design_center)
		return { "rect": Rect2(pos.round(), size), "cell_px": px }
	var area := Vector2(AREA_MAX.x, minf(AREA_MAX.y, DESIGN_SIZE.y - b.x - b.y))
	var cell: int = int(floor(minf(area.x / float(level.width), area.y / float(level.height))))
	var sz := Vector2(level.width * cell, level.height * cell)
	return { "rect": Rect2((center - sz * 0.5).round(), sz), "cell_px": cell }
