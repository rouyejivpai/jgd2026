extends Node2D
## 信标显示（07 §3.1、§6）：选中单位的信标与连线高亮；其他己方单位的信标为小号印记；
## 拖动信标时显示落点（合法金色 / 非法红色）。
## 坐标为 MapLayer 局部（每格 TILE_SIZE），位于受玩法矩形裁剪的 MapLayer 下。只读控制器与模拟数据。
## 2026-10-20 信标材质与光效（风格取信标数字牌 p6_beacon_badge、blast_marker、deploy_zone、unit_aura、TargetLines）：
## · 每个信标 / 路径点脚下一圈 beacon_mark.gdshader 地面光圈——压扁 0.6 成 3/4 视角椭圆，同角色脚下的阵营光圈紧贴地面
##   （黑色阴影盘 + 金色外环 + 旋转符文刻度 + 光晕）。
## · 部署阶段的信标是立在光圈上的方尖碑（3/4 视角两个侧面明暗分面 + 金色四棱锥顶 + 金边），碑身嵌数字牌（选中单位）或发光菱形宝石（其他单位，小号半透明）。
## · 部署阶段选中单位的行动线（单位 → 信标 1 → 信标 2 …）为发光线（TargetLines 三层光晕 + 流动光点）并闪烁。
## · 运行中只留贴地的路径点光圈：各单位当前前往的目标点闪烁并向外扩散光波，单位 → 目标点的行动线发光闪烁；
##   未激活的目标点与其余连线只保留半透明、无光效。
## 本层不受场景光照压暗（同 TargetLines）。

const NAME_FONT: FontFile = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const LINE_PX: float = 3.0
const BLINK_HZ: float = 2.5
const NUMBER_RADIUS: float = 0.14        ## 第四阶段单位编号圆牌半径（格）
const NUMBER_MIN_PX: float = 20.0        ## 圆牌最小直径（屏幕像素）
const SQUASH: float = 0.6                ## 3/4 视角地面椭圆（同 UnitView 脚下光圈）
## 地面光圈外环半径（格，未压扁方向）
const RING_SELECTED: float = 0.42
const RING_OTHER: float = 0.24
const RING_PATH: float = 0.36            ## 运行中的路径点（≈ 角色脚下光圈）
const MARK_QUAD: float = 2.0             ## 光圈方块半边长 = 外环半径 × 此值（光晕、扩散光波留边）
const MARK_COLOR: Color = Color(1.0, 0.74, 0.3)
## 光圈状态：[光效 glow, 不透明度]
const MARK_LIT: Array = [1.0, 1.0]
const MARK_DEPLOY_OTHER: Array = [0.45, 0.6]
const MARK_INACTIVE: Array = [0.0, 0.4]  ## 运行中未激活：只保留半透明
const TEXT_INACTIVE_ALPHA: float = 0.45
const TEXT_SCALE: float = 1.35           ## 编号字号相对布局（牌子比整图小，放大保证可读）
const PLATE_TEXT_BOOST: float = 1.5      ## 碑身数字 HDR 提亮（带辉光，压在深色牌上）
## 方尖碑（格）：底宽、碑身高、顶部收分、金顶高；其他单位的信标整体缩放 / 不透明度
const PILLAR_WIDTH: float = 0.44
const PILLAR_HEIGHT: float = 0.6
const PILLAR_TAPER: float = 0.8
const PILLAR_CAP: float = 0.24
const PILLAR_OTHER_SCALE: float = 0.6
const PILLAR_OTHER_ALPHA: float = 0.6
const STONE_LIT: Color = Color(0.36, 0.24, 0.4)      ## 受光侧面（左）
const STONE_DARK: Color = Color(0.15, 0.09, 0.18)    ## 背光侧面（右）
const CAP_LIT: Color = Color(1.0, 0.78, 0.36)
const CAP_MID: Color = Color(0.72, 0.5, 0.2)
const CAP_DARK: Color = Color(0.45, 0.3, 0.12)
const EDGE_GOLD: Color = Color(1.25, 0.95, 0.45)     ## 金边，略 HDR
const GEM_HOT: Color = Color(2.4, 1.7, 0.6)          ## 宝石 / 前棱高光，HDR 触发辉光
## 行动线：配色与光晕层同 TargetLines 己方
const LINE_CORE: Color = Color(1.9, 1.35, 0.45)
const LINE_GLOW: Color = Color(1.0, 0.62, 0.16)
const LINE_PASSES: Array = [[6.0, 0.14], [2.8, 0.32], [1.0, 0.95]]
const LINE_FLOW_HZ: float = 0.7          ## 光点流动频率（每秒走完一段的次数）
const LINE_INACTIVE: Color = Color(0.91, 0.86, 0.77, 0.3)    ## 骨白半透明
const UNIT_GAP: float = 0.3              ## 行动线离单位脚底的空隙（格）

var level: LevelDefinition = null
var controller: BattleController = null
var root: Node2D = null
var _drag_id: String = ""
var _drag_cell: Vector2i = Vector2i(-1, -1)
var _drag_legal: bool = false
var _marks: Array[ColorRect] = []        ## 地面光圈池（show_behind_parent，在连线与方尖碑之下）
var _plate_k: float = -1.0               ## 数字牌样式缓存对应的缩放
var _plate_style: StyleBox = null


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func setup(p_level: LevelDefinition, p_controller: BattleController, p_root: Node2D) -> void:
	level = p_level
	controller = p_controller
	root = p_root
	EventBus.beacons_changed.connect(func(_id: int) -> void: queue_redraw())
	EventBus.unit_selected.connect(func(_id: int) -> void: queue_redraw())
	EventBus.deployment_changed.connect(queue_redraw)
	EventBus.battle_phase_changed.connect(func(_p: int) -> void: queue_redraw())
	controller.world_rebuilt.connect(queue_redraw)
	queue_redraw()


func set_drag(beacon_id: String, cell: Vector2i, legal: bool) -> void:
	_drag_id = beacon_id
	_drag_cell = cell
	_drag_legal = legal
	queue_redraw()


func clear_drag() -> void:
	_drag_id = ""
	queue_redraw()


func _process(_delta: float) -> void:
	if controller != null and is_visible_in_tree():
		queue_redraw()     # 闪烁、流动光点、光圈跟随


func _draw() -> void:
	var used: int = 0
	if level != null and controller != null:
		used = _draw_beacons()
	for i: int in range(used, _marks.size()):
		_marks[i].visible = false


## 画全部信标与行动线，返回用掉的地面光圈数
func _draw_beacons() -> int:
	var deploy: bool = controller.phase == SimTypes.Phase.DEPLOY
	var edit: bool = deploy or controller.boss_pending          # Boss 换阶段暂停也在编辑信标：读控制器配置、按部署样式画（单位位置仍取模拟）
	var selected_slot: String = controller.slot_of_unit(int(root.get("selected_id")))
	var t: float = float(SimTypes.TILE_SIZE)
	var k: float = maxf(get_global_transform().get_scale().x, 0.01)
	var line_w: float = LINE_PX / k
	var phase: float = fmod(Time.get_ticks_msec() * 0.001 * BLINK_HZ, 1.0)
	var flash: float = 0.35 + 0.65 * exp(-phase * 4.0)        # 快速亮起、缓慢回落（光圈着色器同相位）
	var used: int = 0
	var pillars: Array = []                                    # [位置, 编号（"" = 宝石）, 是否选中单位]，按 y 排序后画
	var labels: Array = []                                     # 运行中选中单位的路径点编号：[位置, 编号, 是否激活]
	for uid: String in controller.uids():
		var beacons: Array[Dictionary] = _beacons_of(uid, edit)
		if beacons.is_empty():
			continue
		var target_index: int = -1
		var u: SimUnit = controller.world.get_unit(controller.unit_id_of_slot(uid)) if controller.world != null else null
		if not edit and u != null and u.alive and u.current_action == SimTypes.ActionType.FOLLOW_BEACONS:
			target_index = u.beacon_index
		var is_sel: bool = uid == selected_slot
		var pts: Array[Vector2] = []
		for b: Dictionary in beacons:
			pts.append(_px(b["cell"] as Vector2i))
		var ring_sel: float = (RING_SELECTED if edit else RING_PATH) * t
		# 行动线：部署阶段选中单位整条（单位 → 各信标）发光闪烁；运行中选中单位的连线半透明，单位 → 目标点发光闪烁
		if is_sel:
			var start: Vector2 = _unit_pos(uid, u, deploy)
			var chain: Array[Vector2] = pts.duplicate()
			var from_unit: bool = edit and start.x > -INF
			if from_unit:
				chain.push_front(start)
			for i: int in range(1, chain.size()):
				var unit_end: bool = from_unit and i == 1
				if edit:
					_glow_line(chain[i - 1], chain[i], -1.0 if unit_end else ring_sel, ring_sel, line_w, flash, float(i) * 0.31)
				else:
					_plain_line(chain[i - 1], chain[i], ring_sel, ring_sel, line_w)
		if target_index >= 0 and target_index < pts.size():
			var from: Vector2 = _unit_pos(uid, u, deploy)
			if from.x > -INF:
				_glow_line(from, pts[target_index], -1.0, RING_PATH * t, line_w, flash, 0.0)
		# 地面光圈；部署阶段立方尖碑，运行中选中单位的路径点标编号
		for i: int in pts.size():
			var active: bool = i == target_index
			var ring_r: float = RING_PATH * t
			var state: Array = MARK_LIT if active else MARK_INACTIVE
			if edit:
				ring_r = (RING_SELECTED if is_sel else RING_OTHER) * t
				state = MARK_LIT if is_sel else MARK_DEPLOY_OTHER
				pillars.append([pts[i], str(beacons[i]["id"]) if is_sel else "", is_sel])
			elif is_sel:
				labels.append([pts[i], str(beacons[i]["id"]), active])
			_place_mark(used, pts[i], ring_r, float(state[0]), float(state[1]), active, line_w, phase, absi(uid.hash()) % 97 + i)
			used += 1
	pillars.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	for pl: Array in pillars:
		_draw_pillar(pl[0] as Vector2, str(pl[1]), bool(pl[2]), line_w)
	for lb: Array in labels:
		_draw_number(lb[0] as Vector2, str(lb[1]), bool(lb[2]), flash)
	if deploy:
		_draw_unit_numbers(line_w)
	if _drag_id != "" and level.in_bounds(_drag_cell):
		var dc: Color = Palette.ALCHEMY_GOLD if _drag_legal else Palette.WARN_RED
		draw_set_transform(_px(_drag_cell), 0.0, Vector2(1.0, SQUASH))
		draw_arc(Vector2.ZERO, RING_SELECTED * t, 0.0, TAU, 40, dc, line_w)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return used


## 第 index 块地面光圈（不够时新建）：以 at 为中心压扁成椭圆
func _place_mark(index: int, at: Vector2, ring_r: float, glow: float, opacity: float, blink: bool, line_w: float, phase: float, seed: int) -> void:
	while _marks.size() <= index:
		var q := ColorRect.new()
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.show_behind_parent = true
		q.material = Art.material("beacon_mark")
		add_child(q)
		_marks.append(q)
	var q: ColorRect = _marks[index]
	var half: float = ring_r * MARK_QUAD
	q.visible = true
	q.size = Vector2(half, half) * 2.0
	q.pivot_offset = Vector2(half, half)
	q.scale = Vector2(1.0, SQUASH)
	q.position = at - Vector2(half, half)
	var m: ShaderMaterial = q.material as ShaderMaterial
	m.set_shader_parameter("color", MARK_COLOR)
	m.set_shader_parameter("quad_px", half)
	m.set_shader_parameter("ring_px", ring_r)
	m.set_shader_parameter("line_px", line_w)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("blink", 1.0 if blink else 0.0)
	m.set_shader_parameter("flash_phase", phase)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("seed", float(seed) * 0.173)


## 方尖碑：底面为 3/4 视角菱形（压扁 SQUASH），可见左（受光）、右（背光）两个侧面 + 四棱锥金顶，金边勾棱；
## 选中单位的碑身嵌数字牌，其他单位为小号半透明、嵌发光菱形宝石
func _draw_pillar(p: Vector2, id: String, selected: bool, line_w: float) -> void:
	var t: float = float(SimTypes.TILE_SIZE)
	var s: float = 1.0 if selected else PILLAR_OTHER_SCALE
	var a: float = 1.0 if selected else PILLAR_OTHER_ALPHA
	var hw: float = PILLAR_WIDTH * 0.5 * t * s
	var hd: float = hw * SQUASH
	var h: float = PILLAR_HEIGHT * t * s
	var tw: float = hw * PILLAR_TAPER
	var td: float = hd * PILLAR_TAPER
	var l0 := p + Vector2(-hw, 0.0)
	var f0 := p + Vector2(0.0, hd)
	var r0 := p + Vector2(hw, 0.0)
	var top := p + Vector2(0.0, -h)
	var l1 := top + Vector2(-tw, 0.0)
	var f1 := top + Vector2(0.0, td)
	var r1 := top + Vector2(tw, 0.0)
	var b1 := top + Vector2(0.0, -td)
	var apex := top + Vector2(0.0, -PILLAR_CAP * t * s)
	# 金顶背面（俯视可见）→ 碑身两侧 → 金顶正面
	draw_colored_polygon(PackedVector2Array([l1, b1, apex]), Color(CAP_MID, a))
	draw_colored_polygon(PackedVector2Array([b1, r1, apex]), Color(CAP_DARK, a))
	draw_colored_polygon(PackedVector2Array([l0, f0, f1, l1]), Color(STONE_LIT, a))
	draw_colored_polygon(PackedVector2Array([f0, r0, r1, f1]), Color(STONE_DARK, a))
	draw_colored_polygon(PackedVector2Array([l1, f1, apex]), Color(CAP_LIT, a))
	draw_colored_polygon(PackedVector2Array([f1, r1, apex]), Color(CAP_MID, a))
	var ew: float = line_w * 0.6 * s
	var edge := Color(EDGE_GOLD, a)
	draw_polyline(PackedVector2Array([l0, l1, apex, r1, r0]), edge, ew, true)
	draw_polyline(PackedVector2Array([l1, f1, r1]), edge, ew, true)
	draw_line(f1, apex, edge, ew, true)
	draw_line(f0, f1, Color(GEM_HOT, a), ew * 1.3, true)       # 正对镜头的前棱最亮
	var mid: Vector2 = p + Vector2(0.0, -h * 0.5)
	var dot: Texture2D = StatusParticles.dot_texture()
	var gr: float = hw * 1.5
	draw_texture_rect(dot, Rect2(mid - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(LINE_GLOW, 0.55 * a))
	if id != "":
		_draw_plate(mid, id)
	else:
		var gs: float = hw * 0.45
		draw_colored_polygon(PackedVector2Array([mid + Vector2(0.0, -gs * 1.4), mid + Vector2(gs, 0.0), mid + Vector2(0.0, gs * 1.4), mid + Vector2(-gs, 0.0)]), Color(GEM_HOT, a))


## 发光行动线：两端各让出地面光圈（gap < 0 = 单位端，让出 UNIT_GAP），三层光晕随 flash 闪烁，两颗光点沿行进方向流动
func _glow_line(a: Vector2, b: Vector2, gap_a: float, gap_b: float, line_w: float, flash: float, phase: float) -> void:
	var dist: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / maxf(dist, 0.001)
	var ga: float = UNIT_GAP * float(SimTypes.TILE_SIZE) if gap_a < 0.0 else _ellipse_gap(dir, gap_a)
	var gb: float = _ellipse_gap(dir, gap_b)
	if dist <= ga + gb + 2.0:
		return
	var p0: Vector2 = a + dir * ga
	var p1: Vector2 = b - dir * gb
	for pass_: Array in LINE_PASSES:
		var glow_pass: bool = float(pass_[0]) > 1.5
		var c: Color = LINE_GLOW if glow_pass else LINE_CORE
		var al: float = float(pass_[1]) * (flash if glow_pass else lerpf(0.6, 1.0, flash))
		draw_line(p0, p1, Color(c, al), line_w * float(pass_[0]), true)
	var dot: Texture2D = StatusParticles.dot_texture()
	for j: int in 2:
		var s: float = fposmod(Time.get_ticks_msec() * 0.001 * LINE_FLOW_HZ + phase + float(j) * 0.5, 1.0)
		var at: Vector2 = p0.lerp(p1, s)
		var fade: float = sin(s * PI)
		var r: float = line_w * 3.0 * (0.6 + 0.4 * fade)
		draw_texture_rect(dot, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(LINE_GLOW, 0.9 * fade))
		draw_circle(at, line_w * 0.75, Color(LINE_CORE * 1.3, fade))


## 未激活连线：骨白半透明细线，无光效
func _plain_line(a: Vector2, b: Vector2, gap_a: float, gap_b: float, line_w: float) -> void:
	var dist: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / maxf(dist, 0.001)
	var ga: float = _ellipse_gap(dir, gap_a)
	var gb: float = _ellipse_gap(dir, gap_b)
	if dist <= ga + gb + 2.0:
		return
	draw_line(a + dir * ga, b - dir * gb, LINE_INACTIVE, line_w, true)


## 沿 dir 方向到压扁椭圆（横半径 r、纵半径 r × SQUASH）边缘的距离
func _ellipse_gap(dir: Vector2, r: float) -> float:
	return r * SQUASH / sqrt(pow(SQUASH * dir.x, 2.0) + dir.y * dir.y)


## 单位当前所在（本层局部）：部署阶段为部署格中心；运行中取单位视图（平滑）；没有时返回 -INF
func _unit_pos(slot_id: String, u: SimUnit, deploy: bool) -> Vector2:
	if deploy:
		if controller.placements.has(slot_id):
			return _px(controller.placements[slot_id] as Vector2i)
		return Vector2(-INF, -INF)
	if u == null or not u.alive:
		return Vector2(-INF, -INF)
	var v: Node2D = root.call("_view", u.id) as Node2D if root != null and root.has_method("_view") else null
	if v != null:
		return to_local(v.global_position)
	return SimTypes.sim_to_screen(u.pos, level.height)


## 碑身数字牌（批准整图 ui_21：深底金边圆角方块 + 金色数字；样式取布局 fx_beacon / fx_beacon_text）；
## 边长 = 碑宽的 0.8（不小于布局 min_px 的 0.8 屏幕像素）
func _draw_plate(p: Vector2, id: String) -> void:
	var e: Dictionary = UiKit.layout_element("battle_hud", "fx_beacon")
	var data: Dictionary = e.get("data", {}) as Dictionary
	var th: Theme = UiKit.ui_theme("battle_hud")
	var k: float = maxf(get_global_transform().get_scale().x, 0.01)
	var side: float = maxf(PILLAR_WIDTH * 0.8 * SimTypes.TILE_SIZE, float(data.get("min_px", 26)) * 0.8 / k)
	var rect := Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side))
	if not is_equal_approx(k, _plate_k) or _plate_style == null:
		_plate_k = k
		_plate_style = th.get_stylebox("panel", StringName(str(e.get("theme_type", "")))).duplicate() as StyleBox
		if _plate_style is StyleBoxFlat:          # 边框与圆角按屏幕像素，换成本层局部单位
			var f: StyleBoxFlat = _plate_style as StyleBoxFlat
			f.set_border_width_all(maxi(int(round(f.border_width_left / k)), 1))
			f.set_corner_radius_all(int(round(f.corner_radius_top_left / k)))
	draw_style_box(_plate_style, rect)
	_draw_id_text(p, id, side, th.get_color("font_color", _text_type()) * PLATE_TEXT_BOOST)


## 运行中选中单位的路径点编号：贴在光圈中心，激活的随闪烁提亮，其余半透明
func _draw_number(p: Vector2, id: String, active: bool, flash: float) -> void:
	var col: Color = UiKit.ui_theme("battle_hud").get_color("font_color", _text_type())
	if active:
		col = Color(col * lerpf(1.0, 1.6, flash), 1.0)
	else:
		col.a = TEXT_INACTIVE_ALPHA
	_draw_id_text(p, id, PILLAR_WIDTH * 0.8 * SimTypes.TILE_SIZE, col)


func _text_type() -> StringName:
	return StringName(str(UiKit.layout_element("battle_hud", "fx_beacon_text").get("theme_type", "")))


## 居中画编号；字号随牌子边长（整图牌边长对应布局字号），本层局部单位
func _draw_id_text(p: Vector2, id: String, side: float, col: Color) -> void:
	var th: Theme = UiKit.ui_theme("battle_hud")
	var tt: StringName = _text_type()
	var font: Font = th.get_font("font", tt)
	var ref_side: float = UiKit.layout_rect("battle_hud", "fx_beacon", UiKit.design_size("battle_hud")).size.x
	var fs: int = maxi(int(round(float(th.get_font_size("font_size", tt)) * side / ref_side * TEXT_SCALE)), 1)
	var w: float = font.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	draw_string(font, p + Vector2(-w * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


## 第四阶段：部署阶段在每个已部署单位所在格左下角画编号圆牌（= 进入信标模式的数字键；信标模式中的单位为金底）
func _draw_unit_numbers(line_w: float) -> void:
	var t: float = float(SimTypes.TILE_SIZE)
	var hud: Node = root.get_node_or_null("UI/HUD") if root != null else null
	var active: String = str(hud.call("beacon_mode_slot")) if hud != null and hud.has_method("beacon_mode_slot") else ""
	var list: Array[String] = controller.deployed_uids()
	var k: float = maxf(get_global_transform().get_scale().x, 0.01)
	var r: float = maxf(NUMBER_RADIUS * t, NUMBER_MIN_PX * 0.5 / k)
	var fs: int = maxi(int(round(r * 1.3)), 1)
	for i: int in list.size():
		var cell: Vector2i = controller.placements[list[i]] as Vector2i
		var c: Vector2 = _px(cell) + Vector2(-0.5 * t + r + 2.0, 0.5 * t - r - 2.0)
		var on: bool = list[i] == active
		draw_circle(c, r, Palette.ALCHEMY_GOLD if on else Color(Palette.BG_DEEP, 0.85))
		draw_arc(c, r, 0.0, TAU, 24, Palette.ALCHEMY_GOLD, line_w)
		var txt: String = str(i + 1)
		var sz: Vector2 = NAME_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		draw_string(NAME_FONT, c + Vector2(-sz.x * 0.5, (NAME_FONT.get_ascent(fs) - NAME_FONT.get_descent(fs)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Palette.BG_DEEP if on else Palette.ALCHEMY_GOLD)


## 部署阶段 / Boss 换阶段暂停读控制器配置（暂停中改的信标「继续」时才写进模拟）；运行中读模拟单位（已阵亡的不画）
func _beacons_of(slot_id: String, edit: bool) -> Array[Dictionary]:
	if edit and (controller.phase == SimTypes.Phase.DEPLOY or _alive(slot_id)):
		return controller.get_beacons(slot_id)
	if edit:
		return [] as Array[Dictionary]
	var u: SimUnit = controller.world.get_unit(controller.unit_id_of_slot(slot_id)) if controller.world != null else null
	var out: Array[Dictionary] = []
	if u != null and u.alive:
		out.assign(u.beacons)
	return out


func _alive(slot_id: String) -> bool:
	var u: SimUnit = controller.world.get_unit(controller.unit_id_of_slot(slot_id)) if controller.world != null else null
	return u != null and u.alive


func _px(cell: Vector2i) -> Vector2:
	return SimTypes.sim_to_screen(SimTypes.cell_center(cell), level.height)
