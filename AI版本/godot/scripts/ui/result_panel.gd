extends Control
## 结算面板（01 §9 result_panel）：胜/败、失败原因（fail_feedback）、保护对象的最后一次攻击来源与时间、
## 完成时间、存活单位、奖励；按钮：重试（保留配置）/ 下一关 / 返回。第三阶段删除"导出本局记录"（10 §6.1），记录只由 tools/run_playtests 生成。
## 逃离类失败（reach_zone）按本局记录分三类说明（FailDiagnosis，03 §7）。
## 第三阶段 P6 按批准整图 ui_10（胜利）/ ui_11（失败）换皮：两套版式（data/ui_layout/battle_hud.json 的 win_* / lose_*），
## 框体、标题、关卡名、分隔线、完成时间、存活单位；胜利另有「解锁」+ 奖励（多行时上下滚动），失败另有原因 + 最后一击（多行时上下滚动）；
## 按钮：胜利 = 重试 / 下一关 / 返回，失败 = 重试 / 返回（无下一关时胜利也只显示重试 / 返回，按钮按整图位置排）。
## 节点各一份，按结果切换主题变体与位置。
## P8：标题有艺术字素材（data/art_text.json）时换成艺术字，字形高与位置按布局 ref_ink。
## P6 补充素材（P6_MISSING_ASSETS #7 / #8）：胜利 = 标题后纹章、左上月牙、两侧菱形装饰线；失败 = 右侧裂痕罗盘、带菱形的分隔线（贴图）。
## 2026-10-19 结算演出（参数 data/ui_motion.json 的 result；动效总闸关闭时直接显示终态）：
## 胜利：框体淡入 → 计分四行（人数 / 指令要素 / 信标 / 用时）逐行出现，数字从 0 涨到该项分数，越接近越慢（expo out）
## → 右侧斜着「盖章」综合分（大号落下 + 轻震）→ 其余结算（时间、存活、解锁）打字机逐字出现，超出正文区时自动滚到底 → 最后按钮淡入。
## 失败：框体淡入 → 文字打字机 → 按钮。演出中任意处点击或按确认 / 取消键 = 跳到终态。
## 2026-10-20 03.zip 换皮：胜负共用一张框（H01，标题字已从图上抹掉，由程序两字一行写在标题牌里），正文全在框内深色区；
## 印章换成框右侧的得分圆环（H05，「综合得分」「最高得分」在图上，程序写两个数字）；按钮字烘在切图上（布局 data.baked_text）。
## 框体只在一条窄带纵向拉伸：正文放不下时连同框外的按钮一起算可加高的空间（修复：无解锁时计分区没算进正文高度，框体不加高、计分被截掉）。

var controller: BattleController = null
var level: LevelDefinition = null
var _last_hits: Dictionary = {}          ## 目标 unit id -> { source, time }
var diagnosis: FailDiagnosis = null      ## 逃离类失败分三类说明（03 §7）
var _title: Label
var _reason: Label
var _last_hit: Label
var _time: Label
var _survivors: Label
var _rewards: Label
var _score: Label                       ## 胜利：综合分 + 明细（Scoring，越低越好）
var _next: Button
var _retry: Button
var _back: Button
var _level_name: Label
var _reward_head: Label
var _bg: Control
var _seps: Array[Control] = []          ## [胜利分隔线, 失败第二条分隔线]（平面线）
var _decor: Dictionary = {}              ## 布局 id → 装饰贴图节点（只在对应结果显示）
var _scrolls: Dictionary = {}           ## 文字节点 → 包裹的 ScrollText（摆放时用包裹节点）
var _body: VBoxContainer                ## 失败：原因 + 最后一击；胜利：奖励各行（在一个滚动区里）
var _body_scroll: ScrollText
var _score_block: Control = null        ## 胜利计分区：左 = 四行明细，右 = 印章
var _score_rows: Array[Dictionary] = [] ## { key, row, value, detail, target }
var _stamp: Control = null              ## 得分圆环（胜利时「盖章」落下）：子节点 = 综合分、最高分、新纪录
var _stamp_total: Label = null
var _stamp_best: Label = null
var _stamp_note: Label = null
var _dim: ColorRect = null              ## 全屏压暗底（布局 <k>_panel.data.dim），不拦截点击
var _show_tween: Tween = null           ## 结算演出（点击跳过时停掉）
var _typing: Array[Label] = []          ## 本次要打字机显示的文字
const SCORE_ROW_H: float = 30.0
const SCORE_NAME_W: float = 96.0
const SCORE_VALUE_W: float = 64.0
const SCORE_KEYS: Array[String] = ["units", "complexity", "beacons", "time"]
const RESULT_Z: int = 10                 ## 高于 HUD 其他节点（默认 0），低于剧情层

const SKIN: String = "battle_hud"
const WIN_DECOR: Array[String] = ["win_title_sigil", "win_title_crescent", "win_title_lines"]
const LOSE_DECOR: Array[String] = ["lose_title_compass", "lose_sep"]


func setup(p_controller: BattleController, p_level: LevelDefinition) -> void:
	controller = p_controller
	level = p_level
	diagnosis = FailDiagnosis.new(level)
	theme = UiKit.ui_theme(SKIN)
	# 结算压在 HUD 其余一切之上（含之后才加入的提示栏、弹窗），压暗层因此盖住所有其他界面；
	# 只抬 z 不挪节点顺序：剧情层（z 近上限）仍在结算之上，且仍先收到点击（胜利剧情盖在结算上播放）
	z_index = RESULT_Z
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_bg = UiKit.node_for(UiKit.layout_element(SKIN, "win_panel"))
	add_child(_bg)
	for id: String in WIN_DECOR + LOSE_DECOR:           # 装饰在框体之上、文字之下（纹章 / 罗盘衬在标题后面）
		var c: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		c.name = "Decor_" + id
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_decor[id] = c
	for id: String in ["win_sep", "lose_sep2"]:
		var sep: Control = UiKit.node_for(UiKit.layout_element(SKIN, id))
		add_child(sep)
		_seps.append(sep)
	_title = _text_node()
	_level_name = _text_node()
	_time = _text_node()
	_survivors = _text_node()
	_body = VBoxContainer.new()
	_body.name = "ResultBody"
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_body)
	_score = _body_label()
	_score.add_theme_color_override("font_color", Palette.ALCHEMY_GOLD)
	_score.visible = false                   # 2026-10-19：综合分改由计分区 + 印章显示，此标签只保留文字（两行明细）供查阅
	_build_score_block()
	_build_score_badge()
	_reason = _body_label()
	_last_hit = _body_label()
	_last_hit.add_theme_color_override("font_color", Palette.WARN_RED)
	_reward_head = _body_label()             # 2026-10-18：「解锁」标题并入正文流（综合分在它上面）
	_rewards = _body_label()
	_retry = _button(DataRegistry.get_string("ui.retry"), controller.reset)
	_next = _button(DataRegistry.get_string("ui.next_level"), _on_next)
	_back = _button(DataRegistry.get_string("ui.back"), controller.exit)
	# 标题不包 ScrollText、不裁剪：艺术字是标题的子节点，裁剪会把光晕切成硬边（2026-10-18）；标题文字固定且短
	for l: Label in [_level_name, _survivors]:
		l.clip_text = true
		_scrolls[l] = ScrollText.wrap(l, ScrollText.Mode.AUTO, Rect2(Vector2.ZERO, Vector2.ONE))
	_body_scroll = ScrollText.wrap_box(_body, ScrollText.Mode.MANUAL, Rect2(Vector2.ZERO, Vector2.ONE))
	visible = false
	EventBus.sim_event.connect(_on_sim_event)
	controller.ticked.connect(_on_ticked)
	EventBus.battle_phase_changed.connect(_on_phase_changed)


## 计分区：四行（名称 · 数量 × 系数 · 分数），占正文全宽
func _build_score_block() -> void:
	_score_block = Control.new()
	_score_block.name = "ScoreBlock"
	_score_block.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(_score_block)
	_body.move_child(_score_block, 0)
	var col := VBoxContainer.new()
	col.name = "Rows"
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_block.add_child(col)
	for k: String in SCORE_KEYS:
		var row := HBoxContainer.new()
		row.name = "Row_" + k
		row.custom_minimum_size = Vector2(0.0, SCORE_ROW_H)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := Label.new()
		name_l.name = "Name"
		name_l.text = DataRegistry.get_string("ui.score_row_" + ("rules" if k == "complexity" else k))
		name_l.custom_minimum_size = Vector2(SCORE_NAME_W, 0.0)
		var detail := Label.new()
		detail.name = "Detail"
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.modulate = Color(1.0, 1.0, 1.0, 0.7)
		var value := Label.new()
		value.name = "Value"
		value.custom_minimum_size = Vector2(SCORE_VALUE_W, 0.0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for l: Label in [name_l, detail, value]:
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.clip_text = true
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(l)
		col.add_child(row)
		_score_rows.append({ "key": k, "row": row, "value": value, "detail": detail, "target": 0.0 })


## 得分圆环（H05）：圆环贴图 + 综合分 / 最高分 / 新纪录三个文字（位置按布局，相对圆环）
func _build_score_badge() -> void:
	_stamp = UiKit.node_for(UiKit.layout_element(SKIN, "win_score_ring"))
	_stamp.name = "ScoreRing"
	add_child(_stamp)
	var ring: Rect2 = _r("win_score_ring")
	_stamp.size = ring.size
	_stamp.pivot_offset = ring.size * 0.5
	var labels: Array[Label] = []
	for id: String in ["win_score_total", "win_score_best", "win_score_note"]:
		var l: Label = UiKit.node_for(UiKit.layout_element(SKIN, id)) as Label
		var r: Rect2 = _r(id, true)
		l.position = r.position - ring.position
		l.size = r.size
		_stamp.add_child(l)
		labels.append(l)
	_stamp_total = labels[0]
	_stamp_best = labels[1]
	_stamp_note = labels[2]
	_stamp_note.text = DataRegistry.get_string("ui.score_stamp_record")
	_stamp.visible = false


## 计分区摆放：四行占满正文宽；返回计分区高度
func _layout_score_block(width: float) -> float:
	var rows_h: float = SCORE_ROW_H * float(SCORE_KEYS.size())
	var h: float = rows_h + 8.0
	_score_block.custom_minimum_size = Vector2(width, h)
	var col: Control = _score_block.get_node("Rows") as Control
	col.position = Vector2(0.0, (h - rows_h) * 0.5)
	col.size = Vector2(width, rows_h)
	return h


func _text_node() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _body_label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta(TEXT_META, text)              # 换皮时字烘在切图上则清空，原文留在这里
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.pressed.connect(cb)
	add_child(b)
	return b


func _r(id: String, text_rect: bool = false) -> Rect2:
	var d: Vector2 = UiKit.design_size(SKIN)
	return UiKit.layout_text_rect(SKIN, id, d) if text_rect else UiKit.layout_rect(SKIN, id, d)


func _tt(id: String) -> StringName:
	return StringName(str(UiKit.layout_element(SKIN, id).get("theme_type", "")))


## 按结果摆放：win_* 或 lose_* 一套（框体在视口中按设计坐标居中，内部位置相对框体）
func _apply_layout(won: bool) -> void:
	var k: String = "win_" if won else "lose_"
	var panel: Rect2 = _r(k + "panel")
	var panel_e: Dictionary = UiKit.layout_element(SKIN, k + "panel")
	var panel_data: Dictionary = panel_e.get("data", {}) as Dictionary
	UiKit.place(self, UiKit.layout_rect(SKIN, k + "panel", get_viewport_rect().size))
	_bg.theme_type_variation = _tt(k + "panel")
	_bg.position = Vector2.ZERO
	_bg.size = panel.size
	var put := func(c: Control, r: Rect2) -> void:
		var holder: Control = _scrolls.get(c, c) as Control
		holder.position = r.position - panel.position
		holder.size = r.size
	put.call(_title, _r(k + "title", true))
	_title.theme_type_variation = _tt(k + "title")
	_title.horizontal_alignment = UiKit.text_align(str(UiKit.layout_element(SKIN, k + "title").get("align", "left")))
	_title.text = _wrap_chars(_title.text, int((UiKit.layout_element(SKIN, k + "title").get("data", {}) as Dictionary).get("wrap_chars", 0)))
	put.call(_level_name, _r(k + "level", true))
	_level_name.theme_type_variation = _tt(k + "level")
	_level_name.horizontal_alignment = UiKit.text_align(str(UiKit.layout_element(SKIN, k + "level").get("align", "left")))
	put.call(_time, _r(k + "time", true))
	_time.theme_type_variation = _tt(k + "time")
	put.call(_survivors, _r(k + "survivors", true))
	_survivors.theme_type_variation = _tt(k + "survivors")
	_seps[0].visible = won
	_seps[1].visible = not won
	put.call(_seps[0], _r("win_sep"))
	put.call(_seps[1], _r("lose_sep2"))
	for id: String in _decor.keys():
		var c: Control = _decor[id] as Control
		c.visible = (id in WIN_DECOR) == won
		put.call(c, _r(id))
	_reward_head.visible = won and _rewards.text != ""
	var buttons: Array[Button] = [_retry, _back]
	var ids: Array[String] = ["lose_retry", "lose_back"]        # 无「下一关」时两个按钮，按失败版式的两键位置
	if _next.visible:
		buttons = [_retry, _next, _back]
		ids = ["win_retry", "win_next", "win_back"]
	var btn_top: float = _r(ids[0]).position.y
	var btn_bottom: float = _r(ids[0]).end.y
	var body_top: Rect2
	if won:
		_reward_head.theme_type_variation = _tt("win_reward_head")
		var head_r: Rect2 = _r("win_reward_head", true)
		body_top = Rect2(head_r.position, _r("win_reward", true).size)      # 正文从原「解锁」标题位置开始：计分 → 解锁 → 奖励
		_rewards.theme_type_variation = _tt("win_reward")
		_score.theme_type_variation = _tt("win_reward")
		for r: Dictionary in _score_rows:
			for n: String in ["Name", "Detail"]:
				((r["row"] as Control).get_node(n) as Label).theme_type_variation = _tt("win_score_row")
			(r["value"] as Label).theme_type_variation = _tt("win_score_value")
	else:
		body_top = _r("lose_reason", true)
		_reason.theme_type_variation = _tt("lose_reason")
		_last_hit.theme_type_variation = _tt("lose_reason")
	var line_gap: float = body_top.size.y * 0.15
	var body_bottom: float = float(panel_data.get("body_bottom", btn_top - line_gap * 2.0 - BODY_BOTTOM_PAD))   # 正文下沿：布局给了就用框内深色区底（按钮在框外）
	var body_h: float = body_bottom - body_top.position.y
	_body_scroll.position = body_top.position - panel.position
	_body_scroll.size = Vector2(body_top.size.x, body_h)
	for l: Label in [_score, _reason, _last_hit, _reward_head, _rewards]:
		l.custom_minimum_size = Vector2(body_top.size.x, 0.0)
	_score_block.visible = won and not controller.last_score.is_empty()
	if _score_block.visible:
		_layout_score_block(body_top.size.x)
	# 可加高的空间：框体连同框外按钮整体（保持居中）不超出视口留边
	var span: float = maxf(panel.end.y, btn_bottom) - panel.position.y
	var room: float = maxf(get_viewport_rect().size.y - span - SCREEN_MARGIN * 2.0, 0.0)
	var extra: float = _fit_body(body_top.size.x, body_h, room)
	var stretch_top: float = float((panel_e.get("ninepatch", [0, 0, 0, 0]) as Array)[1])     # 框体拉伸带以下的部件随框体下移
	if extra > 0.0:                      # 正文放不下：框体向下加高（保持居中），按钮随之下移
		position.y -= extra * 0.5
		size.y += extra
		_bg.size.y += extra
		_body_scroll.size.y += extra
	_stamp.visible = _score_block.visible
	put.call(_stamp, _r("win_score_ring"))
	if extra > 0.0 and _stamp.position.y >= stretch_top:
		_stamp.position.y += extra
	_fit_label_width(_stamp_total)
	for i: int in buttons.size():
		put.call(buttons[i], _r(ids[i]))
		buttons[i].position.y += extra
		buttons[i].theme_type_variation = _tt(ids[i])
		var baked: bool = bool((UiKit.layout_element(SKIN, ids[i]).get("data", {}) as Dictionary).get("baked_text", false))
		buttons[i].text = "" if baked else str(buttons[i].get_meta(TEXT_META, ""))      # 字在切图上就不再写字
		if buttons[i].has_meta(ButtonMotion.META):      # 按钮动效已按旧变体接管了样式：按新变体重新取
			(buttons[i].get_node(ButtonMotion.NODE_NAME) as ButtonMotion).recapture()
	_dim.visible = panel_data.has("dim")
	_dim.color = Color(str(panel_data.get("dim", "#00000000")))
	_dim.position = -position
	_dim.size = get_viewport_rect().size


## 标题按 n 字一行（布局 data.wrap_chars：结算框顶的标题牌窄，两字一行叠放）；n ≤ 0 不换行
static func _wrap_chars(text: String, n: int) -> String:
	var t: String = text.replace("\n", "")
	if n <= 0:
		return t
	var lines: PackedStringArray = PackedStringArray()
	for i: int in range(0, t.length(), n):
		lines.append(t.substr(i, n))
	return "\n".join(lines)


## 单行文字超出文字区宽度时逐级缩小字号（综合分位数多时）
static func _fit_label_width(l: Label) -> void:
	l.remove_theme_font_size_override("font_size")
	var font: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	while fs > 10 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x > l.size.x:
		fs -= 2
	l.add_theme_font_size_override("font_size", fs)


## 结算页不翻页（2026-10-18）：正文（计分 / 解锁 / 失败原因）按实际字体与换行宽度量高，超出正文区时先把框体向下加高
## （不超过 room），仍放不下再逐级缩小字号（最小 BODY_MIN_SCALE 倍），保证全部内容一屏显示、不需要滚动。返回框体加高量。
## 2026-10-20 修复：没有解锁（奖励为空）时正文里只剩计分区，原来直接返回 0，计分区没算进高度，框体不加高、计分被截掉一截。
const BODY_MIN_SCALE: float = 0.6
const BODY_BOTTOM_PAD: float = 14.0       ## 正文滚动区下沿离按钮的留白（布局给了 body_bottom 时不用）
const SCREEN_MARGIN: float = 24.0
const TEXT_META: StringName = &"result_text"


func _fit_body(width: float, max_h: float, room: float) -> float:
	var labels: Array[Label] = []
	for l: Label in [_score, _reason, _last_hit, _reward_head, _rewards]:
		l.remove_theme_font_size_override("font_size")
		if l.visible and l.text != "":
			labels.append(l)
	if labels.is_empty() and not _score_block.visible:
		return 0.0
	var base: int = labels[0].get_theme_font_size("font_size") if not labels.is_empty() else 0
	var gap: float = float(_body.get_theme_constant("separation"))
	var extra: float = clampf(_body_height(labels, width, base, gap) - max_h, 0.0, room)
	var fs: int = base
	while not labels.is_empty() and fs > int(base * BODY_MIN_SCALE) and _body_height(labels, width, fs, gap) > max_h + extra:
		fs -= 1
	if fs != base:
		for l: Label in labels:
			l.add_theme_font_size_override("font_size", fs)
	return ceilf(extra)


func _body_height(labels: Array[Label], width: float, size: int, gap: float) -> float:
	var parts: int = labels.size()
	var h: float = 0.0
	if _score_block != null and _score_block.visible:        # 计分区（固定高）
		h += _score_block.custom_minimum_size.y
		parts += 1
	h += gap * float(maxi(parts - 1, 0))
	for l: Label in labels:
		var font: Font = l.get_theme_font("font")
		var lines: int = 0
		for para: String in l.text.split("\n"):
			var w: float = font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			lines += maxi(1, ceili(w / maxf(width, 1.0)))
		h += float(lines) * (font.get_height(size) + float(l.get_theme_constant("line_spacing")))
	return h


func _on_phase_changed(phase: int) -> void:
	if phase == SimTypes.Phase.DEPLOY:
		_last_hits.clear()
		diagnosis.reset()
	if phase != SimTypes.Phase.ENDED:
		visible = false


func _on_sim_event(e: Dictionary) -> void:
	var t: int = int(e["type"])
	if t == SimTypes.EventType.DAMAGE_APPLIED:
		_last_hits[int(e["target"])] = { "source": int(e["source"]), "time": float(e["time"]) }
	diagnosis.observe_event(e, controller.world)


func _on_ticked() -> void:
	diagnosis.observe_tick(controller.world)


## delay > 0：延后弹出（第二关首败先展示目标连线高亮）
func show_result(result: int, delay: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if controller.phase != SimTypes.Phase.ENDED:
			return
	var world: SimWorld = controller.world
	var won: bool = result == SimTypes.BattleResult.WIN
	var survive: bool = false
	for o: ObjectiveDef in level.win:
		survive = survive or o.type == SimTypes.ObjectiveType.SURVIVE
	_title.text = DataRegistry.get_string("ui.win" if survive else "ui.win_generic") if won else DataRegistry.get_string("ui.lose")
	_level_name.text = level.title
	_reason.visible = not won
	_reason.text = RuleText.label_value("ui.result_reason", diagnosis.fail_text(world))
	_last_hit.text = _last_hit_text(world)
	_last_hit.visible = not won and _last_hit.text != ""
	_time.text = RuleText.label_value("ui.result_time", "%.1f" % world.clock.time)
	var alive: PackedStringArray = PackedStringArray()
	for u: SimUnit in world.units:
		if u.faction == SimTypes.Faction.ALLY and u.kind == SimTypes.UnitKind.UNIT and u.alive:
			alive.append(RuleText.unit_name(u, level))
	_survivors.text = RuleText.label_value("ui.result_survivors", DataRegistry.get_string("ui.list_sep").join(alive) if not alive.is_empty() else DataRegistry.get_string("ui.none"))
	_rewards.text = _rewards_text() if won else ""
	_rewards.visible = _rewards.text != ""
	_score.text = _score_text() if won else ""
	_fill_score_rows(won)
	_reward_head.text = DataRegistry.get_string("ui.result_rewards")
	var next_id: String = str(level.rewards.get("unlock_level", ""))
	_next.visible = won and next_id != "" and GameState.is_level_unlocked(next_id)
	_apply_layout(won)
	ArtText.attach(_title, SKIN, ("win_" if won else "lose_") + "title")       # P8：「战斗胜利 / 失败」艺术字（R6b；「保护成功」无素材则保留文字）
	visible = true
	_play_show(won)


# ---- 2026-10-19 结算演出 ----
func _fill_score_rows(won: bool) -> void:
	var sc: Dictionary = controller.last_score if won else {}
	if sc.is_empty():
		return
	var c: Dictionary = Scoring.coefficients()
	var parts: Dictionary = sc["parts"] as Dictionary
	var counts: Dictionary = { "units": int(sc["unit_count"]), "complexity": int(sc["action_count"]) + int(sc["condition_count"]), "beacons": int(sc["beacon_count"]) }
	for r: Dictionary in _score_rows:
		var k: String = str(r["key"])
		r["target"] = float(parts.get(k, 0.0))
		var detail: String
		if k == "time":
			detail = DataRegistry.get_string("ui.score_row_time_detail").format({ "n": "%.1f" % float(sc["seconds"]), "c": Scoring.num(c[k]) })
		else:
			detail = DataRegistry.get_string("ui.score_row_detail").format({ "n": counts[k], "c": Scoring.num(c[k]) })
		(r["detail"] as Label).text = detail
		(r["value"] as Label).text = _score_value(float(r["target"]), float(r["target"]))
	_stamp_total.text = str(int(sc["total"]))
	var best: int = SaveManager.best_score(level.id) if controller.persist else -1      # 已含本局（record_score 在结算前写入）
	_stamp_best.text = str(best) if best >= 0 else DataRegistry.get_string("ui.score_best_none")
	_stamp_note.visible = controller.last_score_record


## 计分数字：目标为整数时显示整数，否则一位小数
static func _score_value(v: float, target: float) -> String:
	return str(int(round(v))) if is_equal_approx(target, round(target)) else "%.1f" % v


## 演出：动效关闭时直接终态；否则按 result 参数串成一条 Tween（点击面板跳过）
func _play_show(won: bool) -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_typing.clear()
	var texts: Array[Label] = []
	texts.assign([_time, _survivors, _reward_head, _rewards] if won else [_time, _survivors, _reason, _last_hit])
	for l: Label in texts:
		if l.visible and l.text != "":
			_typing.append(l)
	if not UiKit.motion_enabled:
		_finish_show()
		return
	var p: Dictionary = UiKit.motion_params("result")
	var sp: Dictionary = p.get("stamp", {}) as Dictionary
	UiKit.pop_in(self, "panel_in")
	for r: Dictionary in _score_rows:
		(r["row"] as Control).modulate.a = 0.0
		(r["value"] as Label).text = _score_value(0.0, float(r["target"]))
	_stamp.visible = false
	for l: Label in _typing:
		l.visible_ratio = 0.0
	for b: Button in [_retry, _next, _back] as Array[Button]:
		b.modulate.a = 0.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_scroll.offset = 0.0
	var t: Tween = create_tween()
	_show_tween = t
	t.tween_interval(float(p.get("panel_in_s", 0.25)))
	if _score_block.visible:
		var trans: Tween.TransitionType = UiKit.MOTION_TRANS.get(str(p.get("count_trans", "expo")), Tween.TRANS_EXPO) as Tween.TransitionType
		var ease_t: Tween.EaseType = UiKit.MOTION_EASE.get(str(p.get("count_ease", "out")), Tween.EASE_OUT) as Tween.EaseType
		for r: Dictionary in _score_rows:
			var row: Control = r["row"] as Control
			var value: Label = r["value"] as Label
			var target: float = float(r["target"])
			t.tween_property(row, "modulate:a", 1.0, 0.12)
			t.tween_method(func(v: float) -> void: value.text = _score_value(v, target), 0.0, target, float(p.get("count_s", 0.9))).set_trans(trans).set_ease(ease_t)
			t.tween_interval(float(p.get("row_gap_s", 0.15)))
		t.tween_interval(float(sp.get("delay_s", 0.25)))
		t.tween_callback(_stamp_down)
		t.tween_interval(float(sp.get("duration", 0.32)) + float(sp.get("shake_s", 0.18)))
	var cps: float = maxf(float(p.get("type_cps", 40.0)), 1.0)
	for l: Label in _typing:
		var n: int = maxi(l.get_total_character_count(), 1)
		t.tween_property(l, "visible_ratio", 1.0, float(n) / cps)
		t.tween_callback(_scroll_to_bottom)
		t.tween_interval(float(p.get("line_gap_s", 0.1)))
	var bd: float = float(p.get("buttons_in_s", 0.3))
	t.tween_property(_retry, "modulate:a", 1.0, bd)
	t.parallel().tween_property(_next, "modulate:a", 1.0, bd)
	t.parallel().tween_property(_back, "modulate:a", 1.0, bd)
	t.tween_callback(_finish_show)


## 盖章：从大、透明落到原大小（back out），随后整块轻震
func _stamp_down() -> void:
	var sp: Dictionary = UiKit.motion_params("result").get("stamp", {}) as Dictionary
	_stamp.visible = true
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2.ONE * float(sp.get("from_scale", 2.6))
	var d: float = float(sp.get("duration", 0.32))
	var t: Tween = _stamp.create_tween().set_parallel(true)
	t.tween_property(_stamp, "scale", Vector2.ONE, d).set_trans(UiKit.motion_trans(sp)).set_ease(UiKit.motion_ease(sp))
	t.tween_property(_stamp, "modulate:a", 1.0, d * 0.5)
	var shake: float = float(sp.get("shake_px", 6.0))
	var base: Vector2 = _stamp.position
	var k: Tween = _stamp.create_tween()
	k.tween_interval(d * 0.8)
	for off: Vector2 in [Vector2(shake, shake * 0.5), Vector2(-shake * 0.6, -shake * 0.4), Vector2(shake * 0.3, 0.0), Vector2.ZERO]:
		k.tween_property(_stamp, "position", base + off, float(sp.get("shake_s", 0.18)) / 4.0)


## 正文超出滚动区时滚到底（打字机每出一行就跟一次）
func _scroll_to_bottom() -> void:
	var over: float = _body_scroll.overflow()
	if over <= 0.0:
		return
	var t: Tween = _body_scroll.create_tween()
	t.tween_property(_body_scroll, "offset", over, float(UiKit.motion_params("result").get("scroll_s", 0.25))).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## 终态：全部数字、印章、文字、按钮就位（演出结束或点击跳过）
func _finish_show() -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = null
	for r: Dictionary in _score_rows:
		(r["row"] as Control).modulate.a = 1.0
		(r["value"] as Label).text = _score_value(float(r["target"]), float(r["target"]))
	_stamp.visible = _score_block.visible
	_stamp.scale = Vector2.ONE
	_stamp.modulate.a = 1.0
	modulate.a = 1.0
	scale = Vector2.ONE
	for l: Label in _typing:
		l.visible_ratio = 1.0
	for b: Button in [_retry, _next, _back] as Array[Button]:
		b.modulate.a = 1.0
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	if _body_scroll.overflow() > 0.0:
		_body_scroll.offset = _body_scroll.overflow()


func is_showing() -> bool:
	return _show_tween != null and _show_tween.is_valid()


## 演出中：任意处点击（含按钮位置——按钮在演出结束前不响应）或按确认 / 取消键 = 直接跳到结束，这一下不传给下层
func _input(event: InputEvent) -> void:
	if not is_showing():
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var click: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish_show()
		get_viewport().set_input_as_handled()


## 胜利：综合分（新纪录 / 最佳）+ 明细一行
func _score_text() -> String:
	var sc: Dictionary = controller.last_score
	if sc.is_empty():
		return ""
	var head: String = DataRegistry.get_string("ui.result_score").format({ "total": int(sc["total"]) })
	var best: int = SaveManager.best_score(level.id) if controller.persist else -1
	if controller.last_score_record:
		head += "  " + DataRegistry.get_string("ui.result_score_record")
	elif best >= 0:
		head += DataRegistry.get_string("ui.result_score_best").format({ "best": best })
	var c: Dictionary = Scoring.coefficients()
	var parts: String = DataRegistry.get_string("ui.result_score_parts").format({
		"units": int(sc["unit_count"]), "rules": int(sc["action_count"]) + int(sc["condition_count"]),
		"beacons": int(sc["beacon_count"]), "seconds": "%.1f" % float(sc["seconds"]),
		"cu": _coef(c["units"]), "ck": _coef(c["complexity"]), "cb": _coef(c["beacons"]), "ct": _coef(c["time"]) })
	return head + "
" + parts


static func _coef(v: Variant) -> String:
	var f: float = float(v)
	return str(int(f)) if is_equal_approx(f, round(f)) else "%.1f" % f


## 失败目标为"某单位被摧毁"时：最后一次有效攻击来源与时间（第七关）
func _last_hit_text(world: SimWorld) -> String:
	for o: ObjectiveDef in level.lose:
		if o.id == world.result_objective and o.type == SimTypes.ObjectiveType.UNIT_DEAD:
			var target: SimUnit = world.get_spawn(o.target)
			if target != null and _last_hits.has(target.id):
				var hit: Dictionary = _last_hits[target.id] as Dictionary
				return DataRegistry.get_string("ui.last_hit_from").format({
					"unit": RuleText.unit_name(world.get_unit(int(hit["source"])), level), "time": "%.1f" % float(hit["time"]) })
	return ""


func _rewards_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var sep: String = DataRegistry.get_string("ui.list_sep")
	var forms: PackedStringArray = PackedStringArray()
	for f: Variant in level.rewards.get("unlock_forms", []) as Array:
		forms.append(DataRegistry.get_unit(str(f)).display_name)
	if not forms.is_empty():
		lines.append(RuleText.label_value("ui.reward_forms", sep.join(forms)))
	# 10 §5.1：预组合指令已删除；unlock_presets 键解锁的目标类型（filters 只由解锁键控制）单列一行，
	# 行为 / 条件 / 选敌由下面三类 unlock_* 列出
	var cat: CommandCatalog = DataRegistry.get_commands()
	var keys: Array = level.rewards.get("unlock_presets", []) as Array
	var filters: PackedStringArray = PackedStringArray()
	for f: String in cat.ids("filters"):
		if keys.has(cat.unlock_key("filters", f)):
			filters.append(RuleText.filter_name(SimTypes.parse_filter(f)))
	if not filters.is_empty():
		lines.append(RuleText.label_value("ui.reward_filters", sep.join(filters)))
	var groups: Array = [["unlock_conditions", "ui.reward_conditions", "conditions"], ["unlock_selectors", "ui.reward_selectors", "selectors"], ["unlock_actions", "ui.reward_actions", "actions"]]
	for g: Variant in groups:
		var ga: Array = g as Array
		var items: PackedStringArray = PackedStringArray()
		for v: Variant in level.rewards.get(str(ga[0]), []) as Array:
			items.append(DataRegistry.get_string("names.%s.%s" % [str(ga[2]), str(v)]))
		if not items.is_empty():
			lines.append(RuleText.label_value(str(ga[1]), sep.join(items)))
	var relics: PackedStringArray = PackedStringArray()
	for r: String in level.reward_relics():
		relics.append(str(DataRegistry.get_relic(r).get("name", r)))
	if not relics.is_empty():
		lines.append(RuleText.label_value("ui.reward_relics", sep.join(relics)))
	if lines.is_empty():
		return ""
	return "\n".join(lines)          # 「解锁」标题单独一行（_reward_head，批准整图 ui_10）


func _on_next() -> void:
	controller.save_config()
	var next_id: String = str(level.rewards.get("unlock_level", ""))
	SceneRouter.goto_battle(next_id)

