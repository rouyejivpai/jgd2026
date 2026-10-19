class_name UnitView
extends Node2D
## 单位表现（01 §8 UnitView）。只读 SimUnit，不写模拟数据。
## M7：Q 版精灵（visuals.sprite，脚底锚定、向左移动水平翻转）、呼吸着色器、受击白闪、死亡溶解、选中描边、
## 每单位 PointLight2D。资源缺失时回退 M2 的程序绘制占位。
## 阵营区分不只靠颜色（策划已定）：底座形状（己方圆环 / 敌方荆棘八角 / 建筑方框）与血条形状（圆角 / 尖角 / 方角）。
## 第二阶段：朝向迟滞与背步（A04，FacingTracker）；特殊目标头顶常驻图标 + 底座金色脉动（A03）。
## 第四阶段（用户 2026-10-08「撤离时容易抽搐」）：撤离中 ① 翻身阈值加大（RETREAT_FLIP_*，多数时候以后仰背步代替翻身）；
## ② 显示位置做短时平滑（2026-10-19 起由通用的显示弹簧 _spring_to 承担）；③ 移动时留下渐隐残影（AFTERIMAGE_*）。只碰表现。
## 2026-10-19 敌我都用 Q 版人物：阵营光效（UnitAura）——己方金色光圈 + 身后金光与金色光点，敌方暗红光圈 + 身后暗红光芒与血滴；
## 光芒 / 粒子在 Aura 层（Base 与 Body 之间，被人物遮住），人物只有轮廓外一圈淡光（RimGlow，Body 内、本体之前）。
## 2026-10-19 战斗打击感：① 显示位置用临界阻尼弹簧追模拟位置（起步加速、匀速、停下减速，过渡约 0.2 s，无过冲）；
## ② 移动时一步一跳（Gait 节点：跳起高度 + 左右交替倾斜 + 落地压扁），每落一步发 footstep 信号留脚印；
## ③ 受击背离攻击者小幅后挫并压扁；④ 击败：白闪 → 背离击杀者击飞（落点限制在 bounds 内）→ 灰化 → 自上而下化为灰烬粒子。

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
const LIGHT_ENERGY: float = 0.32          ## 2026-10-18 哥特暗黑童话：场景半压暗，单位光做出烛光般的光池
const LIGHT_SCALE: float = 2.6
const DEATH_SECONDS: float = 1.0
const RETREAT_FLIP_CELLS: float = 1.2
const RETREAT_FLIP_SECONDS: float = 0.9
const AFTERIMAGE_INTERVAL: float = 0.06   ## 秒：残影间隔
const AFTERIMAGE_LIFE: float = 0.3        ## 秒：残影渐隐时长
const AFTERIMAGE_ALPHA: float = 0.45
const AFTERIMAGE_TINT: Color = Color(1.0, 0.86, 0.55)          ## 己方金色残影
const AFTERIMAGE_TINT_ENEMY: Color = Color(1.0, 0.42, 0.42)    ## 敌方红色残影
const AFTERIMAGE_MIN_PX: float = 0.6      ## 每帧显示位移不足该像素不留残影（原地不动时）
const RING_PULSE_HZ: float = 0.45         ## 阵营光圈呼吸
const SELECT_COLOR: Color = Color(1.5, 1.45, 1.3, 1.0)   ## 选中环：亮白（金色已用作己方光圈）
const MOVE_OMEGA: float = 22.0            ## 显示位置弹簧角频率：越大越跟手；加减速过渡约 4.7 / ω 秒
const HOP_PX: float = 9.0                 ## 每步跳起高度（像素，乘单位缩放）
const SWAY_DEG: float = 8.0               ## 每步左右倾斜（以脚底为轴）
const LAND_SQUASH: float = 0.07           ## 落地压扁幅度
const GAIT_SPEED_MIN: float = 14.0        ## 显示速度（像素/秒）低于此不跳
const GAIT_SPEED_FULL: float = 70.0       ## 显示速度达到此时跳动幅度满额
const STEP_RATE: Vector2 = Vector2(3.2, 6.5)   ## 每秒步数范围（随速度）
const FOOT_SPREAD_PX: float = 7.0         ## 左右脚印离行进中线的距离
const CHEST_Y: float = -46.0              ## 胸口高度（像素，乘单位缩放）：射弹出手 / 命中、斩击中心、碎屑起点
const HIT_KNOCK_PX: float = 6.0
const KNOCK_PX: float = 110.0             ## 击飞距离（像素，乘单位缩放；被 bounds 截短）
const KNOCK_SECONDS: float = 0.42
const KNOCK_HEIGHT: float = 46.0
const GRAY_SECONDS: float = 0.28
const ASH_SECONDS: float = 0.95           ## 自上而下化为粒子

signal footstep(pos: Vector2, ally: bool, size: float)

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
var _rim: Sprite2D = null
var _aura: Node2D = null
var _body_material: ShaderMaterial = null
var _light: PointLight2D = null
var _facing: FacingTracker = FacingTracker.new()
var _flip_tween: Tween = null
var _lean_tween: Tween = null
var _leaning: bool = false
var _ghost_clock: float = 0.0
var _gait: Node2D = null                 ## 精灵的父节点（Body 之内）：跳动 / 倾斜 / 压扁只作用于人物
var _vel: Vector2 = Vector2.ZERO         ## 显示位置速度（本层像素 / 秒）
var _gait_phase: float = 0.0             ## 每 π 一步
var _gait_amt: float = 0.0               ## 跳动幅度 0–1（随速度平滑）
var _ash: CPUParticles2D = null          ## 击败灰烬发射器（挂在单位层，跟随剔除线）
var _ash_cut: float = 0.0

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
	_build_aura()
	_build_light()
	snap()


func has_sprite() -> bool:
	return _sprite != null


func _build_sprite() -> void:
	var tex: Texture2D = Art.texture(str(unit.def.visuals.get("sprite", "")))
	if tex == null:
		return
	var s: float = SPRITE_SCALE * _scale()
	var seed: float = float(unit.id % 17) / 17.0
	_gait = Node2D.new()
	_gait.name = "Gait"
	_body.add_child(_gait)
	if not unit.is_structure():
		_rim = UnitAura.rim_sprite(unit.faction == SimTypes.Faction.ALLY, tex, Vector2(0.0, SPRITE_FEET_OFFSET), s, seed)
		_gait.add_child(_rim)
	_outline = Sprite2D.new()
	_outline.texture = tex
	_outline.offset = Vector2(0.0, SPRITE_FEET_OFFSET)
	_outline.scale = Vector2(s, s)
	_outline.material = Art.material("outline")
	_outline.visible = selected
	_gait.add_child(_outline)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.offset = Vector2(0.0, SPRITE_FEET_OFFSET)
	_sprite.scale = Vector2(s, s)
	_body_material = Art.material("breathing")
	_body_material.set_shader_parameter("seed", seed)
	_sprite.material = _body_material
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_gait.add_child(_sprite)
	# 默认面向右；敌方开局在右侧，面向左
	_facing = FacingTracker.new(unit.faction == SimTypes.Faction.ENEMY)
	_apply_flip()
	_body.queue_redraw()


## 阵营光效层：Base 之后、Body 之前（光芒与粒子被人物本体遮住）
func _build_aura() -> void:
	if _sprite == null or unit.is_structure():
		return
	_aura = Node2D.new()
	_aura.name = "Aura"
	add_child(_aura)
	move_child(_aura, _base.get_index() + 1)
	UnitAura.build(_aura, unit.faction == SimTypes.Faction.ALLY, _sprite.texture, _sprite.scale.x, SPRITE_FEET_OFFSET, float(unit.id % 17) / 17.0, unit.def.id)


func _build_light() -> void:
	_light = PointLight2D.new()
	_light.texture = Art.light_texture()
	_light.texture_scale = LIGHT_SCALE * _scale()
	_light.energy = LIGHT_ENERGY
	var fallback: Color = Palette.BONE if unit.faction == SimTypes.Faction.ALLY else Palette.WARN_RED
	_light.color = Art.color_from_hex(str(unit.def.visuals.get("light_color", "")), fallback)
	_light.position = Vector2(0.0, -40.0)
	add_child(_light)


## 直接对齐到当前模拟位置（部署、重建时）
func snap() -> void:
	prev_pos = unit.pos
	cur_pos = unit.pos
	position = SimTypes.sim_to_screen(cur_pos, grid_height)
	_vel = Vector2.ZERO


## 暂停 / 结束：插值端点对齐到模拟位置，显示位置由弹簧平滑停过去（不跳变）
func settle() -> void:
	prev_pos = unit.pos
	cur_pos = unit.pos


## 胸口相对脚底的偏移（本层像素）
func chest_offset() -> Vector2:
	return Vector2(0.0, CHEST_Y * _scale())


func chest_pos() -> Vector2:
	return position + chest_offset()


func view_scale() -> float:
	return _scale()


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
		if _rim != null:
			_rim.flip_h = _facing.facing_left


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
	if is_dying:
		_update_ash()
		return
	var p: Vector2 = cur_pos
	if interpolate:
		p = prev_pos.lerp(cur_pos, Engine.get_physics_interpolation_fraction())
	var target: Vector2 = SimTypes.sim_to_screen(p, grid_height)
	var before: Vector2 = position
	_spring_to(target, delta)
	if interpolate and is_retreating():
		_ghost_clock += delta
		if _ghost_clock >= AFTERIMAGE_INTERVAL and before.distance_to(position) >= AFTERIMAGE_MIN_PX:
			_ghost_clock = 0.0
			_spawn_afterimage()
	_update_gait(delta)
	_overlay.queue_redraw()
	if objective_kind != OBJ_NONE or not unit.is_structure():
		_base.queue_redraw()     # 金色脉动 / 阵营光圈呼吸


## 临界阻尼弹簧（SmoothDamp 精确解）：起步加速、匀速时略滞后、停下时减速贴合，无过冲。也吸收撤离点切换造成的来回小位移
func _spring_to(target: Vector2, delta: float) -> void:
	if position.distance_squared_to(target) < 0.0001 and _vel.length_squared() < 0.01:
		position = target
		_vel = Vector2.ZERO
		return
	var x: Vector2 = position - target
	var e: float = exp(-MOVE_OMEGA * delta)
	var tmp: Vector2 = (_vel + x * MOVE_OMEGA) * delta
	_vel = (_vel - tmp * MOVE_OMEGA) * e
	position = target + (x + tmp) * e


## 一步一跳：|sin| 为跳起高度，sin 的正负交替为左右倾斜（左右脚交替），落地瞬间轻微压扁；每落一步留一个脚印
func _update_gait(delta: float) -> void:
	if _gait == null:
		return
	var spd: float = _vel.length()
	var want: float = clampf((spd - GAIT_SPEED_MIN) / (GAIT_SPEED_FULL - GAIT_SPEED_MIN), 0.0, 1.0)
	_gait_amt = move_toward(_gait_amt, want, delta * 7.0)
	if _gait_amt <= 0.001:
		_gait_phase = 0.0
		_gait.position = Vector2.ZERO
		_gait.rotation = 0.0
		_gait.scale = Vector2.ONE
		if _aura != null:
			_aura.position = Vector2.ZERO
		return
	var rate: float = clampf(STEP_RATE.x + spd / float(SimTypes.TILE_SIZE) * 0.9, STEP_RATE.x, STEP_RATE.y)
	var step_before: int = int(floor(_gait_phase / PI))
	_gait_phase += PI * rate * delta
	var step_now: int = int(floor(_gait_phase / PI))
	var sn: float = sin(_gait_phase)
	var h: float = absf(sn) * HOP_PX * _scale() * _gait_amt
	var squash: float = pow(1.0 - absf(sn), 6.0) * LAND_SQUASH * _gait_amt
	_gait.position = Vector2(0.0, -h)
	_gait.rotation = sn * deg_to_rad(SWAY_DEG) * _gait_amt
	_gait.scale = Vector2(1.0 + squash, 1.0 - squash)
	if _aura != null:
		_aura.position = _gait.position
	if step_now != step_before and _gait_amt > 0.3 and spd > GAIT_SPEED_MIN:
		var side: float = 1.0 if step_now % 2 == 0 else -1.0
		var across: Vector2 = _vel.normalized().orthogonal() * Vector2(1.0, 0.6)
		footstep.emit(position + across * FOOT_SPREAD_PX * side * _scale(), unit.faction == SimTypes.Faction.ALLY, _scale())


## 残影：当前精灵的一份拷贝留在原地（单位层内、画在本单位之后），阵营色（己方金 / 敌方红）、渐隐后释放
func _spawn_afterimage() -> void:
	if _sprite == null or get_parent() == null or not UiKit.motion_enabled:
		return
	var g := Sprite2D.new()
	g.name = "Afterimage"
	g.texture = _sprite.texture
	g.offset = _sprite.offset
	g.scale = _sprite.scale * Vector2(_body.scale.x, 1.0) * _gait.scale
	g.flip_h = _sprite.flip_h
	g.rotation = _body.rotation + _gait.rotation
	g.position = position + _body.position + _gait.position
	g.texture_filter = _sprite.texture_filter
	g.modulate = Color(AFTERIMAGE_TINT if unit.faction == SimTypes.Faction.ALLY else AFTERIMAGE_TINT_ENEMY, AFTERIMAGE_ALPHA)
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


## dir：攻击者 → 本单位的方向（零向量 = 原地抖动）。白闪 + 背离攻击者后挫 + 压扁回弹
func play_hit(dir: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return
	if _body_material != null:
		_set_flash(1.0)
		var f: Tween = _new_tween()
		f.tween_method(_set_flash, 1.0, 0.0, 0.1)
	else:
		var t: Tween = _new_tween()
		_body.modulate = Color(3.0, 3.0, 3.0, 1.0)
		t.tween_property(_body, "modulate", Color.WHITE, 0.08)
	var s: Tween = _new_tween()
	if dir.length() > 0.01:
		var knock: Vector2 = dir.normalized() * Vector2(1.0, 0.5) * HIT_KNOCK_PX * _scale()
		s.tween_property(_body, "position", knock, 0.04).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		s.tween_property(_body, "position", Vector2.ZERO, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		s.tween_property(_body, "position", Vector2(2.0, 0.0), 0.03)
		s.tween_property(_body, "position", Vector2(-2.0, 0.0), 0.03)
		s.tween_property(_body, "position", Vector2.ZERO, 0.03)
	var q: Tween = _new_tween()
	q.tween_property(_body, "scale:y", 0.88, 0.04)
	q.tween_property(_body, "scale:y", 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _set_flash(v: float) -> void:
	if _body_material != null:
		_body_material.set_shader_parameter("flash", v)


## 击败：白闪 → 背离击杀者击飞（抛物线 + 翻转，落点限制在 bounds 内，不出战场 / 屏幕）→ 落地一弹 → 灰化 →
## 自上而下化为灰烬粒子（剔除线由 death_ash 着色器画，粒子发射器跟随剔除线）→ 释放。
## dir：击杀者 → 本单位方向（零向量 = 按朝向向后）；bounds：本层坐标下允许的脚底落点范围（空 = 不限制）
func play_death(dir: Vector2 = Vector2.ZERO, bounds: Rect2 = Rect2()) -> void:
	if is_dying:
		return
	is_dying = true
	_vel = Vector2.ZERO
	_base.queue_redraw()
	_overlay.queue_redraw()
	if _outline != null:
		_outline.visible = false
	for tw: Tween in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	_body.position = Vector2.ZERO
	_body.scale = Vector2(1.0, 1.0)
	if _gait != null:
		_gait.position = Vector2.ZERO
		_gait.rotation = 0.0
		_gait.scale = Vector2.ONE
	if _sprite == null:
		_death_fallback()
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2(1.0 if _facing.facing_left else -1.0, 0.0)
	var rooted: bool = unit.is_structure()            # 建筑不击飞、不翻转：原地闪白 → 灰化 → 自上而下崩成灰烬
	var dest: Vector2 = position if rooted else position + d * Vector2(1.0, 0.55) * KNOCK_PX * _scale()
	if bounds.has_area():
		dest = Vector2(clampf(dest.x, bounds.position.x, bounds.end.x), clampf(dest.y, bounds.position.y, bounds.end.y))
	# 着色器：灰化 + 自上而下剔除（同时承担白闪）
	var vis: Rect2i = UnitAura.visible_rect(_sprite.texture)
	var th: float = float(_sprite.texture.get_height())
	var dm: ShaderMaterial = Art.material("death_ash")
	dm.set_shader_parameter("uv_top", float(vis.position.y) / th)
	dm.set_shader_parameter("uv_bottom", float(vis.end.y) / th)
	dm.set_shader_parameter("edge_color", Color(1.0, 0.86, 0.6) if unit.faction == SimTypes.Faction.ALLY else Color(1.0, 0.45, 0.4))
	dm.set_shader_parameter("flash", 1.0)
	_sprite.material = dm
	var spin: float = 0.0 if rooted else (1.0 if d.x >= 0.0 else -1.0) * deg_to_rad(28.0)
	var lift: float = 0.0 if rooted else KNOCK_HEIGHT
	var t: Tween = _new_tween()
	# 击飞：水平缓出 + 抛物线高度 + 向后翻
	t.tween_method(func(v: float) -> void: dm.set_shader_parameter("flash", v), 1.0, 0.0, 0.16)
	t.parallel().tween_property(self, "position", dest, KNOCK_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_method(func(k: float) -> void: _gait.position = Vector2(0.0, -lift * _scale() * 4.0 * k * (1.0 - k)), 0.0, 1.0, KNOCK_SECONDS)
	t.parallel().tween_property(_gait, "rotation", spin, KNOCK_SECONDS * 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _rim != null:
		t.parallel().tween_property(_rim, "modulate:a", 0.0, 0.2)
	if _aura != null:
		t.parallel().tween_property(_aura, "modulate:a", 0.0, 0.3)
		for c: Node in _aura.get_children():
			if c is CPUParticles2D:
				(c as CPUParticles2D).emitting = false
	t.parallel().tween_property(_base, "modulate:a", 0.0, KNOCK_SECONDS)
	if _light != null:
		t.parallel().tween_property(_light, "energy", 0.0, KNOCK_SECONDS + GRAY_SECONDS)
	# 落地：压扁一下、再弹起一点；同时灰化
	t.tween_property(_gait, "scale", Vector2(1.12, 0.86), 0.06)
	t.parallel().tween_method(func(v: float) -> void: dm.set_shader_parameter("gray", v), 0.0, 1.0, GRAY_SECONDS)
	t.tween_method(func(k: float) -> void: _gait.position = Vector2(0.0, -lift * 0.22 * _scale() * 4.0 * k * (1.0 - k)), 0.0, 1.0, 0.16)
	t.parallel().tween_property(_gait, "scale", Vector2.ONE, 0.16)
	t.parallel().tween_property(_gait, "rotation", spin * 0.55, 0.16)
	t.tween_interval(maxf(0.0, GRAY_SECONDS - 0.22))
	# 自上而下化为灰烬
	t.tween_callback(_start_ash)
	t.tween_method(_set_ash_cut.bind(dm), 0.0, 1.0, ASH_SECONDS)
	t.tween_callback(_stop_ash)
	t.tween_callback(queue_free)


func _set_ash_cut(v: float, dm: ShaderMaterial) -> void:
	_ash_cut = v
	dm.set_shader_parameter("cut", v)


## 无精灵（占位绘制）：保持原来的整体淡出
func _death_fallback() -> void:
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


## 人物可见区域在本节点坐标下的纵向范围（x = 顶，y = 底）与宽度（z）
func _sprite_span() -> Vector3:
	var vis: Rect2i = UnitAura.visible_rect(_sprite.texture)
	var half: float = float(_sprite.texture.get_height()) * 0.5
	var s: float = _sprite.scale.y
	var top: float = (float(vis.position.y) - half + SPRITE_FEET_OFFSET) * s
	var bottom: float = (float(vis.end.y) - half + SPRITE_FEET_OFFSET) * s
	return Vector3(top, bottom, float(vis.size.x) * _sprite.scale.x)


## 灰烬发射器：挂在单位层（本单位释放后粒子仍飘完），z 抬高画在单位之上
func _start_ash() -> void:
	if get_parent() == null:
		return
	var span: Vector3 = _sprite_span()
	var lean: float = 1.0 if _gait.rotation >= 0.0 else -1.0
	var p := CPUParticles2D.new()
	p.name = "AshEmitter"
	p.z_index = 1
	p.local_coords = false
	p.texture = StatusParticles.dot_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(span.z * 0.36, 3.0)
	p.amount = 90
	p.lifetime = 1.0
	p.direction = Vector2(0.35 * lean, -1.0)
	p.spread = 40.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 75.0
	p.gravity = Vector2(25.0 * lean, -40.0)
	p.damping_min = 8.0
	p.damping_max = 20.0
	p.scale_amount_min = 2.0 / float(StatusParticles.TEX_SIZE)
	p.scale_amount_max = 5.0 / float(StatusParticles.TEX_SIZE)
	var g := Gradient.new()
	g.set_color(0, Color(1.6, 1.5, 1.4, 1.0))
	g.set_color(1, Color(0.35, 0.35, 0.36, 0.0))
	g.add_point(0.25, Color(0.78, 0.76, 0.75, 0.9))
	p.color_ramp = g
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = m
	p.emitting = true
	get_parent().add_child(p)
	_ash = p
	_ash_cut = 0.0
	_update_ash()


func _update_ash() -> void:
	if _ash == null or not is_instance_valid(_ash) or _sprite == null:
		return
	var span: Vector3 = _sprite_span()
	var y: float = lerpf(span.x, span.y, clampf(_ash_cut, 0.0, 1.0))
	_ash.position = position + _gait.position + Vector2(0.0, y).rotated(_gait.rotation)
	_ash.rotation = _gait.rotation


func _stop_ash() -> void:
	if _ash != null and is_instance_valid(_ash):
		_ash.emitting = false
		CombatFx.free_after(_ash, _ash.lifetime + 0.1)
	_ash = null


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
	else:
		_draw_faction_ring(r)
	if objective_kind != OBJ_NONE and not is_dying:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * OBJ_PULSE_HZ)
		_base.draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 48, Color(Palette.ALCHEMY_GOLD, 0.35 + 0.5 * pulse), 3.0 + 2.0 * pulse)
	if selected and not is_dying:
		_base.draw_arc(Vector2.ZERO, r * 1.3, 0.0, TAU, 48, SELECT_COLOR, 3.0)
	_base.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 阵营光圈（已在 3/4 视角椭圆变换下）：己方金色圆环；敌方暗红圆环 + 8 根外凸尖刺（灰度下仍凭形状区分，04 §4.5-2）。
## 外层宽淡弧 + 不透明芯弧 + 内细弧，HDR 提亮让光圈带辉光；整体缓慢呼吸。
func _draw_faction_ring(r: float) -> void:
	var ally: bool = unit.faction == SimTypes.Faction.ALLY
	var col: Color = UnitAura.ring_color(ally)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * RING_PULSE_HZ + float(unit.id % 7))
	var e: float = (2.0 if ally else 1.7) + 0.4 * pulse
	var hot := Color(col.r * e, col.g * e, col.b * e, 1.0)
	_base.draw_circle(Vector2.ZERO, r * 0.95, Color(col, 0.16 + 0.06 * pulse))
	_base.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(hot, 0.22 + 0.1 * pulse), 11.0)
	_base.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(hot, 0.95), 3.0)
	_base.draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 64, Color(hot, 0.45), 1.5)
	if not ally:
		for i: int in 8:
			var a: float = TAU * float(i) / 8.0 + TAU / 16.0
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x) * r * 0.1
			_base.draw_colored_polygon(PackedVector2Array([dir * r * 1.02 + side, dir * r * 1.28, dir * r * 1.02 - side]), Color(hot, 0.9))


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
