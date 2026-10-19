class_name BlastMarker
extends Node2D
## 延迟爆炸落点标记（01 §8 BlastMarker）：blast_marker.gdshader 绘制外环与随倒计时收缩的填充，上方倒计时数字（Cinzel）；
## 落点固定在放置时的位置（不追踪目标），只读 SimWorld.blasts 的剩余时间。
## 2026-10-19 战斗打击感：按施放者阵营着色（己方金色、敌方红色）。预警期光点从外环向中心汇聚、越临近越密；
## 到期爆炸：白热闪光 → 火球 → 两道冲击环 → 放射火花 + 上浮余烬 + 灰黑碎屑，震屏（BattleRoot），地面留下渐隐的焦痕。

const NUMBER_FONT: FontVariation = preload("res://assets/fonts/Cinzel-Bold.tres")
const BLAST_SECONDS: float = 0.55          ## 爆炸主体（闪光 / 火球 / 冲击环）
const SCORCH_SECONDS: float = 1.6          ## 焦痕渐隐
const FLASH_LIGHT_ENERGY: float = 2.2
const QUAD_MARGIN_PX: float = 24.0
const TICK_INTERVAL: float = 0.5
const TICK_INTERVAL_FAST: float = 0.2
const ALLY_COLOR: Color = Color(1.0, 0.72, 0.26)
const ENEMY_COLOR: Color = Color(1.0, 0.12, 0.1)

var blast_id: int = 0
var world: SimWorld = null
var radius_px: float = 0.0
var delay: float = 1.0
var ally: bool = false
var _remaining: float = 0.0
var _boom_t: float = -1.0                  ## 爆炸后经过的时间（< 0 = 预警中）
var _quad: ColorRect
var _mat: ShaderMaterial
var _light: PointLight2D
var _charge: CPUParticles2D
var _next_tick: float = 0.0       ## 下一次预警滴答的剩余时间阈值
var _col: Dictionary = {}


func setup(p_world: SimWorld, p_blast_id: int, screen_pos: Vector2, radius_cells: float, p_delay: float, p_ally: bool = false) -> void:
	world = p_world
	blast_id = p_blast_id
	ally = p_ally
	_col = CombatFx.colors(ally)
	material = CombatFx.material(ally)
	position = screen_pos
	radius_px = radius_cells * float(SimTypes.TILE_SIZE)
	delay = maxf(p_delay, SimTypes.TIME_EPS)
	_remaining = p_delay
	_next_tick = p_delay - TICK_INTERVAL
	var half: float = radius_px * 1.1 + QUAD_MARGIN_PX
	_quad = ColorRect.new()
	_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad.size = Vector2(half, half) * 2.0
	_quad.position = -Vector2(half, half)
	_mat = Art.material("blast_marker")
	_mat.set_shader_parameter("radius_px", radius_px)
	_mat.set_shader_parameter("quad_px", half)
	_mat.set_shader_parameter("color", ALLY_COLOR if ally else ENEMY_COLOR)
	_mat.set_shader_parameter("energy", 1.7 if ally else 1.5)
	_mat.set_shader_parameter("spin_dir", 1.0 if ally else -1.0)
	_quad.material = _mat
	_quad.show_behind_parent = true
	add_child(_quad)
	# 汇聚光点：从外环发射、径向向内加速
	_charge = CombatFx.sparks(ally, 28, 0.9, Vector2.RIGHT, 180.0, Vector2(0.0, 6.0), Vector2(2.5, 5.5), false)
	_charge.local_coords = true
	_charge.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_charge.emission_sphere_radius = radius_px
	_charge.radial_accel_min = -radius_px * 2.4
	_charge.radial_accel_max = -radius_px * 1.6
	_charge.damping_min = 0.0
	_charge.damping_max = 0.0
	add_child(_charge)
	_light = PointLight2D.new()
	_light.texture = Art.light_texture()
	_light.texture_scale = radius_px * 2.6 / float(Art.LIGHT_TEXTURE_SIZE)
	_light.color = ALLY_COLOR if ally else ENEMY_COLOR
	_light.energy = 0.25
	add_child(_light)


## 到期：爆炸、留下焦痕后释放
func detonate() -> void:
	if _boom_t >= 0.0:
		return
	_boom_t = 0.0
	_quad.visible = false
	_charge.emitting = false
	var burst: CPUParticles2D = CombatFx.sparks(ally, 90, 0.75, Vector2.UP, 180.0, Vector2(radius_px * 1.6, radius_px * 4.2), Vector2(3.0, 8.0), true)
	burst.gravity = Vector2(0.0, 320.0)
	add_child(burst)
	var embers: CPUParticles2D = CombatFx.sparks(ally, 40, 1.4, Vector2.UP, 60.0, Vector2(30.0, 110.0), Vector2(2.5, 6.0), true)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = radius_px * 0.6
	embers.gravity = Vector2(0.0, -70.0)
	embers.explosiveness = 0.6
	add_child(embers)
	var fx: Node = get_parent()
	if fx != null and fx.has_method("spawn_debris"):
		for i: int in 3:
			var dir := Vector2.from_angle(randf() * TAU)
			fx.call("spawn_debris", position + dir * radius_px * 0.2, 18.0, dir, 6, 1.4)


func _process(delta: float) -> void:
	if _boom_t >= 0.0:
		_boom_t += delta
		_light.energy = FLASH_LIGHT_ENERGY * maxf(0.0, 1.0 - _boom_t / BLAST_SECONDS)
		if _boom_t >= BLAST_SECONDS + SCORCH_SECONDS:
			queue_free()
	else:
		var b: SimBlast = _find()
		if b == null:
			queue_free()      # 世界被重建（重置）等情况
			return
		_remaining = b.remaining
		if _remaining <= _next_tick:   # 预警滴答：最后 1 秒加速
			AudioManager.play_sfx("blast_warn_tick")
			_next_tick -= TICK_INTERVAL_FAST if _remaining <= 1.0 else TICK_INTERVAL
		var t: float = clampf(_remaining / delay, 0.0, 1.0)
		_mat.set_shader_parameter("t", t)
		_charge.speed_scale = 0.8 + 1.4 * (1.0 - t)      # 越临近爆炸，光点汇聚越快
		_light.energy = 0.25 + 0.5 * (1.0 - t) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02))
	queue_redraw()


func _find() -> SimBlast:
	if world == null:
		return null
	for b: SimBlast in world.blasts:
		if b.id == blast_id:
			return b
	return null


func _draw() -> void:
	if _boom_t >= 0.0:
		_draw_boom()
		return
	var text: String = "%.1f" % maxf(_remaining, 0.0)
	var urg: float = 1.0 - clampf(_remaining / delay, 0.0, 1.0)
	var size: int = 30 + int(8.0 * urg)
	draw_string(NUMBER_FONT, Vector2(-60.0, -radius_px * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, size, (_col["core"] as Color).lerp(_col["main"] as Color, 0.4))


func _draw_boom() -> void:
	var dot: Texture2D = StatusParticles.dot_texture()
	var r: float = radius_px
	# 焦痕：灰黑圆斑（叠加材质下用很淡的主色描边，实际以爆炸后残留的辉光呈现）
	var sk: float = clampf((_boom_t - BLAST_SECONDS * 0.4) / SCORCH_SECONDS, 0.0, 1.0)
	if _boom_t > BLAST_SECONDS * 0.4:
		draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 64, Color(_col["glow"] as Color, 0.35 * (1.0 - sk)), 3.0, true)
		draw_texture_rect(dot, Rect2(-Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), false, Color(_col["glow"] as Color, 0.25 * (1.0 - sk)))
	if _boom_t >= BLAST_SECONDS:
		return
	var k: float = _boom_t / BLAST_SECONDS
	var out: float = 1.0 - pow(1.0 - k, 3.0)
	# 白热闪光（前 25%）
	var fk: float = clampf(_boom_t / (BLAST_SECONDS * 0.25), 0.0, 1.0)
	if fk < 1.0:
		draw_texture_rect(dot, Rect2(-Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(_col["glow"] as Color, 0.9 * (1.0 - fk)))
		draw_texture_rect(dot, Rect2(-Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), false, Color(_col["core"] as Color, 1.0 - fk))
		CombatFx.glint(self, Vector2.ZERO, 0.3, r * (1.2 + 0.8 * fk), r * 0.09 * (1.0 - fk), Color(_col["core"] as Color, 1.0 - fk))
	# 火球：先胀大后收缩变暗
	var fr: float = r * (0.35 + 0.75 * out) * (1.0 - 0.5 * k * k)
	draw_texture_rect(dot, Rect2(-Vector2(fr, fr) * 1.6, Vector2(fr, fr) * 3.2), false, Color(_col["glow"] as Color, 0.95 * (1.0 - k)))
	draw_circle(Vector2.ZERO, fr * 0.75, Color(_col["main"] as Color, 0.85 * (1.0 - k)))
	draw_circle(Vector2.ZERO, fr * 0.4, Color(_col["core"] as Color, 0.9 * (1.0 - k) * (1.0 - k)))
	# 两道冲击环
	for ring: Array in [[0.0, 1.35, 9.0], [0.12, 1.05, 4.0]]:
		var rk: float = clampf((k - float(ring[0])) / (1.0 - float(ring[0])), 0.0, 1.0)
		if rk <= 0.0 or rk >= 1.0:
			continue
		var rr: float = r * float(ring[1]) * (1.0 - pow(1.0 - rk, 2.5))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 72, Color(_col["main"] as Color, 0.95 * (1.0 - rk)), float(ring[2]) * (1.0 - rk * 0.7), true)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 72, Color(_col["glow"] as Color, 0.35 * (1.0 - rk)), float(ring[2]) * 3.0, true)
