class_name BattleRenderer
extends Node2D
## 战场绘制：网格、墙、终点区、**信标**、放置提示、地图外暗底。
##
## ## 坐标约定（务必与逻辑层一致）
##
## **逻辑坐标 = 瓦片中心的格偏移量**：瓦片 (i,j) 的逻辑中心是 `(i+0.5, j+0.5)`。
## 于是 `BattleMap.tile_to_world(i, j) = (i+0.5, j+0.5) * TILE_PX` 就是瓦片中心，
## 墙的 64×64 碰撞形状也正是**以该点为中心** —— 两者天然对齐。
##
## **我第一版把瓦片画在以 `i*TILE_PX` 为中心的位置**（少减半格），于是
## 所有地形整体偏了半格；再叠加"单位画在左上角"的旧约定，
## 玩家看到的症状是「鼠标悬停高亮偏右偏下」—— 其实是**地形画错了**
## （用户实测反馈）。
##
## **所以本文件里所有几何一律以「格」为单位书写**，只在真正 `draw_*` 时乘
## `TILE_PX`，并且统一走 `tile_rect()` / `tile_centre()` 两个换算函数。
##
## ## 为什么必须有这个文件
## 用户实测反馈「成功放置信标也没有看到显示」—— 因为信标此前**只是数据**
## （`BattleMap._beacons` 字典），从头到尾没有任何绘制代码。
## 单位与墙各有 `Polygon2D`，唯独信标是隐形的。

const TILE_PX := 64.0
## 地块内缩（格）：让相邻地块之间留出缝，视觉上分得开
const INSET := 0.04
## 信标半径（格）
const BEACON_R := 0.22

const COLOR_BG := Color(0.10, 0.11, 0.14)
## 地图之外（不可点击）的底色：明显更暗，用来区分可玩区域
const COLOR_OUTSIDE := Color(0.035, 0.040, 0.055)
## 【0.07 → 0.10】原值太淡：配合"1px 被分摊"的问题会整条消失（见 `_draw_grid`）。
## 提一点余量，让它在最差的像素覆盖率下仍然可辨。
const COLOR_GRID := Color(1, 1, 1, 0.10)
const COLOR_BORDER := Color(0.45, 0.50, 0.62, 0.9)
const COLOR_WALL := Color(0.34, 0.36, 0.42)
const COLOR_WALL_EDGE := Color(0.52, 0.55, 0.62)
const COLOR_GOAL := Color(0.25, 0.62, 0.40, 0.55)
const COLOR_GOAL_EDGE := Color(0.45, 0.95, 0.65)
const COLOR_BEACON := Color(0.35, 0.80, 1.0)
const COLOR_BEACON_EDGE := Color(0.85, 0.96, 1.0)
const COLOR_HOVER_OK := Color(0.40, 1.0, 0.55, 0.30)
const COLOR_HOVER_BAD := Color(1.0, 0.40, 0.40, 0.30)
## 敌方视野圈：半透明描边（FR-TUT-04）
const COLOR_ENEMY_VISION := Color(1.0, 0.55, 0.42, 0.55)
## 我方（主角）单位的视野圈。
## 【为什么是绿色】语义上一眼可辨："绿=我方、橙红=敌方"。
## 与信标（实心青色圆）形状不同（这是空心圆弧），与目标区（实心方块）也不同，不会混。
const COLOR_ALLY_VISION := Color(0.55, 1.0, 0.70, 0.50)
## 外边框厚度（px）。见 `_draw_frame` 的说明：它必须**填充**着画，不能描边。
const BORDER_PX := 4.0

var battle_map = null
var beacon_layer = null
## 会话（用来取敌方单位与它们的有效视野半径）。为 null 时不画视野圈。
var session = null
## 「视野」辅助显示开关（FR-TUT-04），默认开。
## 【第 14 轮起他也画我方】原名叫「敌人视野」且只画敌方，
## 用户实测指出"主角单位的视野没有显示"后改成双方都画，开关随之改名「视野」。
var show_vision := true
## 鼠标悬停的格（信标模式下给放置反馈）
var hover_tile := Vector2i(-999, -999)
var hover_valid := false
var show_hover := false


func setup(p_map, p_beacon_layer) -> void:
	battle_map = p_map
	beacon_layer = p_beacon_layer
	queue_redraw()


func set_hover(tile: Vector2i, valid: bool, show: bool) -> void:
	hover_tile = tile
	hover_valid = valid
	show_hover = show
	queue_redraw()


## 信标或地图变化后重画
func refresh() -> void:
	queue_redraw()


func set_show_vision(on: bool) -> void:
	show_vision = on
	queue_redraw()


# ---------------------------------------------------------------------------
# 坐标换算（唯一的真相来源）
# ---------------------------------------------------------------------------

## 格 → 世界像素矩形。**所有地形绘制都必须经这里。**
## 与 `BattleMap.tile_to_world(i,j)`（瓦片中心）对齐：矩形 = 中心 ± 半格。
func tile_rect(i: int, j: int) -> Rect2:
	return Rect2(tile_centre(i, j) - Vector2(TILE_PX, TILE_PX) * 0.5,
		Vector2(TILE_PX, TILE_PX))


## 格中心 → 世界像素坐标（与 BattleMap.tile_to_world 同一约定）
func tile_centre(i: int, j: int) -> Vector2:
	return (Vector2(float(i), float(j)) + Vector2(0.5, 0.5)) * TILE_PX


func _draw() -> void:
	if battle_map == null:
		return
	# BattleMap 暴露的是 width / height 字段（没有 map_width() 方法）
	var w: int = int(battle_map.get("width"))
	var h: int = int(battle_map.get("height"))
	if w <= 0 or h <= 0:
		return

	_draw_outside(w, h)

	# 地图底板：让可玩区域一眼可见
	draw_rect(tile_rect(0, 0).merge(tile_rect(w - 1, h - 1)), COLOR_BG, true)

	# 逐格：墙 / 终点区
	for j in h:
		for i in w:
			var t: int = int(battle_map.tile_at(i, j))
			if t == 1:                                  # 墙
				var rw := tile_rect(i, j).grow(-INSET * TILE_PX)
				draw_rect(rw, COLOR_WALL, true)
				draw_rect(rw, COLOR_WALL_EDGE, false, 2.0)
			elif t == 2:                                # 终点区
				var rg := tile_rect(i, j).grow(-INSET * TILE_PX)
				draw_rect(rg, COLOR_GOAL, true)
				draw_rect(rg, COLOR_GOAL_EDGE, false, 3.0)

	_draw_grid(w, h)
	# 外边框：明确「哪块区域能点」
	_draw_frame(w, h)

	# 悬停格反馈（信标模式）
	if show_hover and hover_tile.x >= 0 and hover_tile.y >= 0:
		draw_rect(tile_rect(hover_tile.x, hover_tile.y),
			COLOR_HOVER_OK if hover_valid else COLOR_HOVER_BAD, true)

	# 视野圈（我方 + 敌方）：画在信标**下面**，免得挡住信标
	_draw_visions()

	_draw_beacons()


## 视野圈：**我方与敌方都画**（详设 10 的 4.6 + 用户实测反馈）
##
## 【口径必须与判定一致】半径直接取单位的 `effective_vision_radius()`
## ——它的定义是"`vision_radius` > 0 就用它，否则取射程"，与条件
## `enemy_in_vision` 的判定同源。**在这里另算一套就会画出假信息。**
##
## 【为什么我方也要画】原来这里写死了 `team != 1 → continue`，**只画敌方**。
## 但玩家要判断的恰恰是"我的人能看见谁"，看不到自己的视野就无从下手
## （用户实测："主角单位的视野没有显示"）。
##
## 【只描边不填充】填充会盖住地形，玩家看不清墙和目标区（详设 10 要求）。
## 【纯表现】不参与任何判定。
func _draw_visions() -> void:
	if not show_vision or session == null:
		return
	for u in (session.get("units") as Array):
		if u == null or bool(u.get("is_dead")):
			continue
		var team := int(u.get("team"))
		if team != 0 and team != 1:
			continue                                  # 中立单位没有视野概念
		var radius: float = float(u.call("effective_vision_radius"))
		if radius <= 0.0:
			continue                                  # 没有视野能力就不画
		var p: Vector2 = u.get("position_logic")
		var centre := p * TILE_PX                     # 逻辑坐标已是格中心
		draw_arc(centre, radius * TILE_PX, 0.0, TAU, 48,
			COLOR_ALLY_VISION if team == 0 else COLOR_ENEMY_VISION, 2.0, true)


## 【先铺一层屏幕大小的暗底】地图之外是**不可点击**的区域，但按 1:1 画时
## 屏幕上大部分地方看起来和地图一样"空"，玩家会去点，然后不断收到
## 「这里不能放信标」（用户实测反馈）。给外部一个明显的暗色底。
func _draw_outside(w: int, h: int) -> void:
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var zoom := 1.0
	if get_viewport() != null:
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			zoom = maxf(cam.zoom.x, 0.001)
	var view_world := Vector2(vw, vh) / zoom
	# 地图整体中心 = 首格中心与末格中心的中点 = (w, h) * TILE_PX * 0.5
	var centre := Vector2(float(w), float(h)) * TILE_PX * 0.5
	draw_rect(Rect2(centre - view_world, view_world * 2.0), COLOR_OUTSIDE, true)


## 网格线：按「格边界」画，与地块矩形完全对齐。
##
## 【线宽 2px 而不是 1px，且 alpha 提到 0.10】这是用户报的
## "偶尔会有边界线看不到"的根因：
## 1px 的线在**小数像素偏移**下会被分摊到相邻两个像素（各拿约一半覆盖率），
## 叠加本来就极低的 alpha（原来是 0.07）后，有效 alpha 掉到 ~0.035 → **整条看不见**；
## 而相机偏移一变（开合抽屉、缩放取整差异）可见性就翻转 —— 表现就是"偶尔"。
## **2px 的线无论落点如何，总有一个像素被完整覆盖**，因此永远不会消失。
func _draw_grid(w: int, h: int) -> void:
	var full := tile_rect(0, 0).merge(tile_rect(w - 1, h - 1))
	for i in range(w + 1):
		var x := full.position.x + float(i) * TILE_PX
		draw_line(Vector2(x, full.position.y), Vector2(x, full.end.y), COLOR_GRID, 2.0)
	for j in range(h + 1):
		var y := full.position.y + float(j) * TILE_PX
		draw_line(Vector2(full.position.x, y), Vector2(full.end.x, y), COLOR_GRID, 2.0)


## 外边框：**用 4 条填充矩形画在贴图内侧**，而不是去描边一个矩形。
##
## 【为什么不描边】`draw_rect(rect, color, false, 4.0)` 的描边是**以矩形边线为中心**
## 向外各扩一半的，于是有 2px 落在贴图**外面**；再叠加相机的小数偏移，
## 细线的像素覆盖率不足时会**整条消失** —— 这正是用户报的"边界线看不到"。
## 填充矩形贴在**内侧**：宽度固定、每个像素都被完整覆盖，画不出来是不可能的。
func _draw_frame(w: int, h: int) -> void:
	var full := tile_rect(0, 0).merge(tile_rect(w - 1, h - 1))
	var t := BORDER_PX
	draw_rect(Rect2(full.position.x, full.position.y, full.size.x, t), COLOR_BORDER, true)
	draw_rect(Rect2(full.position.x, full.end.y - t, full.size.x, t), COLOR_BORDER, true)
	draw_rect(Rect2(full.position.x, full.position.y, t, full.size.y), COLOR_BORDER, true)
	draw_rect(Rect2(full.end.x - t, full.position.y, t, full.size.y), COLOR_BORDER, true)


## 绘制信标：圆点 + 序号（序号就是规则里引用的编号，必须看得见）
func _draw_beacons() -> void:
	if beacon_layer == null:
		return
	var n: int = int(beacon_layer.call("count"))
	var font := ThemeDB.fallback_font
	for idx in range(1, n + 1):
		# 【注意 at() 是 1 起的】`BeaconLayer.at(index)` 直接吃「信标序号」，
		# 不是数组下标。我一开始传 `idx - 1`，于是信标 1 取不到（返回 null）、
		# 信标 2 画成了 1 号的位置 —— 全部错位一格。
		var tp = beacon_layer.call("at", idx)
		if tp == null:
			continue
		var tile: Vector2i = tp
		var centre := tile_centre(tile.x, tile.y)
		draw_circle(centre, BEACON_R * TILE_PX, COLOR_BEACON)
		draw_arc(centre, BEACON_R * TILE_PX, 0.0, TAU, 32, COLOR_BEACON_EDGE, 3.0, true)
		var label := str(idx)
		var fs := 30
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, centre + Vector2(-tw.x * 0.5, tw.y * 0.34), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.10, 0.16))
