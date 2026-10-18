class_name GlowLines
extends RefCounted
## 发光格线（2026-10-18）：一组格子的边线画成「不透明芯线 + 柔和光晕」，格内不填色。
## 同一条直线上相连的边合并成一段；每段两端沿直线方向越出一小截并淡出到透明（长度按坐标确定性抖动），
## 让格线看起来像在完整底图上手绘出来的。构成实际格子的部分始终不透明，只有越出的部分渐隐。
## 坐标为 MapLayer 局部（每格 TILE_SIZE）。另提供特殊地块标志（draw_mark）。

const CORE_WIDTH: float = 2.4
## 光晕：[线宽, 相对不透明度]，由宽到窄叠画
const GLOW_PASSES: Array = [[14.0, 0.07], [7.0, 0.16]]
const OVERSHOOT_CELLS: float = 0.45
## 特殊地块标志：assets/sprites/tile_marks/<名>.png（白色剪影 + alpha，用 tools/slice_tile_marks.py 从 gpt-image 生成图切出），按类型着色半透明叠到格上
const MARK_DIR: String = "res://assets/sprites/tile_marks/%s.png"
const MARK_SIZE: float = 0.62            ## 标志边长（格）
const MARK_ALPHA: float = 0.55


## 画 cells（Vector2i → true 的集合）的全部格边。glow：光晕强度倍率；core：是否画不透明芯线；
## overshoot：越出长度（格）；core_width：芯线宽（本层单位）
static func draw_cells(ci: CanvasItem, cells: Dictionary, height: int, color: Color, glow: float = 1.0,
		core: bool = true, overshoot: float = OVERSHOOT_CELLS, core_width: float = CORE_WIDTH) -> void:
	var t: float = float(SimTypes.TILE_SIZE)
	for seg: Array in runs(cells):
		var a: Vector2 = SimTypes.sim_to_screen(seg[0] as Vector2, height)
		var b: Vector2 = SimTypes.sim_to_screen(seg[1] as Vector2, height)
		var ext_a: float = overshoot * t * _jitter(seg[0] as Vector2, 0)
		var ext_b: float = overshoot * t * _jitter(seg[1] as Vector2, 1)
		stroke(ci, a, b, color, glow, core, ext_a, ext_b, core_width)


## 一段发光线：a→b 不透明（芯线），两端各越出 ext_a / ext_b 并淡出
static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, glow: float = 1.0, core: bool = true,
		ext_a: float = 0.0, ext_b: float = 0.0, core_width: float = CORE_WIDTH) -> void:
	var dir: Vector2 = (b - a).normalized()
	var passes: Array = []
	if glow > 0.0:
		for p: Array in GLOW_PASSES:
			passes.append([float(p[0]), minf(float(p[1]) * glow, 1.0)])
	if core:
		passes.append([core_width, 1.0])
	for p: Array in passes:
		var w: float = float(p[0])
		var c := Color(color, color.a * float(p[1]))
		var clear := Color(c, 0.0)
		ci.draw_line(a, b, c, w, true)
		if ext_a > 0.0:
			ci.draw_polyline_colors(PackedVector2Array([a, a - dir * ext_a]), PackedColorArray([c, clear]), w, true)
		if ext_b > 0.0:
			ci.draw_polyline_colors(PackedVector2Array([b, b + dir * ext_b]), PackedColorArray([c, clear]), w, true)


## 格集合的边线，按直线合并成段：[[起点, 终点]]（模拟坐标，整数格点）
static func runs(cells: Dictionary) -> Array:
	var out: Array = []
	if cells.is_empty():
		return out
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for c: Vector2i in cells.keys():
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	for j: int in range(lo.y, hi.y + 2):          # 横线 y = j：格 (x, j-1) 与 (x, j) 之间
		var start: int = -1
		for x: int in range(lo.x, hi.x + 2):
			var on: bool = x <= hi.x and (cells.has(Vector2i(x, j - 1)) or cells.has(Vector2i(x, j)))
			if on and start < 0:
				start = x
			elif not on and start >= 0:
				out.append([Vector2(start, j), Vector2(x, j)])
				start = -1
	for i: int in range(lo.x, hi.x + 2):          # 竖线 x = i：格 (i-1, y) 与 (i, y) 之间
		var start: int = -1
		for y: int in range(lo.y, hi.y + 2):
			var on: bool = y <= hi.y and (cells.has(Vector2i(i - 1, y)) or cells.has(Vector2i(i, y)))
			if on and start < 0:
				start = y
			elif not on and start >= 0:
				out.append([Vector2(i, start), Vector2(i, y)])
				start = -1
	return out


## 标志贴图；缺失返回 null（调用方自行退回线条记号）
static func mark_texture(mark_name: String) -> Texture2D:
	return Art.texture(MARK_DIR % mark_name)


## 在 cell 中心画一个着色、半透明的标志
static func draw_mark(ci: CanvasItem, tex: Texture2D, cell: Vector2i, height: int, color: Color, alpha: float = MARK_ALPHA) -> void:
	var s: float = float(SimTypes.TILE_SIZE) * MARK_SIZE
	var c: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), height)
	ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(color, alpha))


static func cell_set(cells: Array) -> Dictionary:
	var d: Dictionary = {}
	for c: Vector2i in cells:
		d[c] = true
	return d


## 越出长度的确定性抖动（0.6–1.2 倍），同一端点每次相同
static func _jitter(p: Vector2, salt: int) -> float:
	var h: int = absi((int(p.x) * 73856093) ^ (int(p.y) * 19349663) ^ (salt * 83492791))
	return 0.6 + float(h % 1000) / 1000.0 * 0.6
