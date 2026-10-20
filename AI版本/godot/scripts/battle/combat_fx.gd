class_name CombatFx
extends RefCounted
## 2026-10-19 战斗打击感（用户：强化战斗的风味感和打击感）。只碰表现，不读写模拟数据；随机数只用于特效外观。
## · 远程：射弹（菱形 / 三角 / 锥形）沿随机弧线飞行 + 拖尾 + 沿途火花 + 出手闪光；命中时朝飞行的反方向崩裂成碎片，并带闪光、冲击环。
## · 近身：斩击（横斩 / 竖斩 / 斜斩随机）——斩痕是一段倾斜椭圆上的弧，正面宽亮、背面窄暗（伪 3D）；斩完化为粒子消散。
## · 受击：灰黑碎屑总是背离攻击者抛飞，落到战场上（交给 GroundFx）再渐隐。
## · 击败：大量碎屑 + 阵营色火花 + 冲击环（震屏、击飞、灰化消散由 BattleRoot / UnitView 负责）。
## 己方特效金色、敌方暗红。坐标 = 各玩法层局部坐标（每格 TILE_SIZE）。

enum Shape { DIAMOND, TRIANGLE, CONE }

const PROJECTILE_SPEED: float = 1500.0     ## 本层像素 / 秒
const PROJECTILE_MIN_TIME: float = 0.12
const PROJECTILE_MAX_TIME: float = 0.34
const ARC_BEND: Vector2 = Vector2(0.12, 0.34)  ## 射弹弧线：控制点沿法线偏出的距离（相对敌我距离）范围
const ARC_S_CHANCE: float = 0.25           ## 弹道为 S 形（两个控制点异侧）的概率
const TRAIL_LEN: float = 120.0
const BODY_SCALE: float = 1.8             ## 弹体放大倍数（战场常按 0.6 倍左右缩放显示）
const SLASH_SWEEP: float = 0.1             ## 秒：刀光扫过
const SLASH_FADE: float = 0.22             ## 秒：刀光收细、化为粒子
const SLASH_HIT_AT: float = 0.05           ## 秒：斩击的命中时刻（受击表现在此刻播放）
const DEBRIS_GRAVITY: float = 980.0
## 射弹贴图名 → 形状（visuals.projectile_shape 可覆盖："diamond" / "triangle" / "cone"）
const SHAPE_BY_PROJECTILE: Dictionary = {
	"bone_shard": Shape.DIAMOND, "lance_beam": Shape.CONE, "whisper_bolt": Shape.TRIANGLE,
	"bone_spit": Shape.TRIANGLE, "pollen_orb": Shape.DIAMOND,
}
const SHAPE_NAMES: Dictionary = { "diamond": Shape.DIAMOND, "triangle": Shape.TRIANGLE, "cone": Shape.CONE }

static var _mat_add: CanvasItemMaterial = null
static var _mat_mix: CanvasItemMaterial = null


## 阵营色：core = 白热芯，main = 主色，glow = 外晕（HDR，透过场景压暗并触发辉光）
## tint：2026-10-20 敌人技能色（visuals.skill_color，如骨花粉红、骨者暗火）；alpha = 0 时用阵营色
static func colors(ally: bool, tint: Color = Color(0, 0, 0, 0)) -> Dictionary:
	if tint.a > 0.0:
		return { "core": Color(tint.r * 1.4 + 0.7, tint.g * 1.4 + 0.7, tint.b * 1.4 + 0.7), "main": Color(tint.r * 1.05, tint.g * 1.05, tint.b * 1.05), "glow": Color(tint.r * 0.45, tint.g * 0.45, tint.b * 0.45) }
	if ally:
		return { "core": Color(2.3, 2.0, 1.4), "main": Color(1.85, 1.25, 0.42), "glow": Color(1.05, 0.6, 0.15) }
	return { "core": Color(2.1, 0.55, 0.45), "main": Color(1.05, 0.07, 0.1), "glow": Color(0.45, 0.0, 0.04) }


## 己方叠加发光；敌方正常混合（暗红在叠加下会被吃掉），都不受场景光照压暗
static func material(ally: bool) -> CanvasItemMaterial:
	if _mat_add == null:
		_mat_add = CanvasItemMaterial.new()
		_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_mat_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_mat_mix = CanvasItemMaterial.new()
		_mat_mix.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _mat_add if ally else _mat_mix


static func shape_for(def: UnitDefinition) -> int:
	if def == null:
		return Shape.DIAMOND
	var override: String = str(def.visuals.get("projectile_shape", ""))
	if SHAPE_NAMES.has(override):
		return int(SHAPE_NAMES[override])
	var proj: String = str(def.visuals.get("projectile", "")).get_file().get_basename()
	if SHAPE_BY_PROJECTILE.has(proj):
		return int(SHAPE_BY_PROJECTILE[proj])
	return absi((proj if proj != "" and proj != "none" else def.id).hash()) % 3      # 没配射弹的角色（如近战形态）远距离出手时也有固定形状


static func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, stops[0][1] as Color)
	g.set_offset(0, float(stops[0][0]))
	g.set_color(1, stops[stops.size() - 1][1] as Color)
	g.set_offset(1, float(stops[stops.size() - 1][0]))
	for i: int in range(1, stops.size() - 1):
		g.add_point(float(stops[i][0]), stops[i][1] as Color)
	return g


## 一次性 / 持续的火花发射器（世界坐标，粒子不随发射器移动）
static func sparks(ally: bool, amount: int, lifetime: float, dir: Vector2, spread: float, vel: Vector2, size_px: Vector2, one_shot: bool, tint: Color = Color(0, 0, 0, 0)) -> CPUParticles2D:
	var col: Dictionary = colors(ally, tint)
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.texture = StatusParticles.dot_texture()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.damping_min = vel.y * 1.2
	p.damping_max = vel.y * 2.0
	p.scale_amount_min = size_px.x / float(StatusParticles.TEX_SIZE)
	p.scale_amount_max = size_px.y / float(StatusParticles.TEX_SIZE)
	p.color_ramp = _ramp([[0.0, col["core"]], [0.25, col["main"]], [1.0, Color(col["glow"] as Color, 0.0)]])
	p.material = material(ally)
	p.emitting = true
	return p


## 节点在 seconds 后释放（粒子放完）
static func free_after(n: Node, seconds: float) -> void:
	var t: Tween = n.create_tween()
	t.tween_interval(seconds)
	t.tween_callback(n.queue_free)


# ---------------------------------------------------------------- 射弹 ----

## 射弹沿三次贝塞尔曲线飞行（2026-10-19 用户：不要直线，在空中划出随机弧线）：两个控制点在连线的 1/3、2/3 处
## 沿法线随机偏出（多数同侧 = 一道弧，少数异侧 = S 形），并略微上挑；拖尾沿曲线回溯采样，弹体朝向 = 曲线切线。
## bend_side：+1 / −1 指定弧线偏向哪一侧（齐射时交替，让几发弹道散开），0 = 随机。
class Projectile extends Node2D:
	var from: Vector2
	var to: Vector2
	var ally: bool = true
	var shape: int = CombatFx.Shape.DIAMOND
	var size: float = 1.0
	var bend_side: float = 0.0
	var tint: Color = Color(0, 0, 0, 0)        ## 技能色（敌人技能射弹），alpha = 0 = 阵营色
	var on_impact: Callable = Callable()
	var _t: float = 0.0
	var _dur: float = 0.2
	var _k: float = 0.0
	var _len: float = 1.0
	var _c1: Vector2
	var _c2: Vector2
	var _dir: Vector2 = Vector2.RIGHT
	var _done: bool = false
	var _col: Dictionary = {}
	var _trail_sparks: CPUParticles2D = null
	const TRAIL_SAMPLES: int = 14

	func _ready() -> void:
		_col = CombatFx.colors(ally, tint)
		material = CombatFx.material(ally)
		position = from
		var d: Vector2 = to - from
		var dist: float = maxf(d.length(), 1.0)
		var n: Vector2 = d.orthogonal() / dist
		var side: float = bend_side if bend_side != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		var b1: float = randf_range(CombatFx.ARC_BEND.x, CombatFx.ARC_BEND.y) * side
		var b2: float = randf_range(CombatFx.ARC_BEND.x, CombatFx.ARC_BEND.y) * side
		if randf() < CombatFx.ARC_S_CHANCE:
			b2 = -b2 * 0.7
		var lift := Vector2(0.0, -dist * randf_range(0.04, 0.14))
		_c1 = from + d * 0.33 + n * b1 * dist + lift
		_c2 = from + d * 0.66 + n * b2 * dist + lift
		_len = 0.0
		var prev: Vector2 = from
		for i: int in range(1, 13):
			var p: Vector2 = point(float(i) / 12.0)
			_len += prev.distance_to(p)
			prev = p
		_dur = clampf(_len / CombatFx.PROJECTILE_SPEED, CombatFx.PROJECTILE_MIN_TIME, CombatFx.PROJECTILE_MAX_TIME)
		_dir = tangent(0.0)
		_trail_sparks = CombatFx.sparks(ally, 44, 0.38, -_dir, 32.0, Vector2(30.0, 140.0), Vector2(3.0, 7.0) * sqrt(size), false, tint)
		_trail_sparks.gravity = Vector2(0.0, 60.0)
		add_child(_trail_sparks)
		get_parent().add_child.call_deferred(MuzzleFlash.make(from, _dir, ally, size))

	func point(u: float) -> Vector2:
		var v: float = 1.0 - u
		return from * (v * v * v) + _c1 * (3.0 * v * v * u) + _c2 * (3.0 * v * u * u) + to * (u * u * u)

	func tangent(u: float) -> Vector2:
		var v: float = 1.0 - u
		var t: Vector2 = (_c1 - from) * (3.0 * v * v) + (_c2 - _c1) * (6.0 * v * u) + (to - _c2) * (3.0 * u * u)
		return t.normalized() if t.length_squared() > 0.0001 else (to - from).normalized()

	func _process(delta: float) -> void:
		if _done:
			return
		_t += delta
		_k = minf(_t / _dur, 1.0)
		position = point(_k)
		_dir = tangent(_k)
		_trail_sparks.direction = -_dir
		queue_redraw()
		if _k >= 1.0:
			_impact()

	func _impact() -> void:
		_done = true
		queue_redraw()
		_trail_sparks.emitting = false
		get_parent().add_child(Shatter.make(to, _dir, ally, size, shape))
		if on_impact.is_valid():
			on_impact.call()
		CombatFx.free_after(self, 0.4)

	func _draw() -> void:
		if _done:
			return
		var pop: float = minf(_t / 0.05, 1.0)          # 出手瞬间从小放大
		var s: float = size * (0.5 + 0.5 * pop)
		# 拖尾：沿曲线回溯一段，向后渐细渐隐（外晕 + 主色 + 芯）
		var back: float = minf(_k, CombatFx.TRAIL_LEN * size / maxf(_len, 1.0))
		if back * _len > 2.0:
			var pts := PackedVector2Array()
			var nrm := PackedVector2Array()
			for i: int in TRAIL_SAMPLES:
				var u: float = _k - back * float(i) / float(TRAIL_SAMPLES - 1)      # i = 0 在弹头
				pts.append(point(u) - position)
				nrm.append(tangent(u).orthogonal())
			for layer: Array in [[15.0, _col["glow"], 0.5], [7.5, _col["main"], 0.9], [2.8, _col["core"], 1.0]]:
				var c: Color = layer[1] as Color
				for i: int in TRAIL_SAMPLES - 1:
					var f0: float = 1.0 - float(i) / float(TRAIL_SAMPLES - 1)
					var f1: float = 1.0 - float(i + 1) / float(TRAIL_SAMPLES - 1)
					var w0: float = float(layer[0]) * s * f0
					var w1: float = float(layer[0]) * s * f1
					var c0 := Color(c, float(layer[2]) * f0)
					var c1 := Color(c, float(layer[2]) * f1)
					var a0: Vector2 = pts[i] + nrm[i] * w0
					var b0: Vector2 = pts[i] - nrm[i] * w0
					var a1: Vector2 = pts[i + 1] + nrm[i + 1] * w1
					var b1: Vector2 = pts[i + 1] - nrm[i + 1] * w1
					draw_primitive(PackedVector2Array([a0, a1, b1]), PackedColorArray([c0, c1, c1]), PackedVector2Array())
					draw_primitive(PackedVector2Array([a0, b1, b0]), PackedColorArray([c0, c1, c0]), PackedVector2Array())
		draw_texture_rect(StatusParticles.dot_texture(), Rect2(Vector2(-44.0, -44.0) * s, Vector2(88.0, 88.0) * s), false, Color(_col["glow"] as Color, 0.8))
		# 弹体：沿曲线切线；菱形绕飞行轴自转（纵向缩放模拟）
		var spin: float = 1.0
		if shape == CombatFx.Shape.DIAMOND:
			spin = 0.45 + 0.55 * absf(cos(_t * 26.0))
		draw_set_transform(Vector2.ZERO, _dir.angle(), Vector2(s, s * spin) * CombatFx.BODY_SCALE)
		var body: PackedVector2Array = CombatFx.shape_points(shape)
		draw_colored_polygon(CombatFx.scaled(body, 1.55), Color(_col["glow"] as Color, 0.55))
		draw_colored_polygon(body, _col["main"] as Color)
		draw_colored_polygon(CombatFx.scaled(body, 0.5, Vector2(3.0, 0.0)), _col["core"] as Color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 弹体轮廓（指向 +x，约 30 px 长）
static func shape_points(shape: int) -> PackedVector2Array:
	match shape:
		Shape.TRIANGLE:
			return PackedVector2Array([Vector2(15.0, 0.0), Vector2(-9.0, 9.0), Vector2(-4.0, 0.0), Vector2(-9.0, -9.0)])
		Shape.CONE:
			var pts := PackedVector2Array([Vector2(18.0, 0.0)])
			for i: int in 9:
				var a: float = PI * 0.5 + PI * float(i) / 8.0
				pts.append(Vector2(-6.0, 0.0) + Vector2(cos(a), sin(a)) * 6.5)
			return pts
	return PackedVector2Array([Vector2(15.0, 0.0), Vector2(0.0, 6.5), Vector2(-11.0, 0.0), Vector2(0.0, -6.5)])


static func scaled(pts: PackedVector2Array, k: float, shift: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p * k + shift)
	return out


## 出手闪光：短促的星芒 + 小光环
class MuzzleFlash extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var ally: bool = true
	var size: float = 1.0
	var _t: float = 0.0
	const LIFE: float = 0.12

	static func make(at: Vector2, p_dir: Vector2, p_ally: bool, p_size: float) -> MuzzleFlash:
		var m := MuzzleFlash.new()
		m.position = at
		m.dir = p_dir
		m.ally = p_ally
		m.size = p_size
		return m

	func _ready() -> void:
		material = CombatFx.material(ally)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = _t / LIFE
		var col: Dictionary = CombatFx.colors(ally)
		var a: float = 1.0 - k
		draw_texture_rect(StatusParticles.dot_texture(), Rect2(Vector2(-36.0, -36.0) * size, Vector2(72.0, 72.0) * size), false, Color(col["glow"] as Color, a))
		CombatFx.glint(self, Vector2.ZERO, dir.angle(), (26.0 + 26.0 * k) * size, 5.0 * size * a, Color(col["core"] as Color, a))
		draw_arc(Vector2.ZERO, (10.0 + 24.0 * k) * size, 0.0, TAU, 24, Color(col["main"] as Color, 0.8 * a), 3.0 * size)


## 星芒：沿 angle 的长菱形 + 垂直方向的短菱形
static func glint(ci: CanvasItem, at: Vector2, angle: float, length: float, width: float, c: Color) -> void:
	for axis: Array in [[angle, 1.0], [angle + PI * 0.5, 0.45]]:
		var d := Vector2.from_angle(float(axis[0])) * length * float(axis[1])
		var n := Vector2.from_angle(float(axis[0])).orthogonal() * width
		ci.draw_colored_polygon(PackedVector2Array([at + d, at + n, at - d, at - n]), c)


## 命中崩裂：碎片朝飞行的反方向迸开（旋转、减速、缩小、渐隐）+ 闪光 + 冲击环 + 反向火花
class Shatter extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var ally: bool = true
	var size: float = 1.0
	var shape: int = CombatFx.Shape.DIAMOND
	var _t: float = 0.0
	var _shards: Array = []      ## [位置, 速度, 角度, 角速度, 长度, 寿命]
	var _col: Dictionary = {}
	const LIFE: float = 0.48

	static func make(at: Vector2, p_dir: Vector2, p_ally: bool, p_size: float, p_shape: int) -> Shatter:
		var s := Shatter.new()
		s.position = at
		s.dir = p_dir
		s.ally = p_ally
		s.size = p_size
		s.shape = p_shape
		return s

	func _ready() -> void:
		_col = CombatFx.colors(ally)
		material = CombatFx.material(ally)
		var back: float = (-dir).angle()
		for i: int in 11:
			var a: float = back + randf_range(-1.0, 1.0) * 0.95
			var v: Vector2 = Vector2.from_angle(a) * randf_range(150.0, 430.0) * size
			_shards.append([Vector2.ZERO, v, randf() * TAU, randf_range(-18.0, 18.0), randf_range(7.0, 15.0) * size, randf_range(0.26, LIFE)])
		var sp: CPUParticles2D = CombatFx.sparks(ally, 34, 0.45, -dir, 55.0, Vector2(110.0, 380.0), Vector2(3.0, 7.0), true)
		sp.gravity = Vector2(0.0, 240.0)
		add_child(sp)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		for s: Array in _shards:
			var v: Vector2 = s[1] as Vector2
			s[0] = (s[0] as Vector2) + v * delta
			s[1] = v * exp(-6.0 * delta) + Vector2(0.0, 300.0 * delta)
			s[2] = float(s[2]) + float(s[3]) * delta
		queue_redraw()

	func _draw() -> void:
		var k: float = _t / LIFE
		# 闪光与冲击环（前 40%）
		var fk: float = clampf(_t / 0.16, 0.0, 1.0)
		if fk < 1.0:
			var a: float = 1.0 - fk
			draw_texture_rect(StatusParticles.dot_texture(), Rect2(Vector2(-64.0, -64.0) * size, Vector2(128.0, 128.0) * size), false, Color(_col["glow"] as Color, 0.9 * a))
			CombatFx.glint(self, Vector2.ZERO, dir.angle() + PI * 0.5, (28.0 + 40.0 * fk) * size, 6.0 * size * a, Color(_col["core"] as Color, a))
		var rk: float = clampf(_t / 0.22, 0.0, 1.0)
		if rk < 1.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
			draw_arc(Vector2.ZERO, (14.0 + 56.0 * rk) * size, 0.0, TAU, 32, Color(_col["main"] as Color, 0.9 * (1.0 - rk)), (6.0 - 4.0 * rk) * size)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for s: Array in _shards:
			var life: float = float(s[5])
			if _t >= life:
				continue
			var lk: float = _t / life
			var p: Vector2 = s[0] as Vector2
			var ang: float = float(s[2])
			var l: float = float(s[4]) * (1.0 - lk * 0.6)
			var d := Vector2.from_angle(ang) * l
			var nn := Vector2.from_angle(ang).orthogonal() * l * 0.32
			var c: Color = (_col["main"] as Color).lerp(_col["glow"] as Color, lk)
			draw_colored_polygon(PackedVector2Array([p + d, p + nn, p - d * 0.6]), Color(c, 1.0 - lk * lk))
			draw_colored_polygon(PackedVector2Array([p + d * 0.6, p + nn * 0.4, p - d * 0.2]), Color(_col["core"] as Color, (1.0 - lk) * 0.9))


# ---------------------------------------------------------------- 斩击 ----

## 斩击：倾斜椭圆（伪 3D 圆环在屏幕上的投影）上的一段弧。参数角 θ 处 sinθ > 0 为朝向镜头的前半圈（宽、亮），
## 背面半圈窄、暗。刀头沿弧急速扫过（0.1 s，五次缓出），刀尾随后追上，形成针尖刀头、白热刃口的月牙形刀光，
## 刀头后方跟几道发丝般的刀风细线；命中瞬间沿切线闪出一道笔直的细切痕。扫完后刀光先收成一线再变淡，沿弧化为粒子消散。
class Slash extends Node2D:
	var ally: bool = true
	var radius: float = 70.0
	var _rot: float = 0.0
	var _squash: float = 0.32
	var _a0: float = 0.0
	var _a1: float = PI
	var _t: float = 0.0
	var _col: Dictionary = {}
	var _dissolved: bool = false
	var _flashed: bool = false
	var _flash_at: Vector2 = Vector2.ZERO
	var _flash_t: float = -1.0
	var _flash_dir: Vector2 = Vector2.RIGHT
	const SAMPLES: int = 34
	const WIDTH: float = 22.0
	const BLADE_PROFILE_MAX: float = 0.5112      ## u^1.6·(1-u)^0.22 的最大值（u ≈ 0.88），宽度归一化用

	## kind：0 横斩，1 竖斩，2 斜斩；-1 随机。toward：攻击者 → 目标方向（决定横斩的挥向）
	static func make(center: Vector2, p_ally: bool, size: float, toward: Vector2, kind: int = -1) -> Slash:
		var s := Slash.new()
		s.position = center
		s.ally = p_ally
		s.radius = 70.0 * size * randf_range(0.92, 1.1)
		var k: int = kind if kind >= 0 else randi() % 3
		var lr: float = 1.0 if toward.x >= 0.0 else -1.0
		var span: float = randf_range(1.7, 2.0)
		match k:
			0:   # 横斩：扁椭圆，从攻击者一侧扫向另一侧，经过前半圈
				s._rot = randf_range(-0.18, 0.18)
				s._squash = randf_range(0.26, 0.34)
				s._a0 = PI * 0.5 + span * lr
				s._a1 = PI * 0.5 - span * lr
			1:   # 竖斩：竖立椭圆，自上而下
				s._rot = PI * 0.5 + randf_range(-0.2, 0.2) * lr
				s._squash = randf_range(0.3, 0.4)
				s._a0 = PI + 0.4
				s._a1 = -0.4
			_:   # 斜斩：±40° 左右的倾斜面
				s._rot = randf_range(0.55, 0.85) * (1.0 if randf() < 0.5 else -1.0)
				s._squash = randf_range(0.34, 0.44)
				var sgn: float = 1.0 if randf() < 0.5 else -1.0
				s._a0 = PI * 0.5 + span * sgn
				s._a1 = PI * 0.5 - span * sgn
		return s

	func _ready() -> void:
		_col = CombatFx.colors(ally)
		material = CombatFx.material(ally)

	func point(theta: float, rk: float = 1.0) -> Vector2:
		return Vector2(cos(theta) * radius * rk, sin(theta) * radius * rk * _squash).rotated(_rot)

	func _process(delta: float) -> void:
		_t += delta
		if not _flashed and _t >= CombatFx.SLASH_HIT_AT:
			_flashed = true
			_impact_flash()
		if not _dissolved and _t >= CombatFx.SLASH_SWEEP:
			_dissolved = true
			_dissolve()
		if _t >= CombatFx.SLASH_SWEEP + CombatFx.SLASH_FADE:
			set_process(false)
			CombatFx.free_after(self, 0.7)
		queue_redraw()

	## 刀头 / 刀尾的参数角：刀头急出（五次缓出），刀尾随后快速追上，刀光收成一线
	func _span() -> Vector2:
		var sweep: float = clampf(_t / CombatFx.SLASH_SWEEP, 0.0, 1.0)
		var head_k: float = 1.0 - pow(1.0 - sweep, 5.0)
		var tail_k: float = pow(clampf((_t - 0.02) / (CombatFx.SLASH_SWEEP + 0.06), 0.0, 1.0), 2.2) * 0.45
		if _t > CombatFx.SLASH_SWEEP:
			var fk: float = clampf((_t - CombatFx.SLASH_SWEEP) / CombatFx.SLASH_FADE, 0.0, 1.0)
			tail_k = lerpf(tail_k, head_k * 0.995, pow(fk, 0.8))
		return Vector2(lerpf(_a0, _a1, tail_k), lerpf(_a0, _a1, head_k))

	## 命中瞬间：沿弧在最靠镜头处的切线方向闪出一道笔直的细切痕 + 细星芒 + 顺挥向的火花
	func _impact_flash() -> void:
		var sp_ab: Vector2 = _span()
		var th: float = lerpf(sp_ab.x, sp_ab.y, 0.85)
		_flash_at = point(th)
		_flash_t = _t
		_flash_dir = (point(th + 0.05 * signf(_a1 - _a0)) - point(th)).normalized()
		var sp: CPUParticles2D = CombatFx.sparks(ally, 26, 0.32, _flash_dir, 22.0, Vector2(220.0, 620.0), Vector2(2.0, 4.5), true)
		sp.position = _flash_at
		sp.gravity = Vector2(0.0, 180.0)
		add_child(sp)

	## 化为粒子：沿当前可见的整段刀光（定向点发射），顺挥向、略向外飘散并缓缓上浮
	func _dissolve() -> void:
		var sp_ab: Vector2 = _span()
		var p := CPUParticles2D.new()
		p.local_coords = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
		var pts := PackedVector2Array()
		var nrm := PackedVector2Array()
		var sgn: float = signf(_a1 - _a0)
		for i: int in SAMPLES:
			var th: float = lerpf(sp_ab.x, sp_ab.y, float(i) / float(SAMPLES - 1))
			var at: Vector2 = point(th)
			var tang: Vector2 = (point(th + 0.05 * sgn) - at).normalized()
			var out: Vector2 = tang.orthogonal()
			if out.dot(at) < 0.0:
				out = -out
			pts.append(at)
			nrm.append((tang * 0.75 + out * 0.25).normalized())
		p.emission_points = pts
		p.emission_normals = nrm
		p.amount = 90
		p.lifetime = 0.6
		p.one_shot = true
		p.explosiveness = 0.85
		p.spread = 18.0
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 190.0
		p.damping_min = 140.0
		p.damping_max = 260.0
		p.gravity = Vector2(0.0, -50.0)
		p.texture = StatusParticles.dot_texture()
		p.scale_amount_min = 1.8 / float(StatusParticles.TEX_SIZE)
		p.scale_amount_max = 4.5 / float(StatusParticles.TEX_SIZE)
		p.color_ramp = CombatFx._ramp([[0.0, _col["core"]], [0.3, _col["main"]], [1.0, Color(_col["glow"] as Color, 0.0)]])
		p.material = CombatFx.material(ally)
		p.emitting = true
		add_child(p)

	func _draw() -> void:
		if _t >= CombatFx.SLASH_SWEEP + CombatFx.SLASH_FADE:
			return
		var fk: float = clampf((_t - CombatFx.SLASH_SWEEP) / CombatFx.SLASH_FADE, 0.0, 1.0)
		var alpha: float = 1.0 - fk * fk                        # 先收细、后变淡
		var wk: float = 1.0 - pow(fk, 0.7) * 0.92
		var sp_ab: Vector2 = _span()
		var s: float = radius / 70.0
		if absf(sp_ab.y - sp_ab.x) > 0.02:
			_draw_blade(sp_ab.x, sp_ab.y, wk, alpha)
			# 刀风细线：刀头后方、与刀光同心的几道发丝弧
			for line: Array in [[1.13, 0.55, 0.7], [0.88, 0.62, 0.5], [1.24, 0.72, 0.35]]:
				var pts := PackedVector2Array()
				for i: int in 12:
					pts.append(point(lerpf(lerpf(sp_ab.x, sp_ab.y, float(line[1])), sp_ab.y, float(i) / 11.0), float(line[0])))
				draw_polyline(pts, Color(_col["main"] as Color, float(line[2]) * alpha), 1.4 * s, true)
			# 刀尖：沿切线的细长星芒
			if alpha > 0.3:
				var hp: Vector2 = point(sp_ab.y)
				var ht: Vector2 = (point(sp_ab.y + 0.02 * signf(_a1 - _a0)) - hp).normalized()
				CombatFx.glint(self, hp, ht.angle(), 20.0 * s, 2.2 * s, Color(_col["core"] as Color, alpha))
		if _flash_t >= 0.0:
			var k: float = clampf((_t - _flash_t) / 0.16, 0.0, 1.0)
			if k < 1.0:
				var a: float = 1.0 - k
				var grow: float = 1.0 - pow(1.0 - clampf(k / 0.3, 0.0, 1.0), 3.0)
				var half: Vector2 = _flash_dir * radius * (0.6 + 0.6 * grow)
				# 切痕：外晕 + 白热发丝，越来越细
				draw_line(_flash_at - half, _flash_at + half, Color(_col["glow"] as Color, 0.4 * a), 9.0 * s * a, true)
				draw_line(_flash_at - half, _flash_at + half, Color(_col["main"] as Color, a), 3.5 * s * a, true)
				draw_line(_flash_at - half * 0.85, _flash_at + half * 0.85, Color(_col["core"] as Color, a), 1.6 * s * a + 0.4, true)
				draw_texture_rect(StatusParticles.dot_texture(), Rect2(_flash_at - Vector2(34.0, 34.0) * s, Vector2(68.0, 68.0) * s), false, Color(_col["glow"] as Color, 0.6 * a))
				CombatFx.glint(self, _flash_at, _flash_dir.angle() + PI * 0.5, (14.0 + 22.0 * k) * s, 2.0 * s * a, Color(_col["core"] as Color, a))

	## 刀光：tail→head 的月牙刃。宽度在靠近刀头处最大（≈88%），刀头是针尖、刀尾细长渐隐；
	## 外缘是锐利的刃口（白热发丝描边），内缘薄；背面半圈窄而暗（伪 3D）。wk = 宽度倍数，alpha = 整体不透明度
	func _draw_blade(tail: float, head: float, wk: float, alpha: float) -> void:
		var outer_g := PackedVector2Array()
		var inner_g := PackedVector2Array()
		var outer_m := PackedVector2Array()
		var inner_m := PackedVector2Array()
		var outer_c := PackedVector2Array()
		var inner_c := PackedVector2Array()
		var edge := PackedVector2Array()
		var edge_cols := PackedColorArray()
		var alphas := PackedFloat32Array()
		var core: Color = _col["core"] as Color
		for i: int in SAMPLES:
			var u: float = float(i) / float(SAMPLES - 1)                         # 0 = 刀尾，1 = 刀头
			var th: float = lerpf(tail, head, u)
			var p: Vector2 = point(th)
			var depth: float = 0.5 + 0.5 * sin(th)                               # 1 = 前半圈（朝镜头）
			var tang: Vector2 = point(th + 0.01) - point(th - 0.01)
			var nrm: Vector2 = tang.orthogonal().normalized()
			if nrm.dot(p) < 0.0:
				nrm = -nrm
			var prof: float = pow(u, 1.6) * pow(1.0 - u, 0.22) / BLADE_PROFILE_MAX
			var w: float = WIDTH * (radius / 70.0) * wk * prof * (0.25 + 0.75 * depth)
			outer_g.append(p + nrm * w * 1.5)
			inner_g.append(p - nrm * w * 0.6)
			outer_m.append(p + nrm * w)
			inner_m.append(p - nrm * w * 0.18)
			outer_c.append(p + nrm * w * 0.96)
			inner_c.append(p + nrm * w * 0.42)
			edge.append(p + nrm * w)
			var da: float = (0.3 + 0.7 * depth) * alpha
			alphas.append(da)
			edge_cols.append(Color(core, da * clampf(u * 3.0, 0.0, 1.0)))
		_strip(outer_g, inner_g, alphas, _col["glow"] as Color, 0.22)
		_strip(outer_m, inner_m, alphas, _col["main"] as Color, 1.0)
		_strip(outer_c, inner_c, alphas, core, 1.0)
		draw_polyline_colors(edge, edge_cols, 1.3 * radius / 70.0, true)

	func _strip(outer: PackedVector2Array, inner: PackedVector2Array, alphas: PackedFloat32Array, c: Color, a: float) -> void:
		for i: int in outer.size() - 1:
			var c0 := Color(c, alphas[i] * a)
			var c1 := Color(c, alphas[i + 1] * a)
			draw_primitive(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1]]), PackedColorArray([c0, c1, c1]), PackedVector2Array())
			draw_primitive(PackedVector2Array([outer[i], inner[i + 1], inner[i]]), PackedColorArray([c0, c1, c0]), PackedVector2Array())


# ---------------------------------------------------------------- 碎屑 ----

## 飞行中的灰黑碎屑（伪 3D：地面位置 + 离地高度），落地后交给 GroundFx 渐隐。总是灰黑色，不受场景光照。
class DebrisFlight extends Node2D:
	var ground: Node = null
	var _pieces: Array = []

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED     # 灰黑就是灰黑，不再被场景压暗成纯黑
		material = m     ## [地面位置, 地面速度, 高度, 竖直速度, 角度, 角速度, 轮廓, 颜色, 已弹跳]

	func add(feet: Vector2, height: float, dir: Vector2, count: int, power: float) -> void:
		var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.UP
		for i: int in count:
			var a: float = d.angle() + randf_range(-0.75, 0.75)
			var gv: Vector2 = Vector2.from_angle(a) * randf_range(70.0, 230.0) * power
			gv.y *= 0.55                                                     # 纵深方向（屏幕 y）透视压扁
			var r: float = randf_range(3.5, 8.0) * sqrt(power)
			var outline := PackedVector2Array()
			var n: int = 3 + randi() % 3
			for k: int in n:
				var aa: float = TAU * float(k) / float(n) + randf_range(-0.4, 0.4)
				outline.append(Vector2.from_angle(aa) * r * randf_range(0.55, 1.0))
			var v: float = randf_range(0.1, 0.42)
			var col := Color(v, v * 0.97, v * 1.02, 1.0)
			_pieces.append([feet + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0)), gv, height * randf_range(0.7, 1.15),
				randf_range(90.0, 300.0) * sqrt(power), randf() * TAU, randf_range(-14.0, 14.0), outline, col, false])

	func _process(delta: float) -> void:
		if _pieces.is_empty():
			return
		var keep: Array = []
		for p: Array in _pieces:
			p[0] = (p[0] as Vector2) + (p[1] as Vector2) * delta
			p[3] = float(p[3]) - CombatFx.DEBRIS_GRAVITY * delta
			p[2] = float(p[2]) + float(p[3]) * delta
			p[4] = float(p[4]) + float(p[5]) * delta
			if float(p[2]) <= 0.0:
				if not bool(p[8]) and float(p[3]) < -160.0:      # 落地弹一下
					p[8] = true
					p[2] = 0.0
					p[3] = -float(p[3]) * 0.28
					p[1] = (p[1] as Vector2) * 0.45
					p[5] = float(p[5]) * 0.5
				else:
					if ground != null and is_instance_valid(ground):
						ground.call("add_debris", p[0] as Vector2, p[6] as PackedVector2Array, float(p[4]), p[7] as Color)
					continue
			keep.append(p)
		_pieces = keep
		queue_redraw()

	func _draw() -> void:
		for p: Array in _pieces:
			var at: Vector2 = (p[0] as Vector2) - Vector2(0.0, float(p[2]))
			draw_set_transform(at, float(p[4]), Vector2.ONE)
			draw_colored_polygon(p[6] as PackedVector2Array, p[7] as Color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 击败爆散：阵营色火花环 + 冲击环 + 闪光（碎屑另由 DebrisFlight 加）
class DeathBurst extends Node2D:
	var ally: bool = true
	var size: float = 1.0
	var dir: Vector2 = Vector2.RIGHT
	var _t: float = 0.0
	var _col: Dictionary = {}
	const LIFE: float = 0.42

	static func make(at: Vector2, p_dir: Vector2, p_ally: bool, p_size: float) -> DeathBurst:
		var b := DeathBurst.new()
		b.position = at
		b.dir = p_dir
		b.ally = p_ally
		b.size = p_size
		return b

	func _ready() -> void:
		_col = CombatFx.colors(ally)
		material = CombatFx.material(ally)
		var ring: CPUParticles2D = CombatFx.sparks(ally, 46, 0.7, Vector2.UP, 180.0, Vector2(140.0, 420.0), Vector2(2.5, 6.0), true)
		ring.gravity = Vector2(0.0, 260.0)
		add_child(ring)
		var jet: CPUParticles2D = CombatFx.sparks(ally, 30, 0.55, dir, 30.0, Vector2(220.0, 560.0), Vector2(2.0, 5.0), true)
		jet.gravity = Vector2(0.0, 300.0)
		add_child(jet)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			set_process(false)
			queue_redraw()
			CombatFx.free_after(self, 0.8)
			return
		queue_redraw()

	func _draw() -> void:
		if _t >= LIFE:
			return
		var k: float = _t / LIFE
		var a: float = 1.0 - k
		draw_texture_rect(StatusParticles.dot_texture(), Rect2(Vector2(-70.0, -70.0) * size, Vector2(140.0, 140.0) * size), false, Color(_col["glow"] as Color, a))
		CombatFx.glint(self, Vector2.ZERO, 0.0, (40.0 + 50.0 * k) * size, 6.0 * size * a, Color(_col["core"] as Color, a))
		draw_set_transform(Vector2(0.0, 40.0 * size), 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, (16.0 + 90.0 * (1.0 - pow(1.0 - k, 2.0))) * size, 0.0, TAU, 48, Color(_col["main"] as Color, 0.9 * a), (7.0 - 5.0 * k) * size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- 光柱 ----

## 光柱：一道竖直光束落下 + 脚下扩散的光环 + 上浮光点。用于增援 / 召唤出场、部署落位、遗物生效（骨刃 / 徽章）。
## kind："spawn" 出场（光柱宽、持续稍长），"place" 部署落位（小而快），"strike" 骨刃（窄而亮、自上劈落），"heal" 徽章（光点多、上浮）
class Pillar extends Node2D:
	var ally: bool = true
	var size: float = 1.0
	var kind: String = "spawn"
	var _t: float = 0.0
	var _life: float = 0.6
	var _col: Dictionary = {}

	static func make(feet: Vector2, p_ally: bool, p_size: float, p_kind: String) -> Pillar:
		var p := Pillar.new()
		p.position = feet
		p.ally = p_ally
		p.size = p_size
		p.kind = p_kind
		return p

	func _ready() -> void:
		_col = CombatFx.colors(ally)
		material = CombatFx.material(ally)
		_life = { "spawn": 0.7, "place": 0.4, "strike": 0.35, "heal": 0.8 }.get(kind, 0.6)
		var n: int = { "spawn": 34, "place": 14, "strike": 26, "heal": 40 }.get(kind, 20)
		var motes: CPUParticles2D = CombatFx.sparks(ally, n, 0.9, Vector2.UP, 25.0, Vector2(40.0, 160.0) * size, Vector2(2.5, 6.0), true)
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = Vector2(26.0, 6.0) * size
		motes.gravity = Vector2(0.0, -60.0)
		motes.explosiveness = 0.5 if kind == "heal" else 0.85
		add_child(motes)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _life:
			set_process(false)
			queue_redraw()
			CombatFx.free_after(self, 1.0)
			return
		queue_redraw()

	func _draw() -> void:
		if _t >= _life:
			return
		var k: float = _t / _life
		var a: float = 1.0 - k
		var w: float = { "spawn": 30.0, "place": 18.0, "strike": 12.0, "heal": 24.0 }.get(kind, 24.0) * size
		var h: float = { "spawn": 260.0, "place": 120.0, "strike": 320.0, "heal": 150.0 }.get(kind, 200.0) * size
		# 光束：落下（前 20%）后收窄淡出；横向三层（外晕 / 主色 / 芯）
		var drop: float = clampf(k / 0.2, 0.0, 1.0)
		var top: float = -h
		var bottom: float = lerpf(-h, 0.0, 1.0 - pow(1.0 - drop, 3.0))
		var wk: float = (1.0 - k * 0.7)
		for layer: Array in [[2.2, _col["glow"], 0.35], [1.0, _col["main"], 0.75], [0.35, _col["core"], 1.0]]:
			var lw: float = w * float(layer[0]) * wk
			var c: Color = layer[1] as Color
			var c_top := Color(c, 0.0)
			var c_bot := Color(c, float(layer[2]) * a)
			draw_polygon(PackedVector2Array([Vector2(-lw * 0.5, top), Vector2(lw * 0.5, top), Vector2(lw * 0.5, bottom), Vector2(-lw * 0.5, bottom)]),
				PackedColorArray([c_top, c_top, c_bot, c_bot]))
		# 脚下光环与地面光斑
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		var rr: float = (14.0 + 46.0 * (1.0 - pow(1.0 - k, 2.0))) * size
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(_col["main"] as Color, a), 5.0 * a * size + 1.0)
		draw_texture_rect(StatusParticles.dot_texture(), Rect2(-Vector2(rr, rr) * 1.3, Vector2(rr, rr) * 2.6), false, Color(_col["glow"] as Color, 0.6 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if kind == "strike" and drop >= 1.0:
			CombatFx.glint(self, Vector2(0.0, -40.0 * size), 0.0, (40.0 + 40.0 * k) * size, 6.0 * size * a, Color(_col["core"] as Color, a))
