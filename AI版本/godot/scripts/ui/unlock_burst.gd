class_name UnlockBurst
extends Control
## 2026-10-20 解锁动画（一级地图的区域名牌、选关地图的关卡名牌共用）：
## 锁颤抖（越抖越急、越来越白）→ 炸成白色粒子（碎片四散 + 慢慢上飘的余烬 + 一团柔光）→ 名牌与文字闪白、微微鼓起 →
## 白里换上名字（on_name）→ 渐变回原样 → on_done。
## 本节点是粒子的画布：放在名牌之上、与名牌同一坐标系里随地图移动；不接收鼠标。名牌 / 文字 / 锁需挂 flash_material()。

const FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")
const SHAKE_TIME: float = 1.05            ## 锁颤抖时长
const BURST_COUNT: int = 80               ## 锁炸开的粒子数
const POP: float = 0.12                   ## 名牌闪白时鼓起的比例
const PARTICLE_COLOR: Color = Color("#F6F2FF")
const PARTICLE_SHADE: Color = Color(0.16, 0.07, 0.05, 0.35)    ## 粒子底下一圈淡褐，白粒子在羊皮纸上也看得清

var _particles: Array[Dictionary] = []
var _flares: Array[Dictionary] = []
var _soft_tex: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(0.5, 0.0)
	_soft_tex.width = 128
	_soft_tex.height = 128


## 名牌 / 文字 / 锁用的闪白材质（每个节点一份）
static func flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter("flash", 0.0)
	return m


static func set_flash(c: Control, v: float) -> void:
	var m: ShaderMaterial = c.material as ShaderMaterial
	if m != null:
		m.set_shader_parameter("flash", v)


## tween_method 先传补间值、再传绑定参数
static func _flash_to(v: float, c: Control) -> void:
	set_flash(c, v)


func is_busy() -> bool:
	return not _particles.is_empty() or not _flares.is_empty()


func clear() -> void:
	_particles.clear()
	_flares.clear()
	queue_redraw()


## 在 tw 末尾追加一段解锁动画。lock 颤抖后隐藏；plate、text 闪白鼓起后渐回；glow（可选）在颤抖时亮起、渐回时熄灭
func append_reveal(tw: Tween, lock: Control, plate: Control, text: Control, on_name: Callable, on_done: Callable, glow: Control = null) -> void:
	tw.tween_callback(func() -> void:
		lock.set_meta(&"shake_base", lock.position)
		lock.visible = true
		AudioManager.play_sfx("blast_warn_tick"))
	tw.tween_method(_shake.bind(lock), 0.0, 1.0, SHAKE_TIME)
	if glow != null:
		tw.parallel().tween_property(glow, "self_modulate:a", 0.55, SHAKE_TIME)
	tw.tween_callback(func() -> void:
		plate.set_meta(&"pop_base", plate.scale)
		text.set_meta(&"pop_base", text.scale)
		_burst_from(lock, plate))
	tw.tween_method(_flash_to.bind(plate), 0.0, 1.0, 0.1)
	tw.parallel().tween_method(_flash_to.bind(text), 0.0, 1.0, 0.1)
	tw.parallel().tween_method(_pop.bind(plate), 0.0, 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pop.bind(text), 0.0, 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(on_name)
	tw.tween_interval(0.14)
	tw.tween_method(_flash_to.bind(plate), 1.0, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(_flash_to.bind(text), 1.0, 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(_pop.bind(plate), 1.0, 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pop.bind(text), 1.0, 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if glow != null:
		tw.parallel().tween_property(glow, "self_modulate:a", 0.0, 1.2)
	tw.tween_callback(on_done)


## k：0 → 1。振幅随 k² 增大，前段按阵抽动（停顿—猛抖—停顿），后段一直抖；锁后半程通体发白
func _shake(k: float, lock: Control) -> void:
	var t: float = k * SHAKE_TIME
	var pulse: float = 0.35 + 0.65 * absf(sin(k * PI * 3.5)) if k < 0.75 else 1.0
	var amp: float = lerpf(0.05, 0.34, k * k) * pulse
	lock.rotation = sin(t * 47.0) * amp
	lock.position = (lock.get_meta(&"shake_base", lock.position) as Vector2) + Vector2(sin(t * 73.0), cos(t * 61.0)) * (0.6 + 3.2 * k * k) * pulse
	lock.scale = Vector2.ONE * (1.0 + 0.2 * k * k)
	set_flash(lock, clampf((k - 0.35) / 0.65, 0.0, 1.0) * 0.9)


func _pop(k: float, c: Control) -> void:
	c.scale = (c.get_meta(&"pop_base", Vector2.ONE) as Vector2) * (1.0 + POP * k)


## 锁炸开：在锁中心喷出粒子，锁复位并隐藏
func _burst_from(lock: Control, plate: Control) -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var c: Vector2 = inv * (lock.get_global_transform() * (lock.size * 0.5))
	var pw: float = plate.size.x * plate.get_global_transform().get_scale().x / maxf(get_global_transform().get_scale().x, 0.001)
	lock.visible = false
	lock.rotation = 0.0
	lock.scale = Vector2.ONE
	lock.position = lock.get_meta(&"shake_base", lock.position) as Vector2
	set_flash(lock, 0.0)
	AudioManager.play_sfx("core_pulse")
	burst(c, pw)


## 在 c（本节点坐标）炸开一团白色粒子；width = 名牌宽（余烬沿名牌横向散开）
func burst(c: Vector2, width: float) -> void:
	for i: int in BURST_COUNT:
		var lingering: bool = i % 4 == 0                  # 四分之一是慢慢上飘、久久不散的余烬
		var ang: float = randf() * TAU
		var spd: float = randf_range(120.0, 520.0) * (0.3 if lingering else 1.0)
		var origin: Vector2 = c + Vector2(randf_range(-0.12, 0.12) * width if lingering else randf_range(-10.0, 10.0), randf_range(-7.0, 7.0))
		_particles.append({
			"p": origin,
			"v": Vector2.from_angle(ang) * spd * Vector2(1.3, 0.75) + Vector2(0.0, -50.0),
			"age": 0.0,
			"life": randf_range(1.4, 2.4) if lingering else randf_range(0.5, 1.15),
			"size": randf_range(1.4, 3.0) if lingering else randf_range(1.8, 4.4),
			"rot": randf() * TAU,
			"spin": randf_range(-10.0, 10.0),
			"shard": not lingering and randf() < 0.55,
			"drag": 0.9 if lingering else 3.2,
			"fall": -26.0 if lingering else 90.0,
		})
	_flares.append({ "p": c, "age": 0.0, "life": 0.45, "r": 120.0 })
	_flares.append({ "p": c, "age": 0.0, "life": 0.75, "r": width * 0.75, "wide": true })


func _process(delta: float) -> void:
	if not is_busy():
		return
	var dt: float = minf(delta, 1.0 / 30.0)
	for i: int in range(_particles.size() - 1, -1, -1):
		var q: Dictionary = _particles[i]
		q["age"] = float(q["age"]) + dt
		if float(q["age"]) >= float(q["life"]):
			_particles.remove_at(i)
			continue
		var v: Vector2 = (q["v"] as Vector2) * exp(-float(q["drag"]) * dt)
		v.y += float(q["fall"]) * dt
		q["v"] = v
		q["p"] = (q["p"] as Vector2) + v * dt
		q["rot"] = float(q["rot"]) + float(q["spin"]) * dt
	for i: int in range(_flares.size() - 1, -1, -1):
		var f: Dictionary = _flares[i]
		f["age"] = float(f["age"]) + dt
		if float(f["age"]) >= float(f["life"]):
			_flares.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for f: Dictionary in _flares:
		var k: float = float(f["age"]) / float(f["life"])
		var a: float = (1.0 - k) * (1.0 - k)
		var r: float = float(f["r"]) * (0.35 + 0.65 * sqrt(k))
		var sz: Vector2 = Vector2(r * 2.0, r * 0.55) if f.has("wide") else Vector2(r, r)
		draw_texture_rect(_soft_tex, Rect2((f["p"] as Vector2) - sz * 0.5, sz), false, Color(1.0, 1.0, 1.0, a * (0.75 if f.has("wide") else 0.9)))
	for q: Dictionary in _particles:
		var k: float = float(q["age"]) / float(q["life"])
		var a: float = 1.0 - pow(k, 1.6)
		var p: Vector2 = q["p"] as Vector2
		var s: float = float(q["size"]) * (1.0 - 0.4 * k)
		if bool(q["shard"]):
			var d: Vector2 = Vector2.from_angle(float(q["rot"]))
			var n: Vector2 = d.orthogonal()
			var pts := PackedVector2Array([p + d * s * 2.2, p + n * s * 0.6, p - d * s * 2.2, p - n * s * 0.6])
			var shade := PackedVector2Array()
			for v: Vector2 in pts:
				shade.append(v + (v - p) * 0.35 + Vector2(0.0, 1.0))
			draw_colored_polygon(shade, Color(PARTICLE_SHADE, PARTICLE_SHADE.a * a))
			draw_colored_polygon(pts, Color(PARTICLE_COLOR, a))
		else:
			draw_circle(p + Vector2(0.0, 0.8), s * 0.5 + 1.2, Color(PARTICLE_SHADE, PARTICLE_SHADE.a * a))
			draw_circle(p, s * 0.5, Color(PARTICLE_COLOR, a))
