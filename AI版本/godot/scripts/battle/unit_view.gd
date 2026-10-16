class_name UnitView
extends Node2D
## 单位表现（01 §8 UnitView）。只读 SimUnit，不写模拟数据。
## M7：Q 版精灵（visuals.sprite，脚底锚定、向左移动水平翻转）、呼吸着色器、受击白闪、死亡溶解、选中描边、
## 每单位 PointLight2D。资源缺失时回退 M2 的程序绘制占位。
## 阵营区分不只靠颜色（策划已定）：底座形状（己方圆环 / 敌方荆棘八角 / 建筑方框）与血条形状（圆角 / 尖角 / 方角）。
## 第二阶段：朝向迟滞与背步（A04，FacingTracker）；特殊目标头顶常驻图标 + 底座金色脉动（A03）。
## 第四阶段（用户 2026-10-08「撤离时容易抽搐」）：撤离中 ① 翻身阈值加大（RETREAT_FLIP_*，多数时候以后仰背步代替翻身）；
## ② 显示位置做短时平滑（RETREAT_SMOOTH_TAU，吸收撤离点切换造成的来回小位移）；③ 移动时留下渐隐残影（AFTERIMAGE_*）。只碰表现。

const BASE_RADIUS: float = 34.0
const BODY_RADIUS: float = 26.0
const HP_WIDTH: float = 64.0
const HP_HEIGHT: float = 8.0
const HP_OFFSET_Y: float = 10.0           ## 10 §6.2：血条在脚底锚点下方（宽度不变）；目标标记与状态图标仍在头顶
const HEAD_OFFSET_Y: float = -62.0        ## 占位身体时的头顶高度（目标标记 / 状态图标）
const SPRITE_HEAD_OFFSET_Y: float = -112.0  ## 精灵身体时的头顶高度（Q 版约 100 px 高）
const LUNGE_PX: float = 12.0
const SPRITE_SCALE: float = 0.5           ## 04 §2.1：256 画布、角色约 200 px，在 96 px 格上显示约 100 px
const SPRITE_FEET_OFFSET: float = -104.0  ## 04 §2.1：脚底在画布底部 24 px 处
const FLIP_SECONDS: float = 0.12         ## 07 §6：翻转时的缩放过渡
const BACKSTEP_LEAN_DEG: float = 6.0      ## 07 §6：背步时身体后仰
const BACKSTEP_TWEEN: float = 0.08
const OBJ_NONE: int = 0
const OBJ_KILL: int = 1                   ## 击杀 = 骷髅
const OBJ_PROTECT: int = 2                ## 保护 = 盾
const OBJ_DESTROY: int = 3                ## 摧毁 = 裂纹
const OBJ_ICON_SIZE: float = 26.0
const OBJ_PULSE_HZ: float = 0.8
const FLASH_TIMES: int = 3
const FLASH_HALF_SECONDS: float = 0.18
const LIGHT_ENERGY: float = 0.5
const LIGHT_SCALE: float = 2.6
const DEATH_SECONDS: float = 1.0
const RETREAT_FLIP_CELLS: float = 1.2
const RETREAT_FLIP_SECONDS: float = 0.9
const RETREAT_SMOOTH_TAU: float = 0.09    ## 秒：撤离时显示位置向插值位置靠拢的时间常数
const AFTERIMAGE_INTERVAL: float = 0.06   ## 秒：残影间隔
const AFTERIMAGE_LIFE: float = 0.3        ## 秒：残影渐隐时长
const AFTERIMAGE_ALPHA: float = 0.45
const AFTERIMAGE_TINT: Color = Color(0.78, 0.7, 1.0)
const AFTERIMAGE_MIN_PX: float = 0.6      ## 每帧显示位移不足该像素不留残影（原地不动时）

var unit: SimUnit = null
var grid_height: int = 0
var prev_pos: Vector2 = Vector2.ZERO     ## 模拟坐标，插值起点
var cur_pos: Vector2 = Vector2.ZERO      ## 模拟坐标，插值终点
var interpolate: bool = false
var selected: bool = false:
	set(v):
		selected = v
		if is_node_ready():
			_base.queue_redraw()
			if _outline != null:
				_outline.visible = v
var is_dying: bool = false
var show_state: bool = false             ## 运行/暂停中显示待机状态图标
var objective_kind: int = OBJ_NONE       ## 特殊目标标记（objective_kind_for）

var _tweens: Array[Tween] = []
var _sprite: Sprite2D = null
var _outline: Sprite2D = null
var _body_material: ShaderMaterial = null
var _light: PointLight2D = null
var _facing: FacingTracker = FacingTracker.new()
var _flip_tween: Tween = null
var _lean_tween: Tween = null
var _leaning: bool = false
var _smooth: Vector2 = Vector2.INF       ## 撤离平滑中的显示位置（屏幕局部），INF = 未在平滑
var _ghost_clock: float = 0.0

@onready var _base: Node2D = $Base
@onready var _body: Node2D = $Body
@onready var _overlay: Node2D = $Overlay


func _ready() -> void:
	_base.draw.connect(_draw_base)
	_body.draw.connect(_draw_body)
	_overlay.draw.connect(_draw_overlay)


func bind(u: SimUnit, p_grid_height: int, p_objective_kind: int = OBJ_NONE) -> void:
	unit = u
	grid_height = p_grid_height
	objective_kind = p_objective_kind
	_build_sprite()
	_build_light()
	snap()


func has_sprite() -> bool:
	return _sprite != null


func _build_sprite() -> void:
	var tex: Texture2D = Art.texture(str(unit.def.visuals.get("sprite", "")))
	if tex == null:
		return
	var s: float = SPRITE_SCALE * _scale()
	_outline = Sprite2D.new()
	_outline.texture = tex
	_outline.offset = Vector2(0.0, SPRITE_FEET_OFFSET)
	_outline.scale = Vector2(s, s)
	_outline.material = Art.material("outline")
	_outline.visible = selected
	_body.add_child(_outline)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.offset = Vector2(0.0, SPRITE_FEET_OFFSET)
	_sprite.scale = Vector2(s, s)
	_body_material = Art.material("breathing")
	_body_material.set_shader_parameter("seed", float(unit.id % 17) / 17.0)
	_sprite.material = _body_material
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_body.add_child(_sprite)
	# 默认面向右；敌方开局在右侧，面向左
	_facing = FacingTracker.new(unit.faction == SimTypes.Faction.ENEMY)
	_apply_flip()
	_body.queue_redraw()


func _build_light() -> void:
	_light = PointLight2D.new()
	_light.texture = Art.light_texture()
	_light.texture_scale = LIGHT_SCALE * _scale()
	_light.energy = LIGHT_ENERGY
	var fallback: Color = Palette.BONE if unit.faction == SimTypes.Faction.ALLY else Palette.WARN_RED
	_light.color = Art.color_from_hex(str(unit.def.visuals.get("light_color", "")), fallback)
	_light.position = Vector2(0.0, -40.0)
	add_child(_light)


## 直接对齐到当前模拟位置（部署、暂停、重建时）
func snap() -> void:
	prev_pos = unit.pos
	cur_pos = unit.pos
	position = SimTypes.sim_to_screen(cur_pos, grid_height)


## 一个 tick 推进后更新插值端点；sim_dt = 本 tick 推进的模拟时间（用于朝向迟滞计时）
func push_pos(sim_dt: float = SimTypes.SIM_DT) -> void:
	prev_pos = cur_pos
	cur_pos = unit.pos
	var retreating: bool = is_retreating()
	if _facing.update(cur_pos.x - prev_pos.x, sim_dt, RETREAT_FLIP_CELLS if retreating else FacingTracker.FLIP_CELLS, RETREAT_FLIP_SECONDS if retreating else FacingTracker.FLIP_SECONDS):
		_flip_transition()
	_set_lean(_facing.backstep)


## 翻转：0.12 s 内横向缩放到 0 → 换朝向 → 恢复
func _flip_transition() -> void:
	if _sprite == null:
		return
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = _new_tween()
	_flip_tween.tween_property(_body, "scale:x", 0.0, FLIP_SECONDS * 0.5)
	_flip_tween.tween_callback(_apply_flip)
	_flip_tween.tween_property(_body, "scale:x", 1.0, FLIP_SECONDS * 0.5)


func _apply_flip() -> void:
	if _sprite != null:
		_sprite.flip_h = _facing.facing_left
		_outline.flip_h = _facing.facing_left


## 背步：不翻转，身体朝背后方向后仰
func _set_lean(on: bool) -> void:
	if on == _leaning or _sprite == null:
		return
	_leaning = on
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	var target: float = 0.0
	if on:
		target = deg_to_rad(BACKSTEP_LEAN_DEG) * (1.0 if _facing.facing_left else -1.0)
	_lean_tween = _new_tween()
	_lean_tween.tween_property(_body, "rotation", target, BACKSTEP_TWEEN)


## 特殊目标（07 §6）：objectives 引用的 spawn 或 tags 含 objective/protect。
## 保护对象（unit_dead / survive 目标、protect 标签）= 盾；摧毁目标中建筑 = 裂纹、单位 = 骷髅
static func objective_kind_for(level: LevelDefinition, u: SimUnit) -> int:
	if level == null or u == null or u.spawn_id == "":
		return OBJ_NONE
	for o: ObjectiveDef in level.lose:
		if o.type == SimTypes.ObjectiveType.UNIT_DEAD and o.target == u.spawn_id:
			return OBJ_PROTECT
	for o: ObjectiveDef in level.win:
		if (o.type == SimTypes.ObjectiveType.SURVIVE or o.type == SimTypes.ObjectiveType.ESCORT) and o.target == u.spawn_id:
			return OBJ_PROTECT
		if o.type == SimTypes.ObjectiveType.DESTROY and o.targets.has(u.spawn_id):
			return OBJ_DESTROY if u.is_structure() else OBJ_KILL
	if u.tags.has("protect"):
		return OBJ_PROTECT
	if u.tags.has("objective"):
		return OBJ_DESTROY if u.is_structure() else OBJ_KILL
	return OBJ_NONE


## 顶栏任务句被点击：目标闪烁几次
func flash() -> void:
	if is_dying:
		return
	var t: Tween = _new_tween()
	for i: int in FLASH_TIMES:
		t.tween_property(self, "modulate", Color(1.8, 1.5, 0.7, 1.0), FLASH_HALF_SECONDS)
		t.tween_property(self, "modulate", Color.WHITE, FLASH_HALF_SECONDS)


func is_retreating() -> bool:
	return unit != null and unit.alive and unit.current_action == SimTypes.ActionType.RETREAT


func _process(delta: float) -> void:
	if unit == null:
		return
	var p: Vector2 = cur_pos
	if interpolate:
		p = prev_pos.lerp(cur_pos, Engine.get_physics_interpolation_fraction())
	var target: Vector2 = SimTypes.sim_to_screen(p, grid_height)
	var before: Vector2 = position
	if interpolate and is_retreating():
		if _smooth == Vector2.INF:
			_smooth = position
		_smooth = _smooth.lerp(target, 1.0 - exp(-delta / RETREAT_SMOOTH_TAU))
		position = _smooth
		_ghost_clock += delta
		if _ghost_clock >= AFTERIMAGE_INTERVAL and before.distance_to(position) >= AFTERIMAGE_MIN_PX:
			_ghost_clock = 0.0
			_spawn_afterimage()
	else:
		_smooth = Vector2.INF
		position = target
	_overlay.queue_redraw()
	if objective_kind != OBJ_NONE:
		_base.queue_redraw()     # 金色脉动


## 残影：当前精灵的一份拷贝留在原地（单位层内、画在本单位之后），淡紫色、渐隐后释放
func _spawn_afterimage() -> void:
	if _sprite == null or get_parent() == null or not UiKit.motion_enabled:
		return
	var g := Sprite2D.new()
	g.name = "Afterimage"
	g.texture = _sprite.texture
	g.offset = _sprite.offset
	g.scale = _sprite.scale * Vector2(_body.scale.x, 1.0)
	g.flip_h = _sprite.flip_h
	g.rotation = _body.rotation
	g.position = position + _body.position
	g.texture_filter = _sprite.texture_filter
	g.modulate = Color(AFTERIMAGE_TINT, AFTERIMAGE_ALPHA)
	get_parent().add_child(g)
	get_parent().move_child(g, get_index())
	var t: Tween = g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, AFTERIMAGE_LIFE)
	t.tween_callback(g.queue_free)


func play_attack(target_screen_pos: Vector2) -> void:
	if is_dying:
		return
	var dir: Vector2 = (target_screen_pos - position).normalized()
	if absf(dir.x) > 0.1 and _facing.face(dir.x < 0.0):
		_flip_transition()
	_set_lean(false)
	var t: Tween = _new_tween()
	t.tween_property(_body, "position", dir * LUNGE_PX, 0.08)
	t.tween_property(_body, "position", Vector2.ZERO, 0.15)


func play_hit() -> void:
	if is_dying:
		return
	if _body_material != null:
		_set_flash(1.0)
		var f: Tween = _new_tween()
		f.tween_method(_set_flash, 1.0, 0.0, 0.08)
	else:
		var t: Tween = _new_tween()
		_body.modulate = Color(3.0, 3.0, 3.0, 1.0)
		t.tween_property(_body, "modulate", Color.WHITE, 0.08)
	var s: Tween = _new_tween()
	s.tween_property(_body, "position", Vector2(2.0, 0.0), 0.03)
	s.tween_property(_body, "position", Vector2(-2.0, 0.0), 0.03)
	s.tween_property(_body, "position", Vector2.ZERO, 0.03)


func _set_flash(v: float) -> void:
	if _body_material != null:
		_body_material.set_shader_parameter("flash", v)


func play_death() -> void:
	if is_dying:
		return
	is_dying = true
	_base.queue_redraw()
	if _outline != null:
		_outline.visible = false
	var t: Tween = _new_tween()
	if _sprite != null:
		var dm: ShaderMaterial = Art.material("dissolve")
		_sprite.material = dm
		t.tween_method(func(v: float) -> void: dm.set_shader_parameter("progress", v), 0.0, 1.0, DEATH_SECONDS)
		t.parallel().tween_property(_base, "modulate:a", 0.0, DEATH_SECONDS)
	else:
		t.tween_property(self, "modulate:a", 0.0, DEATH_SECONDS)
	if _light != null:
		t.parallel().tween_property(_light, "energy", 0.0, DEATH_SECONDS)
	t.tween_callback(queue_free)


func _new_tween() -> Tween:
	var t: Tween = create_tween()
	_tweens.append(t)
	return t


func _exit_tree() -> void:
	for t: Tween in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()


func _faction_color() -> Color:
	if unit.is_structure():
		return Palette.ALCHEMY_GOLD
	return Palette.BONE if unit.faction == SimTypes.Faction.ALLY else Palette.WARN_RED


func _scale() -> float:
	return float(unit.def.visuals.get("scale", 1.0)) if unit != null and unit.def != null else 1.0


func _draw_base() -> void:
	if unit == null:
		return
	var r: float = BASE_RADIUS * _scale()
	_base.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))   # 3/4 视角椭圆
	_base.draw_circle(Vector2.ZERO, r * 1.05, Color(0.0, 0.0, 0.0, 0.35))
	var c: Color = _faction_color()
	if unit.is_structure():
		_base.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), c, false, 3.0)
	elif unit.faction == SimTypes.Faction.ALLY:
		_base.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 3.0)
		_base.draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 48, Color(c, 0.4), 1.5)
	else:
		# 荆棘八角：顶点在内外半径间交替 + 8 根外凸尖刺（灰度下也能凭形状与己方圆环区分，04 §4.5-2）
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 17:
			var ang: float = TAU * float(i) / 16.0
			var rr: float = r if i % 2 == 0 else r * 0.78
			pts.append(Vector2(cos(ang), sin(ang)) * rr)
		_base.draw_polyline(pts, Palette.WARN_RED, 4.0)
		for i: int in 8:
			var a: float = TAU * float(i) / 8.0
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x) * r * 0.12
			_base.draw_colored_polygon(PackedVector2Array([dir * r + side, dir * r * 1.32, dir * r - side]), Palette.WARN_RED)
	if objective_kind != OBJ_NONE and not is_dying:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * OBJ_PULSE_HZ)
		_base.draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 48, Color(Palette.ALCHEMY_GOLD, 0.35 + 0.5 * pulse), 3.0 + 2.0 * pulse)
	if selected and not is_dying:
		_base.draw_arc(Vector2.ZERO, r * 1.3, 0.0, TAU, 48, Palette.ALCHEMY_GOLD, 3.0)
	_base.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body() -> void:
	if unit == null or _sprite != null:
		return
	var r: float = BODY_RADIUS * _scale()
	var center := Vector2(0.0, -r * 0.8)
	if unit.is_structure():
		var pts: PackedVector2Array = PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
		_body.draw_colored_polygon(pts, Palette.ALCHEMY_GOLD)
	elif unit.faction == SimTypes.Faction.ALLY:
		_body.draw_circle(center, r, Palette.BONE)
		_body.draw_circle(center, r * 0.45, Palette.FLESH)
	else:
		_body.draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), Palette.FLESH)
		_body.draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), Palette.WARN_RED, false, 2.0)


func _hp_offset_y() -> float:
	return HP_OFFSET_Y * _scale()


func _head_offset_y() -> float:
	return (SPRITE_HEAD_OFFSET_Y if _sprite != null else HEAD_OFFSET_Y) * _scale()


func _draw_overlay() -> void:
	if unit == null or is_dying:
		return
	var state_x: float = 0.0
	if objective_kind != OBJ_NONE:
		_draw_objective_icon(Vector2(0.0, _head_offset_y() - OBJ_ICON_SIZE * 0.5 - 6.0), objective_kind)
		state_x = OBJ_ICON_SIZE
	if show_state:
		_draw_state_icon(Vector2(state_x, _head_offset_y() - 20.0), RuleText.state_kind(unit))
	var ratio: float = clampf(unit.hp / unit.max_hp, 0.0, 1.0)
	var top_left := Vector2(-HP_WIDTH * 0.5, _hp_offset_y())
	var bg := Rect2(top_left, Vector2(HP_WIDTH, HP_HEIGHT))
	var fill := Rect2(top_left, Vector2(HP_WIDTH * ratio, HP_HEIGHT))
	var c: Color = _faction_color()
	if unit.is_structure():
		_overlay.draw_rect(bg, Palette.VIOLET_DEEP)
		_overlay.draw_rect(fill, c)
		_overlay.draw_rect(bg, c, false, 1.0)
	elif unit.faction == SimTypes.Faction.ALLY:
		# 己方：圆角条
		var h: float = HP_HEIGHT * 0.5
		_overlay.draw_circle(top_left + Vector2(0.0, h), h, Palette.VIOLET_DEEP)
		_overlay.draw_circle(top_left + Vector2(HP_WIDTH, h), h, Palette.VIOLET_DEEP)
		_overlay.draw_rect(bg, Palette.VIOLET_DEEP)
		_overlay.draw_rect(fill, c)
	else:
		# 敌方：两端尖角
		var mid_y: float = top_left.y + HP_HEIGHT * 0.5
		var outline := PackedVector2Array([
			Vector2(top_left.x - HP_HEIGHT, mid_y), top_left, top_left + Vector2(HP_WIDTH, 0.0),
			Vector2(top_left.x + HP_WIDTH + HP_HEIGHT, mid_y), top_left + Vector2(HP_WIDTH, HP_HEIGHT), top_left + Vector2(0.0, HP_HEIGHT),
		])
		_overlay.draw_colored_polygon(outline, Palette.VIOLET_DEEP)
		_overlay.draw_rect(fill, c)
		var closed: PackedVector2Array = outline.duplicate()
		closed.append(outline[0])
		_overlay.draw_polyline(closed, Palette.BONE_DIM, 1.5)   # 浅色轮廓：灰度下尖角形状可辨


## 待机状态图标：有 icons/state_*.svg 时用图标，否则程序绘制。1 待机；2 受阻；3 目标不在射程
func _draw_state_icon(c: Vector2, kind: int) -> void:
	var icon_names: Array[String] = ["", "state_idle", "state_blocked", "state_out_of_range"]
	if kind > 0:
		var icon: Texture2D = Art.texture("ui/icons/%s.svg" % icon_names[kind])
		if icon != null:
			_overlay.draw_texture_rect(icon, Rect2(c - Vector2(12.0, 12.0), Vector2(24.0, 24.0)), false)
			return
	match kind:
		1:
			for z: Vector2 in [Vector2(-6.0, 2.0), Vector2(5.0, -7.0)]:
				var o: Vector2 = c + z
				var pts := PackedVector2Array([o + Vector2(-5, -5), o + Vector2(5, -5), o + Vector2(-5, 5), o + Vector2(5, 5)])
				_overlay.draw_polyline(pts, Palette.BONE, 2.0)
		2:
			_overlay.draw_arc(c, 9.0, 0.0, TAU, 24, Palette.WARN_RED, 2.5)
			_overlay.draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), Palette.WARN_RED, 2.5)
		3:
			_overlay.draw_arc(c, 9.0, 0.0, TAU, 24, Palette.ALCHEMY_GOLD, 2.0)
			_overlay.draw_circle(c, 2.5, Palette.ALCHEMY_GOLD)
			_overlay.draw_line(c + Vector2(4, 4), c + Vector2(12, 12), Palette.WARN_RED, 2.5)
			_overlay.draw_line(c + Vector2(12, 4), c + Vector2(4, 12), Palette.WARN_RED, 2.5)


## 特殊目标图标（程序绘制：骷髅 / 盾 / 裂纹），金色填充 + 深色描边
func _draw_objective_icon(c: Vector2, kind: int) -> void:
	var h: float = OBJ_ICON_SIZE * 0.5
	var gold: Color = Palette.ALCHEMY_GOLD
	var dark: Color = Palette.BG_DEEP
	_overlay.draw_circle(c, h + 3.0, Color(dark, 0.75))
	match kind:
		OBJ_KILL:
			_overlay.draw_circle(c + Vector2(0.0, -2.0), h * 0.72, gold)
			_overlay.draw_rect(Rect2(c + Vector2(-h * 0.42, h * 0.25), Vector2(h * 0.84, h * 0.5)), gold)
			_overlay.draw_circle(c + Vector2(-h * 0.3, -2.0), h * 0.2, dark)
			_overlay.draw_circle(c + Vector2(h * 0.3, -2.0), h * 0.2, dark)
			for k: int in 3:
				var x: float = -h * 0.25 + h * 0.25 * float(k)
				_overlay.draw_line(c + Vector2(x, h * 0.3), c + Vector2(x, h * 0.72), dark, 1.5)
		OBJ_PROTECT:
			var pts := PackedVector2Array([c + Vector2(-h * 0.75, -h * 0.7), c + Vector2(h * 0.75, -h * 0.7),
				c + Vector2(h * 0.7, h * 0.05), c + Vector2(0.0, h * 0.85), c + Vector2(-h * 0.7, h * 0.05)])
			_overlay.draw_colored_polygon(pts, gold)
			_overlay.draw_line(c + Vector2(0.0, -h * 0.55), c + Vector2(0.0, h * 0.6), dark, 2.0)
		OBJ_DESTROY:
			var dia := PackedVector2Array([c + Vector2(0.0, -h * 0.85), c + Vector2(h * 0.75, 0.0), c + Vector2(0.0, h * 0.85), c + Vector2(-h * 0.75, 0.0)])
			_overlay.draw_colored_polygon(dia, gold)
			_overlay.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.1, -h * 0.85), c + Vector2(h * 0.15, -h * 0.25),
				c + Vector2(-h * 0.2, h * 0.1), c + Vector2(h * 0.1, h * 0.85)]), dark, 2.0)
