extends Node2D
## 2026-10-19 地面特效层（地图之上、目标连线与单位之下，随镜头平移缩放）：
## · 脚印：单位移动时每落一步留下一个半透明发光圆（3/4 视角椭圆），己方金色、敌方红色，逐渐缩小直至消失；
## · 落地碎屑：受击 / 击败抛飞的灰黑碎屑（CombatFx.DebrisFlight）落地后停在这里，稍后渐隐。
## 脚印与碎屑分别画在两个子节点上，都不受场景光照压暗（脚印自发光，碎屑保持灰黑本色）。只碰表现。

const PRINT_LIFE: float = 1.25          ## 秒：脚印从出现到缩小消失
const PRINT_RADIUS: float = 10.0        ## 本层像素（再乘单位缩放）
const PRINT_SQUASH: float = 0.55
const PRINT_ALPHA: float = 0.55
const PRINT_MAX: int = 240
const DEBRIS_HOLD: Vector2 = Vector2(0.9, 1.6)    ## 秒：落地后静置多久开始渐隐（随机区间）
const DEBRIS_FADE: float = 0.8
const DEBRIS_MAX: int = 400
const ALLY_PRINT: Color = Color(2.0, 1.45, 0.5)
const ENEMY_PRINT: Color = Color(1.6, 0.12, 0.12)

var _prints: Array = []    ## [位置, 出现时刻, 是否己方, 缩放]
var _debris: Array = []    ## [位置, 轮廓, 角度, 颜色, 落地时刻, 静置时长]
var _print_node: Node2D = null
var _debris_node: Node2D = null
var _time: float = 0.0


func _ready() -> void:
	_debris_node = Node2D.new()
	_debris_node.name = "Debris"
	var dm := CanvasItemMaterial.new()
	dm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_debris_node.material = dm
	add_child(_debris_node)
	_debris_node.draw.connect(_draw_debris)
	_print_node = Node2D.new()
	_print_node.name = "Footprints"
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_print_node.material = m
	add_child(_print_node)
	_print_node.draw.connect(_draw_prints)


func add_footprint(pos: Vector2, ally: bool, size: float) -> void:
	if _prints.size() >= PRINT_MAX:
		_prints.pop_front()
	_prints.append([pos, _time, ally, size])


func add_debris(pos: Vector2, outline: PackedVector2Array, angle: float, color: Color) -> void:
	if _debris.size() >= DEBRIS_MAX:
		_debris.pop_front()
	_debris.append([pos, outline, angle, color, _time, randf_range(DEBRIS_HOLD.x, DEBRIS_HOLD.y)])


func clear() -> void:
	_prints.clear()
	_debris.clear()
	_print_node.queue_redraw()
	_debris_node.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not _prints.is_empty():
		while not _prints.is_empty() and _time - float(_prints[0][1]) >= PRINT_LIFE:
			_prints.pop_front()
		_print_node.queue_redraw()
	if not _debris.is_empty():
		var keep: Array = []
		for d: Array in _debris:
			if _time - float(d[4]) < float(d[5]) + DEBRIS_FADE:
				keep.append(d)
		_debris = keep
		_debris_node.queue_redraw()
	elif _debris_node != null:
		_debris_node.queue_redraw()


func _draw_prints() -> void:
	var dot: Texture2D = StatusParticles.dot_texture()
	for p: Array in _prints:
		var k: float = clampf((_time - float(p[1])) / PRINT_LIFE, 0.0, 1.0)
		var shrink: float = 1.0 - k * k                               # 先慢后快地缩小
		var a: float = PRINT_ALPHA * (1.0 - k * 0.6) * minf(1.0, (_time - float(p[1])) / 0.06 + 0.3)
		var r: float = PRINT_RADIUS * float(p[3]) * shrink
		if r <= 0.3:
			continue
		var c: Color = ALLY_PRINT if bool(p[2]) else ENEMY_PRINT
		var at: Vector2 = p[0] as Vector2
		_print_node.draw_set_transform(at, 0.0, Vector2(1.0, PRINT_SQUASH))
		_print_node.draw_texture_rect(dot, Rect2(Vector2(-r, -r) * 2.4, Vector2(r, r) * 4.8), false, Color(c, a * 0.45))
		_print_node.draw_circle(Vector2.ZERO, r, Color(c, a * 0.55))
		_print_node.draw_circle(Vector2.ZERO, r * 0.55, Color(c * 1.3, a * 0.8))
	_print_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_debris() -> void:
	for d: Array in _debris:
		var age: float = _time - float(d[4])
		var a: float = 1.0 - clampf((age - float(d[5])) / DEBRIS_FADE, 0.0, 1.0)
		_debris_node.draw_set_transform(d[0] as Vector2, float(d[2]), Vector2(1.0, 0.75))
		_debris_node.draw_colored_polygon(d[1] as PackedVector2Array, Color(d[3] as Color, a))
	_debris_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
