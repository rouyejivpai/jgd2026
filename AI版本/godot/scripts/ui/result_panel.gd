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

const SKIN: String = "battle_hud"
const WIN_DECOR: Array[String] = ["win_title_sigil", "win_title_crescent", "win_title_lines"]
const LOSE_DECOR: Array[String] = ["lose_title_compass", "lose_sep"]


func setup(p_controller: BattleController, p_level: LevelDefinition) -> void:
	controller = p_controller
	level = p_level
	diagnosis = FailDiagnosis.new(level)
	theme = UiKit.ui_theme(SKIN)
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
	put.call(_level_name, _r(k + "level", true))
	_level_name.theme_type_variation = _tt(k + "level")
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
	var btn_top: float = _r(k + "retry").position.y
	var body_top: Rect2
	if won:
		_reward_head.theme_type_variation = _tt("win_reward_head")
		var head_r: Rect2 = _r("win_reward_head", true)
		body_top = Rect2(head_r.position, _r("win_reward", true).size)      # 正文从原「解锁」标题位置开始：综合分 → 解锁 → 奖励
		_rewards.theme_type_variation = _tt("win_reward")
		_score.theme_type_variation = _tt("win_reward")
	else:
		body_top = _r("lose_reason", true)
		_reason.theme_type_variation = _tt("lose_reason")
		_last_hit.theme_type_variation = _tt("lose_reason")
	var line_gap: float = body_top.size.y * 0.15
	var body_h: float = btn_top - body_top.position.y - line_gap * 2.0
	_body_scroll.position = body_top.position - panel.position
	_body_scroll.size = Vector2(body_top.size.x, body_h)
	for l: Label in [_score, _reason, _last_hit, _reward_head, _rewards]:
		l.custom_minimum_size = Vector2(body_top.size.x, 0.0)
	var extra: float = _fit_body(body_top.size.x, body_h)
	if extra > 0.0:                      # 正文放不下：框体向下加高（保持居中），按钮随之下移
		position.y -= extra * 0.5
		size.y += extra
		_bg.size.y += extra
		_body_scroll.size.y += extra
	var buttons: Array[Button] = [_retry, _back]
	var ids: Array[String] = ["lose_retry", "lose_back"]        # 无「下一关」时两个按钮，按失败整图的两键位置
	if _next.visible:
		buttons = [_retry, _next, _back]
		ids = ["win_retry", "win_next", "win_back"]
	for i: int in buttons.size():
		put.call(buttons[i], _r(ids[i]))
		buttons[i].position.y += extra
		buttons[i].theme_type_variation = _tt(ids[i])


## 结算页不翻页（2026-10-18）：正文（解锁 / 失败原因）按实际字体与换行宽度量高，超出按钮上方的区域时先把框体向下加高
## （不超过视口留边），仍放不下再逐级缩小字号（最小 BODY_MIN_SCALE 倍），保证全部内容一屏显示、不需要滚动。返回框体加高量。
const BODY_MIN_SCALE: float = 0.6
const SCREEN_MARGIN: float = 24.0


func _fit_body(width: float, max_h: float) -> float:
	var labels: Array[Label] = []
	for l: Label in [_score, _reason, _last_hit, _reward_head, _rewards]:
		l.remove_theme_font_size_override("font_size")
		if l.visible and l.text != "":
			labels.append(l)
	if labels.is_empty():
		return 0.0
	var base: int = labels[0].get_theme_font_size("font_size")
	var gap: float = float(_body.get_theme_constant("separation"))
	var room: float = maxf(get_viewport_rect().size.y - size.y - SCREEN_MARGIN * 2.0, 0.0)
	var extra: float = clampf(_body_height(labels, width, base, gap) - max_h, 0.0, room)
	var fs: int = base
	while fs > int(base * BODY_MIN_SCALE) and _body_height(labels, width, fs, gap) > max_h + extra:
		fs -= 1
	if fs != base:
		for l: Label in labels:
			l.add_theme_font_size_override("font_size", fs)
	return ceilf(extra)


func _body_height(labels: Array[Label], width: float, size: int, gap: float) -> float:
	var h: float = gap * float(labels.size() - 1)
	for l: Label in labels:
		var font: Font = l.get_theme_font("font")
		var lines: int = 0
		for para: String in l.text.split("
"):
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
	_score.visible = _score.text != ""
	_reward_head.text = DataRegistry.get_string("ui.result_rewards")
	var next_id: String = str(level.rewards.get("unlock_level", ""))
	_next.visible = won and next_id != "" and GameState.is_level_unlocked(next_id)
	_apply_layout(won)
	ArtText.attach(_title, SKIN, ("win_" if won else "lose_") + "title")       # P8：「战斗胜利 / 失败」艺术字（R6b；「保护成功」无素材则保留文字）
	visible = true


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

