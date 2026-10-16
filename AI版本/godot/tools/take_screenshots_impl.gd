extends RefCounted
## take_screenshots.gd 的实现（运行时加载，可引用自动加载）。

const DEFAULT_OUT: String = "../docs/screenshots"
const DEFAULT_SIZE: Vector2i = Vector2i(1920, 1080)
const DEFAULT_TIME: float = 3.0
const LOAD_FRAMES: int = 90
const SETTLE_FRAMES: int = 20
## P8 动效连续帧（--screen=main_menu_motion）：需以 --fixed-fps 60 运行（帧间隔固定，Tween 与 TIME 按固定步长推进）；
## 每 MOTION_EVERY 帧存一张，裁出按钮区域。脚本化的鼠标事件序列（秒 → 动作）见 _motion_shots。
const MOTION_FPS: float = 60.0
const MOTION_EVERY: int = 2
const MOTION_CROP: Rect2i = Rect2i(120, 230, 640, 760)
const RunPlaytests: GDScript = preload("res://tools/run_playtests_impl.gd")


func run(tree: SceneTree) -> void:
	var args: Dictionary = _parse_args()
	var size: Vector2i = args.get("size", DEFAULT_SIZE) as Vector2i
	var out_arg: String = str(args.get("out", DEFAULT_OUT))
	var out_dir: String = (out_arg if out_arg.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out_arg)).simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var levels: Array[String] = []
	levels.assign(args.get("levels", DataRegistry.get_level_list()) as Array)
	var sim_time: float = float(args.get("time", DEFAULT_TIME))
	var phase: String = str(args.get("phase", "running"))
	UiKit.motion_enabled = not args.has("no-motion")      # P8：--no-motion 冻结在静止态（ui_diff 比对用）
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	await tree.process_frame
	var saved: Dictionary = SaveManager.data.duplicate(true)
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = RunPlaytests.ALL_UNLOCKED      # 与 run_playtests 相同，按"已玩到该关"的解锁状态截图，不依赖本机存档进度
	print("[shots] window=%s out=%s" % [str(DisplayServer.window_get_size()), out_dir])
	if str(args.get("screen", "battle")) == "main_menu_motion":
		await _motion_shots(tree, out_dir)
		GameState.unlocks = saved_unlocks
		tree.quit(0)
		return
	if str(args.get("screen", "battle")) in ["main_menu", "main_menu_error", "settings_overlay"]:
		await _ui_shot(tree, out_dir, str(args["screen"]))
		GameState.unlocks = saved_unlocks
		SaveManager.data = saved
		GameState.sync_from_save()
		tree.quit(0)
		return
	if str(args.get("screen", "battle")) == "chapter":
		await _chapter_shots(tree, out_dir, args)
		GameState.unlocks = saved_unlocks
		SaveManager.data = saved
		GameState.sync_from_save()
		tree.quit(0)
		return
	for lid: String in levels:
		SaveManager.set_level_config(lid, {})
		SceneRouter.goto_battle(lid)
		for i: int in LOAD_FRAMES:
			await tree.process_frame
		var root: Node = tree.current_scene
		var c: BattleController = root.get_node("BattleController") as BattleController
		c.persist = false
		var dialogue: Node = root.find_child("DialogueOverlay", true, false)
		if dialogue != null:
			(dialogue as CanvasItem).visible = false
		c.apply_recommended()
		if str(args.get("demo", "")) == "objectives":         # P6 ui_06：打开「任务」弹窗
			root.find_child("HUD", true, false).call("_on_objectives_pressed")
		if str(args.get("demo", "")) == "mechanics":          # P6 ui_07：打开「机制说明」弹窗
			root.find_child("HUD", true, false).call("_on_mechanics_pressed")
		if str(args.get("demo", "")) == "hint":               # P6 ui_08：揭示两层提示（存档在内存中，结束时恢复）
			SaveManager.set_hints_seen(c.level.id, 2)
			(root.find_child("HintPanel", true, false) as HintPanel).show_tier(2)
		if str(args.get("demo", "")) == "recommend":          # P6 ui_09：四层都已看，打开推荐阵型确认
			SaveManager.set_hints_seen(c.level.id, c.level.hints.size())
			(root.find_child("HintPanel", true, false) as HintPanel).open_recommend()
		if str(args.get("demo", "")) in ["win", "lose"]:     # P6 ui_10 / ui_11：推荐阵型跑完（胜利）；或清空后用空指令开局并跑完（失败）
			var lose: bool = str(args["demo"]) == "lose"
			if lose:                          # 空指令：分裂体原地待机，跑 24.8 秒后按失败展示（与整图样例时间相同）
				for uid: String in c.uids():
					c.set_rules(uid, [] as Array[RuleDef])
			c.start()
			while c.phase == SimTypes.Phase.RUNNING and (not lose or c.world.clock.time < 24.8):
				c.advance_tick()
			if c.phase == SimTypes.Phase.RUNNING:
				c.pause()
			root.find_child("HUD", true, false).call("show_result", SimTypes.BattleResult.LOSE if lose else c.world.result, 0.0)
			var dlg: Node = root.find_child("DialogueOverlay", true, false)
			if dlg != null:
				(dlg as CanvasItem).visible = false
		if str(args.get("demo", "")) == "validation":         # P6 ui_05：超出预算 + 空指令，按开始弹出问题面板
			_demo_validation(c)
		if str(args.get("demo", "")) == "overflow":           # P6 堆叠内容检验：HUD 全部文字槽填入超长内容，看遮罩、滚动与页边距
			_demo_overflow(root)
		var dm: String = str(args.get("demo", ""))
		if dm in ["beacons", "wait", "follow_beacons", "feedback"] and not c.uids().is_empty():     # P6 ui_16 / 18 / 19
			_demo_rule(c, c.uids()[0], dm)
		if str(args.get("demo", "")) == "two_conditions" and not c.uids().is_empty():
			_demo_two_conditions(c, c.uids()[0])
		if dm == "side_panel" or dm == "side_overflow":     # 第四阶段：侧栏详情 + 信标边栏（批准整图 side_detail/design.png 的样例状态）
			var sid: String = _demo_side_panel(c, dm == "side_overflow")
			for i: int in 3:
				await tree.process_frame
			root.find_child("HUD", true, false).call("enter_beacon_mode", sid)
			if dm == "side_overflow":
				_demo_side_overflow(root)
			args["select"] = "none"
		var sel: String = str(args.get("select", "ally"))        # ally = 选中第一名己方单位（显示对侧面板）；enemy = 第一个敌方；none
		if sel == "ally" and not c.uids().is_empty():
			EventBus.unit_selected.emit(c.unit_id_of_slot(c.uids()[0]))
		elif sel.begins_with("enemy"):          # enemy = 第一个敌方；enemy:<形态 id> = 第一个该形态的敌方（P6 ui_20）
			var want: String = sel.get_slice(":", 1) if sel.contains(":") else ""
			for u: SimUnit in c.world.units:
				if u.faction == SimTypes.Faction.ENEMY and (want == "" or u.def.id == want):
					EventBus.unit_selected.emit(u.id)
					break
		if str(args.get("demo", "")) == "add_action":         # P6 ui_15：选中己方后打开「添加指令」行为列表
			for i: int in 3:
				await tree.process_frame
			(root.find_child("UnitPanel", true, false).find_children("*", "RuleEditor", true, false)[0] as RuleEditor).toggle_picker()
		if str(args.get("demo", "")) == "feedback":           # P6 ui_21：放信标、收起详情、在障碍格上提示不可放置
			for i: int in 3:
				await tree.process_frame
			root.find_child("HUD", true, false).call("hide_side")
			var blocked: Vector2i = c.level.blocked[c.level.blocked.size() / 2] if not c.level.blocked.is_empty() else Vector2i(5, 3)
			root.call("flash_illegal", blocked)
			EventBus.toast_at.emit(DataRegistry.get_string("validation.cannot_place.format").format({ "reason": DataRegistry.get_string("validation.cannot_place.CELL_BLOCKED") }), root.call("cell_top_screen", blocked) as Vector2)
		if str(args.get("demo", "")) == "beacons":            # P6 ui_16：详情中部滚到信标区
			for i: int in 3:
				await tree.process_frame
			var body_scroll: ScrollText = root.find_child("Scroll_DetailBody", true, false) as ScrollText
			if body_scroll != null:
				body_scroll.scroll_by(100000.0)
		if str(args.get("pan", "")) != "":      # --pan=max|min|<像素>：镜头横移（P4 验收截图）
			for i: int in SETTLE_FRAMES:
				await tree.process_frame
			var pv: String = str(args["pan"])
			root.call("set_pan", UiKit.PAN_MAX if pv == "max" else (-UiKit.PAN_MAX if pv == "min" else float(pv)))
		if phase == "running":
			c.start()
			while c.phase == SimTypes.Phase.RUNNING and c.world.clock.time < sim_time:
				await tree.physics_frame
			if not args.has("live"):         # --live：不暂停，截运行中的画面（P6 ui_02）
				c.pause()
		for i: int in SETTLE_FRAMES:
			await tree.process_frame
		var img: Image = tree.root.get_texture().get_image()
		if tree.root.use_hdr_2d:
			img = _linear_to_srgb8(img)      # hdr_2d 下视口纹理为线性半浮点（PROGRESS M0 已知问题）
		var path: String = out_dir.path_join("%s.png" % lid)
		img.save_png(path)
		_save_meta(path)
		if args.has("text-layer"):           # P6 几何验收：再拍一张隐藏全部文字的，两张之差 = 文字 ink（tools/ui_geom_check.py --notext）
			_hide_text(root)
			for i: int in 3:
				await tree.process_frame
			var bare: Image = tree.root.get_texture().get_image()
			if tree.root.use_hdr_2d:
				bare = _linear_to_srgb8(bare)
			bare.save_png(out_dir.path_join("%s_notext.png" % lid))
		print("[shots] %s t=%.2f -> %s (%dx%d)" % [lid, c.world.clock.time, path, img.get_width(), img.get_height()])
	GameState.unlocks = saved_unlocks
	SaveManager.data = saved
	tree.quit(0)


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		if not a.contains("="):      # 无值开关，如 --no-motion
			out[a.substr(2)] = true
			continue
		var key: String = a.substr(2, a.find("=") - 2)
		var val: String = a.substr(a.find("=") + 1)
		match key:
			"size":
				var p: PackedStringArray = val.split("x")
				out["size"] = Vector2i(int(p[0]), int(p[1]))
			"levels":
				out["levels"] = Array(val.split(","))
			_:
				out[key] = val
	return out


## 线性浮点图 → sRGB 8 位（Image.linear_to_srgb 只接受 8 位格式，先量化会让暗部出现色带）
func _linear_to_srgb8(src: Image) -> Image:
	var img: Image = src.duplicate() as Image
	img.convert(Image.FORMAT_RGBAF)
	var f: PackedFloat32Array = img.get_data().to_float32_array()
	var out: PackedByteArray = PackedByteArray()
	out.resize(f.size())
	for i: int in f.size():
		var v: float = clampf(f[i], 0.0, 1.0)
		if i % 4 != 3:
			v = v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055
		out[i] = int(round(v * 255.0))
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, out)


## --demo=validation：推荐阵型之外再加一名快速形态（内存中临时放宽预算与人数，加完恢复），按开始 → 预算超出 + 空指令提醒（与整图 ui_05 同为两行）
func _demo_validation(c: BattleController) -> void:
	var budget: int = c.level.roster_budget
	var max_units: int = c.level.max_units
	c.level.roster_budget = 999
	c.level.max_units = 99
	for form: String in ["swift"]:
		for cell: Vector2i in c.level.deploy_cells:
			if c.can_place_new(cell) and c.add_unit(form, cell) != "":
				break
	c.level.roster_budget = budget
	c.level.max_units = max_units
	EventBus.deployment_changed.emit()
	c.start()


## --demo=overflow：HUD 全部文字槽换成超长内容（关名、任务句、阶段、按钮、预算、卡名），截图时自动滚动停在起点
func _demo_overflow(root: Node) -> void:
	var long_text: String = "超长文字检验用的一段很长很长的内容甲乙丙丁戊己庚辛壬癸"
	for n: String in ["TitleLabel", "ObjectiveLabel", "PhaseLabel", "BudgetTitle"]:
		(root.find_child(n, true, false) as Label).text = long_text
	(root.find_child("BudgetLabel", true, false) as Label).text = "88888 / 99999"
	for n: String in ["RetryButton", "PauseButton", "ObjectivesButton", "MechanicsButton", "ClearButton", "HintButton", "StartButton"]:
		(root.find_child(n, true, false) as Button).text = long_text
	for card: Node in root.find_children("*", "RosterCard", true, false):
		_set_internal_label(card, "Text_card_name", long_text)


func _set_internal_label(node: Node, label_name: String, text: String) -> void:
	for ch: Node in node.get_children(true):
		if ch is Label and String(ch.name) == label_name:
			(ch as Label).text = text
		_set_internal_label(ch, label_name, text)


## --demo=two_conditions：把第一名单位的第一条指令改成两条件「或」（P1 验收截图：侧栏指令编辑两条件状态）
func _demo_two_conditions(c: BattleController, uid: String) -> void:
	var rules: Array[RuleDef] = c.get_rules(uid)
	if rules.is_empty():
		return
	var r: RuleDef = rules[0]
	r.conditions.clear()
	for key: String in ["enemy_in_range", "enemy_visible"]:
		r.conditions.append(ConditionDef.from_dict({ "type": key }, "demo"))
	r.condition_mode = SimTypes.ConditionMode.ANY
	if r.target == null:
		r.target = TargetDef.create(SimTypes.Selector.NEAREST, SimTypes.TargetFilter.ANY)
	c.set_rules(uid, rules)


## --demo=side_panel（第四阶段）：选中第一名基础攻击形态，指令 = 1 始终 → 沿我的信标（沿路径，从 1 起）；2 目标距离 < 3 → 撤离（覆盖）；
## 3 射程内敌人 → 追击并攻击；放两个信标；进入该单位的信标模式（底部边栏）。side_overflow：再加到 7 条指令（看滚动），名字 / 说明换超长。返回 uid
func _demo_side_panel(c: BattleController, overflow: bool) -> String:
	var uid: String = c.deployed_uids()[0] if not c.deployed_uids().is_empty() else ""
	for u: String in c.deployed_uids():
		if c.form_of(u) == "striker":
			uid = u
			break
	if uid == "":
		return ""
	var placed: Vector2i = c.placements[uid] as Vector2i
	for dx: int in [2, 4]:
		c.add_beacon(uid, placed + Vector2i(dx, 0))
	var raw: Array = [
		{ "conditions": [], "action": { "type": "follow_beacons", "mode": "once", "from": "1" } },
		{ "conditions": [{ "type": "target_distance", "op": "<", "value": 3.0 }], "target": { "selector": "nearest", "filter": "unit" }, "action": { "type": "retreat" }, "override": true },
		{ "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "chase_attack" } },
	]
	if overflow:
		for i: int in 4:
			raw.append({ "conditions": [{ "type": "self_hp_below", "ratio": 0.4 }, { "type": "enemy_visible" }], "condition_mode": "any", "action": { "type": "wait", "seconds": 2.0 } })
	var rules: Array[RuleDef] = []
	for d: Dictionary in raw:
		rules.append(RuleDef.from_dict(d, "demo"))
	c.set_rules(uid, rules)
	return uid


## 侧栏堆叠检验：形态名、说明、信标边栏标题 / 说明换成超长文字（遮罩 + 滚动），出场卡外的长文本同理
func _demo_side_overflow(root: Node) -> void:
	var up: Node = root.find_child("UnitPanel", true, false)
	var long: String = "超长名字测试超长名字测试超长名字测试超长名字测试"
	(up.get("_name") as Label).text = long
	(up.get("_desc") as Label).text = long.repeat(6)
	var hud: Node = root.find_child("HUD", true, false)
	var bar: Node = hud.get_node("BeaconBar")
	for n: Node in bar.find_children("*", "Label", true, false):
		(n as Label).text = long.repeat(3)


## --demo=beacons：第一名单位放两个信标；wait：第一条指令改为「等待 2 秒，自身生命低于 40% 或 射程内敌人」；
## follow_beacons：第一条改为「沿我的信标（单程，从 1 起）」并放两个信标（批准整图 ui_16 / ui_18 / ui_19 的样例）
func _demo_rule(c: BattleController, uid: String, kind: String) -> void:
	if kind != "wait":
		var placed: Vector2i = c.placements.get(uid, Vector2i(2, 5)) as Vector2i
		for dx: int in [1, 3]:
			c.add_beacon(uid, placed + Vector2i(dx, 0))
	if kind == "beacons" or kind == "feedback":
		return
	var rules: Array[RuleDef] = c.get_rules(uid)
	if rules.is_empty():
		return
	var r: RuleDef = rules[0]
	if kind == "wait":
		r.action = ActionDef.from_dict({ "type": "wait", "seconds": 2.0 }, "demo")
		r.conditions.clear()
		r.conditions.append(ConditionDef.from_dict({ "type": "self_hp_below", "ratio": 0.4 }, "demo"))
		r.conditions.append(ConditionDef.from_dict({ "type": "enemy_in_range" }, "demo"))
		r.condition_mode = SimTypes.ConditionMode.ANY
		r.target = null
	else:
		r.action = ActionDef.from_dict({ "type": "follow_beacons", "mode": "once", "from": "1" }, "demo")
		r.conditions.clear()
		r.target = null
	c.set_rules(uid, rules)


## --screen=chapter：章节地图两端与详情面板（P3 验收）。--completed=N 表示前 N 关已通关（默认 3）；
## 输出 chapter_start.png（默认选中、滚到中央）、chapter_end.png（滚到最右、选中第 25 节点）
func _chapter_shots(tree: SceneTree, out_dir: String, args: Dictionary) -> void:
	var completed: Array = []
	for i: int in int(args.get("completed", "3")):
		completed.append(DataRegistry.get_level_list()[i])
	SaveManager.data["progress"] = { "completed": completed, "unlocked_levels": [] }
	SaveManager.data["stories_seen"] = {}          # 已看剧情按批准整图的设定：已通关各关的开场 / 胜利与当前可挑战关的开场看过，锁定关没看过（回放控件的可用 / 禁用不随本机存档变；结束时恢复存档）
	var levels: Array = DataRegistry.get_level_list()
	for i: int in mini(completed.size() + 1, levels.size()):
		SaveManager.mark_story_seen("%s_intro" % str(levels[i]))
		if i < completed.size():
			SaveManager.mark_story_seen("%s_win" % str(levels[i]))
	GameState.sync_from_save()
	SceneRouter.goto_level_select()
	for i: int in LOAD_FRAMES:
		await tree.process_frame
	var sel: Node = tree.current_scene
	await _save_chapter_shot(tree, out_dir.path_join("chapter_start.png"), args)
	sel.call("set_scroll", float(sel.call("max_scroll")))
	sel.call("select_node", "node_25")
	for i: int in SETTLE_FRAMES:
		await tree.process_frame
	await _save_chapter_shot(tree, out_dir.path_join("chapter_end.png"), args)
	sel.call("set_scroll", 0.0)
	sel.call("select_node", str(completed[0]) if not completed.is_empty() else "level_01")
	for i: int in SETTLE_FRAMES:
		await tree.process_frame
	await _save_chapter_shot(tree, out_dir.path_join("chapter_detail_completed.png"), args)
	if args.has("node"):                     # P6：--node=<节点 id> 再拍一张选中该节点（居中）的，chapter_node.png
		var nid: String = str(args["node"])
		sel.call("select_node", nid)
		sel.call("center_on", nid)
		for i: int in SETTLE_FRAMES:
			await tree.process_frame
		await _save_chapter_shot(tree, out_dir.path_join("chapter_node.png"), args)


func _save_shot(tree: SceneTree, path: String) -> void:
	var img: Image = tree.root.get_texture().get_image()
	if tree.root.use_hdr_2d:
		img = _linear_to_srgb8(img)
	img.save_png(path)
	_save_meta(path)
	print("[shots] %s (%dx%d)" % [path, img.get_width(), img.get_height()])


## 章节地图截图；--text-layer 时再拍一张隐藏全部文字的 <名>_notext.png（几何验收），拍完恢复文字（后面还要拍其他状态）
func _save_chapter_shot(tree: SceneTree, path: String, args: Dictionary) -> void:
	_save_shot(tree, path)
	if not args.has("text-layer"):
		return
	var saved: Array = []
	_hide_text(tree.current_scene, saved)
	for i: int in 3:
		await tree.process_frame
	_save_shot(tree, path.get_basename() + "_notext.png")
	for item: Array in saved:
		var n: Node = item[0] as Node
		if n is Label:
			(n as Label).self_modulate = item[1] as Color
		else:
			var b: Button = n as Button
			var old: Dictionary = item[1] as Dictionary
			for c: String in old.keys():
				if old[c] == null:
					b.remove_theme_color_override(c)
				else:
					b.add_theme_color_override(c, old[c] as Color)
	for i: int in 3:
		await tree.process_frame


## 隐藏全部文字：Label 隐藏，按钮文字设透明（按钮背景不变）；saved 非 null 时记下原值供恢复（[节点, 原 self_modulate 或 {颜色名: 原覆盖或 null}]）
func _hide_text(node: Node, saved: Variant = null) -> void:
	if node is Label:
		if saved != null:
			(saved as Array).append([node, (node as Label).self_modulate])
		(node as Label).self_modulate.a = 0.0
	elif node is Button:
		var old: Dictionary = {}
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			old[c] = (node as Button).get_theme_color(c) if (node as Button).has_theme_color_override(c) else null
			(node as Button).add_theme_color_override(c, Color(0.0, 0.0, 0.0, 0.0))
		if saved != null:
			(saved as Array).append([node, old])
	for ch: Node in node.get_children(true):          # 含内部子节点（卡面文字、按钮文字代理）
		_hide_text(ch, saved)


## 截图旁写 <png>.meta.json（motion：截图时动效是否开启），ui_diff.py --no-motion 据此确认比对的是静止态
func _save_meta(png_path: String) -> void:
	var f: FileAccess = FileAccess.open(png_path + ".meta.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({ "motion": UiKit.motion_enabled }) + "
")


## P8 主界面动效连续帧：开始按钮默认焦点（呼吸）→ 鼠标移到「设置」（光带扫过、焦点跟随）→ 按下「设置」（微缩）→
## 按住移出后松开（回弹到焦点态，不触发）→ 移到「退出」→ 移到空白处。输出 frame_####.png（裁切按钮区域）。
func _motion_shots(tree: SceneTree, out_dir: String) -> void:
	SceneRouter.goto_main_menu()
	for i: int in LOAD_FRAMES:
		await tree.process_frame
	var menu: Node = tree.current_scene
	var center: Callable = func(id: String) -> Vector2:
		return ((menu.get("nodes") as Dictionary)[id] as Control).get_global_rect().get_center()
	var blank := Vector2(1100.0, 300.0)
	var script: Array = [
		[1.4, "move", center.call("btn_settings")], [2.6, "down", center.call("btn_settings")],
		[3.0, "move_held", blank], [3.1, "up", blank], [3.9, "move", center.call("btn_quit")], [5.0, "move", blank], [5.6, "end", blank],
	]
	var frame: int = 0
	var step: int = 0
	while step < script.size():
		var t: float = float(frame) / MOTION_FPS
		while step < script.size() and t >= float((script[step] as Array)[0]):
			var act: String = str((script[step] as Array)[1])
			var pos: Vector2 = (script[step] as Array)[2] as Vector2
			if act == "end":
				step = script.size()
				break
			_push_mouse(tree, act, pos)
			step += 1
		if frame % MOTION_EVERY == 0:
			var img: Image = tree.root.get_texture().get_image().get_region(MOTION_CROP)
			img.save_png(out_dir.path_join("frame_%04d.png" % (frame / MOTION_EVERY)))
		await tree.process_frame
		frame += 1
	print("[shots] motion frames: %d -> %s" % [frame / MOTION_EVERY, out_dir])


func _push_mouse(tree: SceneTree, act: String, pos: Vector2) -> void:
	if act == "move" or act == "move_held":
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if act == "move_held" else 0
		tree.root.push_input(m)
		return
	var b := InputEventMouseButton.new()
	b.position = pos
	b.global_position = pos
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = act == "down"
	b.button_mask = MOUSE_BUTTON_MASK_LEFT if act == "down" else 0
	tree.root.push_input(b)


## P5 换皮比对（--screen=main_menu|main_menu_error|settings_overlay）：输出 <screen>_actual.png，与 assets/ui/<screen>/design.png 用 tools/ui_diff.py 比对。
## 设置浮窗的数值按设计图样例临时设定（主音量 100%、音乐 80%、音效 85%、全屏关、目标连线开、字体 100%、模拟日志关），不写存档、不应用显示设置；
## 错误态临时置 DataRegistry.has_errors。
func _ui_shot(tree: SceneTree, out_dir: String, screen: String) -> void:
	var saved_errors: bool = DataRegistry.has_errors
	DataRegistry.has_errors = screen == "main_menu_error"
	if screen == "settings_overlay":
		for kv: Array in [["master", 1.0], ["music", 0.8], ["sfx", 0.85], ["fullscreen", false], ["target_lines", true], ["font_scale", 1.0], ["sim_log", false]]:
			GameState.settings[str(kv[0])] = kv[1]
	SceneRouter.goto_main_menu()
	for i: int in LOAD_FRAMES:
		await tree.process_frame
	if screen == "settings_overlay":
		SceneRouter.open_settings()
	for i: int in SETTLE_FRAMES:
		await tree.process_frame
	_save_shot(tree, out_dir.path_join("%s_actual.png" % screen))
	if screen == "settings_overlay":
		SceneRouter.settings_overlay().visible = false     # 不经 close()，不写存档
	DataRegistry.has_errors = saved_errors
