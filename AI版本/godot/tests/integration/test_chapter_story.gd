extends GutTest
## P5（07 §10）：章节数据与解锁规则（存在一条已完成的前驱连线）、节点结构可扩到 24 个（legacy_ids）、节点连线选关界面；
## StoryPlayer：每关开始 / 胜利 / 失败播放 <level_id>_intro / _win / _lose；剧情文件缺失或 scenes 为空 = 静默不触发（无弹窗、无告警）。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const SaveManagerScript: GDScript = preload("res://scripts/autoloads/save_manager.gd")
const SELECT_SCENE: PackedScene = preload("res://scenes/screens/level_select.tscn")
const SELECT_SCRIPT: GDScript = preload("res://scripts/screens/level_select.gd")
const STORY_SCENE: PackedScene = preload("res://scenes/ui/dialogue_overlay.tscn")
const TMP_DIR: String = "user://test_tmp/stories"
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
	"presets": [],
}

var _saved_data: Dictionary
var _saved_level_id: String
var _saved_unlocks: Dictionary
var _saved_progress: Dictionary


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.autosave = false          # 2026-10-20：选关 / 一级地图会记解锁动画的揭开记录，测试里不写盘
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	_saved_progress = GameState.progress
	GameState.unlocks = ALL_UNLOCKED
	DataRegistry.story_dir = DataRegistry.STORY_DIR
	SELECT_SCRIPT.set("chapter_index", DataRegistry.get_chapters().find(DataRegistry.get_chapter("chapter_01")))   # 第一章（不分区域）的地图测试
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	for f: String in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	SaveManager.autosave = true
	GameState.unlocks = _saved_unlocks
	GameState.progress = _saved_progress
	DataRegistry.story_dir = DataRegistry.STORY_DIR
	SELECT_SCRIPT.set("chapter_index", -1)


## 把部分正式剧情复制到临时目录（其余视为"已删除"）
func _story_dir_with(ids: Array[String]) -> void:
	for sid: String in ids:
		var src: String = DataRegistry.STORY_DIR.path_join("%s.json" % sid)
		var f: FileAccess = FileAccess.open(TMP_DIR.path_join("%s.json" % sid), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(src))
		f.close()
	DataRegistry.story_dir = TMP_DIR


func _no_engine_errors_or_warnings() -> void:
	assert_eq(get_errors().size(), 0, "剧情缺失时没有任何告警 / 错误")


# ---- 章节 ----
func test_chapter_01_has_25_nodes_and_valid_links() -> void:
	var ch: ChapterDef = DataRegistry.get_chapter("chapter_01")
	assert_not_null(ch)
	assert_eq(ch.nodes.size(), 25, "10 §3.1：扩到 25 个节点")
	assert_eq(ch.map_size, Vector2(3240.0, 1080.0), "map_size = R3 宽图按高 1080 等比（P6）")
	for i: int in 8:
		assert_eq(str(ch.nodes[i]["level"]), "level_0%d" % (i + 1), "1–8 为现有关卡，编号不变")
		assert_eq(str(ch.nodes[i]["id"]), "level_0%d" % (i + 1), "关卡节点 id 缺省 = level")
	for i: int in range(8, 25):
		assert_true(bool(ch.nodes[i]["placeholder"]), "9–25 为占位节点")
		assert_eq(str(ch.nodes[i]["id"]), "node_%02d" % (i + 1))
		assert_eq(str(ch.nodes[i]["level"]), "")
	assert_eq(ch.predecessors("level_02"), ["level_01"] as Array[String])
	assert_true(bool(ch.node_of("level_08")["boss"]))
	assert_eq(DataRegistry.chapter_of("level_05"), ch)
	assert_false(DataRegistry.has_errors)


## 10 §3.1：node_of(id)；占位节点恒锁定；指向占位节点的连线按锁定色
func test_placeholder_nodes_locked_and_node_of_id() -> void:
	var ch: ChapterDef = DataRegistry.get_chapter("chapter_01")
	var n09: Dictionary = ch.node_of("node_09")
	assert_false(n09.is_empty(), "node_of 按 id 取节点")
	assert_true(ch.is_placeholder("node_09"))
	assert_eq(str(n09["title_key"]), "ui.node_placeholder")
	assert_eq(ch.node_of("level_03"), ch.node_of_level("level_03"), "关卡节点可用关卡 id 取")
	var all_done: Array = []
	for i: int in 8:
		all_done.append("level_0%d" % (i + 1))
	assert_false(ch.is_unlocked("node_09", all_done, ["level_01"]), "前驱全部通关，占位节点仍锁定")
	assert_false(ch.is_unlocked("node_25", all_done, ["level_01"]))
	assert_eq(ch.link_state("level_08", "node_09", all_done), 0, "指向占位节点的连线 = 锁定")
	assert_eq(ch.link_state("node_09", "node_10", all_done), 0)
	# 校验：占位节点不得有 level / boss / story_on_unlock；无 level 时 id 必填
	var before: int = DataReader.error_count
	DataReader.silent = true
	ChapterDef.from_dict({ "id": "c", "title": "t", "regions": [], "nodes": [
		{ "id": "x", "placeholder": true, "boss": true, "pos": [0, 0], "links": [] },
		{ "pos": [0, 0], "links": [] },
	] }, "test_placeholder")
	DataReader.silent = false
	assert_eq(DataReader.error_count, before + 3, "占位节点带 boss 报错；无 level 无 id 报两条")


func test_unlock_requires_completed_predecessor_link() -> void:
	var ch: ChapterDef = DataRegistry.get_chapter("chapter_01")
	var initial: Array = DataRegistry.get_initial_levels()
	assert_true(ch.is_unlocked("level_01", [], initial), "起点按初始关卡解锁")
	assert_false(ch.is_unlocked("level_02", [], initial))
	assert_true(ch.is_unlocked("level_02", ["level_01"], initial), "前驱已完成 → 解锁")
	assert_false(ch.is_unlocked("level_03", ["level_01"], initial))
	assert_eq(ch.link_state("level_01", "level_02", ["level_01"]), 1, "可挑战连线")
	assert_eq(ch.link_state("level_01", "level_02", ["level_01", "level_02"]), 2, "已完成连线")
	assert_eq(ch.link_state("level_02", "level_03", ["level_01"]), 0, "锁定连线")
	GameState.progress = { "completed": ["level_01", "level_02"], "unlocked_levels": [] }
	assert_true(GameState.is_level_unlocked("level_03"), "GameState 按章节连线判断解锁")
	assert_false(GameState.is_level_unlocked("level_04"))


func test_node_structure_supports_24_nodes_with_legacy_ids() -> void:
	var nodes: Array = []
	for i: int in 24:
		nodes.append({ "level": "level_%02d" % (i + 1), "region": "r", "pos": [i * 70, 500], "links": ["level_%02d" % (i + 2)] if i < 23 else [],
			"legacy_ids": ["old_%d" % i] if i == 3 else [] })
	var ch: ChapterDef = ChapterDef.from_dict({ "id": "c", "title": "t", "regions": [{ "id": "r", "title": "R" }], "nodes": nodes }, "test")
	assert_eq(ch.nodes.size(), 24)
	assert_eq(ch.node_of("level_04")["legacy_ids"], ["old_3"] as Array[String], "legacy_ids 映射位")
	assert_true(ch.is_unlocked("level_24", ["level_23"], ["level_01"]))


func test_level_select_draws_node_states() -> void:
	GameState.progress = { "completed": ["level_01"], "unlocked_levels": ["level_01", "level_02"] }
	var sel: Control = SELECT_SCENE.instantiate() as Control
	add_child_autofree(sel)
	sel.set("navigate", false)
	await wait_process_frames(2)
	var buttons: Dictionary = sel.get("node_buttons") as Dictionary
	assert_eq(buttons.size(), 25, "25 个节点")
	assert_eq(int(sel.call("node_state", "level_01")), 2, "已完成")
	assert_eq(int(sel.call("node_state", "level_02")), 1, "可挑战")
	assert_eq(int(sel.call("node_state", "level_03")), 0, "锁定")
	assert_eq(int(sel.call("node_state", "node_12")), 0, "占位节点锁定")
	var b1: Button = buttons["level_01"] as Button
	var b2: Button = buttons["level_02"] as Button
	var k: float = float(sel.get("_scale"))
	var dx: float = ((ch_pos(sel, "level_02")) - (ch_pos(sel, "level_01"))).x
	assert_almost_eq((b2.position + b2.size * 0.5).x - (b1.position + b1.size * 0.5).x, dx * k, 1.0, "节点按 chapter pos（设计坐标 × 缩放）摆放")
	assert_eq((b1.get_node("Nameplate") as Label).text, "01 · " + DataRegistry.get_level("level_01").title, "名牌 =「编号 · 关卡名」（批准整图 ui_22）")
	assert_eq((buttons["node_12"] as Button).get_node("Nameplate").get("text"), "未开放", "占位节点名牌")
	var ld: Dictionary = UiKit.layout_element("chapter", "link").get("data", {}) as Dictionary
	assert_eq(sel.call("link_color", "level_01", "level_02"), Color(str(ld["open"])), "可挑战连线（布局色）")


func ch_pos(sel: Control, nid: String) -> Vector2:
	return ((sel.get("chapter") as ChapterDef).node_of(nid)["pos"]) as Vector2


# ---- StoryPlayer ----
func test_story_player_plays_and_finishes() -> void:
	var sp: StoryPlayer = STORY_SCENE.instantiate() as StoryPlayer
	add_child_autofree(sp)
	watch_signals(sp)
	assert_true(sp.play_story("level_01_intro", "提示卡"))
	assert_true(sp.visible)
	assert_eq(sp.current_story, "level_01_intro")
	for i: int in 10:
		sp.advance()
		sp.advance()
	assert_false(sp.visible, "三句剧情 + 机制提示卡后结束")
	assert_signal_emitted(sp, "finished")


func test_missing_or_empty_story_is_silent() -> void:
	var sp: StoryPlayer = STORY_SCENE.instantiate() as StoryPlayer
	add_child_autofree(sp)
	assert_false(sp.play_story("level_99_intro"), "文件不存在")
	assert_false(sp.visible, "不弹任何界面")
	var f: FileAccess = FileAccess.open(TMP_DIR.path_join("empty_story.json"), FileAccess.WRITE)
	f.store_string('{ "id": "empty_story", "scenes": [] }')
	f.close()
	sp.story_dir = TMP_DIR
	assert_false(sp.play_story("empty_story"), "scenes 为空 = 不触发")
	assert_false(sp.visible)
	_no_engine_errors_or_warnings()


func test_all_24_story_files_exist_and_follow_convention() -> void:
	for lid: String in DataRegistry.get_chapter("chapter_01").level_ids():      # 第一章；30 关战役（chapter_02）见 test_campaign_levels.gd
		for kind: String in ["intro", "win", "lose"]:
			var st: Dictionary = DataRegistry.load_story("%s_%s" % [lid, kind])
			assert_false(st.is_empty(), "%s_%s 存在且有场景" % [lid, kind])
	var intro: Dictionary = DataRegistry.load_story("level_01_intro")
	assert_eq(((intro["scenes"] as Array)[0] as Dictionary)["speaker"], "witch", "第一关战前对白已迁入 _intro")
	var win8: Dictionary = DataRegistry.load_story("level_08_win")
	assert_true(str(((win8["scenes"] as Array)[0] as Dictionary)["text"]).contains("骨花核心碎裂"), "ch1_boss_outro 已迁入 level_08_win")


func test_deprecated_briefing_dialogue_and_story_id() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_01.json")) as Dictionary
	(d["briefing"] as Dictionary)["dialogue"] = []
	(d["rewards"] as Dictionary)["story_id"] = "x"
	var before: int = DataReader.messages.size()
	LevelDefinition.from_dict(d, "test")
	var msgs: String = str(DataReader.messages.slice(before))
	assert_true(msgs.contains("DEPRECATED_FIELD briefing.dialogue"))
	assert_true(msgs.contains("DEPRECATED_FIELD rewards.story_id"))
	for e: Object in get_errors():
		e.set("handled", true)


# ---- 关卡中的三处触发 ----
func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	return root


func _story_player(root: Node2D) -> StoryPlayer:
	return root.find_child("DialogueOverlay", true, false) as StoryPlayer


func _run_to_end(c: BattleController) -> void:
	for i: int in int(60.0 / SimTypes.SIM_DT):
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()


func test_intro_and_win_stories_play() -> void:
	var root: Node2D = _battle("level_01")
	await wait_process_frames(2)
	var sp: StoryPlayer = _story_player(root)
	assert_true(sp.visible, "关卡开始播放剧情")
	assert_eq(sp.current_story, "level_01_intro")
	sp.visible = false
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	assert_true(c.start())
	_run_to_end(c)
	assert_eq(c.world.result, SimTypes.BattleResult.WIN)
	assert_true(sp.visible)
	assert_eq(sp.current_story, "level_01_win", "胜利播放 _win")


func test_lose_story_plays() -> void:
	var root: Node2D = _battle("level_01")
	await wait_process_frames(2)
	var sp: StoryPlayer = _story_player(root)
	sp.visible = false
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	for uid: String in c.uids():
		c.set_rules(uid, SimFactory.to_rules([SimFactory.r_idle()]))   # 只待机 → 被击杀
	assert_true(c.start())
	_run_to_end(c)
	assert_eq(c.world.result, SimTypes.BattleResult.LOSE)
	assert_eq(sp.current_story, "level_01_lose", "失败播放 _lose")


func test_deleted_story_files_are_silently_skipped() -> void:
	_story_dir_with(["level_01_win"] as Array[String])      # 删除 _intro 与 _lose
	var root: Node2D = _battle("level_01")
	await wait_process_frames(2)
	var sp: StoryPlayer = _story_player(root)
	assert_false(sp.visible, "开始剧情缺失：静默不触发")
	var popup: Control = root.find_child("MechanicsPopup", true, false) as Control
	assert_false(popup.visible, "也不改弹机制提示卡")
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	for uid: String in c.uids():
		c.set_rules(uid, SimFactory.to_rules([SimFactory.r_idle()]))
	assert_true(c.start())
	_run_to_end(c)
	assert_eq(c.world.result, SimTypes.BattleResult.LOSE)
	assert_false(sp.visible, "失败剧情缺失：静默不触发")
	_no_engine_errors_or_warnings()
	# 胜利剧情仍在 → 照常播放
	c.reset()
	assert_true(c.apply_recommended())
	assert_true(c.start())
	_run_to_end(c)
	assert_eq(c.world.result, SimTypes.BattleResult.WIN)
	assert_eq(sp.current_story, "level_01_win")


## 完成标准：按章节连线依次通关 8 关，每通一关解锁下一节点（奖励流程 SaveManager.apply_rewards，内存存档，不写盘）
func test_completing_levels_unlocks_next_nodes_in_order() -> void:
	var save: Dictionary = SaveManagerScript.call("new_save", DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels()) as Dictionary
	GameState.progress = save["progress"] as Dictionary
	var ids: Array[String] = DataRegistry.get_chapter("chapter_01").level_ids()      # 第一章；30 关战役（chapter_02）见 test_campaign_levels.gd
	for i: int in ids.size():
		assert_true(GameState.is_level_unlocked(ids[i]), "%s 已解锁" % ids[i])
		if i + 1 < ids.size():
			assert_false(GameState.is_level_unlocked(ids[i + 1]), "%s 尚未解锁" % ids[i + 1])
		SaveManagerScript.call("apply_rewards", save, ids[i], DataRegistry.get_level(ids[i]).rewards)
		GameState.progress = save["progress"] as Dictionary
	assert_eq((GameState.progress["completed"] as Array).size(), 8, "8 关全部通关")
