extends Node2D
## 目标连线（01 §8 TargetLines）：运行中每个单位锁定目标后，在它与目标之间画一条发光线（己方金色、敌方暗红）；
## 可在设置中关闭；highlight() 用于第二关首次失败后的强制高亮（关卡册 3.2）。
## 2026-10-19 战斗打击感：发光线 = 外晕 + 主色 + 亮芯三层，沿线有光点从攻击者流向目标；目标脚下一圈旋转的锁定环；
## 刚锁定 / 换目标时锁定环从大收拢到目标身上（LOCK_FLASH）。不受场景光照压暗。只碰表现。

const WIDTH: float = 3.0
const HIGHLIGHT_WIDTH: float = 4.0
const END_GAP: float = 22.0             ## 线两端离单位脚底的空隙（本层像素），不压在阵营光圈中心
const PULSE_HZ: float = 0.9             ## 光点流动频率（每秒走完全程的次数）
const LOCK_FLASH: float = 0.28          ## 秒：锁定收拢动画
const RETICLE_RADIUS: float = 30.0
const ALLY_COLOR: Color = Color(1.9, 1.35, 0.45)
const ALLY_GLOW: Color = Color(1.0, 0.62, 0.16)
const ENEMY_COLOR: Color = Color(0.85, 0.06, 0.1)
const ENEMY_GLOW: Color = Color(0.45, 0.0, 0.04)
## 光晕层：[线宽倍数, 不透明度]
const PASSES: Array = [[6.0, 0.14], [2.8, 0.32], [1.0, 0.95]]

var views: Dictionary = {}       ## unit id -> UnitView（与 BattleRoot 共用同一字典）
var world: SimWorld = null       ## 高亮时按模拟位置绘制（含刚倒下的目标）
var grid_height: int = 0
var enabled: bool = true
var _highlight_left: float = 0.0
var _locks: Dictionary = {}      ## unit id -> [目标 id, 锁定时刻]
var _time: float = 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func highlight(seconds: float) -> void:
	_highlight_left = seconds


func _process(delta: float) -> void:
	_time += delta
	if _highlight_left > 0.0:
		_highlight_left = maxf(0.0, _highlight_left - delta)
	if visible:
		queue_redraw()


func _draw() -> void:
	var hl: bool = _highlight_left > 0.0
	if hl and world != null:
		_draw_highlight()
		return
	if not enabled:
		return
	var seen: Dictionary = {}
	for id: int in views.keys():
		var v: UnitView = _alive(id)
		if v == null or v.unit.current_target < 0:
			continue
		var t: UnitView = _alive(v.unit.current_target)
		if t == null:
			continue
		seen[id] = true
		var lock: Array = _locks.get(id, []) as Array
		if lock.is_empty() or int(lock[0]) != t.unit.id:
			lock = [t.unit.id, _time]
			_locks[id] = lock
		var ally: bool = v.unit.faction == SimTypes.Faction.ALLY
		_draw_tether(v.position, t.position, ally, float(id % 7) * 0.137, WIDTH)
		_draw_reticle(t.position, ally, t.view_scale(), _time - float(lock[1]))
	for id: int in _locks.keys():
		if not seen.has(id):
			_locks.erase(id)


## 发光连线：两端留空隙，三层光晕，两颗光点沿线流向目标
func _draw_tether(a: Vector2, b: Vector2, ally: bool, phase: float, width: float) -> void:
	var dist: float = a.distance_to(b)
	if dist < END_GAP * 2.0 + 4.0:
		return
	var dir: Vector2 = (b - a) / dist
	var p0: Vector2 = a + dir * END_GAP
	var p1: Vector2 = b - dir * END_GAP
	var core: Color = ALLY_COLOR if ally else ENEMY_COLOR
	var glow: Color = ALLY_GLOW if ally else ENEMY_GLOW
	for pass_: Array in PASSES:
		var c: Color = glow if float(pass_[0]) > 1.5 else core
		var a0 := Color(c, float(pass_[1]) * 0.35)
		var a1 := Color(c, float(pass_[1]))
		draw_polyline_colors(PackedVector2Array([p0, p0.lerp(p1, 0.5), p1]), PackedColorArray([a0, a1, a1]), width * float(pass_[0]), true)
	var dot: Texture2D = StatusParticles.dot_texture()
	for k: int in 2:
		var u: float = fposmod(_time * PULSE_HZ + phase + float(k) * 0.5, 1.0)
		var at: Vector2 = p0.lerp(p1, u)
		var fade: float = sin(u * PI)
		var r: float = 9.0 * (0.6 + 0.4 * fade)
		draw_texture_rect(dot, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(glow, 0.9 * fade))
		draw_circle(at, 2.2, Color(core * 1.3, fade))


## 目标脚下的锁定环（3/4 视角椭圆）：三段弧缓慢旋转；刚锁定时从大到小收拢并闪亮
func _draw_reticle(at: Vector2, ally: bool, size: float, age: float) -> void:
	var core: Color = ALLY_COLOR if ally else ENEMY_COLOR
	var k: float = clampf(age / LOCK_FLASH, 0.0, 1.0)
	var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
	var r: float = RETICLE_RADIUS * size * lerpf(2.2, 1.0, ease_k)
	var alpha: float = lerpf(1.0, 0.6, ease_k)
	var spin: float = _time * 1.4 * (1.0 if ally else -1.0)
	draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
	for i: int in 3:
		var a0: float = spin + TAU * float(i) / 3.0
		draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 3.0 * 0.55, 12, Color(core, alpha), 2.5 + 2.0 * (1.0 - ease_k), true)
	if k < 1.0:
		draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 40, Color(core, 0.5 * (1.0 - k)), 6.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _alive(id: int) -> UnitView:
	var raw: Variant = views.get(id, null)
	if raw == null or not is_instance_valid(raw):
		return null
	var v: UnitView = raw as UnitView
	return v if not v.is_dying and v.unit != null and v.unit.alive else null


## 结算时刻的连线：存活单位 → 其最后目标（目标可能已倒下），全不透明加粗
func _draw_highlight() -> void:
	for u: SimUnit in world.units:
		if not u.alive or u.current_target < 0:
			continue
		var t: SimUnit = world.get_unit(u.current_target)
		if t == null:
			continue
		var ally: bool = u.faction == SimTypes.Faction.ALLY
		var tp: Vector2 = SimTypes.sim_to_screen(t.pos, grid_height)
		_draw_tether(SimTypes.sim_to_screen(u.pos, grid_height), tp, ally, 0.0, HIGHLIGHT_WIDTH)
		draw_circle(tp, 10.0, ALLY_COLOR if ally else ENEMY_COLOR)
