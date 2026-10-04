class_name EditorMapView
extends Control
## 编辑器中央地图视图：地形绘制、网格、单位标记、缩放平移、点击编辑。
## 详细设计：[docs/design/07-关卡编辑器.md](../../docs/design/07-关卡编辑器.md) 1.3 / 4.1
##
## 【边界】本控件**只发信号**，不直接改数据 —— 所有改动都交给 EditorSession。
## 这样"改了数据后要压撤销栈 / 要同步目标区 / 要刷新面板"这些副作用只有一处。
##
## 【坐标】与玩法侧同一套约定：瓦片 (i,j) 的**中心** = (i+0.5, j+0.5) 格。
## 本控件自己的画布坐标 = 格 × tile_px × zoom + pan。

const BattleMapScript := preload("res://src/core/map/battle_map.gd")

## 一次点击/拖拽落在某个格子上
signal tile_pressed(x: int, y: int, button: int)
signal tile_dragged(x: int, y: int)
signal drag_finished()

const TILE_PX := 40.0
const ZOOM_MIN := 0.25
## 缩放上限。6.0 而不是 4.0：7×7 这种小图在 4.0 时只能填满视口的 85%，
## 而"看全地图"的期望是小图**尽量放大**到好编辑（6.0 下能填到 ~96%）。
const ZOOM_MAX := 6.0
const ZOOM_STEP := 1.15
const TILE_EMPTY := BattleMapScript.TILE_EMPTY
const TILE_WALL := BattleMapScript.TILE_WALL
const TILE_GOAL := BattleMapScript.TILE_GOAL

const C_OUTSIDE := Color(0.035, 0.040, 0.055)
const C_FLOOR := Color(0.10, 0.11, 0.14)
const C_GRID := Color(0.20, 0.22, 0.28)
const C_BORDER := Color(0.45, 0.50, 0.60)
const C_WALL := Color(0.34, 0.36, 0.42)
const C_GOAL := Color(0.25, 0.62, 0.40, 0.55)
const C_GOAL_EDGE := Color(0.45, 0.95, 0.65)
const C_ALLY := Color(0.30, 0.70, 1.00)
const C_ENEMY := Color(1.00, 0.42, 0.38)

## 网格线与外框的**像素厚度**。它们一律**填充**着画（不描边）：
## 描边线会被小数偏移分摊到相邻像素而整条消失（见 `_draw` 里的说明）。
## 【为什么是固定像素而不是乘缩放】这样缩到很小时线也仍然连续可见。
const GRID_PX := 1.0
const BORDER_PX := 2.0

## EditorSession（只读它，改动通过信号交出去）
var session = null
## 画布偏移（像素），与 zoom 一起决定"格 → 屏幕"
var pan := Vector2.ZERO
var zoom := 1.0
var _dragging := false
var _panning := false
var _last_mouse := Vector2.ZERO
var _last_tile := Vector2i(-1, -1)
## 是否还等着"第一次真正拿到尺寸后自动看全"。
## 【为什么需要】装配时容器还没布局，`size` 是 0，此时 `fit_to_view()` 会直接返回；
## 之后再也没人调它，结果地图一直以 1:1（40px/格）挤在中间（截图里一眼可见）。
var _needs_auto_fit := true


func _ready() -> void:
	name = "MapView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# 跟随容器尺寸：地图视图要占满中间那一列
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)


func _on_resized() -> void:
	# 第一次真正拿到尺寸时自动看全一次；之后只保持居中，不干扰用户自己的缩放
	if session != null and _needs_auto_fit and size.x > 0.0 and size.y > 0.0:
		_needs_auto_fit = false
		fit_to_view()
	elif session != null and pan == Vector2.ZERO:
		center_map()


## 让整张地图居中并缩放到"看得全"
func fit_to_view() -> void:
	if session == null:
		return
	var w: int = int(session.call("map_width"))
	var h: int = int(session.call("map_height"))
	if w <= 0 or h <= 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var margin := 24.0
	var fit: float = minf((size.x - margin * 2.0) / (w * TILE_PX),
		(size.y - margin * 2.0) / (h * TILE_PX))
	zoom = clampf(fit, ZOOM_MIN, ZOOM_MAX)
	center_map()


## 只挪偏移，不改缩放
func center_map() -> void:
	if session == null:
		return
	var w: int = int(session.call("map_width"))
	var h: int = int(session.call("map_height"))
	var map_px := Vector2(w, h) * TILE_PX * zoom
	pan = (size - map_px) * 0.5
	queue_redraw()


# ---------------------------------------------------------------------------
# 坐标换算（与玩法侧同一套：格中心的偏移量）
# ---------------------------------------------------------------------------

func tile_to_screen(x: int, y: int) -> Vector2:
	return Vector2(x, y) * TILE_PX * zoom + pan


func screen_to_tile(p: Vector2) -> Vector2i:
	var local := (p - pan) / (TILE_PX * zoom)
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


func tile_size_px() -> float:
	return TILE_PX * zoom


## 屏幕矩形是否落在地图内（越界格不响应编辑）
func in_bounds(x: int, y: int) -> bool:
	if session == null:
		return false
	return x >= 0 and y >= 0 \
		and x < int(session.call("map_width")) and y < int(session.call("map_height"))


# ---------------------------------------------------------------------------
# 输入：左键编辑、中键平移、滚轮缩放
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_last_mouse = mb.position
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			var t := screen_to_tile(mb.position)
			if mb.pressed:
				_dragging = true
				_last_tile = t
				tile_pressed.emit(t.x, t.y, mb.button_index)
			else:
				_dragging = false
				drag_finished.emit()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			pan += mm.position - _last_mouse
			_last_mouse = mm.position
			queue_redraw()
			accept_event()
		elif _dragging:
			# 拖拽刷多格：同一格重复经过不重复发信号
			var t2 := screen_to_tile(mm.position)
			if t2 != _last_tile:
				_last_tile = t2
				tile_dragged.emit(t2.x, t2.y)
			accept_event()


## 以鼠标位置为锚点缩放（滚轮缩放时鼠标下的格子不动）
func _zoom_at(anchor: Vector2, factor: float) -> void:
	var before := (anchor - pan) / zoom
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	pan = anchor - before * zoom
	queue_redraw()


# ---------------------------------------------------------------------------
# 绘制
# ---------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_OUTSIDE)
	if session == null:
		return
	var w: int = int(session.call("map_width"))
	var h: int = int(session.call("map_height"))
	var cell := tile_size_px()

	# 地板 + 网格
	#
	# 【网格线用填充矩形，不用 1px 描边】描边 1px + 相机/缩放的小数偏移时，
	# 线会被分摊到相邻两像素而**整条看不见**（同一个坑在战斗渲染里也踩过，
	# 用户报成"偶尔有边界线看不到"）。填充矩形保证每个像素被完整覆盖。
	var line := GRID_PX
	for y in h:
		for x in w:
			var r := Rect2(tile_to_screen(x, y), Vector2(cell, cell))
			draw_rect(r, C_FLOOR)
			# 只画右边与下边，避免相邻格重复描同一条线（重叠会显得深浅不一）
			draw_rect(Rect2(r.end.x - line, r.position.y, line, cell), C_GRID)
			draw_rect(Rect2(r.position.x, r.end.y - line, cell, line), C_GRID)

	# 地形
	for y in h:
		for x in w:
			var t: int = int(session.call("tile_at", x, y))
			if t == TILE_EMPTY:
				continue
			var r2 := Rect2(tile_to_screen(x, y), Vector2(cell, cell))
			if t == TILE_WALL:
				draw_rect(r2.grow(-1.0), C_WALL)
			elif t == TILE_GOAL:
				draw_rect(r2.grow(-1.0), C_GOAL)
				draw_rect(r2.grow(-1.0), C_GOAL_EDGE, false, 2.0)

	# 单位（画成实心方块 + 队伍色）
	var units: Array = session.get("level_data").get("units")
	for u in units:
		var pos: Array = (u as Dictionary).get("pos", [0, 0])
		var ux := int(pos[0])
		var uy := int(pos[1])
		if not in_bounds(ux, uy):
			continue
		var center := tile_to_screen(ux, uy) + Vector2(cell, cell) * 0.5
		var half := cell * 0.36
		var col: Color = C_ALLY if str((u as Dictionary).get("team")) == "ally" else C_ENEMY
		draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), col)

	# 地图外框：同样用**填充**矩形画在**内侧**（描边会有一半落在贴图外，可能被裁掉）
	var full := Rect2(tile_to_screen(0, 0), Vector2(w, h) * cell)
	var bt := BORDER_PX
	draw_rect(Rect2(full.position.x, full.position.y, full.size.x, bt), C_BORDER)
	draw_rect(Rect2(full.position.x, full.end.y - bt, full.size.x, bt), C_BORDER)
	draw_rect(Rect2(full.position.x, full.position.y, bt, full.size.y), C_BORDER)
	draw_rect(Rect2(full.end.x - bt, full.position.y, bt, full.size.y), C_BORDER)

	# 鼠标悬停格高亮（越界不画）
	var mp := get_local_mouse_position()
	var ht := screen_to_tile(mp)
	if in_bounds(ht.x, ht.y):
		draw_rect(Rect2(tile_to_screen(ht.x, ht.y), Vector2(cell, cell)),
			Color(1, 1, 1, 0.18), false, 2.0)


func _process(_delta: float) -> void:
	# 悬停高亮要跟着鼠标走（不重绘就看不到）
	queue_redraw()


# ---------------------------------------------------------------------------
# 测试/断言用
# ---------------------------------------------------------------------------

func visible_tile_count() -> int:
	"""当前视口内可见的格子数（用来断言"地图能看全"）"""
	if session == null:
		return 0
	var w: int = int(session.call("map_width"))
	var h: int = int(session.call("map_height"))
	var n := 0
	var cell := tile_size_px()
	for y in h:
		for x in w:
			var r := Rect2(tile_to_screen(x, y), Vector2(cell, cell))
			if r.position.x >= -0.5 and r.position.y >= -0.5 \
				and r.position.x + cell <= size.x + 0.5 and r.position.y + cell <= size.y + 0.5:
				n += 1
	return n


func map_rect_on_screen() -> Rect2:
	if session == null:
		return Rect2()
	var w: int = int(session.call("map_width"))
	var h: int = int(session.call("map_height"))
	return Rect2(tile_to_screen(0, 0), Vector2(w, h) * tile_size_px())
