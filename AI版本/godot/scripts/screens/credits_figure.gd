class_name CreditsFigure
extends Node2D
## 片尾名单里的一个 Q 版人偶（2026-10-20）。两种用法：
## · 主角（hero = true）：同战斗中的己方单位——身后金色光芒与金色光点（UnitAura）、轮廓金色淡光、一步一跳的步伐、每落一步发 footstep 留金色脚印；
##   但没有脚底金色光圈、没有形态图标环绕（纹章），也不画信标线。由 CreditsRoll 每帧给 speed，自己按速度前进。
## · 开发者（hero = false）：各自选的 Q 版形象（credits.json 的 sprite，缺省为人偶图），不带光效，站着呼吸；
##   脸部（credits.json 的 head，缺省为人偶图的脸；只盖脸、露出头饰）盖一个圆形头像（avatar 贴图，缺省时画首字占位）。
##   平时略暗，主角走近时 light_up() 亮起；主角走过后 face(false) 转身目送。
## 朝向用 Body 的横向缩放翻转；原画朝左的形象（credits.json faces_left）取反。头像在开发者初始朝向（面向主角）时不镜像，
## 转身后随形象一起镜像（2026-10-20 / 21 用户定）；翻转过程同 UnitView：0.12 s 内缩到 0 再展开。

signal footstep(pos: Vector2)

const FEET_OFFSET: float = UnitView.SPRITE_FEET_OFFSET
## 人偶图（256 画布）的脸：圆心 (144, 108)、半径 38（贴图像素，左上为原点；露出头上的发饰）；脚底锚点在贴图 (128, 232)
const HEAD_DEFAULT: Array = [144.0, 108.0, 38.0]
const FEET_TEX: Vector2 = Vector2(128.0, 128.0 - FEET_OFFSET)
const DIM: Color = Color(0.5, 0.47, 0.52)                  ## 开发者未被照亮时的明暗
const LIGHT_SECONDS: float = 0.5
const STEP_TILE: float = 96.0                              ## 步频换算用的「格」宽（同 SimTypes.TILE_SIZE）

var hero: bool = false
var speed: float = 0.0                   ## 主角：当前前进速度（像素 / 秒，向右为正）
var facing_left: bool = false
var native_left: bool = false            ## 原画朝左（大多数 Q 版原画朝右）

var _s: float = 1.0                      ## 精灵缩放
var _k: float = 1.0                      ## 相对战斗中单位的放大倍数（步伐幅度、脚印大小随之放大）
var _body: Node2D
var _gait: Node2D
var _aura: Node2D = null
var _head: Node2D = null
var _head_center: Vector2 = Vector2.ZERO  ## 头部圆心相对脚底锚点（本节点像素）
var _head_r: float = 0.0
var _gait_phase: float = 0.0
var _gait_amt: float = 0.0
var _flip_tween: Tween = null
var _light_tween: Tween = null


## tex = 人偶图；s = 精灵缩放；member = 开发者条目（credits.json members[]，主角传空）
func setup(tex: Texture2D, p_hero: bool, s: float, seed: float, p_facing_left: bool, member: Dictionary = {}, font: Font = null) -> void:
	hero = p_hero
	_s = s
	_k = s / UnitView.SPRITE_SCALE
	if hero:
		_aura = Node2D.new()
		_aura.name = "Aura"
		add_child(_aura)
		UnitAura.build(_aura, true, tex, s, FEET_OFFSET, seed, "")      # form 为空 = 不加形态图标环绕
	_body = Node2D.new()
	_body.name = "Body"
	add_child(_body)
	_gait = Node2D.new()
	_gait.name = "Gait"
	_body.add_child(_gait)
	if hero:
		_gait.add_child(UnitAura.rim_sprite(true, tex, Vector2(0.0, FEET_OFFSET), s, seed))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	sprite.offset = Vector2(0.0, FEET_OFFSET)
	sprite.scale = Vector2(s, s)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var m: ShaderMaterial = Art.material("breathing")
	m.set_shader_parameter("seed", seed)
	sprite.material = m
	_gait.add_child(sprite)
	if not hero:
		var hd: Array = member.get("head", HEAD_DEFAULT) as Array
		if hd.size() < 3:
			hd = HEAD_DEFAULT
		_head_center = (Vector2(float(hd[0]), float(hd[1])) - FEET_TEX) * s
		_head_r = float(hd[2]) * s
		_head = Avatar.new()
		_head.name = "Head"
		_head.position = _head_center
		(_head as Avatar).setup(member, _head_r, font)
		native_left = bool(member.get("faces_left", false))
		_gait.add_child(_head)
		_body.modulate = DIM
	facing_left = p_facing_left
	_apply_facing()
	if _head != null:
		_head.scale.x = _body.scale.x   # 初始朝向下抵消 Body 镜像：头像正着；转身后 Body 反向，头像随之镜像


## 头顶（对话框尾巴指向处）相对脚底的偏移
func head_top() -> Vector2:
	return Vector2(0.0, _head_center.y - _head_r)


## 开发者：主角走近时亮起
func light_up() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween()
	_light_tween.tween_property(_body, "modulate", Color.WHITE, LIGHT_SECONDS)


## 转向（0.12 s 内横向缩到 0 → 换朝向 → 展开）
func face(left: bool) -> void:
	if left == facing_left:
		return
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.tween_property(_body, "scale:x", 0.0, UnitView.FLIP_SECONDS * 0.5)
	_flip_tween.tween_callback(func() -> void:
		facing_left = left
		_apply_facing())
	_flip_tween.tween_property(_body, "scale:x", _facing_sign(left), UnitView.FLIP_SECONDS * 0.5)


## 面向左 / 右时 Body 的横向缩放：原画朝右时向左 = -1；原画朝左时取反
func _facing_sign(left: bool) -> float:
	return (-1.0 if left else 1.0) * (-1.0 if native_left else 1.0)


func _apply_facing() -> void:
	var dir: float = _facing_sign(facing_left)
	_body.scale.x = dir
	if _aura != null:
		_aura.scale.x = dir


func _process(delta: float) -> void:
	if not hero:
		return
	position.x += speed * delta
	_update_gait(delta)


## 一步一跳（同 UnitView._update_gait，幅度按放大倍数缩放）：跳起 + 左右倾斜 + 落地压扁，每落一步发 footstep
func _update_gait(delta: float) -> void:
	var spd: float = absf(speed) / _k            # 换算回战斗尺度的速度，步频与战斗中一致
	var want: float = clampf((spd - UnitView.GAIT_SPEED_MIN) / (UnitView.GAIT_SPEED_FULL - UnitView.GAIT_SPEED_MIN), 0.0, 1.0)
	_gait_amt = move_toward(_gait_amt, want, delta * 7.0)
	if _gait_amt <= 0.001:
		_gait_phase = 0.0
		_gait.position = Vector2.ZERO
		_gait.rotation = 0.0
		_gait.scale = Vector2.ONE
		if _aura != null:
			_aura.position = Vector2.ZERO
		return
	var rate: float = clampf(UnitView.STEP_RATE.x + spd / STEP_TILE * 0.9, UnitView.STEP_RATE.x, UnitView.STEP_RATE.y)
	var step_before: int = int(floor(_gait_phase / PI))
	_gait_phase += PI * rate * delta
	var step_now: int = int(floor(_gait_phase / PI))
	var sn: float = sin(_gait_phase)
	var h: float = absf(sn) * UnitView.HOP_PX * _k * _gait_amt
	var squash: float = pow(1.0 - absf(sn), 6.0) * UnitView.LAND_SQUASH * _gait_amt
	_gait.position = Vector2(0.0, -h)
	_gait.rotation = sn * deg_to_rad(UnitView.SWAY_DEG) * _gait_amt
	_gait.scale = Vector2(1.0 + squash, 1.0 - squash)
	if _aura != null:
		_aura.position = _gait.position
	if step_now != step_before and _gait_amt > 0.3:
		var side: float = 1.0 if step_now % 2 == 0 else -1.0
		footstep.emit(position + Vector2(0.0, side * UnitView.FOOT_SPREAD_PX * 0.6 * _k))


## 脚印大小（传给 ground_fx.add_footprint 的 size）
func print_size() -> float:
	return _k


## 头像（2026-10-20 用户定：照实机指令详情面板的头像位）：底下是从面板底图切出的头像位底座
## （assets/credits/portrait_backdrop.png：灰色圆盘外沿、两侧银白弯刃、红蓝星芒，tools/credits/cut_ornaments.py 生成），
## 上面是圆形头像 + 细金圈（同实机 UiKit.portrait 的 circle_mask 着色器）。有 avatar 贴图时直接套 circle_mask；
## 没有时画紫黑底 + 名字首字（思源宋体粗体）+ 同色金圈占位。头像半径 = 头部半径。
class Avatar:
	extends Node2D

	const BACKDROP: String = "res://assets/credits/portrait_backdrop.png"
	const BACKDROP_PORTRAIT_R: float = 75.0               ## 底座贴图中头像圆的半径（实机 det_portrait 150×150）
	const MASK: String = "res://assets/shaders/circle_mask.gdshader"
	const RING: Color = Color(0.79, 0.64, 0.29)           ## circle_mask 的 ring_color 默认值
	const RING_WIDTH: float = 0.03                        ## circle_mask 的 ring_width 默认值（直径比例）
	const FILL_TOP: Color = Color(0.2, 0.13, 0.22)
	const FILL_BOTTOM: Color = Color(0.09, 0.05, 0.1)
	const BOLD: FontFile = preload("res://assets/fonts/NotoSerifSC-Bold.otf")

	var _radius: float = 40.0
	var _letter: String = ""
	var _has_tex: bool = false
	var _face: Node2D = null

	func setup(member: Dictionary, radius: float, _font: Font = null) -> void:
		_radius = radius
		_letter = str(member.get("name", "")).substr(0, 1)
		var back_tex: Texture2D = Art.texture(BACKDROP)
		if back_tex != null:
			var bk := Sprite2D.new()
			bk.name = "Backdrop"
			bk.texture = back_tex
			bk.scale = Vector2.ONE * (radius / BACKDROP_PORTRAIT_R)
			bk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			add_child(bk)
		var tex: Texture2D = Art.texture(str(member.get("avatar", "")))
		if tex != null:
			_has_tex = true
			var sp := Sprite2D.new()
			sp.name = "Picture"
			sp.texture = tex
			sp.scale = Vector2.ONE * (radius * 2.0 / float(maxi(tex.get_width(), tex.get_height())))
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var m := ShaderMaterial.new()
			m.shader = load(MASK) as Shader
			sp.material = m
			add_child(sp)
			return
		_face = Node2D.new()
		_face.name = "Face"
		add_child(_face)
		_face.draw.connect(_draw_face)
		_face.queue_redraw()

	## 占位：上亮下暗的紫黑圆 + 首字 + 细金圈（位置 / 粗细同 circle_mask）
	func _draw_face() -> void:
		var n: int = 64
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i: int in n:
			var a: float = TAU * float(i) / float(n)
			var p := Vector2(cos(a), sin(a)) * _radius
			pts.append(p)
			cols.append(FILL_TOP.lerp(FILL_BOTTOM, (p.y / _radius + 1.0) * 0.5))
		_face.draw_polygon(pts, cols)
		if _letter != "":
			var size: int = int(_radius * 0.95)
			var asc: float = BOLD.get_ascent(size)
			var desc: float = BOLD.get_descent(size)
			var base := Vector2(-_radius, (asc - desc) * 0.5)
			_face.draw_string(BOLD, base + Vector2(0.0, 2.0), _letter, HORIZONTAL_ALIGNMENT_CENTER, _radius * 2.0, size, Color(0.0, 0.0, 0.0, 0.6))
			_face.draw_string(BOLD, base, _letter, HORIZONTAL_ALIGNMENT_CENTER, _radius * 2.0, size, Palette.BONE)
		var w: float = maxf(2.0, RING_WIDTH * _radius)
		_face.draw_arc(Vector2.ZERO, _radius * (1.0 - RING_WIDTH * 1.5), 0.0, TAU, 96, RING, w, true)
