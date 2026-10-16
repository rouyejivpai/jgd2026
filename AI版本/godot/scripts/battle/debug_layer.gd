extends Node2D
## F3 调试覆盖层（01 §11）：每单位 id、当前规则下标、目标 id、冷却、原因码、路径折线。默认隐藏。

var views: Dictionary = {}       ## unit id -> UnitView（与 BattleRoot 共用）
var grid_height: int = 0


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for id: int in views.keys():
		var raw: Variant = views[id]
		if raw == null or not is_instance_valid(raw):
			continue
		var v: UnitView = raw as UnitView
		var u: SimUnit = v.unit
		if u == null or not u.alive:
			continue
		var text: String = "#%d r%d t%d cd%.2f %s" % [u.id, u.current_rule, u.current_target, u.cooldown, SimTypes.reason_to_key(u.reason)]
		draw_string(font, v.position + Vector2(-60.0, 40.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Palette.ALCHEMY_GOLD)
		if not u.path.is_empty():
			var pts: PackedVector2Array = PackedVector2Array([v.position])
			for c: Vector2i in u.path:
				pts.append(SimTypes.sim_to_screen(SimTypes.cell_center(c), grid_height))
			draw_polyline(pts, Color(Palette.DIVINE_VIOLET, 0.8), 2.0)
