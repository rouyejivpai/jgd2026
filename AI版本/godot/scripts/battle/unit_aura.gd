class_name UnitAura
extends RefCounted
## 2026-10-19 阵营光效（用户：敌我都用 Q 版人物，靠光效区分）：
## 己方 = 脚底金色光圈 + 身后金色放射光芒 + 金色球形光点缓缓上浮；敌方 = 暗红光圈 + 身后暗红光芒 + 血滴迸溅与血色微光。
## 遮挡：光芒与粒子都在 UnitView 的 Aura 层（Base 之后、Body 之前），被人物本体遮住，只从轮廓四周透出；
## 人物本体只在轮廓外有一圈淡光（rim_glow，画在本体之后）。光圈由 UnitView._draw_base 画（脚底，最底层）。
## 只碰表现，不读写模拟数据。建筑不加光效（保留方框底座）。
## 2026-10-19 形态图标（区分共用人偶图的六个形态）：己方单位有 form_icons/<形态>.png 时，金色发光图标绕人物腰部做伪 3D 水平环绕——
## 转到身后（椭圆上半）画在人物之后、变小变暗；转到身前（椭圆下半）画在人物之前、变大变亮。

const GOLD: Color = Color(1.0, 0.78, 0.32)
const GOLD_DEEP: Color = Color(1.0, 0.58, 0.16)
const BLOOD: Color = Color(0.62, 0.03, 0.07)
const BLOOD_DEEP: Color = Color(0.32, 0.0, 0.03)
const BLOOD_DROP_TEX: String = "vfx/blood_drop.png"

## 光芒尺寸（相对人物可见高度）与位置（人物可见区域中心）
const AURA_W_RATIO: float = 1.7
const AURA_H_RATIO: float = 1.45
const AURA_MIN_PX: float = 110.0

const FORM_ICON_DIR: String = "form_icons/%s.png"            ## 带烘焙外发光（卡面、头像用）
const FORM_ICON_SOLID_DIR: String = "form_icons/%s_solid.png" ## 实心剪影（战场环绕用：靠场景辉光发光，形状更清楚）
## 图标颜色已烘焙：金色 → 形态标志色（= 人偶描边色）的斜向渐变，见 tools/make_form_icons.py FORM_COLORS
const ORBIT_PERIOD: float = 3.4          ## 秒 / 圈
const ORBIT_RX_RATIO: float = 0.8        ## 水平半径（相对人物可见宽度）
const ORBIT_RX_MIN: float = 56.0
const ORBIT_FLATTEN: float = 0.3         ## 竖直半径 = 水平半径 × 此值（俯视压扁）
const ORBIT_Y_RATIO: float = 0.58        ## 环绕高度：从脚底往上占人物可见高度的比例（腰部）
const ORBIT_ICON_PX: float = 92.0
const ORBIT_GOLD: Color = Color(1.45, 1.45, 1.45, 1.0)  ## 亮度略超 1（颜色在贴图里）：透过 CanvasModulate、带一点辉光但不糊掉形状

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
static func build(parent: Node2D, ally: bool, tex: Texture2D, s: float, feet_offset: float, seed: float, form: String = "") -> void:
	var vis: Rect2i = visible_rect(tex)
	var half: float = float(tex.get_height()) * 0.5
	var top: float = (float(vis.position.y) - half + feet_offset) * s
	var h: float = float(vis.size.y) * s
	var w: float = float(vis.size.x) * s
	var center := Vector2(0.0, top + h * 0.5)
	parent.add_child(_backlight(ally, center, maxf(w * AURA_W_RATIO, AURA_MIN_PX), maxf(h * AURA_H_RATIO, AURA_MIN_PX), seed))
	if ally:
		parent.add_child(_gold_motes(center, w, h))
		var icon: Texture2D = Art.texture(FORM_ICON_SOLID_DIR % form) if form != "" else null
		if icon != null:
			var orbit := OrbitIcon.new()
			orbit.setup(parent, icon, Vector2(0.0, top + h * (1.0 - ORBIT_Y_RATIO)), maxf(w * ORBIT_RX_RATIO, ORBIT_RX_MIN), seed)
			parent.add_child(orbit)
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


## 形态图标环绕：本节点在 Aura 层里画「身后」那半圈；身前半圈由插在 Body 之后的 OrbitFront 节点画（同一张图，按深度切换显示）。
## 跟随 Aura 层的位置（步伐跳动）与透明度（击败渐隐）。
class OrbitIcon:
	extends Node2D

	var _aura: Node2D = null
	var _front_holder: Node2D = null
	var _back: Sprite2D = null
	var _front: Sprite2D = null
	var _center: Vector2 = Vector2.ZERO
	var _rx: float = 0.0
	var _phase: float = 0.0

	func setup(aura: Node2D, icon: Texture2D, center: Vector2, rx: float, seed: float) -> void:
		name = "FormOrbit"
		_aura = aura
		_center = center
		_rx = rx
		_phase = seed * TAU
		_back = _icon_sprite(icon)
		add_child(_back)
		_front = _icon_sprite(icon)

	func _ready() -> void:
		var view: Node = _aura.get_parent()
		var body: Node = view.get_node_or_null("Body")
		_front_holder = Node2D.new()
		_front_holder.name = "OrbitFront"
		_front_holder.add_child(_front)
		view.add_child(_front_holder)
		if body != null:
			view.move_child(_front_holder, body.get_index() + 1)
		_update(0.0)

	func _exit_tree() -> void:
		if is_instance_valid(_front_holder):
			_front_holder.queue_free()

	func _icon_sprite(icon: Texture2D) -> Sprite2D:
		var sp := Sprite2D.new()
		sp.texture = icon
		sp.modulate = ORBIT_GOLD
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sp.material = m
		return sp

	func _process(delta: float) -> void:
		_update(delta)

	func _update(delta: float) -> void:
		_phase = fmod(_phase + TAU * delta / ORBIT_PERIOD, TAU)
		var depth: float = sin(_phase)                     # > 0：在人物身前（椭圆下半）
		var p: Vector2 = _center + Vector2(cos(_phase) * _rx, depth * _rx * ORBIT_FLATTEN)
		var k: float = 0.5 + 0.5 * depth
		var px: float = ORBIT_ICON_PX * lerpf(0.8, 1.1, k)
		var sc: float = px / float(maxi(_back.texture.get_width(), 1))
		var alpha: float = lerpf(0.5, 1.0, k)
		for sp: Sprite2D in [_back, _front]:
			sp.position = p
			sp.scale = Vector2(sc, sc)
			sp.modulate = Color(ORBIT_GOLD, alpha)
		_back.visible = depth <= 0.0
		_front.visible = depth > 0.0
		if is_instance_valid(_front_holder):
			_front_holder.position = _aura.position
			_front_holder.modulate.a = _aura.modulate.a
