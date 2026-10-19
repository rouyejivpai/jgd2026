class_name LilyPetals
extends Control
## 2026-10-20 一级地图：彼岸花瓣粒子。细长、两头尖、向后卷的花瓣从右下往左上角飘散，边飘边摆、边翻面（宽度随翻转相位缩放），
## 每片花瓣后面垫一团同色的柔光，整体不亮、只是散发微光。飘出左 / 上边界后从右 / 下边界重新进来。
## 一级地图用两层：far（地图后面，小、暗、慢）与 near（地图上面，名牌之下）。不接收鼠标。

const PETAL_COLORS: Array[Color] = [Color("#B82C4E"), Color("#A3265C"), Color("#C43A52"), Color("#952050")]
const GLOW_COLOR: Color = Color("#B8306A")
const SEGMENTS: int = 9                    ## 花瓣中线分段数

@export var count: int = 24
@export var depth: float = 1.0             ## 1 = 近层；越小越远：更小、更暗、更慢
@export var flow: Vector2 = Vector2(-1.0, -0.62)   ## 飘散方向（左上）

var _petals: Array[Dictionary] = []
var _glow_tex: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(0.5, 0.0)
	_glow_tex.width = 64
	_glow_tex.height = 64
	resized.connect(_seed)
	_seed()


## 按当前尺寸撒满一屏（进场时画面里就已经有花瓣）
func _seed() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_petals.clear()
	for i: int in count:
		_petals.append(_spawn(Vector2(randf() * size.x, randf() * size.y)))


func _spawn(at: Vector2) -> Dictionary:
	var d: float = depth * randf_range(0.7, 1.15)
	return {
		"p": at,
		"speed": randf_range(26.0, 48.0) * d,
		"len": randf_range(32.0, 54.0) * d,
		"wid": randf_range(7.0, 11.0) * d,
		"curl": randf_range(0.35, 0.8) * (1.0 if randf() < 0.5 else -1.0),
		"rot": randf() * TAU,
		"spin": randf_range(-0.9, 0.9),
		"flip": randf() * TAU,
		"flip_speed": randf_range(1.2, 2.8),
		"sway": randf() * TAU,
		"sway_speed": randf_range(0.6, 1.3),
		"color": PETAL_COLORS[randi() % PETAL_COLORS.size()],
		"alpha": randf_range(0.5, 0.7) * lerpf(0.6, 1.0, clampf(depth, 0.0, 1.0)),
		"glow": randf_range(0.2, 0.3) * lerpf(0.6, 1.0, clampf(depth, 0.0, 1.0)),
	}


## 从右边或下边重新飘进来
func _respawn() -> Dictionary:
	var m: float = 40.0
	var along_right: bool = randf() < size.y / (size.x + size.y)
	var at: Vector2 = Vector2(size.x + m, randf() * size.y * 1.1) if along_right else Vector2(randf() * size.x * 1.1, size.y + m)
	return _spawn(at)


func _process(delta: float) -> void:
	if _petals.is_empty():
		return
	var dt: float = minf(delta, 1.0 / 20.0)
	var dir: Vector2 = flow.normalized()
	var side: Vector2 = dir.orthogonal()
	for i: int in _petals.size():
		var q: Dictionary = _petals[i]
		q["sway"] = float(q["sway"]) + float(q["sway_speed"]) * dt
		q["flip"] = float(q["flip"]) + float(q["flip_speed"]) * dt
		q["rot"] = float(q["rot"]) + float(q["spin"]) * dt
		var v: Vector2 = dir * float(q["speed"]) + side * sin(float(q["sway"])) * float(q["speed"]) * 0.45
		q["p"] = (q["p"] as Vector2) + v * dt
		var p: Vector2 = q["p"] as Vector2
		if p.x < -60.0 or p.y < -60.0:
			_petals[i] = _respawn()
	queue_redraw()


func _draw() -> void:
	for q: Dictionary in _petals:
		_draw_petal(q)


## 中线是一段弧（curl 控制弯曲），宽度两头尖、靠根部略宽；翻面时宽度按 |cos| 收窄，边缘略加波纹
func _draw_petal(q: Dictionary) -> void:
	var p: Vector2 = q["p"] as Vector2
	var length: float = float(q["len"])
	var flip: float = cos(float(q["flip"]))
	var w: float = float(q["wid"]) * maxf(absf(flip), 0.18)
	var col: Color = q["color"] as Color
	var g: float = float(q["glow"]) * (0.75 + 0.25 * absf(flip))
	var gs: float = length * 2.3
	draw_texture_rect(_glow_tex, Rect2(p - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(GLOW_COLOR, g))
	var rot: float = float(q["rot"])
	var curl: float = float(q["curl"]) * signf(flip + 0.0001)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for s: int in SEGMENTS + 1:
		var t: float = float(s) / float(SEGMENTS)
		var a: float = rot + curl * (t - 0.5) * 1.6
		var c: Vector2 = Vector2(cos(rot), sin(rot)) * (t - 0.5) * length + Vector2(-sin(rot), cos(rot)) * curl * length * 0.22 * (t * t - 0.25)
		var n: Vector2 = Vector2(-sin(a), cos(a))
		var half: float = w * 0.5 * pow(sin(PI * t), 0.75) * (1.0 + 0.25 * (1.0 - t)) * (1.0 + 0.12 * sin(t * 19.0))
		left.append(p + c + n * half)
		if s > 0 and s < SEGMENTS:                 # 两个尖端只放一次，避免重合点让三角剖分失败
			right.append(p + c - n * half)
	right.reverse()
	var poly: PackedVector2Array = left + right
	var shade: float = 0.75 + 0.25 * flip              # 翻到背面略暗
	draw_colored_polygon(poly, Color(col.r * shade, col.g * shade, col.b * shade, float(q["alpha"])))
