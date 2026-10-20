class_name RelicLayer
extends Node2D
## 遗物的地图表现（data/relics.json）。随地图平移缩放（BattleRoot 的 panned layers），只读控制器 / 模拟状态。
## mode = GROUND（单位之下）：已放下的遗物地块（遗物色块 + 外框 + 中心图标，开战后缓慢呼吸）；
##   部署阶段拖动 / 点选遗物时吸附到悬停格的 3×3 预览（合法 = 遗物色、非法 = 红），与放置人偶的虚影同一手感。
## mode = TOP（单位之上）：骨刃 / 徽章进入「点选目标」时，可选目标脚下的脉动圈（悬停者加粗）；生效时的扩散圈与飘字。

enum Mode { GROUND, TOP }

const FX_SECONDS: float = 1.2
const TILE_ICON_CELLS: float = 0.9      ## 地块中心图标边长（格）
const GHOST_ALPHA: float = 0.75
## 伤害数字弹跳（bounce = true，用户 2026-10-21）：弹出放大回落 → 跳两下（第二下矮）落地压扁 → 缓缓上飘渐隐
const POP_SECONDS: float = 0.16          ## 弹出：0.35 倍放大到 1 倍（带回冲）
const POP_OVERSHOOT: float = 2.2
const HOP_SECONDS: Vector2 = Vector2(0.30, 0.16)   ## 第一下 / 第二下的腾空时长
const HOP_PX: float = 34.0               ## 第一下高度（像素），第二下 × HOP2_RATIO
const HOP2_RATIO: float = 0.35
const SQUASH: float = 0.18               ## 落地压扁幅度（横向放大、纵向压低同一比例）
const SQUASH_SECONDS: float = 0.07
const DRIFT_PX: float = 14.0             ## 弹跳期间沿偏移方向横移的距离
const RISE_CELLS: float = 0.35           ## 落地后到消失时再上飘的高度（格）
const FADE_FROM: float = 0.6             ## 寿命过了这一比例开始渐隐

var mode: int = Mode.GROUND
var controller: BattleController = null
var grid_height: int = 0
## 悬停预览（GROUND）：relic = "" 时不画
var hover_relic: String = ""
var hover_cell: Vector2i = Vector2i(-1, -1)
var hover_legal: bool = false
## 点选目标（TOP）
var armed_relic: String = ""
var hover_unit: int = -1
var _fx: Array[Dictionary] = []          ## { pos: Vector2（屏幕局部）, color, text, t }
var _t: float = 0.0


static func relic_color(id: String) -> Color:
	var raw: String = str(DataRegistry.get_relic(id).get("color", "#c9a24a"))
	return Color(raw) if Color.html_is_valid(raw) else Palette.ALCHEMY_GOLD


static func relic_icon(id: String) -> Texture2D:
	return Art.texture(str(DataRegistry.get_relic(id).get("icon", "")))


func set_hover(relic_id: String, cell: Vector2i, legal: bool) -> void:
	hover_relic = relic_id
	hover_cell = cell
	hover_legal = legal
	queue_redraw()


func clear_hover() -> void:
	set_hover("", Vector2i(-1, -1), false)


func set_armed(relic_id: String, unit_id: int) -> void:
	armed_relic = relic_id
	hover_unit = unit_id
	queue_redraw()


## 生效特效：扩散圈 + 飘字（sim 坐标）。ring = false 只飘字（普通伤害数字，BattleRoot._show_hit），fs = 字号，shift = 屏幕偏移，
## bounce = 飘字走弹跳动画（关闭动效时退回直线上飘）
func spawn_fx(sim_pos: Vector2, color: Color, text: String, ring: bool = true, fs: int = 64, shift: Vector2 = Vector2.ZERO, bounce: bool = false) -> void:
	_fx.append({ "pos": SimTypes.sim_to_screen(sim_pos, grid_height) + shift, "color": color, "text": text, "t": 0.0, "ring": ring, "fs": fs,
		"bounce": bounce and UiKit.motion_enabled, "dir": signf(shift.x) })


func _process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < FX_SECONDS)
	queue_redraw()


func _draw() -> void:
	if controller == null or controller.world == null:
		return
	if mode == Mode.GROUND:
		_draw_tiles()
		_draw_hover()
	else:
		_draw_targets()
		_draw_fx()


func _cell_rect(c: Vector2i) -> Rect2:
	var t: float = float(SimTypes.TILE_SIZE)
	return Rect2(SimTypes.sim_to_screen(Vector2(c.x, c.y + 1), grid_height), Vector2(t, t))


## 已放下的地块：按遗物分组，色块 + 只描外边 + 中心图标
func _draw_tiles() -> void:
	var world: SimWorld = controller.world
	if world.relic_tiles.is_empty():
		return
	var breathe: float = 0.5 + 0.5 * sin(_t * 2.2) if controller.phase != SimTypes.Phase.DEPLOY else 1.0
	var by_relic: Dictionary = {}
	for c: Vector2i in world.relic_tiles.keys():
		var rid: String = str((world.relic_tiles[c] as Dictionary)["relic"])
		if not by_relic.has(rid):
			by_relic[rid] = [] as Array[Vector2i]
		(by_relic[rid] as Array[Vector2i]).append(c)
	for rid: String in by_relic.keys():
		var cells: Array[Vector2i] = by_relic[rid] as Array[Vector2i]
		var col: Color = relic_color(rid)
		_draw_area(cells, col, 0.16 + 0.08 * breathe, 0.85)
		var center: Vector2i = controller.relic_tile.get("cell", cells[0]) as Vector2i
		_draw_icon(rid, _cell_rect(center).get_center(), 0.9)


func _draw_hover() -> void:
	if hover_relic == "" or controller.level == null or not controller.level.in_bounds(hover_cell):
		return
	var cells: Array[Vector2i] = controller.relic_tile_cells(hover_relic, hover_cell)
	if cells.is_empty():
		cells = [hover_cell] as Array[Vector2i]
	var col: Color = relic_color(hover_relic) if hover_legal else Palette.WARN_RED
	_draw_area(cells, col, 0.3, 1.0)
	var ring: Rect2 = _cell_rect(hover_cell).grow(-3.0)
	draw_rect(ring, Color(Palette.ALCHEMY_GOLD if hover_legal else Palette.WARN_RED, 0.9), false, 3.0)
	_draw_icon(hover_relic, ring.get_center(), GHOST_ALPHA, Color.WHITE if hover_legal else RosterCard.PREVIEW_TINT_ILLEGAL)


## 一组格：每格半透明填充，外边（相邻格不属于本组的边）描实线
func _draw_area(cells: Array[Vector2i], col: Color, fill_a: float, line_a: float) -> void:
	var t: float = float(SimTypes.TILE_SIZE)
	for c: Vector2i in cells:
		var r: Rect2 = _cell_rect(c)
		draw_rect(r, Color(col, fill_a))
		var edges: Array = [
			[Vector2i(0, 1), r.position, r.position + Vector2(t, 0.0)],
			[Vector2i(0, -1), r.position + Vector2(0.0, t), r.end],
			[Vector2i(-1, 0), r.position, r.position + Vector2(0.0, t)],
			[Vector2i(1, 0), r.position + Vector2(t, 0.0), r.end],
		]
		for e: Array in edges:
			if not cells.has(c + (e[0] as Vector2i)):
				draw_line(e[1] as Vector2, e[2] as Vector2, Color(col, line_a), 3.0)
		var k: float = t * 0.12                       # 四角小菱形，与地形效果格的记号区分
		var p: Vector2 = r.get_center()
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, 0), p + Vector2(0, k), p + Vector2(-k, 0)]), Color(col, fill_a + 0.15))


func _draw_icon(rid: String, center: Vector2, alpha: float, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = relic_icon(rid)
	if tex == null:
		return
	var side: float = float(SimTypes.TILE_SIZE) * TILE_ICON_CELLS
	draw_circle(center, side * 0.46, Color(Palette.BG_DEEP, 0.55 * alpha))
	draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(tint, alpha))


## 点选目标：可选目标脚下脉动圈；悬停的可选目标加粗放大
func _draw_targets() -> void:
	if armed_relic == "":
		return
	var col: Color = relic_color(armed_relic)
	var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
	var tile: float = float(SimTypes.TILE_SIZE)
	for u: SimUnit in controller.world.units:
		if not controller.relic_target_ok(armed_relic, u.id):
			continue
		var p: Vector2 = SimTypes.sim_to_screen(u.pos, grid_height)
		var hot: bool = u.id == hover_unit
		var r: float = tile * (0.62 if hot else 0.52) + pulse * 6.0
		draw_circle(p, r, Color(col, 0.22 if hot else 0.1))
		draw_arc(p, r + 3.0, 0.0, TAU, 48, Color(Palette.BG_DEEP, 0.8), 9.0 if hot else 7.0)       # 深色描边，红色地图上也看得清
		draw_arc(p, r, 0.0, TAU, 48, Color(col.lightened(0.3), 1.0 if hot else 0.85), 6.0 if hot else 4.0)
		if hot:
			draw_arc(p, r * 0.55, 0.0, TAU, 32, Color(Color.WHITE, 0.8), 2.5)


func _draw_fx() -> void:
	var font: Font = ThemeDB.fallback_font
	var tile: float = float(SimTypes.TILE_SIZE)
	for f: Dictionary in _fx:
		var k: float = float(f["t"]) / FX_SECONDS
		var col: Color = f["color"] as Color
		var p: Vector2 = f["pos"] as Vector2
		if bool(f.get("ring", true)):
			draw_arc(p, tile * (0.3 + 0.9 * k), 0.0, TAU, 40, Color(col.lightened(0.3), 1.0 - k), 8.0 * (1.0 - k) + 1.0)
		var text: String = str(f["text"])
		var fs: int = int(f.get("fs", 64))
		var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		if bool(f.get("bounce", false)):
			_draw_bouncing(font, f, p + Vector2(0.0, -tile * 1.2), text, fs, sz.x, col)
			continue
		var at: Vector2 = p + Vector2(-sz.x * 0.5, -tile * (1.2 + 0.6 * k))
		var a: float = 1.0 - k * k
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 14, Color(Palette.BG_DEEP, a))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(col.lightened(0.45), a))


## 弹跳飘字：以文字底边中点为轴缩放（落地压扁贴着"地面"），base = 起跳点
func _draw_bouncing(font: Font, f: Dictionary, base: Vector2, text: String, fs: int, w: float, col: Color) -> void:
	var t: float = float(f["t"])
	var k: float = t / FX_SECONDS
	var land1: float = HOP_SECONDS.x
	var land2: float = HOP_SECONDS.x + HOP_SECONDS.y
	var s: float = 1.0
	if t < POP_SECONDS:
		var u: float = t / POP_SECONDS - 1.0
		s = lerpf(0.35, 1.0, 1.0 + (POP_OVERSHOOT + 1.0) * u * u * u + POP_OVERSHOOT * u * u)
	var y: float = 0.0
	if t < land1:
		y = -HOP_PX * sin(PI * t / HOP_SECONDS.x)
	elif t < land2:
		y = -HOP_PX * HOP2_RATIO * sin(PI * (t - land1) / HOP_SECONDS.y)
	else:
		y = -float(SimTypes.TILE_SIZE) * RISE_CELLS * (t - land2) / maxf(FX_SECONDS - land2, 0.01)
	var q: float = 0.0
	for land: float in [land1, land2]:
		if t >= land and t < land + SQUASH_SECONDS:
			q = SQUASH * (1.0 - (t - land) / SQUASH_SECONDS) * (1.0 if land == land1 else HOP2_RATIO * 2.0)
	var x: float = float(f.get("dir", 0.0)) * DRIFT_PX * minf(t / land2, 1.0)
	var a: float = 1.0 - smoothstep(FADE_FROM, 1.0, k)
	draw_set_transform(base + Vector2(x, y), 0.0, Vector2(s * (1.0 + q), s * (1.0 - q)))
	var at := Vector2(-w * 0.5, 0.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 14, Color(Palette.BG_DEEP, a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(col.lightened(0.45), a))
	draw_set_transform(Vector2.ZERO)
