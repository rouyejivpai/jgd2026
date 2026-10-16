extends Node2D
## 目标连线（01 §8 TargetLines）：运行中每个单位→当前目标的细线（己方骨白、敌方暗红、30% alpha）；
## 可在设置中关闭；highlight() 用于第二关首次失败后的强制高亮（关卡册 3.2）。

const ALPHA: float = 0.3
const WIDTH: float = 2.0
const HIGHLIGHT_WIDTH: float = 4.0

var views: Dictionary = {}       ## unit id -> UnitView（与 BattleRoot 共用同一字典）
var world: SimWorld = null       ## 高亮时按模拟位置绘制（含刚倒下的目标）
var grid_height: int = 0
var enabled: bool = true
var _highlight_left: float = 0.0


func highlight(seconds: float) -> void:
	_highlight_left = seconds


func _process(delta: float) -> void:
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
	for id: int in views.keys():
		var v: UnitView = _alive(id)
		if v == null or v.unit.current_target < 0:
			continue
		var t: UnitView = _alive(v.unit.current_target)
		if t == null:
			continue
		var c: Color = Palette.BONE if v.unit.faction == SimTypes.Faction.ALLY else Palette.WARN_RED
		draw_line(v.position, t.position, Color(c, 1.0 if hl else ALPHA), HIGHLIGHT_WIDTH if hl else WIDTH)


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
		var c: Color = Palette.BONE if u.faction == SimTypes.Faction.ALLY else Palette.WARN_RED
		draw_line(SimTypes.sim_to_screen(u.pos, grid_height), SimTypes.sim_to_screen(t.pos, grid_height), c, HIGHLIGHT_WIDTH)
		draw_circle(SimTypes.sim_to_screen(t.pos, grid_height), 10.0, c)
