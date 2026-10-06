extends Node
## 视觉回归：把《人工神灵》的各个界面截成 PNG，并输出**结构化元数据**，
## 供外部脚本做像素级断言。
##
## ## 为什么要这么干
## 本工程的沙箱禁止子进程写项目目录，所以历史上我只能靠"读日志"验证逻辑，
## **从来没看过运行画面** —— 结果坐标偏格、信标没渲染、文字溢出这类问题
## 全是被用户肉眼发现的。本工具把"看画面"变成可自动回归的断言。
##
## ## 两条已验证的前提（tools/probe_capture.gd 实测）
## 1. 非 headless 下 `get_viewport().get_texture().get_image()` 能截到真实画面；
## 2. **Godot 写不了 `res://` 与 `user://`（err=12），但能写工作区绝对路径**（err=0）。
##    所以输出目录默认取 `D:/jgd2026/_shots`，由 `--shot-dir` 覆盖。
##
## ## 用法
##     godot --path <项目> --resolution 1920x1080 res://tools/capture_screens.tscn
##     # 自定义输出目录：
##     godot --path <项目> res://tools/capture_screens.tscn -- --shot-dir=D:/other/dir
##
## 元数据以 `SHOTMETA {json}` 单行打印，check_shots.py 据此计算每个瓦片
## 应该出现在屏幕的哪个像素上（与 BattleRenderer 同一套坐标约定）。

const OUT_DEFAULT := "D:/jgd2026/_shots"

const TILE_PX := 64.0

## 给单位直接写规则用（截图脚本要制造"子弹在飞"的那一帧）
const StoryPlayerScript := preload("res://src/ui/story_player.gd")
const RuleEngineScript := preload("res://src/core/rule/rule_engine.gd")
const RuleActionScript := preload("res://src/core/rule/action.gd")

var out_dir := OUT_DEFAULT
var metas: Array = []
## A/B 配对：给"成对拍摄"的那张图标注它的对照图名。
## 【为什么需要显式标注】检查器原来对**任何**开了视野、且有敌人的图都去和
## `12_no_vision` 逐像素比对 —— 但那三张（子弹在飞 / 结算 / 第二关）是**完全不同的
## 场景状态**，逐像素当然不同，于是误报。A/B 只能比**成对的那种同状态图**。
var _ab_pair := ""
## 截图前提不满足的记录；非空时以退出码 3 结束（区别于断言失败的 1）
var _precondition_failures: Array[String] = []


func _ready() -> void:
	# 【必须 ALWAYS】后面要拍暂停菜单，而打开它会把整棵树 paused；
	# 本脚本若被一起冻结，await 就再也回不来了。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	call_deferred("_run")


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--shot-dir="):
			out_dir = s.substr("--shot-dir=".length())


func _run() -> void:
	var mk: int = DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT 输出目录 ", out_dir, " (mkdir=", mk, ")")

	# ---- 1. 主菜单 ----
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _settle(20)
	await _shot("01_main_menu")
	menu.queue_free()
	await _settle(6)

	# ---- 2. 选关页 ----
	var sel: Node = (load("res://src/ui/level_select.tscn") as PackedScene).instantiate()
	add_child(sel)
	await _settle(20)
	await _shot("02_level_select")
	sel.queue_free()
	await _settle(6)

	# ---- 3~7. 玩法场景 ----
	var play: Node = (load("res://src/play/play_scene.tscn") as PackedScene).instantiate()
	play.call("load_level_id", "tutorial_01")
	add_child(play)
	await _settle(20)

	# 进关卡**首次**会自动弹一次介绍（FR-TUT-03）—— 先把它拍下来。
	#
	# 【把前提写显式】这张图的内容就是"介绍弹窗"，所以不能依赖"碰巧弹出来了"：
	# 万一以后语义再变（或这一关在本进程里已经被进过），这张图会**静默**
	# 变成一张没有弹窗的截图，而断言只验"弹窗居中"之类就照样通过。
	# 这里显式确认：没弹就用工具条的「关卡介绍」按钮强开。
	var dlg = play.get("intro_dialog")
	if dlg != null and not bool(dlg.call("is_showing")):
		play.get("toolbar").get_node("Row/Btn_intro").emit_signal("pressed")
		await _settle(6)
	_ok_shot_precondition(dlg != null and bool(dlg.call("is_showing")),
		"03_intro_dialog：拍摄前介绍弹窗确实是打开状态")
	await _shot("03_intro_dialog", play)
	if dlg != null:
		dlg.call("press_ok")
	await _settle(10)

	# 编制期：先放两个信标（与第一关的通关路线一致）
	play.call("try_place_beacon_at", Vector2(6.5 * TILE_PX, 1.5 * TILE_PX))
	play.call("try_place_beacon_at", Vector2(5.5 * TILE_PX, 6.5 * TILE_PX))
	await _settle(10)
	await _shot("04_play_build", play)

	# 指令抽屉：点场上单位打开，并**按玩家的真实操作**加一条「沿着信标移动」指令。
	# 不加指令的话推演期单位不会动，后面两张图就毫无信息量。
	play.call("_click_at", Vector2(1.5 * TILE_PX, 1.5 * TILE_PX))
	await _settle(14)
	var rp = play.get("rule_panel")
	_add_move_rule(rp)
	await _settle(14)
	await _shot("05_play_rule_panel", play)
	# 拍完撤掉拖拽状态、删掉为演示而加的那条开火指令与两个条件，
	# 让这一关仍能顺利通关（条件默认是「视野内出现敌人」，第一关没有敌人）
	rp.call("_on_drag_ended")
	# 把信标序列改回**有效**的 [1, 2]，否则这条指令会被整条跳过、单位不动
	rp.call("_on_clear_beacons", 0)
	rp.call("_on_append_beacon", 0, 1)
	rp.call("_on_append_beacon", 0, 2)
	rp.call("_on_delete_rule", 1)
	rp.call("_on_delete_condition", 0, 1)
	rp.call("_on_delete_condition", 0, 0)
	await _settle(6)
	rp.call("close")
	await _settle(8)

	# 推演期：点开始，让它走一段
	var tb: Control = play.get("toolbar")
	tb.get_node("Row/Btn_start").emit_signal("pressed")
	for i in 60:
		play.get("session").call("step_tick")
	await _settle(10)
	await _shot("06_play_running", play)

	# 结算期：推到结束（同时驱动时钟，让用时不为 0）
	var guard := 0
	var clk = play.get("clock")
	while int(play.get("session").get("verdict")) == 0 and guard < 4000:
		clk.call("_physics_process", 1.0 / 60.0)
		guard += 1
	await _settle(20)
	await _shot("07_result_screen", play)
	play.get("result_screen").call("hide_result")
	await _settle(8)

	# ---- 8. 机制说明面板 ----
	play.get("toolbar").get_node("Row/Btn_help").emit_signal("pressed")
	await _settle(16)
	await _shot("08_help_panel", play)
	play.get("help_panel").call("close_panel")
	await _settle(8)

	# ---- 9. 暂停菜单（打开会把整棵树 paused，所以本脚本必须是 ALWAYS）----
	play.call("_toggle_pause")
	await _settle(16)
	await _shot("09_pause_menu", play)
	play.call("_toggle_pause")
	await _settle(8)

	# ---- 10. 关卡编辑器 ----
	play.queue_free()
	await _settle(6)
	var ed: Control = (load("res://src/editor/editor_scene.tscn") as PackedScene).instantiate()
	add_child(ed)
	await _settle(24)
	ed.call("press_tool", 1)                 # 选「刷障碍」，让工具按钮有选中态
	# 把失败条件换成「超时」，这样属性面板上能看到**条件类型下拉 + 秒数参数**
	# （FR-EDIT-04/05 要求"可增删条件并配置参数"，只读文本体现不出这一点）。
	# 只改内存里的 level_data，本脚本从不点保存，不会动真实关卡文件。
	ed.call("_on_condition_type_changed", "lose", 0, "timeout")
	ed.call("_on_condition_param_changed", "lose", 0, "seconds", 30.0)
	await _settle(10)
	await _shot("10_editor", ed)

	# ---- 16. 编辑器「新建关卡」（FR-TEST-05 的第一步）----
	# 拍一张"刚新建、尚未保存"的空白关卡：状态栏应提示尚未保存，地图是空白 7×7
	ed.call("_do_new_level")
	await _settle(14)
	await _shot("16_editor_new_level", ed)

	# ---- 17. 编辑器的「打开关卡」列表（用户要求：列表项显示关卡名称）----
	# ---- 18. 剧情播放器（D-25，策划案 v2 3.7）----
	var story: Control = StoryPlayerScript.new()
	add_child(story)
	story.call("load_story", StoryPlayerScript.DEFAULT_STORY)
	story.call("open_player")
	await _settle(10)
	await _shot("18_story_player", story)
	story.call("skip_all")
	story.queue_free()
	await _settle(6)

	ed.call("_do_open_level_menu")
	await _settle(14)
	await _shot("17_editor_open_level", ed)
	var om := ed.find_child("OpenLevelMenu", true, false) as PopupMenu
	if om != null:
		om.hide()
	await _settle(6)
	ed.queue_free()
	await _settle(6)

	# ---- 11. 敌人视野辅助显示（第三关有敌人）----
	var play3: Node = (load("res://src/play/play_scene.tscn") as PackedScene).instantiate()
	play3.call("load_level_id", "tutorial_03")
	add_child(play3)
	await _settle(20)
	play3.get("intro_dialog").call("press_ok")
	await _settle(10)
	_ab_pair = "12_no_vision"          # 下一张是同状态的对照图
	await _shot("11_enemy_vision", play3)
	# 同一关再拍一张"关掉视野"的，供 A/B 对比。
	# 【为什么要成对拍】视野圈是**半透明描边**，压在墙/地板上会混色，
	# 单张图里没法用"是否等于某个固定颜色"来判定它画在哪。
	# 成对拍就能断言"圈上的像素变了、圈外的像素一模一样"。
	# 【必须在 _shot 之前设好】元数据是在 _shot 里**打印**出去的，
	# 事后改内存里的 metas 不会进 SHOTMETA 行 —— 检查器读到空配对就会**静默跳过**
	# 整个 A/B 断言（我第一版就是这样：断言数从 233 掉到 225，却全绿）。
	_ab_pair = ""
	play3.get("toolbar").call("set_vision_visible", false)
	play3.get("toolbar").emit_signal("vision_toggled", false)
	await _settle(10)
	await _shot("12_no_vision", play3)
	# 视野开回来，后面的图不该受这张影响
	play3.get("toolbar").call("set_vision_visible", true)
	play3.get("toolbar").emit_signal("vision_toggled", true)

	# ---- 13. 子弹在飞（FR-CBT-01「有明显飞行过程，不是瞬时命中」）----
	# 第三关的冰寒单位射程 10，开局就够得着 (5,0) 的敌人；弹速 12 格/秒
	# → 约 36 tick 抵达。取第 18 tick 拍，子弹正好在半路。
	var fire_act: RefCounted = RuleActionScript.from_dict(
		{"type": RuleActionScript.T_SET_FIRE_MODE, "fire": true})
	for u3 in (play3.get("session").get("units") as Array):
		if int(u3.get("team")) == 0:
			u3.set("rules", [RuleEngineScript.make_rule([], [fire_act])])
	play3.get("toolbar").get_node("Row/Btn_start").emit_signal("pressed")
	for _i in 18:
		play3.get("clock").call("_physics_process", 1.0 / 60.0)
	await _settle(4)
	await _shot("13_projectile_in_flight", play3)

	# ---- 14. 第三关结算 ----
	var g3 := 0
	while int(play3.get("session").get("verdict")) == 0 and g3 < 2400:
		for _j in 4:
			play3.get("clock").call("_physics_process", 1.0 / 60.0)
			g3 += 1
		await get_tree().process_frame
	await _settle(16)
	await _shot("14_level3_result", play3)
	play3.queue_free()
	await _settle(6)

	# ---- 15. 第二关编制期（14×3 长条地图，含墙与敌人）----
	var play2: Node = (load("res://src/play/play_scene.tscn") as PackedScene).instantiate()
	play2.call("load_level_id", "tutorial_02")
	add_child(play2)
	await _settle(20)
	play2.get("intro_dialog").call("press_ok")
	# 【这张是**地形验证图**，必须关掉视野】我方视野弧会叠在地形上：第二关我方在
	# (1,1)、射程 3，视野圈**恰好穿过 (4,1) 的中心**，于是"墙是灰色"的断言会读到
	# 混色 (0.44,0.68,0.56)。不是 bug，是这张图的取样前提被新功能破坏了。
	play2.get("toolbar").call("set_vision_visible", false)
	play2.get("toolbar").emit_signal("vision_toggled", false)
	await _settle(10)
	await _shot("15_level2_build", play2)

	print("SHOT 完成，共 ", metas.size(), " 张")

	# 把元数据汇总成一行 JSON，方便外部解析
	var blob := JSON.stringify({"shots": metas})
	print("SHOTMETA_ALL ", blob)
	# 【退出码要区分"拍了但前提不对"和"正常完成"】
	# 否则前提不满足只会留下一行容易看漏的打印，而调用方以为一切正常。
	if not _precondition_failures.is_empty():
		print("SHOT 前提不满足 %d 处：%s" % [
			_precondition_failures.size(), str(_precondition_failures)])
		get_tree().quit(3)
		return
	get_tree().quit()


## 截图前提检查：不满足就**明确报错**，而不是拍一张"看起来还行"的图。
## 截图工具本身没有断言机制（断言在 check_shots.py 里），但"拍之前状态对不对"
## 只有这里知道，所以留一个最小出口。
func _ok_shot_precondition(cond: bool, what: String) -> void:
	if cond:
		print("   [前提OK] %s" % what)
	else:
		print("   [前提不满足] %s" % what)
		_precondition_failures.append(what)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## 走一遍玩家真实操作：选「沿着信标移动」→ 加指令 → 按顺序追加信标 1、2
func _add_move_rule(rp) -> void:
	if rp == null:
		return
	var picker := rp.get_node_or_null("Drawer/Column/AddRow/ActionPicker") as OptionButton
	var add := rp.get_node_or_null("Drawer/Column/AddRow/AddRuleButton") as Button
	if picker == null or add == null:
		print("SHOT 警告：抽屉里找不到下拉/按钮，跳过加指令")
		return
	for i in picker.item_count:
		if str(picker.get_item_metadata(i)) == "move_along_beacons":
			picker.selected = i
	add.emit_signal("pressed")
	rp.call("_on_append_beacon", 0, 1)
	rp.call("_on_append_beacon", 0, 2)
	# 再加两个条件，让截图能看到条件区（与/或、参数控件、加条件按钮）。
	# 【注意】条件是真的会拦住规则的：默认条件「视野内出现敌人」在第一关
	# 永远不成立（本关没有敌人），所以拍完必须把它们删掉，否则单位不会动、
	# 后面就不会有推演与结算画面（实测 07 那张图退化成了推演期）。
	rp.call("_on_add_condition", 0)
	rp.call("_on_add_condition", 0)
	# 再加一条指令，这样"上移/下移"两个按钮才有可点的地方，也能看到排序控件。
	# 开火与移动不冲突（冲突键不同），所以不影响这一关的通关。
	var picker2 := rp.get_node_or_null("Drawer/Column/AddRow/ActionPicker") as OptionButton
	if picker2 != null:
		for i in picker2.item_count:
			if str(picker2.get_item_metadata(i)) == "set_fire_mode":
				picker2.selected = i
	rp.call("_on_add_rule")
	# 故意让第 1 条指令引用一个**还不存在的信标**（3 号），于是：
	# · 指令行按详设 09 §4.5 立刻标黄
	# · 工具条右侧出现「无效指令 1」角标（详设 10 的 1.3）
	# 拍完必须改回来 —— 引用了不存在信标的指令会被引擎**整条跳过**，关卡就打不通了。
	rp.call("_on_clear_beacons", 0)
	rp.call("_on_append_beacon", 0, 1)
	rp.call("_on_append_beacon", 0, 2)
	rp.call("_on_append_beacon", 0, 3)
	# 拖拽到第 2 条上方 → 插入指示线亮起，正好拍进图里
	rp.call("_on_drag_started", 0)
	rp.call("_on_drag_hover", 1, true)
	await _settle(10)


## 截一张并记录元数据（scene 非空时同时记录地图/信标等信息）
func _shot(shot_name: String, scene = null) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	var err: int = img.save_png(path)

	# 颜色统计：不靠眼睛也能判断"到底画出东西没有"
	var seen := {}
	var fg := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c: Color = img.get_pixel(x, y)
			seen[c.to_rgba32()] = true
			if c.r + c.g + c.b > 0.45:
				fg += 1
	print("SHOT %s err=%d size=%s 唯一色=%d 前景采样=%d" % [
		shot_name, err, str(img.get_size()), seen.size(), fg])

	var meta := {
		"name": shot_name,
		"file": path.replace("\\", "/"),
		"viewport": [img.get_width(), img.get_height()],
		"save_err": err,
		"ab_pair": _ab_pair,
		"unique_colors": seen.size(),
		"fg_samples": fg,
	}
	if scene != null:
		meta.merge(_scene_meta(scene), true)
		# 编辑器场景额外报三栏矩形，供"不重叠"断言用
		if scene.has_method("main_rects"):
			var r: Dictionary = scene.call("main_rects")
			meta["editor_rects"] = {
				"left": _rect_arr(r["left"]),
				"center": _rect_arr(r["center"]),
				"right": _rect_arr(r["right"]),
			}
		# 编辑器里胜负条件的**类型下拉与参数控件**是否真的生成了
		# 【必须守卫】`status_text()` 只有编辑器场景有；不加判断就对每一张图都调，
		# 玩法场景会报 `Nonexistent function 'status_text (via call)'`（实测 12 个错误）。
		# 这与"把 PackedScene 当脚本用"是同一类错：**假设了对方有什么能力**。
		if scene.has_method("status_text"):
			meta["editor_status"] = str(scene.call("status_text"))
			# 「打开关卡」菜单的内容（用来断言"列表项是名称、元数据是 id"）
			#
			# 【缩进必须与上一行同级】我第一版这段用了少一层的缩进，
			# 结果 ①它跑到了 `status_text` 守卫之外，
			# ②**原本紧跟其后的 `var esess` 被吞进了 `if om2 != null:` 里** ——
			# 于是"编辑器地图尺寸"这个字段只在菜单展开时才存在。
			# 像素检查当场报出 `NonexNone`（281/282）。
			# **生成式补丁里的缩进就是控制流**，不能当成排版。
			var om2 := scene.find_child("OpenLevelMenu", true, false) as PopupMenu
			if om2 != null:
				var mitems: Array = []
				for i3 in om2.item_count:
					mitems.append(str(om2.get_item_text(i3)))
				meta["open_menu_items"] = mitems
				meta["open_menu_visible"] = om2.visible
			var esess = scene.get("session")
			if esess != null:
				meta["editor_map"] = {"w": int(esess.call("map_width")),
					"h": int(esess.call("map_height"))}
		# 剧情播放器（D-25）：拍它时 scene 就是播放器自己
		if scene.has_method("segment_count"):
			meta["story_showing"] = bool(scene.call("is_open"))
			meta["story_segments"] = int(scene.call("segment_count"))
			meta["story_rect"] = _rect_arr(scene.call("panel_rect"))
		var insp = scene.get("inspector")
		if insp != null:
			# 【期望值由数据算出来】"该不该有秒数控件"取决于关卡里有没有
			# timeout / survive_until 条件 —— 不能写死成"编辑器图就必须有"，
			# 否则新建关卡（失败条件 all_allies_dead）那张会误报。
			var esess2 = scene.get("session")
			var expect_sec := false
			if esess2 != null:
				var ld = esess2.get("level_data")
				for grp in ["win", "lose"]:
					for c in ((ld.get(grp) as Dictionary).get("conditions", []) as Array):
						var ct := str((c as Dictionary).get("type"))
						if ct == "timeout" or ct == "survive_until":
							expect_sec = true
			meta["editor_cond_widgets"] = {
				"expect_seconds": expect_sec,
				"type_picker": insp.find_child("CondType_lose_0", true, false) != null,
				"seconds_field": insp.find_child("F_seconds", true, false) != null,
			}
	metas.append(meta)
	print("SHOTMETA ", JSON.stringify(meta))


## 采集"瓦片 → 屏幕像素"换算所需的一切，供 check_shots.py 复用
func _scene_meta(scene) -> Dictionary:
	var out := {"tile_px": TILE_PX}
	var session = scene.get("session")
	if session == null:
		return out
	# 【编辑器会话没有地图对象】EditorSession 与 LevelSession 都叫 `session`，
	# 但前者数据结构完全不同（没有 map/units/verdict）。不判这一下就会对 Nil
	# 调方法（实测报 `Nonexistent function 'get' in base 'Nil'`）。
	var mp = session.get("map")
	if mp == null:
		return out
	var cam: Camera2D = scene.get("camera")
	out["map"] = {"w": int(mp.get("width")), "h": int(mp.get("height"))}
	out["zoom"] = cam.zoom.x if cam != null else 1.0
	out["camera"] = [cam.position.x, cam.position.y] if cam != null else [0.0, 0.0]
	out["goals"] = _as_arrays(mp.call("goal_cells"))
	out["beacons"] = _beacon_tiles(scene)
	out["walls"] = _wall_tiles(mp)
	out["units"] = _unit_tiles(session)
	out["state"] = int(session.get("state"))
	out["verdict"] = int(session.get("verdict"))
	# 敌人视野圈：把"圆心（瓦片）与半径（格）"报出来，供像素断言验圈真的画在半径上
	var enemies: Array = []
	for u in (session.get("units") as Array):
		if int(u.get("team")) == 1:
			var up: Vector2 = u.get("position_logic")
			enemies.append({
				"logic": [up.x, up.y],
				"radius": float(u.call("effective_vision_radius")),
			})
	out["enemies"] = enemies
	# 子弹：把每颗的位置与阵营报出来，供像素断言验"真的画在飞行的位置上"
	var shots: Array = []
	var bs = session.get("battle_state")
	if bs != null:
		for k in (bs.get("projectiles") as Dictionary).keys():
			var pr = (bs.get("projectiles") as Dictionary).get(k)
			if pr != null and is_instance_valid(pr):
				var pp: Vector2 = pr.get("position_logic")
				shots.append({"logic": [pp.x, pp.y], "team": int(pr.get("team"))})
	out["projectiles"] = shots
	# 视野圈：**双方都报**（第 14 轮补上了我方视野，这里要能被断言）
	var vis: Array = []
	if session != null:
		for u in (session.get("units") as Array):
			if u == null or bool(u.get("is_dead")):
				continue
			var rr: float = float(u.call("effective_vision_radius"))
			if rr <= 0.0:
				continue
			var pl: Vector2 = u.get("position_logic")
			vis.append({"logic": [pl.x, pl.y], "radius": rr, "team": int(u.get("team"))})
	out["visions"] = vis
	# 地图外框四条边的取样点（世界坐标），用来验"边界线有没有画出来"
	# 【类型要判对】`session.get("map")` 返回的是 **Dictionary**（不是 RefCounted）。
	# 我第一版写成 `(mp0 as RefCounted).get(...)`，强转失败得到 null，
	# 于是每张图都抛一次 "Cannot call method 'get' on a null value"
	# —— 一次运行刷了 12 个错误，并且**把整个元数据采集打断了**（后续字段全丢）。
	# 教训：从 Variant 取出来的东西，**先判类型再用**。
	var mp0 = session.get("map")
	if mp0 is Dictionary:
		var mw := float((mp0 as Dictionary).get("width", 0))
		var mh := float((mp0 as Dictionary).get("height", 0))
		out["frame_samples"] = [
			[(mw * 0.5) * TILE_PX, 2.0],
			[(mw * 0.5) * TILE_PX, mh * TILE_PX - 2.0],
			[2.0, (mh * 0.5) * TILE_PX],
			[mw * TILE_PX - 2.0, (mh * 0.5) * TILE_PX],
		]
		# 一条内部网格线上的点（第 2 列竖线的中点）
		out["grid_sample"] = [2.0 * TILE_PX, (mh * 0.5) * TILE_PX]
	var rnd = scene.get("renderer")
	if rnd != null:
		out["show_vision"] = bool(rnd.get("show_vision"))
	out["ui"] = _ui_meta(scene)
	return out


## UI 几何诊断：抽屉/工具条到底占了多大、在哪儿。
## 这些数字比"我看截图觉得窄了"可靠得多（截图只能量个大概）。
func _ui_meta(scene) -> Dictionary:
	var out := {}
	# 主菜单：入口按钮与标题的**相对位置**（用户报过"按钮跑到标题上方"）
	var vbox: Node = scene.get_node_or_null("Center/VBox")
	if vbox != null:
		var entry: Array = []
		for nm2 in ["GodEntryButton", "EditorEntryButton"]:
			var b2 := vbox.get_node_or_null(nm2) as Control
			if b2 != null:
				var r2 := b2.get_global_rect()
				entry.append({"name": nm2, "rect": [r2.position.x, r2.position.y,
					r2.size.x, r2.size.y]})
		out["menu_entries"] = entry
		var tl := vbox.get_node_or_null("Title") as Control
		if tl != null:
			var rt := tl.get_global_rect()
			out["menu_title_rect"] = [rt.position.x, rt.position.y, rt.size.x, rt.size.y]
		var st2 := vbox.get_node_or_null("Subtitle") as Control
		if st2 != null:
			var rs := st2.get_global_rect()
			out["menu_subtitle_rect"] = [rs.position.x, rs.position.y, rs.size.x, rs.size.y]
	var rp = scene.get("rule_panel")
	if rp != null:
		out["rule_panel_size"] = [rp.size.x, rp.size.y]
		out["drawer_rect"] = _rect_arr(rp.call("drawer_rect"))
		out["drawer_ratio"] = rp.call("width_ratio")
		out["drawer_open"] = rp.call("is_open")
		# 拖拽插入指示线（FR-CMD-08）：用来断言"拖拽时确实画了那条线"
		out["drop_indicator"] = rp.call("indicator_visible")
		out["drop_indicator_y"] = rp.call("indicator_y")
		out["rule_count"] = int((rp.get("target_unit").get("rules") as Array).size()) \
			if rp.get("target_unit") != null else 0
		# 左条件 / 右行为（用户补充需求）：**由面板自己报告**两栏矩形。
		#
		# 【为什么不用 find_child("Conds_0")】我第一版就是那样写的 —— 结果**永远
		# 返回 null**，于是这条像素断言被**静默跳过**，报告照样全绿
		# （和第 11 轮 A/B 配对是同一类失败）。面板本来就知道两栏是谁，
		# 直接问它最可靠，也不会因为节点改名而失效。
		var sr = rp.call("split_rects", 0)      # 不写 :=（call() 返回 Variant）
		if sr is Dictionary and not (sr as Dictionary).is_empty():
			# 【注意它在 ui 字典里】`_ui_meta()` 返回的是 ui 子字典，
			# 所以这个字段的位置是 `meta["ui"]["split_rects"]`。
			# 我第一版让检查器去读顶层 `meta["split_rects"]` —— 永远读不到，
			# 于是左右布局断言又被静默跳过（同一类问题第三次）。
			out["split_rects"] = sr
		var tb2 = scene.get("toolbar")
		if tb2 != null:
			out["invalid_badge_visible"] = tb2.call("is_invalid_badge_visible")
			out["invalid_text"] = str(tb2.call("invalid_text"))
	var tb = scene.get("toolbar")
	if tb != null:
		out["toolbar_rect"] = _rect_arr(tb.get_global_rect())
	var banner = scene.get_node_or_null("HUD/BannerLayer")
	if banner != null:
		out["banner_rect"] = _rect_arr(banner.get_global_rect())
	# 两个模态弹窗的面板矩形：用来断言"居中"（贴左上角是个真实踩过的 bug）
	var dlg = scene.get("intro_dialog")
	if dlg != null:
		out["intro_showing"] = dlg.call("is_showing")
		out["intro_panel_rect"] = _rect_arr(dlg.call("panel_rect"))
	var rsc = scene.get("result_screen")
	if rsc != null:
		out["result_showing"] = rsc.call("is_showing")
		out["result_panel_rect"] = _rect_arr(rsc.call("panel_rect"))
	var hp = scene.get("help_panel")
	if hp != null:
		out["help_showing"] = hp.call("is_open")
		out["help_panel_rect"] = _rect_arr(hp.call("panel_rect"))
		out["help_sections"] = int(hp.call("section_count"))
	var pm = scene.get("pause_menu")
	if pm != null:
		out["pause_showing"] = pm.call("is_open")
	return out


func _rect_arr(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _as_arrays(cells) -> Array:
	var out: Array = []
	for c in (cells as Array):
		out.append([int((c as Vector2i).x), int((c as Vector2i).y)])
	return out


func _beacon_tiles(scene) -> Array:
	var out: Array = []
	var bl = scene.get("beacon_layer")
	if bl == null:
		return out
	# 【D-22】信标按归属单位着色，所以元数据要带上 owner 与**渲染器实际用的颜色**，
	# 像素断言才能按颜色采样（而不是按写死的青色）。
	var rend = scene.get("renderer")
	for i in range(1, int(bl.call("count")) + 1):
		var t = bl.call("at", i)      # at() 是 1 起的序号
		if t == null:
			continue
		var owner := int(bl.call("owner_at", i))
		var col: Array = [0.35, 0.80, 1.00]
		if rend != null and rend.has_method("beacon_face_color"):
			var c: Color = rend.call("beacon_face_color", owner)
			col = [c.r, c.g, c.b]
		out.append({
			"tile": [int((t as Vector2i).x), int((t as Vector2i).y)],
			"owner": owner,
			"ordinal": int(bl.call("owner_ordinal", i)),
			"color": col,
		})
	return out


func _wall_tiles(mp) -> Array:
	var out: Array = []
	for j in int(mp.get("height")):
		for i in int(mp.get("width")):
			if int(mp.call("tile_at", i, j)) == 1:
				out.append([i, j])
	return out


func _unit_tiles(session) -> Array:
	var out: Array = []
	for u in (session.get("units") as Array):
		var p: Vector2 = u.get("position_logic")
		out.append({
			"team": int(u.get("team")),
			"logic": [p.x, p.y],
			"tile": [int(floor(p.x)), int(floor(p.y))],
		})
	return out
