class_name UnitAura
extends RefCounted
## 2026-10-19 阵营光效（用户：敌我都用 Q 版人物，靠光效区分）：
## 己方 = 脚底金色光圈 + 身后金色放射光芒 + 金色球形光点缓缓上浮；敌方 = 暗红光圈 + 身后暗红光芒 + 血滴迸溅与血色微光。
## 遮挡：光芒与粒子都在 UnitView 的 Aura 层（Base 之后、Body 之前），被人物本体遮住，只从轮廓四周透出；
## 人物本体只在轮廓外有一圈淡光（rim_glow，画在本体之后）。光圈由 UnitView._draw_base 画（脚底，最底层）。
## 只碰表现，不读写模拟数据。建筑不加光效（保留方框底座）。

const GOLD: Color = Color(1.0, 0.78, 0.32)
const GOLD_DEEP: Color = Color(1.0, 0.58, 0.16)
const BLOOD: Color = Color(0.62, 0.03, 0.07)
const BLOOD_DEEP: Color = Color(0.32, 0.0, 0.03)
const BLOOD_DROP_TEX: String = "vfx/blood_drop.png"

## 光芒尺寸（相对人物可见高度）与位置（人物可见区域中心）
const AURA_W_RATIO: float = 1.7
const AURA_H_RATIO: float = 1.45
const AURA_MIN_PX: float = 110.0

static var _quad: ImageTexture = null
static var _rects: Dictionary = {}


static func ring_color(ally: bool) -> Color:
	return GOLD if ally else BLOOD


## 人物在精灵画布上的可见区域（贴图像素），按贴图缓存；读不到图像时按 04 §2.1 的标准框
static func visible_rect(tex: Texture2D) -> Rect2i:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _rects.has(key):
		return _rects[key] as Rect2i
	var r := Rect2i(12, 12, 232, 220)
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			r = used
	_rects[key] = r
	return r


## 建光效层：parent = UnitView 的 Aura 节点；tex = 单位精灵；s = 精灵缩放；feet_offset = 精灵 offset.y（脚底在贴图 y = 尺寸/2 - offset）
static func build(parent: Node2D, ally: bool, tex: Texture2D, s: float, feet_offset: float, seed: float) -> void:
	var vis: Rect2i = visible_rect(tex)
	var half: float = float(tex.get_height()) * 0.5
	var top: float = (float(vis.position.y) - half + feet_offset) * s
	var h: float = float(vis.size.y) * s
	var w: float = float(vis.size.x) * s
	var center := Vector2(0.0, top + h * 0.5)
	parent.add_child(_backlight(ally, center, maxf(w * AURA_W_RATIO, AURA_MIN_PX), maxf(h * AURA_H_RATIO, AURA_MIN_PX), seed))
	if ally:
		parent.add_child(_gold_motes(center, w, h))
	else:
		parent.add_child(_blood_drops(center, w, h))
		parent.add_child(_blood_motes(center, w, h))


static func _quad_texture() -> ImageTexture:
	if _quad == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_quad = ImageTexture.create_from_image(img)
	return _quad


static func _backlight(ally: bool, center: Vector2, w: float, h: float, seed: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = "Backlight"
	sp.texture = _quad_texture()
	sp.position = center
	sp.scale = Vector2(w, h) / 8.0
	var m := Art.material("unit_aura")
	m.set_shader_parameter("seed", seed)
	if ally:
		m.set_shader_parameter("color", GOLD)
		m.set_shader_parameter("energy", 2.2)
		m.set_shader_parameter("additive", 1.0)
		m.set_shader_parameter("core", 0.42)
		m.set_shader_parameter("rays", 0.55)
		m.set_shader_parameter("ray_count", 10.0)
	else:
		m.set_shader_parameter("color", BLOOD)
		m.set_shader_parameter("energy", 1.9)
		m.set_shader_parameter("additive", 0.45)
		m.set_shader_parameter("core", 0.55)
		m.set_shader_parameter("rays", 0.5)
		m.set_shader_parameter("ray_count", 7.0)
		m.set_shader_parameter("ray_speed", -0.18)
		m.set_shader_parameter("pulse_speed", 0.9)
	sp.material = m
	return sp


static func _ramp(c: Color, energy: float, peak_at: float = 0.25) -> Gradient:
	var g := Gradient.new()
	var hot := Color(c.r * energy, c.g * energy, c.b * energy, 1.0)
	g.set_color(0, Color(hot, 0.0))
	g.set_color(1, Color(hot, 0.0))
	g.add_point(peak_at, hot)
	return g


static func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


static func _base_particles(name: String, center: Vector2, w: float, h: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = name
	p.position = center
	p.local_coords = true
	p.texture = StatusParticles.dot_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(w * 0.42, h * 0.4)
	p.preprocess = 1.5                     # 一出场就有粒子，不从零开始喷
	return p


## 己方：金色球形光点从人物身后缓缓上浮、闪烁后消失
static func _gold_motes(center: Vector2, w: float, h: float) -> CPUParticles2D:
	var p := _base_particles("GoldMotes", center, w, h)
	p.amount = 16
	p.lifetime = 2.4
	p.direction = Vector2.UP
	p.spread = 22.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(0.0, -10.0)
	p.scale_amount_min = 3.0 / float(StatusParticles.TEX_SIZE)
	p.scale_amount_max = 8.0 / float(StatusParticles.TEX_SIZE)
	p.color_ramp = _ramp(GOLD, 2.6)
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.03
	p.material = _add_material()
	p.emitting = true
	return p


## 敌方：血滴从人物身上迸出、沿抛物线落下（沿速度方向拉长）
static func _blood_drops(center: Vector2, w: float, h: float) -> CPUParticles2D:
	var p := _base_particles("BloodDrops", center + Vector2(0.0, -h * 0.12), w * 0.8, h * 0.6)
	var drop: Texture2D = Art.texture(BLOOD_DROP_TEX)
	if drop != null:
		p.texture = drop
	p.amount = 9
	p.lifetime = 1.1
	p.direction = Vector2.UP
	p.spread = 60.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 75.0
	p.gravity = Vector2(0.0, 230.0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	var g := Gradient.new()
	g.set_color(0, Color(BLOOD.r * 1.5, BLOOD.g, BLOOD.b, 0.95))
	g.set_color(1, Color(BLOOD_DEEP, 0.0))
	g.add_point(0.7, Color(BLOOD, 0.85))
	p.color_ramp = g
	p.emitting = true
	return p


## 敌方：暗红微光（血雾中的余烬）缓缓上浮
static func _blood_motes(center: Vector2, w: float, h: float) -> CPUParticles2D:
	var p := _base_particles("BloodMotes", center, w, h)
	p.amount = 12
	p.lifetime = 2.2
	p.direction = Vector2.UP
	p.spread = 30.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector2(0.0, -6.0)
	p.scale_amount_min = 4.0 / float(StatusParticles.TEX_SIZE)
	p.scale_amount_max = 9.0 / float(StatusParticles.TEX_SIZE)
	p.color_ramp = _ramp(Color(0.85, 0.06, 0.1), 1.8, 0.3)
	p.material = _add_material()
	p.emitting = true
	return p


## 外轮廓淡光精灵（与本体同贴图 / 偏移 / 缩放；呼吸参数与本体同步）
static func rim_sprite(ally: bool, tex: Texture2D, offset: Vector2, s: float, seed: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = "RimGlow"
	sp.texture = tex
	sp.offset = offset
	sp.scale = Vector2(s, s)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var m := Art.material("rim_glow")
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("color", GOLD if ally else Color(0.9, 0.08, 0.12))
	m.set_shader_parameter("energy", 1.6 if ally else 1.3)
	m.set_shader_parameter("opacity", 0.55 if ally else 0.5)
	sp.material = m
	return sp
