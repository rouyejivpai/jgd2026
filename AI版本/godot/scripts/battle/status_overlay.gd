extends Node2D
## 30 关战役的战斗提示层（盖在单位之上，随地图平移缩放）：
## - 异常状态：单位头顶的小圆牌（易 = 易伤、麻 = 麻痹、缓 = 减速），只读模拟状态，不改任何数据。
## - Boss 信号：亮起时在 Boss 周围画出本次招式的作用范围（内圈 / 外圈）和一行说明，颜色 = 信号色。
## - Boss 换阶段暂停：高亮增援区。
## 素材到位前用纯绘制占位（与 GroundLayer 的障碍占位同一思路）。

const STATUS_STYLE: Dictionary = {
	"vulnerable": { "glyph": "易", "color": Color(1.0, 0.47, 0.41) },
	"paralysis": { "glyph": "麻", "color": Color(1.0, 0.86, 0.35) },
	"slow": { "glyph": "缓", "color": Color(0.47, 0.67, 1.0) },
}
const SIGNAL_COLOR: Dictionary = { "red": Color(1.0, 0.35, 0.3), "yellow": Color(1.0, 0.85, 0.3), "blue": Color(0.45, 0.65, 1.0) }
const PIP_RADIUS: float = 20.0

var controller: BattleController = null
var grid_height: int = 0
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if controller == null or controller.world == null:
		return
	var world: SimWorld = controller.world
	var font: Font = ThemeDB.fallback_font
	var tile: float = float(SimTypes.TILE_SIZE)
	if controller.boss_pending:
		for c: Vector2i in controller.reinforce_cells():
			var r := Rect2(SimTypes.sim_to_screen(Vector2(c.x, c.y + 1), grid_height), Vector2(tile, tile))
			draw_rect(r.grow(-2.0), Color(0.59, 0.96, 0.76, 0.22 + 0.08 * sin(_t * 4.0)))
			draw_rect(r.grow(-2.0), Color(0.59, 0.96, 0.76, 0.8), false, 2.0)
		var first: Vector2i = controller.reinforce_zone.position
		var at: Vector2 = SimTypes.sim_to_screen(Vector2(first.x, controller.reinforce_zone.end.y), grid_height)
		var zl: String = "增援区 · 剩余 %d Cost" % (controller.reinforce_budget - controller.reinforce_cost())
		var zf: int = int(tile * 0.5)
		var zs: Vector2 = font.get_string_size(zl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, zf)
		var zp: Vector2 = at + Vector2(0.0, -14.0)
		draw_rect(Rect2(zp + Vector2(-10.0, -zs.y * 0.85), zs + Vector2(20.0, zs.y * 0.3)), Color(0.04, 0.08, 0.06, 0.85))
		draw_string(font, zp, zl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, zf, Color(0.59, 0.96, 0.76))
	for u: SimUnit in world.units:
		if not u.alive or u.statuses.is_empty():
			continue
		var head: Vector2 = SimTypes.sim_to_screen(u.pos, grid_height) + Vector2(0.0, -tile * 1.55)
		var keys: Array = u.statuses.keys()
		for i: int in keys.size():
			var st: Dictionary = STATUS_STYLE.get(str(keys[i]), {}) as Dictionary
			if st.is_empty():
				continue
			var p: Vector2 = head + Vector2((float(i) - float(keys.size() - 1) * 0.5) * PIP_RADIUS * 2.3, 0.0)
			draw_circle(p, PIP_RADIUS, Color(0.08, 0.05, 0.07, 0.85))
			draw_arc(p, PIP_RADIUS, 0.0, TAU, 24, st["color"] as Color, 2.0)
			draw_string(font, p + Vector2(-13.0, 9.0), str(st["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, st["color"] as Color)
	_draw_boss_signal(world, font, tile)


func _draw_boss_signal(world: SimWorld, font: Font, tile: float) -> void:
	if world.boss.is_empty() or world.boss_signal == "":
		return
	var b: SimUnit = world.get_spawn(str(world.boss.get("unit", "")))
	if b == null or not b.alive:
		return
	var phases: Array = world.boss.get("phases", []) as Array
	var ph: Dictionary = phases[clampi(world.phase - 1, 0, phases.size() - 1)] as Dictionary
	var e: Dictionary = (ph.get("effects", {}) as Dictionary).get(world.boss_signal, {}) as Dictionary
	var col: Color = SIGNAL_COLOR.get(world.boss_signal, Color.WHITE) as Color
	var center: Vector2 = SimTypes.sim_to_screen(b.pos, grid_height)
	var pulse: float = 0.5 + 0.5 * sin(_t * 8.0)
	if e.has("radius"):
		var r: float = float(e["radius"]) * tile
		if str(e.get("side", "inside")) == "inside":
			draw_circle(center, r, Color(col, 0.12 + 0.1 * pulse))
		else:
			draw_circle(center, r, Color(0.0, 0.0, 0.0, 0.0))
			draw_arc(center, r + tile * 0.6, 0.0, TAU, 64, Color(col, 0.18 + 0.12 * pulse), tile * 1.2)
		draw_arc(center, r, 0.0, TAU, 64, Color(col, 0.9), 3.0)
	var label: String = "%s信号：%s" % [DataRegistry.get_string("names.signals." + world.boss_signal), str(e.get("cn", ""))]
	var fs: int = 34
	var sz: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var at: Vector2 = center + Vector2(-sz.x * 0.5, -tile * 2.2)
	draw_rect(Rect2(at + Vector2(-12.0, -sz.y * 0.85), sz + Vector2(24.0, sz.y * 0.35)), Color(0.06, 0.03, 0.05, 0.82))
	draw_rect(Rect2(at + Vector2(-12.0, -sz.y * 0.85), sz + Vector2(24.0, sz.y * 0.35)), col, false, 2.0)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
