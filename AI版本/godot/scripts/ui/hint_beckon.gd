class_name HintBeckon
extends Control
## 「提示」按钮的召唤演出（2026-10-21）：玩家累计重试若干次后，提示按钮散发白色光晕、边缘不断升起白色光点，
## 玩家点任意按钮（场景里任何 BaseButton 的 pressed，包括之后才建出的弹窗按钮）后淡出并自行释放。
## 两层，均为加色混合、不拦截鼠标：
## - 光晕：按钮下的 show_behind_parent 子节点，排在按钮动效层（ButtonMotion）之前，画在按钮底图之下、向外扩出一圈并缓慢呼吸
## - 光点：本节点（按钮的最后一个子节点），画在按钮之上，可飘出按钮范围
## UiKit.motion_enabled = false 时只留静止的光晕，不呼吸、不出光点。
## 参数在 data/ui_motion.json 的 "hint_beckon"。

signal dismissed()

var _button: Control = null
var _p: Dictionary = {}
var _halo: Control = null
var _dot: GradientTexture2D = null
var _t: float = 0.0
var _env: float = 0.0                  ## 整体强度 0..1（淡入 / 淡出）
var _leaving: bool = false
var _spawn_acc: float = 0.0
var _start_frame: int = 0              ## 触发演出的那次点击（第 N 次「重试」）本身不算解除
var _hooked: Array[BaseButton] = []

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()


static func play(button: Control) -> HintBeckon:
	var b := HintBeckon.new()
	b._button = button
	button.add_child(b)
	return b


func _ready() -> void:
	name = "HintBeckon"
	_p = UiKit.motion_params("hint_beckon")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.35), Color(1.0, 1.0, 1.0, 0.0)])
	_dot = GradientTexture2D.new()
	_dot.gradient = g
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(0.5, 0.0)
	_dot.width = 64
	_dot.height = 64
	_halo = Control.new()
	_halo.name = "HintBeckonHalo"
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.show_behind_parent = true
	_halo.material = add
	_halo.draw.connect(_draw_halo)
	_button.add_child(_halo)
	_button.move_child(_halo, 0)        # 动效层也是 show_behind_parent：排在它之前 = 画在按钮底图之下
	_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_frame = Engine.get_process_frames()
	_hook(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	if not UiKit.motion_enabled:
		_env = 1.0


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for b: BaseButton in _hooked:
		if is_instance_valid(b) and b.pressed.is_connected(_on_any_pressed):
			b.pressed.disconnect(_on_any_pressed)
	_hooked.clear()
	if is_instance_valid(_halo):
		_halo.queue_free()


## 淡出后释放（重复调用无副作用）
func stop() -> void:
	if _leaving:
		return
	_leaving = true
	dismissed.emit()
	if not UiKit.motion_enabled:
		queue_free()


func _hook(n: Node) -> void:
	var b: BaseButton = n as BaseButton
	if b != null and not b.pressed.is_connected(_on_any_pressed):
		b.pressed.connect(_on_any_pressed)
		_hooked.append(b)
	for c: Node in n.get_children():
		_hook(c)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_hook(n)


func _on_any_pressed() -> void:
	if Engine.get_process_frames() != _start_frame:
		stop()


func _process(delta: float) -> void:
	if not UiKit.motion_enabled:
		_halo.queue_redraw()
		return
	_t += delta
	if _leaving:
		_env = maxf(_env - delta / maxf(float(_p.get("fade_out_s", 0.3)), 0.01), 0.0)
		if _env <= 0.0:
			queue_free()
			return
	else:
		_env = minf(_env + delta / maxf(float(_p.get("fade_in_s", 0.45)), 0.01), 1.0)
		_spawn_acc += delta * float(_p.get("spawn_per_s", 14.0))
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			_spawn()
	var i: int = _pos.size() - 1
	while i >= 0:
		_age[i] += delta
		if _age[i] >= _life[i]:
			_remove(i)
		else:
			_pos[i] += _vel[i] * delta
			_vel[i].x += sin(_t * 2.3 + _phase[i]) * 18.0 * _k() * delta      # 左右轻摆
		i -= 1
	queue_redraw()
	_halo.queue_redraw()


## 光点从按钮四周（偏下沿与两侧）冒出、向上飘
func _spawn() -> void:
	var s: Vector2 = _button.size
	var k: float = _k()
	var at: Vector2
	var r: float = randf()
	if r < 0.5:
		at = Vector2(randf() * s.x, s.y * randf_range(0.55, 1.0))
	elif r < 0.75:
		at = Vector2(randf_range(-4.0, 6.0) * k, randf() * s.y)
	else:
		at = Vector2(s.x - randf_range(-4.0, 6.0) * k, randf() * s.y)
	var rise: Array = _p.get("rise_px_s", [22.0, 52.0]) as Array
	var drift: float = float(_p.get("drift_px_s", 10.0))
	var life: Array = _p.get("particle_life_s", [0.9, 1.7]) as Array
	var sz: Array = _p.get("particle_size_px", [1.2, 2.6]) as Array
	_pos.append(at)
	_vel.append(Vector2(randf_range(-drift, drift), -randf_range(float(rise[0]), float(rise[1]))) * k)
	_age.append(0.0)
	_life.append(randf_range(float(life[0]), float(life[1])))
	_size.append(randf_range(float(sz[0]), float(sz[1])))
	_phase.append(randf() * TAU)


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_age.remove_at(i)
	_life.remove_at(i)
	_size.remove_at(i)
	_phase.remove_at(i)


func _pulse() -> float:
	if not UiKit.motion_enabled:
		return 0.5
	return 0.5 - 0.5 * cos(_t * TAU / maxf(float(_p.get("pulse_s", 1.6)), 0.1))


func _color() -> Color:
	return Color(str(_p.get("color", "#FFFFFF")))


## 按钮高 32 设计像素时为 1（光晕宽度、光点大小与速度随 HUD 缩放）
func _k() -> float:
	return maxf(_button.size.y / 32.0, 0.1)


## 按钮背后：贴着按钮胶囊外形的两层柔光（StyleBoxFlat 的阴影）——外层宽而淡、内层窄而亮，随呼吸放大、变亮
func _draw_halo() -> void:
	if _env <= 0.0:
		return
	var w: float = _pulse()
	var c: Color = _color()
	var rect := Rect2(Vector2.ZERO, _button.size)
	var k: float = _k()
	var spread: float = lerpf(0.85, 1.15, w)
	for layer: String in ["outer", "inner"]:
		var px: float = float(_p.get("halo_%s_px" % layer, 18.0 if layer == "outer" else 6.0))
		var al: Array = _p.get("halo_%s_alpha" % layer, [0.35, 0.7]) as Array
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_corner_radius_all(int(round(rect.size.y * 0.5)))
		sb.shadow_size = maxi(int(round(px * k * spread)), 1)
		sb.shadow_color = Color(c, lerpf(float(al[0]), float(al[1]), w) * _env)
		_halo.draw_style_box(sb, rect)


func _draw() -> void:
	var c: Color = _color()
	for i: int in _pos.size():
		var k: float = _age[i] / _life[i]
		var a: float = minf(k * 6.0, 1.0) * (1.0 - k) * _env
		a *= 0.75 + 0.25 * sin(_t * 9.0 + _phase[i])          # 闪烁
		var r: float = _size[i] * _k()
		draw_texture_rect(_dot, Rect2(_pos[i] - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(c, 0.5 * a))
		draw_rect(Rect2(_pos[i] - Vector2(r, r) * 0.4, Vector2(r, r) * 0.8), Color(c, a))
