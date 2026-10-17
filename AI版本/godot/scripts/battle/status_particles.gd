class_name StatusParticles
extends RefCounted
## 第五阶段：异常状态粒子（参数 data/status_fx.json，见文件内说明）。CPUParticles2D，只读模拟状态、不改数据；
## 粒子贴图为运行时生成的柔边圆点（不需要美术资源）。由 status_overlay.gd 按"单位 × 状态"创建 / 跟随 / 回收。

const TEX_SIZE: int = 16
const EMISSION: Dictionary = {
	"point": CPUParticles2D.EMISSION_SHAPE_POINT, "sphere": CPUParticles2D.EMISSION_SHAPE_SPHERE,
	"ring": CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE, "box": CPUParticles2D.EMISSION_SHAPE_RECTANGLE,
}

static var _dot: Texture2D = null


## 柔边圆点：中心不透明白 → 边缘透明（颜色由 color_ramp 决定）
static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		g.add_point(0.45, Color(1.0, 1.0, 1.0, 0.85))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = TEX_SIZE
		t.height = TEX_SIZE
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		_dot = t
	return _dot


static func _pair(spec: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var a: Array = spec.get(key, []) as Array
	return Vector2(float(a[0]), float(a[1])) if a.size() == 2 else fallback


## 按一条状态参数建发射器（local_coords：粒子随单位移动、随镜头平移缩放）
static func make(spec: Dictionary) -> CPUParticles2D:
	var tile: float = float(SimTypes.TILE_SIZE)
	var p := CPUParticles2D.new()
	p.amount = maxi(1, int(spec.get("amount", 8)))
	p.lifetime = maxf(0.05, float(spec.get("lifetime", 1.0)))
	p.explosiveness = clampf(float(spec.get("explosiveness", 0.0)), 0.0, 1.0)
	p.local_coords = true
	p.texture = dot_texture()
	p.emission_shape = int(EMISSION.get(str(spec.get("emission", "sphere")), CPUParticles2D.EMISSION_SHAPE_SPHERE)) as CPUParticles2D.EmissionShape
	var r: float = float(spec.get("radius", 0.3)) * tile
	p.emission_sphere_radius = r
	p.emission_rect_extents = Vector2(r, tile * 0.08)
	p.direction = _pair(spec, "direction", Vector2.UP)
	p.spread = float(spec.get("spread", 45.0))
	var v: Vector2 = _pair(spec, "velocity", Vector2(20.0, 40.0))
	p.initial_velocity_min = v.x
	p.initial_velocity_max = v.y
	p.gravity = _pair(spec, "gravity", Vector2.ZERO)
	p.damping_min = float(spec.get("damping", 0.0))
	p.damping_max = float(spec.get("damping", 0.0))
	var sc: Vector2 = _pair(spec, "scale", Vector2(3.0, 5.0)) / float(TEX_SIZE)
	p.scale_amount_min = sc.x
	p.scale_amount_max = sc.y
	var ramp := Gradient.new()
	var energy: float = maxf(0.0, float(spec.get("energy", 1.0)))     # HDR 亮度倍数：透过战斗场景的整体压暗并触发辉光
	var c0 := Color(str(spec.get("color", "#FFFFFF")))
	c0 = Color(c0.r * energy, c0.g * energy, c0.b * energy, c0.a)
	var c1 := Color(str(spec.get("color_end", spec.get("color", "#FFFFFF"))))
	ramp.set_color(0, c0)
	ramp.set_color(1, Color(c1, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	return p


## 发射器相对单位脚下中心的偏移（像素）
static func offset_px(spec: Dictionary) -> Vector2:
	return _pair(spec, "offset", Vector2.ZERO) * float(SimTypes.TILE_SIZE)
