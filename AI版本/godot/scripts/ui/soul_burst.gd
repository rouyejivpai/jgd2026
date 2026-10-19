class_name SoulBurst
extends Control
## 灵魂储量（预算铭牌）被消耗时的数字演出（2026-10-20）：
## - 铭牌亮起并闪一下（亮 → 回落 → 再闪 → 熄）
## - 旧数字白热一瞬，随即按字形化作白色粒子向外炸开、上飘消散
## - 新数字叠在下面浮现（由小到原大、由白热回到原字色），旧数字炸开后就是新数字
## 粒子取自字体字形（TextServer.font_get_glyph_contours 展平后按非零环绕填充采样），炸开的形状就是那个数字。
## 演出期间原 Label 透明、文字由本节点按 Label 相同的居中排版自绘；结束时原样交还 Label（位置一致，无跳动）。
## 本节点不拦截鼠标，按 Label 的全局变换画。它挂在 host 下、紧跟 Label 所在的那个 host 子节点（HUD 的底栏）之后：
## Label 外层 ScrollText 的遮罩裁不到粒子，而排在底栏之后的侧栏（指令页面）、浮窗、剧情层照常盖住演出。
## （2026-10-20 前为 top_level，会画到所在画布的一切之上，盖过指令页面。）
## 参数在 data/ui_motion.json 的 "soul_burst"（时长、粒子数量 / 大小 / 速度、闪烁曲线、颜色）。

const QUAD_SEGMENTS: int = 4          ## 二次曲线展平段数
const MAX_STEP_S: float = 1.0 / 30.0  ## 单帧最多推进的演出时间：部署单位那一帧常卡顿，不封顶会把开头的白热与闪光整段跳过

var _label: Label = null
var _p: Dictionary = {}
var _t: float = 0.0
var _released: bool = false            ## 被下一次演出接管：不再画文字、不再改 Label，只把粒子放完
var _handed_off: bool = false          ## 已交还 Label

var _font: Font = null
var _font_size: int = 0
var _font_color: Color = Color.WHITE
var _shadow_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var _shadow_offset: Vector2 = Vector2.ZERO
var _old_text: String = ""
var _new_text: String = ""
var _old_range: Vector2i = Vector2i.ZERO     ## 旧数字在旧文字里的字符范围 [x, y)
var _new_range: Vector2i = Vector2i.ZERO
var _old_origin: Vector2 = Vector2.ZERO      ## 文字基线左端（Label 本地坐标）
var _new_origin: Vector2 = Vector2.ZERO
var _old_center: Vector2 = Vector2.ZERO      ## 旧 / 新数字的字形中心（Label 本地坐标）
var _new_center: Vector2 = Vector2.ZERO

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _spawned: bool = false
var _fx: Node2D = null                 ## 加色层：铭牌辉光 + 粒子


## 在 host 下开一场演出：label 的文字已从 old_text 换成 new_text，old_num / new_num 为其中的储量数字
static func play(host: Node, label: Label, old_text: String, new_text: String, old_num: String, new_num: String) -> SoulBurst:
	var b := SoulBurst.new()
	b._label = label
	b._old_text = old_text
	b._new_text = new_text
	var oi: int = maxi(old_text.find(old_num), 0)
	var ni: int = maxi(new_text.find(new_num), 0)
	b._old_range = Vector2i(oi, oi + old_num.length())
	b._new_range = Vector2i(ni, ni + new_num.length())
	host.add_child(b)
	var above: Node = label
	while above != null and above.get_parent() != host:
		above = above.get_parent()
	if above != null:
		host.move_child(b, above.get_index() + 1)
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p = UiKit.motion_params("soul_burst")
	_font = _label.get_theme_font("font")
	_font_size = _label.get_theme_font_size("font_size")
	_font_color = _label.get_theme_color("font_color")
	_shadow_color = _label.get_theme_color("font_shadow_color")
	_shadow_offset = Vector2(_label.get_theme_constant("shadow_offset_x"), _label.get_theme_constant("shadow_offset_y"))
	_old_origin = text_origin(_label, _old_text)
	_new_origin = text_origin(_label, _new_text)
	var old_pts: PackedVector2Array = glyph_points(_old_text, _font, _font_size, _old_range.x, _old_range.y, float(_p.get("particle_step_px", 1.25)))
	for i: int in old_pts.size():
		old_pts[i] += _old_origin
	_old_center = _centroid(old_pts, _old_origin + Vector2(_pen_x(_old_text, _old_range.x), -_font.get_ascent(_font_size) * 0.35))
	_new_center = _new_origin + _centroid(glyph_points(_new_text, _font, _font_size, _new_range.x, _new_range.y, 2.0),
		Vector2(_pen_x(_new_text, _new_range.x), -_font.get_ascent(_font_size) * 0.35))
	_pos = old_pts
	_label.self_modulate.a = 0.0
	_fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = mat
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


## 下一次演出开始：本场只把粒子放完（Label 交给新的一场）
func release() -> void:
	if not _spawned:                   # 旧数字还没炸开（同一帧连续扣费）：这个中间数字没人看见，直接作废
		queue_free()
		return
	_released = true
	_handed_off = true
	queue_redraw()


func _process(delta: float) -> void:
	delta = minf(delta, MAX_STEP_S)
	_t += delta
	if not _spawned and _t >= float(_p.get("hold_s", 0.07)):
		_spawn()
	if not is_instance_valid(_label):
		queue_free()
		return
	# 到点交还 Label；演出中文字又被改了（如收回单位退回 Cost）也立刻交还，免得画着过时的数字
	if not _handed_off and (_t >= float(_p.get("handoff_s", 0.62)) or _label.text != _new_text):
		_handed_off = true
		_label.self_modulate.a = 1.0
	if _spawned:
		var drag: float = exp(-float(_p.get("drag", 3.0)) * delta)
		var rise: Vector2 = Vector2(0.0, float(_p.get("rise_px_s2", -90.0)) * delta)
		for i: int in _pos.size():
			_vel[i] = _vel[i] * drag + rise
			_pos[i] += _vel[i] * delta
	if _handed_off and _spawned and _t >= float(_p.get("hold_s", 0.07)) + _max_life():
		queue_free()
		return
	queue_redraw()
	_fx.queue_redraw()


func _max_life() -> float:
	var r: Array = _p.get("particle_life_s", [0.45, 0.95]) as Array
	return float(r[1])


## 旧数字的采样点化作粒子：从数字中心向外（离中心越远越快）、带随机偏角，之后受阻尼并上飘
func _spawn() -> void:
	_spawned = true
	var rng := RandomNumberGenerator.new()
	var sp: Array = _p.get("speed_px_s", [50.0, 210.0]) as Array
	var lf: Array = _p.get("particle_life_s", [0.45, 0.95]) as Array
	var sz: Array = _p.get("particle_size_px", [1.6, 3.2]) as Array
	var spread: float = float(_p.get("spread_rad", 0.5))
	var reach: float = maxf(_font.get_ascent(_font_size) * 0.5, 1.0)
	var n: int = _pos.size()
	_vel.resize(n)
	_life.resize(n)
	_size.resize(n)
	for i: int in n:
		var off: Vector2 = _pos[i] - _old_center
		var dir: Vector2 = off.normalized() if off.length() > 0.5 else Vector2.from_angle(rng.randf() * TAU)
		dir = dir.rotated(rng.randf_range(-spread, spread))
		var k: float = clampf(off.length() / reach, 0.0, 1.0)
		_vel[i] = dir * lerpf(float(sp[0]), float(sp[1]), rng.randf()) * (0.55 + 0.75 * k)
		_life[i] = lerpf(float(lf[0]), float(lf[1]), rng.randf())
		_size[i] = lerpf(float(sz[0]), float(sz[1]), rng.randf())


## 闪烁包络（0..1）：关键帧 [[秒, 强度], …] 线性插值
func _flash() -> float:
	var keys: Array = _p.get("flash_keys", [[0.0, 0.0], [0.04, 1.0], [0.14, 0.35], [0.22, 0.85], [0.6, 0.0]]) as Array
	for i: int in range(1, keys.size()):
		var a: Array = keys[i - 1] as Array
		var b: Array = keys[i] as Array
		if _t <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), inverse_lerp(float(a[0]), float(b[0]), _t))
	return float((keys[keys.size() - 1] as Array)[1])


func _draw() -> void:
	if _handed_off or not is_instance_valid(_label):
		return
	draw_set_transform_matrix(_label_xf())
	var flash: float = _flash()
	var hot := Color(1.0, 1.0, 1.0)
	# 不变的部分（如「 / 8」）：随闪烁提亮
	var still: Color = _font_color.lerp(hot, flash * 0.7)
	_draw_piece(_new_text, 0, _new_range.x, _new_origin, still, 1.0)
	_draw_piece(_new_text, _new_range.y, _new_text.length(), _new_origin, still, 1.0)
	# 新数字：叠在下面，由小到原大浮现，由白热回到原字色
	var delay: float = float(_p.get("new_delay_s", 0.04))
	var u: float = clampf((_t - delay) / float(_p.get("new_in_s", 0.32)), 0.0, 1.0)
	if u > 0.0:
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		var s: float = lerpf(float(_p.get("new_scale_from", 0.82)), 1.0, e)
		var cool: float = clampf((_t - delay) / float(_p.get("new_hot_s", 0.5)), 0.0, 1.0)
		_draw_scaled(_new_text, _new_range, _new_origin, _new_center, s, hot.lerp(_font_color, cool), e)
	# 旧数字：白热一瞬、微微胀大，随即炸成粒子
	var hold: float = float(_p.get("hold_s", 0.07))
	if _t < hold:
		var h: float = _t / hold
		_draw_scaled(_old_text, _old_range, _old_origin, _old_center, lerpf(1.0, float(_p.get("old_scale", 1.12)), h), _font_color.lerp(hot, minf(h * 2.0, 1.0)), 1.0)


## Label 本地坐标 → 本节点本地坐标（_fx 与本节点同变换）
func _label_xf() -> Transform2D:
	return get_global_transform().affine_inverse() * _label.get_global_transform()


func _draw_scaled(text: String, r: Vector2i, origin: Vector2, center: Vector2, s: float, c: Color, alpha: float) -> void:
	var xf: Transform2D = _label_xf() * Transform2D(0.0, Vector2(s, s), 0.0, center - center * s)
	draw_set_transform_matrix(xf)
	_draw_piece(text, r.x, r.y, origin, c, alpha)
	draw_set_transform_matrix(_label_xf())


## 画 text 的 [from, to) 字符（按整串排版时的位置），带 Label 同款投影
func _draw_piece(text: String, from: int, to: int, origin: Vector2, c: Color, alpha: float) -> void:
	if to <= from:
		return
	var at: Vector2 = origin + Vector2(_pen_x(text, from), 0.0)
	var piece: String = text.substr(from, to - from)
	if _shadow_color.a > 0.0:
		draw_string(_font, at + _shadow_offset, piece, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, Color(_shadow_color, _shadow_color.a * alpha))
	draw_string(_font, at, piece, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, Color(c, c.a * alpha))


## 加色层：铭牌辉光（随闪烁包络）+ 白色粒子
func _draw_fx() -> void:
	if not is_instance_valid(_label):
		return
	_fx.draw_set_transform_matrix(_label_xf())
	var dot: Texture2D = StatusParticles.dot_texture()
	if not _released:
		var flash: float = _flash()
		if flash > 0.0:
			var gc: Color = Color(str(_p.get("glow_color", "#DCE6FF")))
			var gs: Array = _p.get("glow_scale", [1.3, 2.6]) as Array
			var plate: Vector2 = _label.size * Vector2(float(gs[0]), float(gs[1]))
			_fx.draw_texture_rect(dot, Rect2(_label.size * 0.5 - plate * 0.5, plate), false, Color(gc, 0.55 * flash))
			var core: Vector2 = Vector2(_font.get_ascent(_font_size) * 2.2, _font.get_ascent(_font_size) * 1.7)
			_fx.draw_texture_rect(dot, Rect2(_new_center - core * 0.5, core), false, Color(gc, 0.8 * flash))
	if not _spawned:
		return
	var pc: Color = Color(str(_p.get("particle_color", "#FFFFFF")))
	var age: float = _t - float(_p.get("hold_s", 0.07))
	for i: int in _pos.size():
		var k: float = age / _life[i]
		if k >= 1.0:
			continue
		var a: float = 1.0 - k * k
		var r: float = _size[i] * (1.0 - 0.6 * k)
		_fx.draw_texture_rect(dot, Rect2(_pos[i] - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(pc, 0.55 * a))
		_fx.draw_rect(Rect2(_pos[i] - Vector2(r, r) * 0.35, Vector2(r, r) * 0.7), Color(pc, a))


# ---- 排版与字形采样 ----

## Label（单行、垂直居中）里 text 的基线左端（Label 本地坐标），与 Label 自身的绘制位置一致
static func text_origin(label: Label, text: String) -> Vector2:
	var line := TextLine.new()
	line.add_string(text, label.get_theme_font("font"), label.get_theme_font_size("font_size"))
	var sz: Vector2 = line.get_size()
	var x: float = 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = float(int(label.size.x - sz.x) / 2)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = label.size.x - sz.x
	var y: float = 0.0
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y = float(int(label.size.y - sz.y) / 2)
		VERTICAL_ALIGNMENT_BOTTOM:
			y = label.size.y - sz.y
	return Vector2(x, y + line.get_line_ascent())


## text 整串排版时第 from 个字符起笔的横向位置（基线左端为 0）
func _pen_x(text: String, from: int) -> float:
	var line := TextLine.new()
	line.add_string(text, _font, _font_size)
	var ts: TextServer = TextServerManager.get_primary_interface()
	var pen: float = 0.0
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		if int(g["start"]) >= from:
			break
		pen += float(g["advance"]) * int(g["repeat"])
	return pen


## text 整串排版（基线左端为原点）后 [from, to) 字符的字形内部采样点：网格步长 step、带抖动，非零环绕判定在字形内
static func glyph_points(text: String, font: Font, font_size: int, from: int, to: int, step: float) -> PackedVector2Array:
	var line := TextLine.new()
	line.add_string(text, font, font_size)
	var ts: TextServer = TextServerManager.get_primary_interface()
	var rng := RandomNumberGenerator.new()
	var out := PackedVector2Array()
	var pen: float = 0.0
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		var start: int = int(g["start"])
		if start >= from and start < to and int(g["index"]) != 0:
			var at: Vector2 = Vector2(pen, 0.0) + (g["offset"] as Vector2)
			var polys: Array[PackedVector2Array] = _flatten(ts.font_get_glyph_contours(g["font_rid"] as RID, int(g["font_size"]), int(g["index"])))
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for poly: PackedVector2Array in polys:
				for v: Vector2 in poly:
					lo = lo.min(v)
					hi = hi.max(v)
			if lo.x < hi.x:
				var y: float = lo.y + step * 0.5
				while y < hi.y:
					var x: float = lo.x + step * 0.5
					while x < hi.x:
						var p := Vector2(x + rng.randf_range(-0.35, 0.35) * step, y + rng.randf_range(-0.35, 0.35) * step)
						if _winding(polys, p) != 0:
							out.append(at + p)
						x += step
					y += step
		pen += float(g["advance"]) * int(g["repeat"])
	return out


## 字形轮廓（TrueType 二次曲线：z = 1 在曲线上、0 为控制点；相邻两个控制点之间隐含中点）展平为多边形
static func _flatten(c: Dictionary) -> Array[PackedVector2Array]:
	var pts: PackedVector3Array = c.get("points", PackedVector3Array()) as PackedVector3Array
	var ends: PackedInt32Array = c.get("contours", PackedInt32Array()) as PackedInt32Array
	var polys: Array[PackedVector2Array] = []
	var begin: int = 0
	for e: int in ends:
		var n: int = e - begin + 1
		if n >= 3:
			var seq: Array[Vector3] = []          # z = 1 在曲线上
			for i: int in n:
				var a: Vector3 = pts[begin + i]
				var b: Vector3 = pts[begin + (i + 1) % n]
				var on_a: float = 0.0 if a.z == 0.0 else 1.0
				seq.append(Vector3(a.x, a.y, on_a))
				if a.z == 0.0 and b.z == 0.0:
					seq.append(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 1.0))
			var k: int = 0
			while k < seq.size() and seq[k].z == 0.0:
				k += 1
			var m: int = seq.size()
			var poly := PackedVector2Array()
			if k < m:
				var cur := Vector2(seq[k].x, seq[k].y)
				poly.append(cur)
				var i: int = 1
				while i <= m:
					var s: Vector3 = seq[(k + i) % m]
					if s.z != 0.0:
						cur = Vector2(s.x, s.y)
						poly.append(cur)
						i += 1
					else:
						var nx: Vector3 = seq[(k + i + 1) % m]
						var to := Vector2(nx.x, nx.y)
						for j: int in range(1, QUAD_SEGMENTS + 1):
							var t: float = float(j) / QUAD_SEGMENTS
							poly.append(cur.lerp(Vector2(s.x, s.y), t).lerp(Vector2(s.x, s.y).lerp(to, t), t))
						cur = to
						i += 2
			polys.append(poly)
		begin = e + 1
	return polys


## 非零环绕数（TrueType 填充规则）
static func _winding(polys: Array[PackedVector2Array], p: Vector2) -> int:
	var w: int = 0
	for poly: PackedVector2Array in polys:
		var n: int = poly.size()
		for i: int in n:
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % n]
			var cross: float = (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
			if a.y <= p.y:
				if b.y > p.y and cross > 0.0:
					w += 1
			elif b.y <= p.y and cross < 0.0:
				w -= 1
	return w


static func _centroid(pts: PackedVector2Array, fallback: Vector2) -> Vector2:
	if pts.is_empty():
		return fallback
	var sum := Vector2.ZERO
	for v: Vector2 in pts:
		sum += v
	return sum / pts.size()
