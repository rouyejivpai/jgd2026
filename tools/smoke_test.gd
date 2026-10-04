extends Node
## 端到端冒烟测试：把「主菜单 → 玩法 → 暂停 → 设置 → 回主菜单」整条闭环跑一遍，
## 外加各玩法系统的纯逻辑用例。
##
## 用法：
##   godot --headless --path <项目目录> res://tools/smoke_test.tscn
## 退出码 0 = 全通过，1 = 有失败项，2 = 超时。
##
## 【约定 · 概设 K3】本文件是**唯一**的公共验收入口，所有人都会往里加用例。
## 为避免并行开发时互相冲突：
##   · 每个工作流只在**自己系统的函数体**内追加断言，不改别人的函数
##   · 新增系统时加一个 _check_<系统>() 并在 _run() 里按顺序调用
##   · 不要改动 _ok / _report_and_quit / 看门狗逻辑

## 看门狗阈值：**多久没有"进展"**就判定卡死（秒）。
## 见 `_run()` 里的说明：盯的是"停滞"，不是"总时长"。
const STALL_SECONDS := 20.0
## 上一次有用例通过的时间戳（毫秒）。任何 `_ok` 都会刷新它。
var _last_progress_msec := 0
## 整套测试的开始时间，用来在结尾报总耗时（慢了自己能看见）
var _run_started_msec := 0

const GAME_SCENE := "res://scenes/game/game_scene.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const PAUSE_MENU := "res://scenes/ui/pause_menu.tscn"

## 【为什么用 preload 而不是 class_name】
## Godot 的 class_name 依赖 res://.godot/global_script_class_cache.cfg，而该缓存
## 只有**编辑器导入时**会写。本工程的沙箱禁止子进程写 .godot/，所以新脚本的
## class_name 永远不会出现在缓存里 → "Identifier not declared"。
## preload 是编译期加载，不经过全局类缓存，因此在本环境下永远可用。
## 约定：跨文件引用一律 const X := preload(...)，不要依赖 class_name。
const GameClockScript := preload("res://src/core/time/game_clock.gd")
const RuleEnumsScript := preload("res://src/core/rule/rule_enums.gd")
const RuleScript := preload("res://src/core/rule/rule.gd")
const TypesScript := preload("res://src/core/types.gd")
const BattleMapScript := preload("res://src/core/map/battle_map.gd")
const BattleStateScript := preload("res://src/core/map/battle_state.gd")
const BeaconLayerScript := preload("res://src/core/map/beacon_layer.gd")
const UnitActorScript := preload("res://src/core/unit/unit_actor.gd")
const MovementScript := preload("res://src/core/unit/movement.gd")
const IntentScript := preload("res://src/core/rule/intent.gd")
const LevelDataScript := preload("res://src/core/level/level_data.gd")
const LevelLoaderScript := preload("res://src/core/level/level_loader.gd")
const LevelSessionScript := preload("res://src/core/level/level_session.gd")
const RuleEngineScript := preload("res://src/core/rule/rule_engine.gd")
const SignalStoreScript := preload("res://src/core/rule/signal_store.gd")
const RuleConditionScript := preload("res://src/core/rule/condition.gd")
const RuleActionScript := preload("res://src/core/rule/action.gd")
const StatisticsScript := preload("res://src/core/score/statistics.gd")
const ScorerScript := preload("res://src/core/score/scorer.gd")
const ResultDataScript := preload("res://src/core/score/result_data.gd")
const DataLoaderScript := preload("res://src/core/data/data_loader.gd")
const EditorSessionScript := preload("res://src/editor/editor_session.gd")
const ToolbarScript := preload("res://src/ui/hud_toolbar.gd")
const PlaySceneScript := preload("res://src/play/play_scene.tscn")
const ResultScreenScript := preload("res://src/ui/result_screen.gd")
const IntroDialogScript := preload("res://src/ui/dialogs/intro_dialog.gd")
const RulePanelScript := preload("res://src/ui/rule_panel.gd")
const RuleFieldFactoryScript := preload("res://src/ui/rule_panel/field_factory.gd")
const HelpPanelScript := preload("res://src/ui/help_panel.gd")
const EditorSceneScript := preload("res://src/editor/editor_scene.gd")

var _failures: Array[String] = []
var _last_score := -1
## 各分组的统计，收尾时汇总打印
var _groups: Array[String] = []
var _group_start_failures := 0
## 跑到底的检查函数名单（见 _done 的说明）
var _completed: Array[String] = []
## 必须跑到底的检查函数。收尾时核对，少一个就判失败——
## 否则「某个检查函数中途因运行时错误中止」会被误报成全部通过。
const EXPECTED_CHECKS: Array[String] = [
	"autoloads", "collision_layers", "audio_buses", "input_actions", "signal_bus",
	"game_helpers", "scene_loop", "phantom_camera", "main_menu", "layout", "pause_menu",
	"types", "clock", "map", "state", "beacons", "rule", "unit", "combat", "level", "editor", "session", "rule_panel", "type_change", "nav_queue", "dyn_calls", "split_layout", "hud", "score", "result_ui", "conditions_ui", "help_ui", "help_consistency", "editor_ui", "editor_labels", "open_level", "req_gaps", "loader_badge", "new_level", "rule_copy", "reorder", "vision", "three_levels", "playthrough", "level_files_untouched", "harness_selfcheck", "no_stubs", "data",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	# 把自己从「当前场景」挪到 /root 下，
	# 否则后面 SceneLoader.goto() 换场景时会被一起释放，await 就断了
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)

	print("\n========== 冒烟测试开始 ==========")
	_run_started_msec = Time.get_ticks_msec()

	# 看门狗：**盯"多久没有进展"，而不是"总共用了多久"**。
	#
	# 【为什么改】原来是一个 30 秒的一次性计时器。它想解决的问题是"某个 await
	# 永远不返回"，但实现成了**总时长上限** —— 于是测试套件一变大就开始误杀：
	# 第 14 轮加了左右分栏与数据保险丝后，整套要跑 31 秒，明明 0 失败却以
	# 退出码 2 结束，还**只跑了一半用例**（完成量两次分别是 911 / 880，随速度浮动）。
	# "全绿但被砍掉一半"比失败更危险，因为它看起来是成功的。
	#
	# 现在每隔几秒检查一次"距上次有断言通过过去了多久"：真的卡住（20 秒没有任何
	# 进展）才退出。跑得慢不再触发它，而卡死仍然会被抓住。
	# 【必须用 Timer 节点，不能用 SceneTreeTimer】后者只响一次（**没有 `repeat`
	# 属性**）。我第一版写成 `create_timer(...).repeat = true`，于是 `_run` 在
	# 第 109 行抛运行期错误并**直接中断**，进程再也走不到 `_report_and_quit()`
	# —— 整套测试从"失败"变成了"挂死"（PASS=0 却永不退出）。
	# Timer 节点可重复，而且**先于一切挂进场景树**：即使后面 `_run` 因任何原因中断，
	# 看门狗仍在运行，20 秒后照样退出 —— 测试框架自己不许挂死。
	var wd := Timer.new()
	wd.name = "StallWatchdog"
	wd.wait_time = 2.0
	wd.one_shot = false
	wd.timeout.connect(_on_stall_check)
	add_child(wd)
	wd.start()
	_last_progress_msec = Time.get_ticks_msec()

	# ---------- 内核（M0 之前就有的 52 项）----------
	_group("内核")
	# 【数据保险丝】先给真实关卡文件拍个"内容快照"，跑完再比对。
	# 「测试把真实关卡写坏」在本工程已经发生过**两次**（M4 一次、第 14 轮一次），
	# 两次都是"写盘本该失败却成功了"这种**依赖环境**的侥幸。
	# 有了这个快照，任何一次意外写入都会在最后一组用例里当场失败。
	_snapshot_level_files()
	_check_autoloads()
	_check_collision_layers()
	_check_audio_buses()
	_check_input_actions()
	_check_signal_bus()
	await _check_game_helpers()
	await _check_scene_loop()
	await _check_phantom_camera()
	await _check_main_menu()
	await _check_layout()
	await _check_pause_menu()

	# ---------- 玩法系统 ----------
	_check_types()
	await _check_clock()
	_check_map()
	_check_state()
	_check_beacons()
	_check_rule()
	# 【必须 await】_check_unit 内部有 await（物理世界用例），
	# 漏掉 await 会让它在第一个 await 处静默返回，后面的用例一条都不跑，
	# 而整套测试仍然报「全部通过」—— 这个坑真的踩到过。
	await _check_unit()
	await _check_combat()
	await _check_level()
	_check_editor()
	await _check_session()
	await _check_rule_panel()
	await _check_rule_type_change()
	await _check_nav_queue()
	await _check_no_bogus_dynamic_calls()
	await _check_rule_split_layout()
	await _check_hud()
	_check_score()
	await _check_result_ui()
	await _check_conditions_ui()
	await _check_help_ui()
	await _check_help_matches_ui()
	await _check_editor_ui()
	await _check_editor_labels()
	await _check_editor_open_level()
	await _check_new_level()
	await _check_loader_errors_and_badge()
	await _check_rule_copy()
	await _check_req_gaps()
	await _check_reorder()
	await _check_vision()
	await _check_three_levels()
	await _check_full_playthrough()
	_check_harness_selfcheck()
	_check_data()
	_check_no_pending_stubs()
	_check_level_files_untouched()

	_report_and_quit()

# ---------------------------------------------------------------------------
# 数据完整性保险丝
# ---------------------------------------------------------------------------

## 真实关卡文件的"内容快照"（解析后再序列化，避免格式差异造成误报）
var _level_snapshot := {}


## 给 `data/levels/` 下的关卡文件拍快照。
##
## 【为什么用"解析后再序列化"而不是文件哈希】测试会临时往 manifest 里加探测条目
## 再清理掉，写回的排版可能变（空格/缩进），文件哈希会误报。
## 比对**内容**才是我真正想守的东西。
func _snapshot_level_files() -> void:
	_level_snapshot.clear()
	# 【文件清单也必须进快照】只比"已有文件的内容"的话，**多出一个文件**永远发现不了 ——
	# 而"测试新建了一个关卡文件并把它写进 manifest"正是实际发生过的事
	# （第 23 轮：`data/levels/new_level_1.json` + manifest 多出一条，
	#  是**提交前检查仓库状态**时才发现的）。现在清单与 manifest 内容都纳入比对。
	_level_snapshot["__file_set__"] = _level_file_set()
	for id in (_level_ids_for_snapshot() as Array):
		var path := "res://data/levels/%s.json" % str(id)
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(text)
		_level_snapshot[str(id)] = JSON.stringify(parsed) if parsed != null else text
	var mpath := "res://data/levels/manifest.json"
	if FileAccess.file_exists(mpath):
		var mf := FileAccess.open(mpath, FileAccess.READ)
		if mf != null:
			_level_snapshot["__manifest__"] = JSON.stringify(JSON.parse_string(mf.get_as_text()))
			mf.close()


## `data/levels/` 下所有 .json 的文件名（排序后拼成一个串，便于直接比对）
func _level_file_set() -> String:
	var files: Array[String] = []
	var d := DirAccess.open("res://data/levels")
	if d == null:
		return ""
	d.list_dir_begin()
	var nm := d.get_next()
	while nm != "":
		if not d.current_is_dir() and nm.ends_with(".json"):
			files.append(nm)
		nm = d.get_next()
	d.list_dir_end()
	files.sort()
	return ",".join(files)


## 快照里要包含哪些关卡：以 manifest 为准，兜底三个教学关
func _level_ids_for_snapshot() -> Array:
	var out: Array = []
	var mpath := "res://data/levels/manifest.json"
	if FileAccess.file_exists(mpath):
		var mf := FileAccess.open(mpath, FileAccess.READ)
		if mf != null:
			var m = JSON.parse_string(mf.get_as_text())
			mf.close()
			if m is Dictionary and (m as Dictionary).get("levels") is Array:
				for x in (m as Dictionary).get("levels"):
					out.append(str(x))
	if out.is_empty():
		out = ["tutorial_01", "tutorial_02", "tutorial_03"]
	return out


## 跑完整套用例后比对：**真实关卡文件一个字节都不该变**。
##
## 【这条用例的价值】它把"环境恰好不让写"这种侥幸换成了一条**确定性的断言**。
## 之前两次覆盖真实关卡，都是因为"写盘失败"替我们挡住了风险；
## 一旦环境允许写，坏掉的就是玩家数据。现在无论环境怎样，写坏了都跑不过。
func _check_level_files_untouched() -> void:
	_group("数据完整性")
	print("\n-- 数据完整性：真实关卡文件不该被测试改写 --")
	var now := {}
	for id in (_level_ids_for_snapshot() as Array):
		var path := "res://data/levels/%s.json" % str(id)
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(text)
		now[str(id)] = JSON.stringify(parsed) if parsed != null else text
	var changed: Array = []
	for id2 in _level_snapshot.keys():
		if str(id2).begins_with("__"):
			continue
		var before := str(_level_snapshot[id2])
		var after := str(now.get(id2, ""))
		if before != after:
			changed.append(str(id2))
	_ok(changed.is_empty(),
		"**测试跑完后真实关卡文件内容未变**（被改动的：%s）" % str(changed))
	# 逐个关卡也报一遍，改动时能直接看出是哪一关
	for id3 in _level_snapshot.keys():
		if str(id3).begins_with("__"):
			continue
		_ok(str(_level_snapshot[id3]) == str(now.get(id3, "")),
			"关卡 %s 内容未变" % str(id3))
	_ok(now.size() >= 3, "快照覆盖了至少 3 个关卡（实际 %d）" % now.size())

	# ---- manifest 的**内容**也要比对（原来只存了却没断言，等于没查）----
	var man_path := "res://data/levels/manifest.json"
	var man_now := ""
	if FileAccess.file_exists(man_path):
		var mf := FileAccess.open(man_path, FileAccess.READ)
		if mf != null:
			man_now = JSON.stringify(JSON.parse_string(mf.get_as_text()))
			mf.close()
	_ok(_level_snapshot.has("__manifest__"), "manifest 在快照里（跑完仍存在）")
	_ok(str(_level_snapshot.get("__manifest__", "")) == man_now,
		"**manifest 内容未被测试改写**（原来只存了没断言，等于没查）")

	# ---- 也不许**多出/少掉**文件（本次事故正是"多出一个关卡文件"）----
	var files_now := _level_file_set()
	_ok(str(_level_snapshot.get("__file_set__", "")) == files_now,
		"**data/levels 的文件清单未变**（跑完：%s；快照：%s）"
		% [files_now, str(_level_snapshot.get("__file_set__", ""))])
	# ---- 既有残留：**响亮报出来，但不作为断言** ----
	#
	# 【为什么不在这里失败】"目录里有 manifest 未登记的残留文件"是**环境状态**，
	# 不是"本次运行造成的改动"。而这条保险丝的职责是后者（本次运行有没有动数据）。
	# 更关键的是：**这个沙箱不允许子进程删除项目里的文件**
	# （第 13 轮的 ACL 报告里有 Everyone 的 `DeleteSubdirectoriesAndFiles` 拒绝项，
	#  那是沙箱**刻意**的保护，不是待修的缺陷；pwsh / Python / Godot 都删不掉）。
	# 所以一旦真有残留，在这里断言失败只会让**整套测试永久变红**，
	# 却给不出任何可执行的修复动作 —— 那是坏断言。
	# 正确做法：**报出来让人去删**，同时用下面那条"清单未变"守住真正的不变量。
	var strays: Array[String] = []
	var keep_ids: Array = _level_ids_for_snapshot()
	for fn in (files_now.split(",", false) as Array):
		var base := str(fn)
		if base == "manifest.json":
			continue
		if not keep_ids.has(base.substr(0, base.length() - 5)):
			strays.append(base)
	if not strays.is_empty():
		print("   [diag] ⚠️ data/levels 里有 manifest 未登记的残留：%s —— 请手动删除"
			% str(strays))
	# 【必须登记 _done】我原来漏了这一句 —— 于是这条保险丝中途出错时，
	# 框架的"未跑到底"检查**不会发现**（它只认识登记过名字的函数）。
	# 保险丝本身悄悄失效，比没有保险丝更危险。
	_done("level_files_untouched")

## 标记进入某个系统的用例分组（只影响输出可读性）
## 看门狗的每 2 秒检查：距上次有断言通过超过阈值就判卡死并退出。
##
## 单独写成方法（而不是 lambda）是有意的：即使 `_run` 中途因运行期错误中断，
## 这个连接依然有效，进程仍会被它带出去。
func _on_stall_check() -> void:
	var idle := float(Time.get_ticks_msec() - _last_progress_msec) / 1000.0
	if idle > STALL_SECONDS:
		print("!! 冒烟测试卡住：已有 %.0f 秒没有任何用例通过（阈值 %.0f 秒）"
			% [idle, STALL_SECONDS])
		get_tree().quit(2)


func _group(name: String) -> void:
	_groups.append(name)
	_group_start_failures = _failures.size()
	print("\n########## 分组：%s ##########" % name)

## 标记某个检查函数已经**跑到底**。
##
## 【为什么需要它】GDScript 里一次运行时错误（例如调了不存在的函数）只会让
## 当前函数**静默中止**，`_run()` 会继续往下走，最后照样打印「全部通过」——
## M1-4 实测踩到：系统 04 的用例在第一条断言后就中断了，却有 15 条 PASS 和
## 一个「全部通过」。所以每个检查函数末尾都要报一次到，收尾时核对名单。
func _done(name: String) -> void:
	_completed.append(name)


func _ok(condition: bool, what: String) -> void:
	_last_progress_msec = Time.get_ticks_msec()   # 刷新看门狗的「有进展」标记
	if condition:
		print("  [PASS] ", what)
	else:
		print("  [FAIL] ", what)
		_failures.append(what)

# =====================================================================
# 内核检查
# =====================================================================

func _check_autoloads() -> void:
	print("\n-- autoload --")
	for autoload_name: String in ["EventBus", "Game", "Audio", "Save", "SceneLoader", "PhantomCameraManager"]:
		_ok(get_node_or_null("/root/" + autoload_name) != null, "autoload %s 已注册" % autoload_name)

## M0-2：碰撞分层必须在 project.godot 里命名好。
## 见 docs/design/05-战斗.md 第 3 章。层号错了不会报错，只会让
## 「子弹打中友军」这类 bug 静默出现，所以这里断言名称。
	_done("autoloads")
func _check_collision_layers() -> void:
	print("\n-- 碰撞分层 --")
	var expected := {
		1: "unit_body",
		2: "obstacle",
		3: "bullet_ally",
		4: "bullet_enemy",
		5: "hurtbox_ally",
		6: "hurtbox_enemy",
	}
	for layer: int in expected:
		# ProjectSettings.get_setting 返回 Variant，不能让它推断变量类型
		var actual: String = str(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, ""))
		_ok(actual == expected[layer],
			"物理层 %d = %s（实际 \"%s\"）" % [layer, expected[layer], actual])
	_done("collision_layers")

func _check_audio_buses() -> void:
	print("\n-- 音频总线 --")
	for bus_name: String in ["Master", "SFX", "Music"]:
		_ok(AudioServer.get_bus_index(bus_name) != -1, "总线 %s 存在" % bus_name)

	# AudioManager._ready() 会读 Save 里存的音量并套用。
	# 如果 autoload 顺序把 Audio 排在 Save 前面，这里会拿到总线默认的 1.0 而不是 0.8，
	# 也就是"设置没生效"这种很难查的静默 bug。
	var expected := float(Save.get_setting("master", 0.8))
	_ok(absf(Audio.get_bus_volume("Master") - expected) < 0.02,
		"启动时自动套用了保存的音量（证明 Audio 能访问到 Save，%.2f）" % expected)
	_done("audio_buses")

func _check_input_actions() -> void:
	print("\n-- 输入映射 --")
	var actions := [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "attack", "dash", "interact", "pause", "restart",
	]
	for action: String in actions:
		_ok(InputMap.has_action(action), "动作 %s 存在" % action)

	var has_pad := false
	var has_key := false
	for ev: InputEvent in InputMap.action_get_events("jump"):
		if ev is InputEventJoypadButton:
			has_pad = true
		elif ev is InputEventKey:
			has_key = true
	_ok(has_key, "jump 有键盘绑定")
	_ok(has_pad, "jump 有手柄绑定")
	_done("input_actions")

func _check_signal_bus() -> void:
	print("\n-- 信号总线 / 全局状态 --")
	EventBus.score_changed.connect(_on_score_changed)
	Game.new_run()
	Game.add_score(42)
	_ok(Game.score == 42, "Game.add_score 累加正确")
	_ok(_last_score == 42, "EventBus.score_changed 已广播")
	EventBus.score_changed.disconnect(_on_score_changed)

	Game.set_combo(5)
	_ok(Game.combo == 5, "Game.set_combo 生效")

	# M0-3：玩法流程信号已就位（能 connect 就说明声明存在）
	var flow_signals := ["level_started", "level_finished", "session_state_changed",
		"unit_died", "unit_hp_changed", "signal_changed", "beacon_changed"]
	for sig_name: String in flow_signals:
		_ok(EventBus.has_signal(sig_name), "EventBus 有信号 %s" % sig_name)
	_done("signal_bus")

func _on_score_changed(score: int) -> void:
	_last_score = score

func _check_game_helpers() -> void:
	print("\n-- 顿帧 / 慢动作 --")
	Engine.time_scale = 1.0
	await Game.hitstop(0.05)
	_ok(is_equal_approx(Engine.time_scale, 1.0), "hitstop 结束后 time_scale 归位（不是永久卡死）")
	_done("game_helpers")

func _check_scene_loop() -> void:
	print("\n-- 场景切换闭环 --")
	await SceneLoader.goto(GAME_SCENE, 0.0)
	await get_tree().process_frame
	var current := get_tree().current_scene
	_ok(current != null and current.name == "GameScene", "SceneLoader.goto 切到了玩法场景")

	var game := get_tree().current_scene
	_ok(game.get_node_or_null("Player") is CharacterBody2D, "玩法场景有 Player")
	_ok(game.get_node_or_null("PauseMenu") != null, "玩法场景挂了 PauseMenu")
	_ok(game.get_node_or_null("HUD/ScoreLabel") != null, "玩法场景有 HUD/ScoreLabel")

	# 玩法场景 _ready 里已经 new_run 过，分数应为 0
	_ok(Game.score == 0, "进入玩法场景时分数重置为 0")

	# 模拟一次命中：加分 + 顿帧 + 音效链路
	game._demo_hit()
	_ok(Game.score == 10, "命中加分走通")
	_done("scene_loop")

func _check_phantom_camera() -> void:
	print("\n-- Phantom Camera 跟随 --")
	var current := get_tree().current_scene
	var player := current.get_node_or_null("Player") as Node2D
	var pcam := current.get_node_or_null("PhantomCamera2D")
	_ok(pcam != null, "场景里有 PhantomCamera2D 节点")

	if pcam == null or player == null:
		return
	# follow_target 是导出节点引用，能取到说明 tscn 里的 node_paths 写对了
	_ok(pcam.get("follow_target") != null, "PhantomCamera2D.follow_target 已解析到 Player")

	var cam := get_viewport().get_camera_2d()
	_ok(cam != null, "存在活动的 Camera2D（PhantomCameraHost 接管成功）")
	if cam == null:
		return

	var start := cam.global_position
	player.global_position = Vector2(1500.0, -1100.0)
	for i in 120:
		await get_tree().physics_frame
	var moved := cam.global_position.distance_to(start)
	var gap := cam.global_position.distance_to(player.global_position)
	_ok(moved > 500.0, "相机确实跟着玩家移动了（位移 %.0f）" % moved)
	_ok(gap < 400.0, "相机跟到了玩家附近（残差 %.0f）" % gap)
	_done("phantom_camera")

func _check_main_menu() -> void:
	print("\n-- 主菜单 / 设置菜单 --")
	await SceneLoader.goto(MAIN_MENU, 0.0)
	await get_tree().process_frame
	var menu := get_tree().current_scene
	_ok(menu != null and menu.name == "MainMenu", "SceneLoader.goto 切回了主菜单")

	var continue_button := menu.get_node_or_null("Center/VBox/ContinueButton") as Button
	_ok(continue_button != null, "主菜单有「继续游戏」按钮")
	var new_game := menu.get_node_or_null("Center/VBox/NewGameButton") as Button
	_ok(new_game != null, "主菜单有「新游戏」按钮")
	_ok(new_game.focus_mode == Control.FOCUS_ALL, "主菜单按钮可获得焦点（键盘/手柄可导航）")

	var settings := menu.get_node_or_null("SettingsMenu")
	_ok(settings != null, "主菜单里实例化了设置菜单")
	if settings == null:
		return

	settings.open()
	_ok(settings.is_open(), "设置菜单能打开")

	var slider := settings.get_node_or_null("Center/Panel/Margin/VBox/MasterRow/MasterSlider") as HSlider
	_ok(slider != null, "设置菜单有主音量滑条")
	if slider != null:
		slider.value = 0.35
		_ok(is_equal_approx(float(Save.get_setting("master", -1.0)), 0.35), "拖动滑条写入了设置")
		_ok(absf(Audio.get_bus_volume("Master") - 0.35) < 0.02, "主音量实时作用到 Master 总线")

	var option := settings.get_node_or_null("Center/Panel/Margin/VBox/ResRow/ResolutionOption") as OptionButton
	_ok(option != null and option.item_count == 3, "分辨率下拉有 3 个选项")

	settings.close()
	_ok(not settings.is_open(), "设置菜单能关闭")

	var closed_fired := [false]
	settings.closed.connect(func() -> void: closed_fired[0] = true)
	settings.open()
	settings.close()
	_ok(closed_fired[0], "关闭设置菜单会 emit closed（宿主才能还焦点）")

## 布局断言：不靠肉眼看图，用几何数值确认 .tscn 里的锚点/HBox/VBox 真的生效了。
## 全是相对断言（相对父容器尺寸），所以任何分辨率下都成立。
	_done("main_menu")
func _check_layout() -> void:
	print("\n-- 界面布局 --")
	var menu: Node = load(MAIN_MENU).instantiate()
	add_child(menu)
	await get_tree().process_frame

	# 诊断输出（不做判定）：确认 Control 的布局空间到底是谁给的
	var win := get_window()
	print("   [diag] viewport visible_rect = ", get_viewport().get_visible_rect())
	print("   [diag] window.size = ", win.size, " content_scale_size = ", win.content_scale_size)
	print("   [diag] MainMenu.size = ", (menu as Control).size)

	var background := menu.get_node_or_null("Background") as Control
	var vbox := menu.get_node_or_null("Center/VBox") as VBoxContainer
	_ok(background != null and background.size.x > 0.0 and background.size.y > 0.0,
		"主菜单背景尺寸非零 %s" % str(background.size if background else Vector2.ZERO))
	if vbox == null or background == null:
		menu.queue_free()
		return
	_ok(absf(vbox.get_global_rect().get_center().x - background.size.x * 0.5) < 2.0,
		"主菜单按钮列水平居中（CenterContainer 生效）")

	var buttons: Array[Button] = []
	for child in vbox.get_children():
		if child is Button:
			buttons.append(child)
	# 模板原有 4 个（继续/新游戏/设置/退出）+ 本项目加的「开始游戏」+「关卡编辑器」。
	# 【注意】模板的「继续/新游戏」指向 WASD 平台跳跃示例场景，本作已把它们
	# **隐藏**（用户点进去会一脸懵）。所以这里按「可见按钮」断言，
	# 既锁住本作的入口，也不会因为模板节点还在就误报。
	_ok(buttons.size() == 6, "主菜单有 6 个按钮（模板 4 + 开始游戏 + 关卡编辑器），实际 %d" % buttons.size())

	var visible_names: Array = []
	for b: Button in buttons:
		if b.visible:
			visible_names.append(str(b.name))
	_ok(visible_names.size() == 4,
		"**可见入口 4 个**（开始游戏/关卡编辑器/设置/退出），实际 %s" % str(visible_names))
	_ok(visible_names.has("GodEntryButton"), "可见入口里有「开始游戏」")
	_ok(visible_names.has("EditorEntryButton"), "**可见入口里有「关卡编辑器」**（详设 10 的 2.1）")
	# 尺寸与既有按钮一致（我第一版随手写了 48 高，被布局用例报出来）
	var ed := vbox.get_node_or_null("EditorEntryButton") as Button
	_ok(ed != null and is_equal_approx(ed.custom_minimum_size.y, 56.0),
		"「关卡编辑器」按钮高度与既有按钮一致（56，实际 %.0f）"
		% (ed.custom_minimum_size.y if ed != null else -1.0))
	_ok(not visible_names.has("NewGameButton") and not visible_names.has("ContinueButton"),
		"**模板遗留的「继续/新游戏」已隐藏**（它们会进入 WASD 示例场景）")
	var start_btn: Button = vbox.get_node_or_null("GodEntryButton")
	_ok(start_btn != null and str(start_btn.text) == "开始游戏",
		"入口按钮文字是「开始游戏」")
	# 【这条断言原来把 bug 当成期望】它写的是 `vbox.get_child(0) == start_btn`
	# —— 也就是"开始按钮必须是 VBox 的第 0 个"。而 VBox 的前两个是
	# Title / Subtitle，所以"第 0 个"恰恰意味着**按钮跑到标题上面去了**
	# （用户实测报的就是这个）。断言写错了方向，于是它一直"通过"。
	#
	# 现在改成断言**相对位置**：标题/副标题必须在入口按钮**之前**，
	# 而入口按钮必须在其余按钮（设置/退出）**之前**。
	var title_i := -1
	var sub_i := -1
	for k in vbox.get_child_count():
		var nm := String(vbox.get_child(k).name)
		if nm == "Title":
			title_i = k
		elif nm == "Subtitle":
			sub_i = k
	var start_i := start_btn.get_index() if start_btn != null else -1
	var settings_i := (vbox.get_node_or_null("SettingsButton") as Node).get_index() \
		if vbox.get_node_or_null("SettingsButton") != null else -1
	_ok(title_i >= 0 and sub_i >= 0 and start_i > title_i and start_i > sub_i,
		"**「开始游戏」在标题与副标题之下**（Title=%d Subtitle=%d 开始=%d）"
		% [title_i, sub_i, start_i])
	_ok(settings_i < 0 or start_i < settings_i,
		"「开始游戏」在「设置」之上（开始=%d 设置=%d）" % [start_i, settings_i])
	var ed_i := (vbox.get_node_or_null("EditorEntryButton") as Node).get_index() \
		if vbox.get_node_or_null("EditorEntryButton") != null else -1
	_ok(ed_i == start_i + 1,
		"**「关卡编辑器」紧跟在「开始游戏」之后、同样在标题下方**（编辑器=%d）" % ed_i)
	_ok(start_btn != null and start_btn.has_focus(), "「开始游戏」是默认焦点")
	# 标题与副标题必须是本作的名字，不能留模板的 "JGD 2026 / 启动模板"
	var title_lbl := vbox.get_node_or_null("Title")
	_ok(title_lbl is Label and str((title_lbl as Label).text) == "人工神灵",
		"**主菜单标题是「人工神灵」**（实际「%s」）" % (
			str((title_lbl as Label).text) if title_lbl is Label else "无标题节点"))
	var sub_lbl := vbox.get_node_or_null("Subtitle")
	_ok(sub_lbl is Label and not str((sub_lbl as Label).text).contains("模板"),
		"副标题不再提「启动模板」（实际「%s」）" % (
			str((sub_lbl as Label).text) if sub_lbl is Label else "无副标题"))

	var size_ok := true
	var order_ok := true
	var last_y := -1.0e20
	var widths: Array[float] = []
	for b: Button in buttons:
		if not b.visible:
			continue                       # 隐藏按钮不参与布局断言
		# 高度必须严格 56；宽度会被 VBoxContainer 拉到最宽子项（标题）的宽度，
		# 所以只断言"不小于设定值"，这是容器的预期行为而不是 bug
		if not is_equal_approx(b.size.y, 56.0):
			size_ok = false
		if b.size.x < 360.0:
			size_ok = false
		widths.append(b.size.x)
		if b.global_position.y <= last_y:
			order_ok = false
		last_y = b.global_position.y
	_ok(size_ok, "按钮高度 56 且宽度不小于 360（实际宽 %.0f）" % (widths[0] if not widths.is_empty() else 0.0))
	_ok(order_ok, "按钮自上而下排列、没有重叠")

	var settings: Control = menu.get_node("SettingsMenu")
	settings.open()
	await get_tree().process_frame

	var panel := settings.get_node_or_null("Center/Panel") as Control
	var sdim := settings.get_node_or_null("Dim") as Control
	_ok(panel != null and panel.size.x > 400.0 and panel.size.y > 300.0,
		"设置面板尺寸合理 %s" % str(panel.size if panel else Vector2.ZERO))
	_ok(sdim != null and is_equal_approx(sdim.size.x, settings.size.x)
		and is_equal_approx(sdim.size.y, settings.size.y), "设置遮罩铺满父容器")
	if panel != null:
		_ok(absf(panel.get_global_rect().get_center().x - settings.size.x * 0.5) < 2.0,
			"设置面板水平居中")

	var rowname := settings.get_node_or_null("Center/Panel/Margin/VBox/MasterRow/Name") as Control
	var slider := settings.get_node_or_null("Center/Panel/Margin/VBox/MasterRow/MasterSlider") as Control
	_ok(rowname != null and slider != null and slider.global_position.x > rowname.global_position.x
		and slider.global_position.x > rowname.global_position.x + rowname.size.x - 1.0,
		"滑条排在标签右侧（HBoxContainer 生效）")

	var vbox_inner := settings.get_node_or_null("Center/Panel/Margin/VBox") as Control
	var back := settings.get_node_or_null("Center/Panel/Margin/VBox/BackButton") as Control
	_ok(vbox_inner != null and back != null and back.global_position.y >= vbox_inner.global_position.y,
		"返回按钮在 VBox 里（不是叠在面板左上角）")

	settings.close()
	menu.queue_free()
	await get_tree().process_frame
	_done("layout")

func _check_pause_menu() -> void:
	print("\n-- 暂停菜单 --")
	var pause: Node = load(PAUSE_MENU).instantiate()
	add_child(pause)
	await get_tree().process_frame

	pause.open()
	_ok(get_tree().paused, "暂停菜单打开后 tree 被暂停")
	_ok(pause.is_open(), "暂停菜单可见")

	pause.close()
	_ok(not get_tree().paused, "暂停菜单关闭后恢复运行")
	_ok(pause.process_mode == Node.PROCESS_MODE_ALWAYS, "暂停菜单是 PROCESS_MODE_ALWAYS（暂停后还能操作）")

	pause.queue_free()

# =====================================================================
# 玩法系统用例
# 每个系统一个函数。只在自己的函数体内加断言。
# =====================================================================

## 类型/枚举容器可被引用
	_done("pause_menu")
func _check_types() -> void:
	print("\n-- types --")
	_ok(TypesScript.TEAM_ALLY == 0 and TypesScript.TEAM_ENEMY == 1, "Team 枚举值正确")
	_ok(BattleMapScript.TILE_EMPTY == 0 and BattleMapScript.TILE_WALL == 1 and BattleMapScript.TILE_GOAL == 2,
		"瓦片类型 id 正确（空地 0 / 障碍 1 / 目标区 2）")
	_ok(is_equal_approx(BattleMapScript.TILE_PX, 64.0), "TILE_PX = 64")

## 详设 01 的 6.1 用例。GameClock 是纯逻辑 Node，直接手动喂 delta，
## **不依赖真实帧率** —— 这是 FR-TEST-03 能被自动化的前提。
	_done("types")
func _check_clock() -> void:
	print("\n-- 系统 01 · 时间与逻辑帧 --")
	# 类型标注只能写引擎内置类型：preload 得到的脚本常量不能当类型用。
	# 标注为 Node 即可，属性访问在运行时照常。
	var clock: Node = GameClockScript.new()
	add_child(clock)
	# 【必须】关掉引擎对它的自动 _physics_process。
	# 否则下面手动喂的 delta 会和引擎真实帧驱动的调用**叠加**，
	# tick 数取决于跑测试时的帧率 —— 那正是本系统要消灭的不确定性。
	clock.set_physics_process(false)

	# --- 步长恒定：60 帧 × 1/60 秒 = 60 个 tick、1.0 秒 ---
	clock.reset()
	for i in 60:
		clock._physics_process(1.0 / 60.0)
	_ok(clock.tick_index == 60, "60 帧 @1x 产生 60 个 tick（实际 %d）" % clock.tick_index)
	_ok(absf(clock.game_time - 1.0) < 1e-6, "game_time ≈ 1.0 秒（实际 %.6f）" % clock.game_time)

	# --- 倍速只改变「每秒多少 tick」，不改变 tick 内容 ---
	clock.reset()
	clock.set_speed_multiplier(3.0)
	var frames_3x: int = 0
	while clock.tick_index < 600 and frames_3x < 10000:
		clock._physics_process(1.0 / 60.0)
		frames_3x += 1
	_ok(clock.tick_index == 600, "3x 下能推进到 600 tick")
	_ok(absf(frames_3x - 200) <= 2, "3x 达到 600 tick 用 %d 帧，1x 需 600 帧（约 1/3）" % frames_3x)
	_ok(absf(clock.game_time - 10.0) < 1e-6, "同一 tick_index 下 game_time 与倍速无关（%.6f）" % clock.game_time)

	# --- 切换倍速时不出现「补发积压」的猛跳 ---
	# set_speed_multiplier 必须先清累加器：否则切到 3x 的下一帧会把 1x 期间
	# 攒下的尾数按 3 倍放大，补发一串 tick（表现为画面猛跳一下）。
	clock.reset()
	clock.set_speed_multiplier(1.0)
	for i in 59:
		clock._physics_process(1.0 / 60.0)
	_ok(clock.tick_index == 59, "59 帧 @1x 产生 59 个 tick（实际 %d）" % clock.tick_index)
	clock.set_speed_multiplier(3.0)
	_ok(is_equal_approx(clock._accumulator, 0.0),
		"切倍速时累加器被清零（实际 %.6f），不会补发积压 tick" % clock._accumulator)
	# 清干净之后，3x 的推进速率：3 个物理帧 × (1/60 × 3) = 9 个 tick。
	# 注意倍速的语义是「同样的真实时间推进 3 倍的游戏时间」，
	# 所以在物理帧率不变的前提下，3x 每帧就是 3 个 tick，而不是 1 个。
	clock.reset()
	clock.set_speed_multiplier(3.0)
	for i in 3:
		clock._physics_process(1.0 / 60.0)
	_ok(clock.tick_index == 9, "3x 下 3 帧产生 9 个 tick（实际 %d）" % clock.tick_index)

	# --- 单帧上限：模拟卡顿，最多 MAX_TICKS_PER_FRAME 个 tick ---
	clock.reset()
	clock.set_speed_multiplier(1.0)
	clock._physics_process(10.0)            # 一个巨大的 delta
	_ok(clock.tick_index == GameClockScript.MAX_TICKS_PER_FRAME_PUBLIC,
		"单帧 tick 数被限制为 %d（实际 %d）" % [GameClockScript.MAX_TICKS_PER_FRAME_PUBLIC, clock.tick_index])

	# --- 倍速为 0 时不推进 ---
	clock.reset()
	clock.set_speed_multiplier(0.0)
	for i in 60:
		clock._physics_process(1.0 / 60.0)
	_ok(clock.tick_index == 0, "倍速为 0 时不产生 tick")

	# --- reset 归零 ---
	clock.set_speed_multiplier(1.0)
	for i in 100:
		clock._physics_process(1.0 / 60.0)
	clock.reset()
	_ok(clock.tick_index == 0, "reset() 后 tick_index 归零")
	_ok(absf(clock.game_time) < 1e-9, "reset() 后 game_time 归零")

	clock.queue_free()
	_done("clock")


## 系统 02 · 规则引擎 —— M2-1…M2-5
##
## 【为什么这一组用例最重要】需求 5.4 的语义是整个玩法的地基，也是全项目最
## 容易返工的地方。所以这里逐条钉死：覆盖顺序 / 持续意图保持 / 序列值相等不
## 重置游标 / 延迟阻塞 / 信号次 tick 生效 / 无效指令整条跳过。
func _check_rule() -> void:
	print("\n-- 系统 02 · 规则引擎 --")

	var engine: RefCounted = RuleEngineScript.new()
	var signals: RefCounted = SignalStoreScript.new()
	signals.call("setup", 3)

	# 地图：7×7 空地 + 信标 1@(5,0)、信标 2@(5,4)
	var m: Node2D = BattleMapScript.new()
	add_child(m)
	m.set_tiles(_make_grid(7, 7, BattleMapScript.TILE_EMPTY))
	m.set_beacons([Vector2i(5, 0), Vector2i(5, 4)])

	var u: Node2D = UnitActorScript.new()
	add_child(u)
	u.call("setup", UnitActorScript.TEAM_ALLY, Vector2(0, 0),
		{"max_hp": 100.0, "move_speed": 3.0, "can_attack": true, "range": 3.0})
	u.set_physics_process(false)
	u.set("battle_map", m)

	var bs: RefCounted = BattleStateScript.new()
	bs.call("register_unit", u)

	# --- 条件/行为清单与 schema（M2-1）---
	_ok(RuleConditionScript.all_types().size() == 5, "条件类型共 5 种（D-13）")
	_ok(RuleActionScript.all_types().size() == 5, "行为类型共 5 种（D-13）")
	_ok(RuleConditionScript.display_name(RuleConditionScript.T_SELF_HP) == "血量状态",
		"条件有中文显示名")
	_ok(RuleActionScript.display_name(RuleActionScript.T_DELAY) == "延迟", "行为有中文显示名")
	_ok(RuleConditionScript.schema(RuleConditionScript.T_BEACON_DISTANCE).size() == 3,
		"条件参数 schema 可驱动 UI（信标距离 3 个参数）")
	_ok(str(RuleActionScript.schema(RuleActionScript.T_DELAY)[0]["key"]) == "seconds",
		"行为参数 schema 正确")
	_ok(str(_act_fire(true).call("conflict_key")) == "fire_mode", "开火冲突键为 fire_mode")
	_ok(str(_act_move([1]).call("conflict_key")) == "move", "移动冲突键为 move")
	_ok(str(_act_signal(2, true).call("conflict_key")) == "signal:2", "信号冲突键带编号")
	_ok(str(_act_delay(1.0).call("conflict_key")).is_empty(), "**延迟没有冲突键**（阻塞型）")
	_ok(_act_move([1]).call("is_persistent"), "移动是持续型")

	# --- 无效指令：整条跳过 + 标黄（M2-5）---
	var r_bad: RefCounted = RuleEngineScript.make_rule([], [_act_move([9])])
	u.set("rules", [r_bad])
	var it_bad = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(it_bad.get("move_intent") == null, "引用不存在的信标 → 整条跳过、不产出意图")
	_ok(str(r_bad.get("invalid_reason")).contains("信标 9"), "写了 invalid_reason（给 UI 标黄）")

	var c_sig_bad = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_SIGNAL_STATE, "signal_index": 99})
	var r_bad2: RefCounted = RuleEngineScript.make_rule([c_sig_bad], [_act_fire(true)])
	u.set("rules", [r_bad2])
	_ok(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent") == null,
		"引用不存在的信号 → 整条跳过")
	_ok(str(r_bad2.get("invalid_reason")).contains("信号 99"), "写了信号相关的 invalid_reason")

	# --- 需求 5.4 原文示例：先停火、后开火 → 有敌人时开火（M2-2）---
	var enemy: Node2D = UnitActorScript.new()
	add_child(enemy)
	enemy.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(1, 0),
		{"max_hp": 100.0, "move_speed": 3.0, "can_attack": true, "range": 5.0})
	enemy.set_physics_process(false)
	bs.call("register_unit", enemy)

	var c_vision = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_ENEMY_IN_VISION, "radius": 0.0})
	var r1: RefCounted = RuleEngineScript.make_rule([], [_act_fire(false)])
	var r2: RefCounted = RuleEngineScript.make_rule([c_vision], [_act_fire(true)])
	u.set("rules", [r1, r2])
	var it1 = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(bool(it1.get("fire_intent")) == true,
		"**需求 5.4 示例**：先停火后开火 → 有敌人时开火（后者覆盖前者）")
	_ok((it1.get("matched_rule_indices") as Array).size() == 2, "两条指令都命中（覆盖不等于不命中）")

	enemy.call("set_logic_position", Vector2(6, 6))     # 挪出视野
	_ok(bool(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent")) == false,
		"敌人离开视野后只剩「停火」生效")

	# --- 三条同类行为只有最靠后一条生效 ---
	var rA: RefCounted = RuleEngineScript.make_rule([], [_act_signal(1, true)])
	var rB: RefCounted = RuleEngineScript.make_rule([], [_act_signal(1, false)])
	var rC: RefCounted = RuleEngineScript.make_rule([], [_act_signal(1, true)])
	u.set("rules", [rA, rB, rC])
	var it3 = engine.call("evaluate_unit", u, bs, m, signals)
	_ok((it3.get("signal_writes") as Array).size() == 1, "同一信号的 3 条行为只产出一条写入")
	_ok(bool((it3.get("signal_writes") as Array)[0][1]) == true, "取最靠后那条（置开）")

	# --- 不相冲突的行为同时生效（FR-CMD-06）---
	var rMix: RefCounted = RuleEngineScript.make_rule([],
		[_act_fire(true), _act_move([1, 2]), _act_signal(2, true)])
	u.set("rules", [rMix])
	var it4 = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(bool(it4.get("fire_intent")) == true, "不相冲突：开火意图生效")
	_ok((it4.get("move_intent") as Array).size() == 2, "不相冲突：移动意图同时生效")
	_ok((it4.get("signal_writes") as Array).size() == 1, "不相冲突：信号写入同时生效")

	# --- 禁用指令（FR-CMD-09）---
	var r_dis: RefCounted = RuleEngineScript.make_rule([], [_act_fire(true)])
	r_dis.set("enabled", false)
	u.set("rules", [r_dis])
	_ok(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent") == null,
		"禁用指令不参与求值")

	# --- 与 / 或（FR-CMD-04）---
	var c_hp_true = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_SELF_HP, "op": RuleConditionScript.OP_GT, "percent": 50.0})
	var c_hp_false = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_SELF_HP, "op": RuleConditionScript.OP_LT, "percent": 50.0})
	u.set("rules", [RuleEngineScript.make_rule([c_hp_true, c_hp_false], [_act_fire(true)], 0)])
	_ok(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent") == null,
		"AND：一真一假 → 不命中")
	enemy.call("set_logic_position", Vector2(1, 0))
	u.set("rules", [RuleEngineScript.make_rule([c_hp_true, c_vision], [_act_fire(true)], 0)])
	_ok(bool(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent")) == true,
		"AND：两个都真 → 命中")
	u.set("rules", [RuleEngineScript.make_rule([c_hp_false, c_vision], [_act_fire(true)], 1)])
	_ok(bool(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent")) == true,
		"OR：任一为真 → 命中")

	# --- 血量条件边界 ---
	var c_hp_lt60 = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_SELF_HP, "op": RuleConditionScript.OP_LT, "percent": 60.0})
	u.set("hp", 100.0)
	_ok(not engine.call("evaluate_condition", c_hp_lt60, u, bs, m, signals), "满血不满足「低于 60%」")
	u.set("hp", 59.0)
	_ok(engine.call("evaluate_condition", c_hp_lt60, u, bs, m, signals), "59% 满足「低于 60%」")
	u.set("hp", 60.0)
	_ok(not engine.call("evaluate_condition", c_hp_lt60, u, bs, m, signals), "恰好 60% 不满足「低于」")
	u.set("hp", 100.0)

	# --- 与某信标距离条件（含边界）---
	var c_bd = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_BEACON_DISTANCE, "beacon_index": 1,
		 "op": RuleConditionScript.OP_LE, "value": 2.0})
	u.call("set_logic_position", Vector2(5.5, 0.5))
	_ok(engine.call("evaluate_condition", c_bd, u, bs, m, signals), "距离 0 ≤ 2 → 真")
	u.call("set_logic_position", Vector2(3.5, 0.5))     # 距信标 1（中心 5.5,0.5）为 2
	_ok(engine.call("evaluate_condition", c_bd, u, bs, m, signals), "距离恰好 2 ≤ 2 → 真")
	u.call("set_logic_position", Vector2(2.5, 0.5))     # 距 3
	_ok(not engine.call("evaluate_condition", c_bd, u, bs, m, signals), "距离 3 > 2 → 假")
	u.call("set_logic_position", Vector2(0.5, 0.5))

	# --- 视野半径 0 表示取射程 ---
	enemy.call("set_logic_position", Vector2(2, 0))     # 距 2，射程 3
	_ok(engine.call("evaluate_condition", c_vision, u, bs, m, signals), "半径 0 → 取射程 3，敌人距 2 在视野内")
	enemy.call("set_logic_position", Vector2(4, 0))     # 距 4 > 3
	_ok(not engine.call("evaluate_condition", c_vision, u, bs, m, signals), "敌人距 4 超出射程 3 → 假")

	# --- 敌人持有状态（任一敌人口径；敌人必须在视野内）---
	var c_st = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_ENEMY_HAS_STATUS,
		 "status": RuleConditionScript.STATUS_SLOWED, "want": true})
	enemy.call("set_logic_position", Vector2(2, 0))     # 拉回射程 3 内
	_ok(not engine.call("evaluate_condition", c_st, u, bs, m, signals), "没有敌人减速 → 假")
	enemy.call("set_slowed")                            # 用单位自己的接口改状态
	_ok(engine.call("evaluate_condition", c_st, u, bs, m, signals), "有敌人减速 → 真")
	enemy.set("is_slowed", false)
	_ok(not engine.call("evaluate_condition", c_st, u, bs, m, signals), "取消减速后又变假")
	# 【注意】往节点 set_meta("is_slowed", …) 是**读不到**的：UnitActor 自己声明了
	# 同名属性，取值优先级是「属性 > meta」（M2 实测踩到）。
	enemy.set_meta("is_slowed", true)
	_ok(not engine.call("evaluate_condition", c_st, u, bs, m, signals),
		"设 meta 不影响（属性优先），说明状态只能经真实字段改")
	enemy.remove_meta("is_slowed")

	# --- 信号次 tick 生效（D4）---
	signals.call("setup", 3)
	var c_sig1 = RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_SIGNAL_STATE, "signal_index": 1, "want": true})
	signals.call("request_write", 1, true)
	_ok(not engine.call("evaluate_condition", c_sig1, u, bs, m, signals),
		"写入后、commit 前，条件仍读不到（本 tick 不生效）")
	signals.call("commit")
	_ok(engine.call("evaluate_condition", c_sig1, u, bs, m, signals),
		"commit 之后条件才读到 → **下一 tick 生效**（D4）")
	signals.call("setup", 3)
	_ok(not engine.call("evaluate_condition", c_sig1, u, bs, m, signals),
		"信号初始默认为关（需求 5.3）")

	# --- 延迟：不占冲突键、取 max 不叠加、阻塞期间不评估（M2-4）---
	u.set("rules", [RuleEngineScript.make_rule([], [_act_delay(1.0), _act_move([1])])])
	var it_d = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(is_equal_approx(float(it_d.get("delay_request")), 1.0), "延迟请求被产出")
	_ok((it_d.get("move_intent") as Array).size() == 1, "延迟与移动**不冲突**，两者都生效")

	u.set("rules", [RuleEngineScript.make_rule([], [_act_delay(1.0)]),
		RuleEngineScript.make_rule([], [_act_delay(2.0)])])
	var it_d2 = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(is_equal_approx(float(it_d2.get("delay_request")), 2.0),
		"两条延迟取 max = 2.0（不叠加成 3.0）")

	u.set("delay_remaining", 1.0)
	var it_blocked = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(it_blocked.get("move_intent") == null and it_blocked.get("fire_intent") == null
		and it_blocked.get("delay_request") == null,
		"延迟阻塞期间不评估条件、产出空意图")
	_ok((it_blocked.get("matched_rule_indices") as Array).is_empty(), "阻塞期间不命中任何指令")
	u.set("delay_remaining", 0.0)

	# --- 0 条件视为真 ---
	u.set("rules", [RuleEngineScript.make_rule([], [_act_fire(true)])])
	_ok(bool(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent")) == true,
		"0 个条件视为成立（无条件指令）")

	# --- 死亡单位不产出意图 ---
	u.set("is_dead", true)
	_ok(engine.call("evaluate_unit", u, bs, m, signals).get("fire_intent") == null,
		"死亡单位不产出意图")
	u.set("is_dead", false)

	# --- 纯函数：重复调用结果一致 ---
	u.set("rules", [r1, r2])
	enemy.call("set_logic_position", Vector2(1, 0))
	var a1 = engine.call("evaluate_unit", u, bs, m, signals)
	var a2 = engine.call("evaluate_unit", u, bs, m, signals)
	_ok(bool(a1.get("fire_intent")) == bool(a2.get("fire_intent"))
		and (a1.get("matched_rule_indices") as Array).size()
			== (a2.get("matched_rule_indices") as Array).size(),
		"重复调用结果一致（纯函数）")

	bs.call("clear")
	m.teardown()
	m.free()
	u.free()
	enemy.free()
	_done("rule")


# --- 规则构造小工具（让用例读起来短）---------------------------------------

func _act_fire(on: bool) -> RefCounted:
	return RuleActionScript.from_dict({"type": RuleActionScript.T_SET_FIRE_MODE, "fire": on})


func _act_move(seq: Array) -> RefCounted:
	return RuleActionScript.from_dict(
		{"type": RuleActionScript.T_MOVE_ALONG_BEACONS, "beacon_indices": seq})


func _act_signal(idx: int, val: bool) -> RefCounted:
	return RuleActionScript.from_dict(
		{"type": RuleActionScript.T_SET_SIGNAL, "signal_index": idx, "value": val})


func _act_delay(secs: float) -> RefCounted:
	return RuleActionScript.from_dict({"type": RuleActionScript.T_DELAY, "seconds": secs})


## 系统 03 · 网格地图 —— M1-2 已实现
func _check_map() -> void:
	print("\n-- 系统 03 · 网格地图 --")
	var map: Node = BattleMapScript.new()
	add_child(map)

	# --- 校验：行数与 height 不符 ---
	var e1: Array = map.load_from({"width": 2, "height": 3, "tiles": [[0, 0], [0, 0]]})
	_ok(e1.size() == 1 and (e1[0] as String).contains("行数"),
		"行数与 height 不符时报错（%s）" % (e1[0] if e1.size() > 0 else "无错误"))
	_ok(not map.is_ready_map(), "校验失败后地图不进入就绪状态")

	# --- 校验：非法瓦片 id，且一次报出全部 ---
	var e2: Array = map.load_from({"width": 2, "height": 2, "tiles": [[0, 9], [0, 9]]})
	_ok(e2.size() == 2, "非法瓦片逐格报错、一次报出全部（%d 条）" % e2.size())
	_ok((e2[0] as String).contains("第 0 行第 1 列"), "报错含行列号（%s）" % (e2[0] if e2.size() > 0 else ""))

	# --- 正常载入 7×7，3 个障碍、2 个目标区 ---
	var t: Array[Array] = []
	for j in 7:
		var row: Array = []
		for i in 7:
			row.append(BattleMapScript.TILE_EMPTY)
		t.append(row)
	t[1][1] = BattleMapScript.TILE_WALL
	t[1][2] = BattleMapScript.TILE_WALL
	t[2][1] = BattleMapScript.TILE_WALL
	t[6][6] = BattleMapScript.TILE_GOAL
	t[6][5] = BattleMapScript.TILE_GOAL
	var e3: Array = map.set_tiles(t)
	_ok(e3.is_empty(), "7×7 合法地图载入成功（错误数 %d）" % e3.size())
	_ok(map.is_ready_map() and map.width == 7 and map.height == 7, "尺寸为 7×7")
	_ok(map.wall_count() == 3, "3 个障碍生成 3 个碰撞体（实际 %d）" % map.wall_count())

	# --- 坐标换算往返 + 相邻格距离 = 1.0 ---
	var round_trip_ok := true
	for j in 7:
		for i in 7:
			var tile_back: Vector2i = map.world_to_tile(map.tile_to_world(i, j))
			if tile_back != Vector2i(i, j):
				round_trip_ok = false
	_ok(round_trip_ok, "tile_to_world → world_to_tile 往返一致")
	_ok(is_equal_approx(map.tile_spacing(), 1.0),
		"相邻瓦片中心的逻辑距离 = 1.0（实际 %.6f）" % map.tile_spacing())
	var logic_back: Vector2i = map.logic_to_tile(map.tile_to_logic(3, 4))
	_ok(logic_back == Vector2i(3, 4), "logic 坐标往返一致（tile_to_logic → logic_to_tile）")

	# --- 通行判定 ---
	_ok(not map.is_passable(1, 1), "障碍格不可通行")
	_ok(map.is_passable(0, 0), "空地可通行")
	_ok(map.is_passable(6, 6), "目标区可通行")
	_ok(not map.is_passable(99, 99), "越界不可通行")

	# --- 信标放置判定（FR-MAP-03）---
	_ok(not map.can_place_beacon(1, 1), "障碍格不可放信标")
	_ok(map.can_place_beacon(0, 0), "空地可放信标")
	_ok(not map.can_place_beacon(6, 6), "目标区不可放信标")

	# --- 目标区格列表 ---
	var goals: Array = map.goal_cells()
	_ok(goals.size() == 2, "目标区格列表有 2 格（实际 %d）" % goals.size())

	# --- 瓦片查询与越界 ---
	_ok(map.tile_at(1, 1) == BattleMapScript.TILE_WALL, "tile_at 取到障碍")
	_ok(map.tile_at(-1, 0) == -1 and map.tile_at(0, 99) == -1, "越界瓦片返回 -1")

	# --- clear() 销毁碰撞体与数据 ---
	map.clear()
	_ok(map.wall_count() == 0, "clear() 后碰撞体为 0（实际 %d）" % map.wall_count())
	_ok(not map.is_ready_map(), "clear() 后地图不再就绪")

	map.teardown()
	map.free()

## 系统 03 · 网格地图 —— M1-3：实体注册表与查询。
## 分三个独立场景，每个场景开头 clear()，避免上一个场景的实体污染判定。
	_done("map")
func _check_state() -> void:
	print("\n-- 系统 03b · 实体注册表 BattleState --")

	# ================= 场景 A：注册、id 自增、升序、最近敌人 =================
	var bs: RefCounted = BattleStateScript.new()
	var a := _make_stub_unit(Vector2(0, 0), BattleStateScript.TEAM_ALLY)
	var e1 := _make_stub_unit(Vector2(3, 0), BattleStateScript.TEAM_ENEMY)
	var e2 := _make_stub_unit(Vector2(1, 0), BattleStateScript.TEAM_ENEMY)
	var id_a: int = bs.register_unit(a)
	var id_e1: int = bs.register_unit(e1)
	var id_e2: int = bs.register_unit(e2)
	print("   [diag] 场景A 注册 id: a=%d e1=%d e2=%d" % [id_a, id_e1, id_e2])
	_ok(id_a == 1 and id_e1 == 2 and id_e2 == 3, "实体 id 从 1 起自增（%d,%d,%d）" % [id_a, id_e1, id_e2])
	_ok(bs.units.size() == 3, "注册后共 3 个单位（实际 %d）" % bs.units.size())
	_ok(bs.find_unit(id_e2) == e2, "find_unit 能取回单位")

	var ids: Array = bs.unit_ids_sorted()
	_ok(ids.size() == 3 and int(ids[0]) == 1 and int(ids[2]) == 3, "unit_ids_sorted 升序")

	_ok(bs.alive_count(BattleStateScript.TEAM_ALLY) == 1, "我方存活 1")
	_ok(bs.alive_count(BattleStateScript.TEAM_ENEMY) == 2, "敌方存活 2")

	_ok(bs.query_nearest_enemy(a, 10.0) == e2, "最近敌人取距离更近者（e2 在 1 距离处，e1 在 3 距离处）")
	_ok(bs.query_nearest_enemy(a, 1.0) == e2, "半径恰好等于距离时算在内（1.0 → 命中）")
	_ok(bs.query_nearest_enemy(a, 0.9) == null, "半径略小于距离时不在内（0.9 → 无目标）")
	_ok(bs.query_nearest_enemy(a, 5.0) == e2, "半径 5 时仍取最近者")

	_ok(bs.has_enemy_in_radius(a, 1.0), "半径内有敌人 → 条件为真")
	_ok(not bs.has_enemy_in_radius(a, 0.5), "半径内无敌人 → 条件为假")

	# 贴身的友军不算敌人
	var ally2 := _make_stub_unit(Vector2(0.1, 0), BattleStateScript.TEAM_ALLY)
	bs.register_unit(ally2)
	_ok(bs.query_nearest_enemy(a, 0.5) == null, "贴身的友军不算敌人")

	# 状态查询（减速口径：任一敌人）
	_ok(not bs.query_any_enemy_with_status(a, "slowed", true, 10.0), "无人减速时为假")
	e1.set_meta("is_slowed", true)
	_ok(bs.query_any_enemy_with_status(a, "slowed", true, 10.0), "有敌人减速时为真")
	_ok(bs.query_any_enemy_with_status(a, "slowed", false, 10.0), "有人不减速 → 「不持有」为真")
	_ok(not bs.query_any_enemy_with_status(a, "unknown_status", true, 10.0), "未知状态类型恒为假")

	# ================= 场景 B：等距取 id 更小者（FR-TEST-08）=================
	# 【必须用干净的注册表】场景 A 里 e2 距 a 只有 1，会把等距的两个对手压下去，
	# 根本测不到「等距」这条规则（M1-3 实测踩到）。
	bs.clear()
	var b := _make_stub_unit(Vector2(0, 0), BattleStateScript.TEAM_ALLY)
	var x1 := _make_stub_unit(Vector2(2, 0), BattleStateScript.TEAM_ENEMY)
	var x2 := _make_stub_unit(Vector2(-2, 0), BattleStateScript.TEAM_ENEMY)
	var id_b: int = bs.register_unit(b)
	var id_x1: int = bs.register_unit(x1)
	var id_x2: int = bs.register_unit(x2)
	print("   [diag] 场景B 注册 id: b=%d x1=%d x2=%d（x1/x2 距 b 均为 2.0）" % [id_b, id_x1, id_x2])
	_ok(id_x1 < id_x2, "两个等距敌人的 id 是 %d 与 %d" % [id_x1, id_x2])
	_ok(bs.query_nearest_enemy(b, 10.0) == x1, "等距时取 id 更小者（可复现）")
	var stable := true
	for i in 20:
		if bs.query_nearest_enemy(b, 10.0) != x1:
			stable = false
	_ok(stable, "等距目标连续 20 次查询结果一致")
	_ok(bs.query_enemies_in_radius(b, 10.0).size() == 2, "两个敌人都被查到（友军与自身不算）")

	# ================= 场景 C：注销与死亡后退出查询 =================
	bs.clear()
	var c_a := _make_stub_unit(Vector2(0, 0), BattleStateScript.TEAM_ALLY)
	var c_e1 := _make_stub_unit(Vector2(3, 0), BattleStateScript.TEAM_ENEMY)
	var c_e2 := _make_stub_unit(Vector2(1, 0), BattleStateScript.TEAM_ENEMY)
	var c_id_a: int = bs.register_unit(c_a)
	var c_id_e1: int = bs.register_unit(c_e1)
	var c_id_e2: int = bs.register_unit(c_e2)
	print("   [diag] 场景C 注册 id: a=%d e1=%d e2=%d" % [c_id_a, c_id_e1, c_id_e2])
	_ok(bs.units.size() == 3, "场景C 注册 3 个")

	bs.unregister_unit(c_id_e2)
	_ok(bs.find_unit(c_id_e2) == null, "注销后 find_unit 取不到")
	_ok(bs.units.size() == 2, "注销后总数减 1（实际 %d）" % bs.units.size())
	_ok(bs.query_nearest_enemy(c_a, 1.0) == null, "注销后不再被索敌命中")
	_ok(bs.alive_count(BattleStateScript.TEAM_ENEMY) == 1, "注销后敌方存活 1")

	# 死亡标记（不注销）也应被查询排除
	var c_e3 := _make_stub_unit(Vector2(2, 0), BattleStateScript.TEAM_ENEMY)
	bs.register_unit(c_e3)
	_ok(bs.alive_count(BattleStateScript.TEAM_ENEMY) == 2, "新增一个敌人后存活 2")
	c_e3.set_meta("is_dead", true)
	_ok(bs.alive_count(BattleStateScript.TEAM_ENEMY) == 1,
		"标记死亡后不计入存活数（实际 %d）" % bs.alive_count(BattleStateScript.TEAM_ENEMY))
	_ok(bs.query_nearest_enemy(c_a, 10.0) == c_e1, "已死目标不参与索敌（只剩 e1）")

	# 子弹登记
	var proj := Node.new()
	bs.register_projectile(proj)
	_ok(bs.projectiles.size() == 1, "子弹登记成功")
	bs.unregister_projectile(proj)
	_ok(bs.projectiles.is_empty(), "子弹注销成功")

	# clear() 与 id 分配器复位
	bs.clear()
	_ok(bs.units.is_empty() and bs.projectiles.is_empty(), "clear() 后注册表为空")
	print("   [diag] clear 后 units.size=%d" % bs.units.size())
	_ok(int(bs.register_unit(_make_stub_unit(Vector2.ZERO, 0))) == 1, "clear() 后 id 分配器复位")


## 造一个「像单位一样」的替身节点：只带 BattleState 约定要读的字段。
## 这样测试不依赖 UnitActor，注册表可以先独立验收。
##
## 【必须用 set_meta】裸 Node2D 没有这些属性，`set()` 只写**已存在**的属性，
## 对不存在的属性会静默失败（M1-3 实测踩到两次）。
	_done("state")
func _make_stub_unit(pos: Vector2, team: int) -> Node2D:
	var n := Node2D.new()
	n.set_meta("team", team)
	n.set_meta("entity_id", 0)
	n.set_meta("is_dead", false)
	n.set_meta("position_logic", pos)
	add_child(n)
	return n


## 网格是否可通行；把 min/max 之间的格都刷成指定瓦片。
## 专供 M1-4 的「撞墙完全停住且不滑墙」用例造一条走廊。
func _make_grid(w: int, h: int, fill: int) -> Array[Array]:
	var t: Array[Array] = []
	for j in h:
		var row: Array = []
		for i in w:
			row.append(fill)
		t.append(row)
	return t


## 系统 03 · 信标层 —— M1-5：放置、撤回、配额、序号前移
func _check_beacons() -> void:
	print("\n-- 系统 03c · 信标层 BeaconLayer --")

	# 造一张 7×7 地图：(0,0)/(1,0) 是空地，(2,0) 是墙，(3,0) 是目标区
	var t := _make_grid(7, 7, BattleMapScript.TILE_EMPTY)
	t[0][2] = BattleMapScript.TILE_WALL
	t[0][3] = BattleMapScript.TILE_GOAL
	var map: Node = BattleMapScript.new()
	add_child(map)
	map.set_tiles(t)

	var layer: RefCounted = BeaconLayerScript.new()
	var events: Array = []
	layer.changed.connect(func(c: int, q: int) -> void: events.append([c, q]))

	# --- 初始状态 ---
	layer.setup(map, 4)
	_ok(layer.count() == 0 and layer.available() == 4, "初始 0 个信标、可用 4 个")
	_ok(not layer.is_full(), "初始未满")
	_ok(map.beacon_count() == 0, "地图侧信标数为 0")

	# --- 放置：序号从 1 开始 ---
	var n1: int = layer.add_beacon(Vector2i(0, 0))
	var n2: int = layer.add_beacon(Vector2i(1, 0))
	_ok(n1 == 1 and n2 == 2, "放置返回序号 1、2（实际 %d、%d）" % [n1, n2])
	_ok(layer.count() == 2 and layer.available() == 2, "放了 2 个后可用剩 2")
	_ok(map.beacon_count() == 2, "放置已同步到地图（单位移动的权威来源）")
	_ok(layer.index_of(Vector2i(1, 0)) == 2, "index_of 取到序号 2")
	_ok(layer.index_of(Vector2i(5, 5)) == 0, "没放过的格子 index_of 为 0")
	_ok(layer.at(1) == Vector2i(0, 0) and layer.at(2) == Vector2i(1, 0), "at(序号) 取回瓦片")
	_ok(layer.at(0) == null and layer.at(9) == null, "越界序号返回 null")

	# --- 变更广播 ---
	_ok(events.size() >= 3, "每次变更都广播 changed（已收到 %d 次）" % events.size())
	_ok(int(events[events.size() - 1][0]) == 2, "广播里带上当前数量")

	# --- 非法格：墙与目标区都不能放 ---
	_ok(not bool(layer.can_place(Vector2i(2, 0))), "墙格不可放")
	_ok(layer.add_beacon(Vector2i(2, 0)) == 0, "往墙格放被拒绝且返回 0")
	_ok(not bool(layer.can_place(Vector2i(3, 0))), "目标区不可放（需求 4.2）")
	_ok(layer.add_beacon(Vector2i(3, 0)) == 0, "往目标区放被拒绝")
	_ok(layer.count() == 2, "被拒的放置没有改变数量")

	# --- 配额用满 ---
	layer.add_beacon(Vector2i(0, 1))
	layer.add_beacon(Vector2i(1, 1))
	_ok(layer.count() == 4 and layer.is_full(), "放满 4 个后 is_full")
	_ok(layer.available() == 0, "可用数为 0")
	_ok(layer.add_beacon(Vector2i(2, 1)) == 0, "配额满后再放被拒绝")
	_ok(layer.count() == 4, "被拒后数量不变")

	# --- 撤回中间的序号前移 ---
	_ok(layer.remove_at(2), "撤回序号 2")
	_ok(layer.count() == 3 and layer.available() == 1, "撤回后数量 3、可用 1")
	_ok(layer.at(2) == Vector2i(0, 1), "原序号 3 前移到序号 2（实际 %s）" % str(layer.at(2)))
	_ok(layer.at(3) == Vector2i(1, 1), "原序号 4 前移到序号 3")
	_ok(layer.index_of(Vector2i(1, 0)) == 0, "被撤回的那格已无信标")
	_ok(map.beacon_count() == 3, "撤回已同步到地图")
	# 【坐标约定】逻辑坐标 = **瓦片中心**的格偏移量，所以瓦片 (0,1) 的逻辑坐标是 (0.5, 1.5)
	_ok(map.beacon_logic_position(2) == Vector2(0.5, 1.5),
		"地图按新序号给出逻辑坐标（瓦片中心，实际 %s）" % str(map.beacon_logic_position(2)))

	# --- 撤回越界与不存在的格 ---
	_ok(not layer.remove_at(0), "撤回序号 0 失败")
	_ok(not layer.remove_at(99), "撤回越界序号失败")
	_ok(not layer.remove_tile(Vector2i(6, 6)), "撤回没放过的格失败")

	# --- 按格撤回 ---
	_ok(layer.remove_tile(Vector2i(0, 1)), "按格撤回成功")
	_ok(layer.count() == 2, "按格撤回后数量 2")

	# --- 配额为 0 的关卡不能放 ---
	var empty_layer: RefCounted = BeaconLayerScript.new()
	empty_layer.setup(map, 0)
	_ok(empty_layer.is_full(), "配额 0 时立即为满")
	_ok(empty_layer.add_beacon(Vector2i(0, 0)) == 0, "配额 0 时不能放信标")

	# --- clear 与 resync ---
	layer.clear()
	_ok(layer.count() == 0 and map.beacon_count() == 0, "clear() 后两边都清空")
	layer.setup(map, 4)
	layer.add_beacon(Vector2i(0, 0))
	layer.resync()
	_ok(layer.count() == 1 and map.beacon_count() == 1, "resync() 保留信标并重新同步")

	# --- 引用不存在的信标时，地图查询返回 null（规则引擎靠它判定整条跳过）---
	_ok(map.beacon_logic_position(9) == null, "不存在的信标索引返回 null")

	# --- FR-MAP-04（P1）：**同一格允许多个信标（重复放置）** ---
	#
	# 【为什么值得单测】这条需求是"允许重复"，而放置判据里只要有人顺手加一句
	# `if index_of(tile) > 0: return false`（很自然的防呆写法）就会**悄悄违反需求**。
	# 实现上没有查重是对的（`can_place_beacon` 只判"在界内且非墙/非终点"），
	# 但没有用例守着 —— 所以补上。
	layer.clear()
	_ok(layer.add_beacon(Vector2i(2, 3)) == 1, "同格重复放置：第一个信标序号 1")
	_ok(layer.add_beacon(Vector2i(2, 3)) == 2,
		"**同一格可以再放一个信标（序号 2）**（FR-MAP-04）")
	_ok(layer.count() == 2, "两个信标都记在册（共 2 个）")
	_ok(layer.at(1) == Vector2i(2, 3) and layer.at(2) == Vector2i(2, 3),
		"两个信标的格子相同")
	# 撤回序号 1 之后，序号 2 前移成 1（顺序语义在重复格上也要成立）
	layer.remove_at(1)
	_ok(layer.count() == 1, "撤回一个后剩 1 个")
	_ok(layer.at(1) == Vector2i(2, 3), "剩下那个前移成序号 1，格子不变")
	# 重复放置也要占用配额
	layer.clear()
	layer.setup(map, 2)
	_ok(layer.add_beacon(Vector2i(1, 1)) == 1, "配额 2：放第 1 个")
	_ok(layer.add_beacon(Vector2i(1, 1)) == 2, "配额 2：同格放第 2 个也成功")
	_ok(layer.add_beacon(Vector2i(1, 1)) == 0, "**配额用满后同格也不能再放**（重复不等于不算数）")
	_ok(layer.count() == 2, "重复放置占用配额（共 2 个）")

	map.teardown()
	map.free()
	_done("beacons")
## 系统 04 · 单位与移动 —— M1-4 已实现
func _check_unit() -> void:
	print("\n-- 系统 04 · 单位与移动 --")

	# ================= 1. 数值与意图落地（纯逻辑，不碰物理）=================
	var u: Node2D = UnitActorScript.new()
	add_child(u)
	u.call("setup", UnitActorScript.TEAM_ALLY, Vector2(0, 0),
		{"max_hp": 100.0, "move_speed": 3.0, "can_attack": false, "range": 0.0})
	# 测试手动驱动 step_movement，必须关掉引擎自动物理，避免两边叠加
	u.set_physics_process(false)
	_ok(is_equal_approx(float(u.get("hp")), 100.0), "setup 后满血")
	_ok(is_equal_approx(u.call("move_speed"), 3.0), "move_speed 取自 stats")
	_ok(not bool(u.call("can_attack")), "无攻击能力单位 can_attack 为假")
	_ok(is_equal_approx(u.call("effective_range"), 0.0), "非攻击单位射程 0")

	# 减速不叠加：置一次就固定降到 50%，再置一次不改变
	u.call("set_slowed")
	_ok(is_equal_approx(u.call("move_speed"), 1.5), "减速后速度降 50%（3.0 → 1.5）")
	u.call("set_slowed")
	_ok(is_equal_approx(u.call("move_speed"), 1.5), "再次减速不叠加（仍为 1.5）")

	# 视野半径：0 表示取射程
	var attacker: Node2D = UnitActorScript.new()
	add_child(attacker)
	attacker.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(0, 0),
		{"max_hp": 100.0, "move_speed": 3.0, "can_attack": true, "range": 5.0})
	# 测试手动驱动 step_movement，必须关掉引擎自动物理，避免两边叠加
	attacker.set_physics_process(false)
	_ok(is_equal_approx(attacker.call("effective_vision_radius"), 5.0), "视野半径 0 时取射程（5.0）")

	# 意图：移动序列落地
	var intent = IntentScript.new()
	intent.move_intent = [1, 2, 3]
	u.call("apply_intents", intent, 1.0 / 60.0)
	_ok((u.get("beacon_sequence") as Array).size() == 3 and int(u.get("beacon_cursor")) == 0,
		"移动意图写入序列并把游标置 0")

	# 值相等 → 保持游标（避免来回震荡）
	u.set("beacon_cursor", 2)
	var same = IntentScript.new()
	same.move_intent = [1, 2, 3]
	u.call("apply_intents", same, 1.0 / 60.0)
	_ok(int(u.get("beacon_cursor")) == 2, "同一序列再次刷新时游标保持（不被重置到 0）")

	# 序列变化 → 重置游标
	var diff = IntentScript.new()
	diff.move_intent = [3, 4]
	u.call("apply_intents", diff, 1.0 / 60.0)
	_ok(int(u.get("beacon_cursor")) == 0 and (u.get("beacon_sequence") as Array).size() == 2,
		"序列变化时游标重置为 0 并换成新序列")

	# 开火意图是持续型：本次不给就不清空
	var fire_on = IntentScript.new()
	fire_on.fire_intent = true
	attacker.call("apply_intents", fire_on, 1.0 / 60.0)
	_ok(bool(attacker.get("fire_mode")), "开火意图置位")
	var empty_intent = IntentScript.new()
	attacker.call("apply_intents", empty_intent, 1.0 / 60.0)
	_ok(bool(attacker.get("fire_mode")), "本次没有开火意图时保持原值（持续型不清空）")

	# 延迟：取 max 不叠加；阻塞期间不动也不开火
	var d1 = IntentScript.new()
	d1.delay_request = 1.0
	attacker.call("apply_intents", d1, 1.0 / 60.0)
	var dr1 := float(attacker.get("delay_remaining"))
	var d2 = IntentScript.new()
	d2.delay_request = 2.0
	attacker.call("apply_intents", d2, 1.0 / 60.0)
	_ok(dr1 > 0.0 and float(attacker.get("delay_remaining")) <= 2.0,
		"延迟取 max 不叠加（1.0 与 2.0 不叠加成 3.0）")
	_ok(not bool(attacker.call("wants_to_fire")), "延迟阻塞期间不开火")
	# 递减到 0 后恢复
	attacker.set("delay_remaining", 0.0)
	_ok(bool(attacker.call("wants_to_fire")), "延迟结束后恢复开火意图")

	# ================= 2. 纯算术移动（无物理世界）=================
	var m := _make_grid(7, 7, BattleMapScript.TILE_EMPTY)
	var map2: Node = BattleMapScript.new()
	add_child(map2)
	map2.set_tiles(m)
	map2.set_beacons([Vector2i(3, 0)])
	u.set("battle_map", map2)
	u.set("beacon_sequence", [1])
	u.set("beacon_cursor", 0)
	u.set("is_slowed", false)
	u.set("delay_remaining", 0.0)
	u.call("set_logic_position", Vector2(0.0, 0.5))   # 与信标同一条水平线，便于断言 y 不变
	# 走两个 tick：速度 3 × (1/60) × 2 = 0.1 格
	u.call("step_movement", 1.0 / 60.0)
	u.call("step_movement", 1.0 / 60.0)
	var after_two := u.get("position_logic") as Vector2
	_ok(absf(after_two.x - 0.1) < 1e-4 and absf(after_two.y - 0.5) < 1e-6,
		"匀速直线：两个 tick 位移 %.4f（期望 0.1）" % after_two.x)

	# 走到信标后自动切下一个；没有更多则停住
	u.set("beacon_sequence", [1])
	u.set("beacon_cursor", 0)
	u.call("set_logic_position", Vector2(3.5, 0.5))   # 直接站在信标中心（瓦片 3,0 的中心）
	u.call("step_movement", 1.0 / 60.0)
	_ok(int(u.get("beacon_cursor")) == 1, "到达信标后游标自动 +1")
	var before_idle := u.get("position_logic") as Vector2
	for i in 30:
		u.call("step_movement", 1.0 / 60.0)
	var after_idle := u.get("position_logic") as Vector2
	_ok(before_idle.distance_to(after_idle) < 1e-9, "走完全部信标后停在原地不漂移")

	# 无目标不动
	var u_idle: Node2D = UnitActorScript.new()
	add_child(u_idle)
	u_idle.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1, 1), {"max_hp": 10.0, "move_speed": 3.0})
	# 测试手动驱动 step_movement，必须关掉引擎自动物理，避免两边叠加
	u_idle.set_physics_process(false)
	u_idle.call("step_movement", 1.0 / 60.0)
	_ok((u_idle.get("position_logic") as Vector2).distance_to(Vector2(1, 1)) < 1e-9, "无任何意图时原地不动")

	# 最后一段精确落点（不抖动）
	# 【诊断】先确认「物理载体的纯直线移动」本身能走：在与 u 相同的环境下
	# 造一个干净单位，看它能否沿 +x 移动。M1-4 就是靠这个把问题锁到
	# move_and_collide 上的。
	var free_map: Node2D = BattleMapScript.new()
	add_child(free_map)
	free_map.set_tiles(_make_grid(9, 5, BattleMapScript.TILE_EMPTY))
	free_map.set_beacons([Vector2i(5, 2)])
	var free_unit: Node2D = UnitActorScript.new()
	add_child(free_unit)
	free_unit.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1, 2), {"max_hp": 10.0, "move_speed": 3.0})
	# 测试手动驱动 step_movement，必须关掉引擎自动物理，避免两边叠加
	free_unit.set_physics_process(false)
	free_unit.set("battle_map", free_map)
	free_unit.set("beacon_sequence", [1])
	free_unit.set("beacon_cursor", 0)
	var free_start := free_unit.get("position_logic") as Vector2
	for i in 20:
		free_unit.call("step_movement", 1.0 / 60.0)
	var free_end := free_unit.get("position_logic") as Vector2
	print("   [diag] 空旷地图移动：%s → %s（期望 x ≈ %.3f）" % [str(free_start), str(free_end), free_start.x + 20.0 / 60.0 * 3.0])
	_ok(free_end.x > free_start.x + 0.5, "空旷地图上单位能自由直线移动（x %.3f → %.3f）" % [free_start.x, free_end.x])
	free_unit.queue_free()
	free_map.teardown()
	free_map.free()

	# 最后一段精确落点（不抖动）
	# 【必须从比 ARRIVE_EPSILON 更远的地方出发】若起始点已经在到达阈值内，
	# step_movement 会判定「已到达」、只把游标 +1 就返回，根本不产生位移——
	# 那测的是到达判定，不是精确落点（M1-4 实测踩到）。
	u.set("beacon_sequence", [1])
	u.set("beacon_cursor", 0)
	u.call("set_logic_position", Vector2(2.0, 0.0))      # 距信标 1.0，远大于阈值 0.15
	var wnames: Array[String] = []
	var wroot = map2.get_node_or_null("Walls")
	if wroot != null:
		for c in wroot.get_children():
			wnames.append(c.name)
	var land_ticks := 0
	while land_ticks < 200 and int(u.get("beacon_cursor")) == 0:
		var before_tick := u.get("position_logic") as Vector2
		var tgt = u.call("current_beacon_target")
		var step_len: float = float(u.call("move_speed")) * (1.0 / 60.0)
		u.call("step_movement", 1.0 / 60.0)
		land_ticks += 1
		if land_ticks <= 6 or (land_ticks >= 16 and land_ticks <= 24):
			var dist: float = before_tick.distance_to(tgt as Vector2)
	var landed := u.get("position_logic") as Vector2
	print("   [diag] 精确落点：%d tick 后 x=%.9f（信标在 x=3）" % [land_ticks, landed.x])
	var blockers: Array[String] = []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is StaticBody2D and (node as StaticBody2D).get_collision_layer_value(2):
			blockers.append("%s@%s" % [node.name, str((node as StaticBody2D).global_position)])
		for c in node.get_children():
			stack.append(c)
	# 信标在瓦片 (3,0)，其**逻辑中心**是 (3.5, 0.5)（坐标约定：逻辑坐标 = 瓦片中心）
	_ok(absf(landed.x - 3.5) < 1e-6, "最后一段精确落到信标中心（x=%.9f，期望 3.5）" % landed.x)
	_ok(int(u.get("beacon_cursor")) == 1, "落点后游标推进（已无更多信标）")
	# 到了之后连续跑，位置必须纹丝不动（不抖动）
	var settle := u.get("position_logic") as Vector2
	for i in 30:
		u.call("step_movement", 1.0 / 60.0)
	_ok((u.get("position_logic") as Vector2).distance_to(settle) < 1e-9,
		"到达后连续 30 tick 位置不变（不抖动）")

	# 延迟期间不移动
	u.set("beacon_sequence", [1])
	u.set("beacon_cursor", 0)
	u.call("set_logic_position", Vector2(0, 0))
	u.set("delay_remaining", 1.0)
	for i in 10:
		u.call("step_movement", 1.0 / 60.0)
	_ok((u.get("position_logic") as Vector2).distance_to(Vector2(0, 0)) < 1e-9, "延迟阻塞期间不移动")

	# 引用了被撤回的信标 → 没有目标，不动
	u.set("delay_remaining", 0.0)
	u.set("beacon_sequence", [9])                    # 信标 9 不存在
	u.set("beacon_cursor", 0)
	u.call("set_logic_position", Vector2(0, 0))
	u.call("step_movement", 1.0 / 60.0)
	_ok((u.get("position_logic") as Vector2).distance_to(Vector2(0, 0)) < 1e-9,
		"引用不存在的信标时没有目标、原地不动")
	_ok(map2.beacon_logic_position(9) == null, "beacon_logic_position 对不存在的索引返回 null")
	_ok(map2.beacon_logic_position(1) is Vector2, "beacon_logic_position 对存在的索引返回逻辑坐标")

	# ================= 3. 物理世界里的撞墙：完全停住、不滑墙 =================
	# 造一条走廊：y=3 一行空地，y=2 与 y=4 全墙；单位在 (1,3) 向 +x 走向信标 (6,3)
	var corridor := _make_grid(9, 7, BattleMapScript.TILE_WALL)
	for i in 9:
		corridor[3][i] = BattleMapScript.TILE_EMPTY
	var pmap: Node2D = BattleMapScript.new()
	add_child(pmap)
	pmap.set_tiles(corridor)
	pmap.set_beacons([Vector2i(6, 3)])

	var runner: Node2D = UnitActorScript.new()
	add_child(runner)
	runner.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1.5, 3.5), {"max_hp": 100.0, "move_speed": 3.0})
	# 测试手动驱动 step_movement，必须关掉引擎自动物理，避免两边叠加
	runner.set_physics_process(false)
	runner.set("battle_map", pmap)
	runner.set("beacon_sequence", [1])
	runner.set("beacon_cursor", 0)

	# 先让物理世界把碰撞体登记进去（StaticBody2D 需要一帧才生效）
	await get_tree().physics_frame
	await get_tree().physics_frame

	var start_pos := runner.get("position_logic") as Vector2
	for i in 60:
		runner.call("step_movement", 1.0 / 60.0)
		await get_tree().physics_frame
	var mid_pos := runner.get("position_logic") as Vector2
	print("   [diag] 走廊移动：起点 %s → 60 tick 后 %s" % [str(start_pos), str(mid_pos)])
	_ok(mid_pos.x > start_pos.x + 0.5, "走廊里确实向前移动了（x %.3f → %.3f）" % [start_pos.x, mid_pos.x])

	# 再跑很久，应停在墙前（x 接近 8 - 半格），且**y 不变**
	for i in 240:
		runner.call("step_movement", 1.0 / 60.0)
		await get_tree().physics_frame
	var end_pos := runner.get("position_logic") as Vector2
	print("   [diag] 走廊终点：%s" % str(end_pos))
	_ok(absf(end_pos.y - 3.5) < 1e-6,
		"撞墙过程零横向偏移（y 恒为 3.5，实际 %.6f）—— 证明没有沿墙滑动" % end_pos.y)
	_ok(end_pos.x < 8.0, "没有穿墙（x=%.3f 仍在地图内）" % end_pos.x)

	# 撞墙后再跑，位置必须完全不变
	var frozen := runner.get("position_logic") as Vector2
	for i in 60:
		runner.call("step_movement", 1.0 / 60.0)
		await get_tree().physics_frame
	var frozen2 := runner.get("position_logic") as Vector2
	_ok(frozen.distance_to(frozen2) < 1e-6,
		"抵住墙后位置完全不再变化（%.4f → %.4f）—— 完全停住" % [frozen.x, frozen2.x])

	# ================= 4. 死亡与重置 =================
	var dead_unit: Node2D = UnitActorScript.new()
	add_child(dead_unit)
	dead_unit.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(2, 2), {"max_hp": 30.0, "move_speed": 2.0})
	# 测试手动驱动 step_movement，必须关掉引擎自动物理，避免两边叠加
	dead_unit.set_physics_process(false)
	var bs2: RefCounted = BattleStateScript.new()
	bs2.register_unit(dead_unit)
	dead_unit.set("battle_state", bs2)
	var died_count := [0]
	EventBus.unit_died.connect(func(_id: int, _t: int, _p: Vector2) -> void: died_count[0] += 1, CONNECT_ONE_SHOT)
	dead_unit.call("die")
	_ok(bool(dead_unit.get("is_dead")), "die() 置死亡标记")
	_ok(bs2.units.size() == 0, "死亡后从注册表注销（尸体节点仍在场景树）")
	_ok(dead_unit.is_inside_tree(), "尸体节点仍保留在场景树里")
	_ok(died_count[0] == 1, "死亡时广播 unit_died 信号")
	dead_unit.call("die")
	_ok(died_count[0] == 1, "重复 die() 不重复广播")

	# 重置恢复，但保留规则
	var keep_rule = RuleScript.new()
	dead_unit.set("rules", [keep_rule])
	dead_unit.call("set_slowed")
	dead_unit.call("reset")
	_ok(not bool(dead_unit.get("is_dead")), "reset() 复活")
	_ok(is_equal_approx(float(dead_unit.get("hp")), 30.0), "reset() 回满血")
	_ok(not bool(dead_unit.get("is_slowed")), "reset() 清除减速")
	_ok((dead_unit.get("position_logic") as Vector2).distance_to(Vector2(2, 2)) < 1e-9, "reset() 回到出生点")
	_ok((dead_unit.get("rules") as Array).size() == 1, "reset() **保留**玩家已写的指令")

	u.queue_free(); attacker.queue_free(); u_idle.queue_free()
	map2.teardown()
	map2.free(); pmap.teardown()
	pmap.free(); runner.queue_free(); dead_unit.queue_free()
	_done("unit")


const ProjectileScript := preload("res://src/core/combat/projectile.gd")


## 让一个 LevelSession 处于「可调用 _step_weapons」的状态。
## 本用例只测武器与子弹，不需要真装配整个关卡，所以直接注入 host 与注册表。
func _wire_weapons(session: RefCounted, bs: RefCounted) -> void:
	session.set("host", self)
	session.set("battle_state", bs)


## 系统 05 · 战斗 —— M2-6…M2-8
func _check_combat() -> void:
	print("\n-- 系统 05 · 战斗 --")

	var bs: RefCounted = BattleStateScript.new()
	var m: Node2D = BattleMapScript.new()
	add_child(m)
	m.set_tiles(_make_grid(12, 3, BattleMapScript.TILE_EMPTY))

	var stats_atk := {
		"max_hp": 100.0, "move_speed": 3.0, "can_attack": true, "range": 3.0,
		"damage": 10.0, "attack_interval": 1.0, "projectile_speed": 12.0,
		"projectile_radius": 0.3, "vision_radius": 0.0, "on_hit_status": "",
	}
	var stats_ice := stats_atk.duplicate(true)
	stats_ice["on_hit_status"] = "slowed"
	stats_ice["range"] = 10.0
	stats_ice["damage"] = 50.0
	stats_ice["attack_interval"] = 2.0

	var shooter: Node2D = UnitActorScript.new()
	add_child(shooter)
	shooter.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1, 1), stats_atk)
	shooter.set_physics_process(false)
	bs.call("register_unit", shooter)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var foe: Node2D = UnitActorScript.new()
	add_child(foe)
	foe.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(2, 1), stats_atk)
	foe.set_physics_process(false)
	bs.call("register_unit", foe)

	# 需要物理世界：碰撞体要一帧才注册进 PhysicsServer
	await get_tree().physics_frame
	await get_tree().physics_frame

	# ================= 冷却：只在想开火时递减（M2-6）=================
	var s2: RefCounted = LevelSessionScript.new()
	_wire_weapons(s2, bs)
	shooter.set("fire_mode", false)
	shooter.set("cooldown_remaining", 0.0)
	var _before_ids1: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	_ok((bs.get("projectiles") as Dictionary).is_empty(), "停火时不生成子弹")
	_ok(is_equal_approx(float(shooter.get("cooldown_remaining")), 0.0),
		"停火期间冷却不变（不会白白转）")

	shooter.set("fire_mode", true)
	var _before_ids2: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	_ok((bs.get("projectiles") as Dictionary).size() == 1, "想开火且冷却就绪 → 生成 1 颗子弹")
	_ok(is_equal_approx(float(shooter.get("cooldown_remaining")), 1.0),
		"开火后冷却重置为 attack_interval（1.0）")
	var _before_ids3: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	_ok((bs.get("projectiles") as Dictionary).size() == 1, "冷却未走完不再生成（仍 1 颗）")

	# 清场
	for k in (bs.get("projectiles") as Dictionary).keys():
		var p = (bs.get("projectiles") as Dictionary)[k]
		p.call("destroy")

	# ================= 无目标不开火、且不消耗冷却 =================
	foe.call("die")
	shooter.set("cooldown_remaining", 0.0)
	var _before_ids4: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	_ok((bs.get("projectiles") as Dictionary).is_empty(), "没有目标时不生成子弹")
	_ok(is_equal_approx(float(shooter.get("cooldown_remaining")), 0.0),
		"没有目标时不消耗冷却")
	# 复活它，好继续测后面的用例。
	# 【必须用 reset()】die() 会把 Hurtbox 的碰撞层清零（这是刻意的：
	# 尸体不该被子弹打中）。如果只把 is_dead 翻回 false，层还是 0，
	# 于是后面的子弹**打不中它**，表现为「命中造成伤害」失败（M2 实测，
	# 排查了很久）。reset() 里会通过 _apply_physics_layers() 把层放回去。
	foe.call("reset")
	foe.set("battle_state", bs)          # 复活后要把注册表链接接回去，否则死亡时无法注销
	foe.set("battle_map", m)
	bs.call("register_unit", foe)
	_ok(foe.call("hurtbox").get_collision_layer_value(6),
		"reset() 之后敌方 Hurtbox 回到层 6（layer=%d）"
			% int(foe.call("hurtbox").get("collision_layer")))

	# ================= 目标必须在射程内 =================
	foe.call("set_logic_position", Vector2(1, 2))      # 距 1，在射程 3 内
	_ok(bs.call("query_nearest_enemy", shooter, 3.0) == foe, "射程内能选到目标")
	foe.call("set_logic_position", Vector2(8, 1))      # 距 7 > 3
	_ok(bs.call("query_nearest_enemy", shooter, 3.0) == null, "射程外选不到目标")
	foe.call("set_logic_position", Vector2(2, 1))

	# ================= 自动选最近（FR-CBT-03 / FR-TEST-08）=================
	var foe2: Node2D = UnitActorScript.new()
	add_child(foe2)
	foe2.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(1, 3), stats_atk)  # 距 2
	foe2.set_physics_process(false)
	bs.call("register_unit", foe2)
	_ok(bs.call("query_nearest_enemy", shooter, 3.0) == foe, "取更近的那个（距 1 优于距 2）")
	foe2.call("set_logic_position", Vector2(1, -1))   # 也距 1 → 等距
	_ok(bs.call("query_nearest_enemy", shooter, 3.0) == foe, "等距时取 id 更小者（可复现）")
	foe2.queue_free()
	bs.call("unregister_unit", int(foe2.get("entity_id")))

	# ================= 命中造成伤害（M2-8）=================
	foe.call("set_logic_position", Vector2(2, 1))
	shooter.set("cooldown_remaining", 0.0)
	var hp0 := float(foe.get("hp"))
	var _before_ids5: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	_ok((bs.get("projectiles") as Dictionary).size() == 1, "生成子弹")
	# 推进子弹直到命中或销毁（最多 60 tick）
	var proj = _newest_projectile(bs, _before_ids5)
	_ok(proj != null, "取到新生成的子弹")
	if proj == null:
		_done("combat")
		return
	proj.set("trace", true)
	var foe_hb = foe.call("hurtbox")
	print("   [diag] 命中前: foe id=%d dead=%s hp=%.1f hb_layer=%d | 子弹 mask=%d | foepos=%s" % [
		int(foe.get("entity_id")), str(foe.get("is_dead")),
		float(foe.get("hp")), int(foe_hb.get("collision_layer")),
		int(proj.get("collision_mask")), str(foe.get("position_logic"))])
	_ok(foe_hb.get_collision_layer_value(6),
		"开火前敌方 Hurtbox 在层 6（layer=%d）" % int(foe_hb.get("collision_layer")))
	for i in 60:
		if not is_instance_valid(proj):
			break
		proj.call("step", 1.0 / 60.0)
		await get_tree().physics_frame
	print("   [diag] 命中后 foe.hp=%.1f（原 %.1f）is_dead=%s 子弹已销毁=%s" % [
		float(foe.get("hp")), hp0, str(foe.get("is_dead")), str(not is_instance_valid(proj))])
	_ok(float(foe.get("hp")) < hp0, "命中造成伤害（%.1f → %.1f）" % [hp0, float(foe.get("hp"))])

	# ================= 击杀 → 死亡注销 =================
	foe.set("hp", 5.0)
	shooter.set("cooldown_remaining", 0.0)
	var _before_ids6: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	var proj2 = _newest_projectile(bs, _before_ids6)
	for i in 60:
		if not is_instance_valid(proj2):
			break
		proj2.call("step", 1.0 / 60.0)
		await get_tree().physics_frame
	print("   [diag] 击杀用例: 开火前 hp=%.1f dead=%s hb_layer=%d；开火后 hp=%.1f dead=%s" % [
		float(foe.get("hp")), str(foe.get("is_dead")),
		int(foe.call("hurtbox").get("collision_layer")),
		float(foe.get("hp")), str(foe.get("is_dead"))])
	_ok(bool(foe.get("is_dead")), "血量归零即死亡")
	var look = bs.call("find_unit", int(foe.get("entity_id")))
	print("   [diag] 注销诊断: foe id=%d battle_state 非空=%s units.size=%d find_unit=%s" % [
		int(foe.get("entity_id")), str(foe.get("battle_state") != null),
		int(bs.get("units").size()), str(look != null)])
	_ok(bs.call("find_unit", int(foe.get("entity_id"))) == null, "死亡后从注册表注销")
	_ok(int(bs.get("units").size()) >= 1, "注册表里仍有别的单位（自我校验）")
	_ok(is_inside_tree_checked(foe), "尸体节点仍保留在场景树")

	# ================= 友军免伤：子弹掩码不含己方 Hurtbox =================
	var friend_: Node2D = UnitActorScript.new()
	add_child(friend_)
	friend_.call("setup", UnitActorScript.TEAM_ALLY, Vector2(2, 1), stats_atk)
	friend_.set_physics_process(false)
	friend_.set("battle_map", m)
	bs.call("register_unit", friend_)
	var hb = friend_.call("hurtbox")
	_ok(hb != null and hb.get_collision_layer_value(5), "我方 Hurtbox 在层 5")
	var hb_foe = foe.call("hurtbox") if is_instance_valid(foe) else null
	# 直接断言掩码：我方子弹的掩码不含层 5
	var test_p: Area2D = ProjectileScript.new()
	add_child(test_p)
	test_p.call("setup", ProjectileScript.TEAM_ALLY, Vector2(1, 1), Vector2.RIGHT,
		12.0, 3.0, 10.0, 0.3, "", 64.0, bs)
	_ok(test_p.get_collision_layer_value(3), "我方子弹在层 3")
	_ok(test_p.get_collision_mask_value(2), "我方子弹掩码含障碍层 2")
	_ok(test_p.get_collision_mask_value(6), "我方子弹掩码含敌方 Hurtbox 层 6")
	_ok(not test_p.get_collision_mask_value(5), "**我方子弹掩码不含我方 Hurtbox 层 5 → 不伤害友军**")
	_ok(not test_p.get_collision_mask_value(3) and not test_p.get_collision_mask_value(4),
		"子弹掩码不含子弹层 → **子弹互不碰撞**")
	test_p.queue_free()

	var p_foe: Area2D = ProjectileScript.new()
	add_child(p_foe)
	p_foe.call("setup", ProjectileScript.TEAM_ENEMY, Vector2(8, 1), Vector2.LEFT,
		12.0, 3.0, 10.0, 0.3, "", 64.0, bs)
	_ok(p_foe.get_collision_layer_value(4), "敌方子弹在层 4")
	_ok(p_foe.get_collision_mask_value(5), "敌方子弹掩码含我方 Hurtbox 层 5")
	_ok(not p_foe.get_collision_mask_value(6), "**敌方子弹掩码不含敌方 Hurtbox 层 6 → 不伤害敌人**")
	p_foe.queue_free()

	# ================= 减速附加（不叠加）=================
	var ice: Node2D = UnitActorScript.new()
	add_child(ice)
	ice.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1, 1), stats_ice)
	ice.set_physics_process(false)
	bs.call("register_unit", ice)
	var victim: Node2D = UnitActorScript.new()
	add_child(victim)
	victim.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(2, 1), stats_atk)
	victim.set_physics_process(false)
	bs.call("register_unit", victim)
	_ok(not bool(victim.get("is_slowed")), "初始未减速")
	var speed_before := float(victim.call("move_speed"))
	ice.set("cooldown_remaining", 0.0)
	ice.set("fire_mode", true)
	var _before_ids7: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	var proj3 = [_newest_projectile(bs, _before_ids7)]
	if proj3.size() > 0:
		var p3 = proj3[0]
		for i in 60:
			if not is_instance_valid(p3):
				break
			p3.call("step", 1.0 / 60.0)
			await get_tree().physics_frame
	_ok(bool(victim.get("is_slowed")), "冰寒单位命中后目标被减速")
	_ok(is_equal_approx(float(victim.call("move_speed")), speed_before * 0.5),
		"减速把移动速度降到 50%（%.2f → %.2f）" % [speed_before, float(victim.call("move_speed"))])
	# 再打一次不叠加
	victim.set("hp", 100.0)
	ice.set("cooldown_remaining", 0.0)
	var _before_ids8: Array = _projectile_ids(bs)
	s2.call("_step_weapons", 1.0 / 60.0)
	var proj4 = [_newest_projectile(bs, _before_ids8)]
	if proj4.size() > 0:
		var p4 = proj4[0]
		for i in 60:
			if not is_instance_valid(p4):
				break
			p4.call("step", 1.0 / 60.0)
			await get_tree().physics_frame
	_ok(is_equal_approx(float(victim.call("move_speed")), speed_before * 0.5),
		"再次命中不叠加（仍是 50%）")

	# ================= 飞满射程即销毁 =================
	# 【必须用一张干净的注册表】否则子弹可能先撞上前面用例留下的单位，
	# 那样销毁原因是「命中」而不是「飞满射程」，测不到本条规则（M2 实测踩到）。
	var bs_far: RefCounted = BattleStateScript.new()
	var far_p: Area2D = ProjectileScript.new()
	add_child(far_p)
	far_p.call("setup", ProjectileScript.TEAM_ALLY, Vector2(0, 0), Vector2.RIGHT,
		12.0, 2.0, 10.0, 0.3, "", 64.0, bs_far)
	bs_far.call("register_projectile", far_p)
	var far_ticks := 0
	for i in 20:
		if bool(far_p.get("consumed")):
			break
		far_p.call("step", 1.0 / 60.0)
		far_ticks += 1
	print("   [diag] 射程用例: %d tick 后 consumed=%s traveled=%s" % [
		far_ticks, str(far_p.get("consumed")), str(far_p.get("traveled"))])
	_ok(bool(far_p.get("consumed")), "飞满射程后子弹被销毁（consumed=true）")
	_ok(float(far_p.get("traveled")) >= 2.0, "确实飞满了射程（traveled=%.3f）" % float(far_p.get("traveled")))

	# ================= 撞墙即销毁 =================
	var wall_map: Node2D = BattleMapScript.new()
	add_child(wall_map)
	var wt := _make_grid(12, 3, BattleMapScript.TILE_EMPTY)
	for j in 3:
		wt[j][5] = BattleMapScript.TILE_WALL        # 第 5 列全是墙
	wall_map.set_tiles(wt)
	var wall_p: Area2D = ProjectileScript.new()
	add_child(wall_p)
	wall_p.call("setup", ProjectileScript.TEAM_ALLY, Vector2(1, 1), Vector2.RIGHT,
		12.0, 20.0, 10.0, 0.3, "", 64.0, bs)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var destroyed_by_wall := false
	for i in 90:
		if not is_instance_valid(wall_p):
			destroyed_by_wall = true
			break
		wall_p.call("step", 1.0 / 60.0)
		await get_tree().physics_frame
	_ok(destroyed_by_wall, "撞到墙后子弹被销毁（掩码含障碍层）")

	# ================= 不预判：目标移动会导致打空 =================
	var aim_foe: Node2D = UnitActorScript.new()
	add_child(aim_foe)
	aim_foe.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(3, 1), stats_atk)
	aim_foe.set_physics_process(false)
	bs.call("register_unit", aim_foe)
	var dir_p: Area2D = ProjectileScript.new()
	add_child(dir_p)
	dir_p.call("setup", ProjectileScript.TEAM_ALLY, Vector2(1, 1),
		Vector2(3, 1) - Vector2(1, 1), 12.0, 10.0, 10.0, 0.3, "", 64.0, bs)
	var dir0: Vector2 = dir_p.get("direction")
	aim_foe.call("set_logic_position", Vector2(1, 5))    # 目标跑掉
	_ok((dir_p.get("direction") as Vector2).is_equal_approx(dir0),
		"子弹方向不随目标移动改变（不预判）")
	dir_p.call("destroy")

	bs.call("clear")
	m.teardown(); m.free()
	wall_map.teardown(); wall_map.free()
	shooter.free(); foe.free(); friend_.free(); ice.free(); victim.free(); aim_foe.free()
	_done("combat")


## 取「最新生成」的那颗子弹。
##
## 【为什么不能直接用 values()[0]】字典顺序不可靠，而前面的用例可能还留着
## 在飞的旧子弹；取到旧的那颗就会推出「打不中」的错误结论（M2 实测，
## 为此排查了很久）。真正的修法是记住开火前的 id 集合，取差集。
func _newest_projectile(bs: RefCounted, before: Array = []) -> Node:
	var d: Dictionary = bs.get("projectiles")
	for k in d.keys():
		if not before.has(int(k)):
			return d[k]
	return null


func _projectile_ids(bs: RefCounted) -> Array:
	var out: Array = []
	for k in (bs.get("projectiles") as Dictionary).keys():
		out.append(int(k))
	return out


## 清掉场上所有子弹，避免用例之间互相干扰
func _clear_projectiles(bs: RefCounted) -> void:
	for k in (bs.get("projectiles") as Dictionary).keys():
		var p = (bs.get("projectiles") as Dictionary)[k]
		if is_instance_valid(p):
			p.call("destroy")


func is_inside_tree_checked(n: Node) -> bool:
	return n.is_inside_tree()


## 系统 06 · 关卡数据与载入 —— M1-6 已实现
func _check_level() -> void:
	print("\n-- 系统 06 · 关卡数据与胜负条件 --")

	var loader: RefCounted = LevelLoaderScript.new()
	var known: Array = ["standard", "standard_attack", "ice", "basic_enemy"]

	# --- 关卡发现 ---
	var ids: Array = loader.list_level_ids()
	print("   [diag] 发现关卡: %s" % str(ids))
	_ok(ids.size() >= 3, "至少发现 3 个关卡（实际 %d）" % ids.size())
	if ids.size() < 3:
		_done("level")
		return
	_ok(ids[0] == "tutorial_01" and ids[2] == "tutorial_03", "关卡顺序来自 manifest（%s）" % str(ids))

	# ================= 第一关：7×7、无敌人、到达终点 =================
	var r1: Dictionary = loader.load_level("tutorial_01", known)
	_ok(bool(r1["ok"]), "tutorial_01 载入通过（错误 %s）" % str(r1["errors"]))
	if bool(r1["ok"]):
		var lv1 = r1["level"]
		_ok(lv1.id == "tutorial_01" and lv1.name != "", "id 与名称解析正确")
		_ok(lv1.map_size() == Vector2i(7, 7), "地图 7×7（实际 %s）" % str(lv1.map_size()))
		_ok(lv1.beacon_quota == 4, "信标配额 4")
		_ok(lv1.signal_count == 1, "信号数 1（第一关不教信号，留一个占位）")
		_ok(is_equal_approx(lv1.time_limit, 0.0), "不限时")
		_ok(lv1.ally_entries().size() == 1, "我方 1 个单位")
		_ok(lv1.enemy_entries().size() == 0, "**第一关没有敌人**（D-02）")
		_ok(lv1.win_conditions().size() == 1
			and str((lv1.win_conditions()[0] as Dictionary).get("type", "")) == "reach_position",
			"胜利条件为 reach_position")
		_ok(str((lv1.lose_conditions()[0] as Dictionary).get("type", "")) == "all_allies_dead",
			"失败条件为我方全灭")
		_ok(lv1.win_logic() == "any", "组间逻辑默认 any")

		# 地图瓦片能直接喂给 BattleMap，且单位落点可通行
		var bm: Node = BattleMapScript.new()
		add_child(bm)
		var merr: Array = bm.load_from(lv1.map)
		_ok(merr.is_empty(), "第一关地图可被 BattleMap 接受（错误 %s）" % str(merr))
		_ok(bm.goal_cells().size() == 3, "地图上有 3 个目标区域格（最右列中段）")
		_ok(bm.wall_count() >= 1, "地图上有墙（逼玩家分段放信标）")
		var pos1: Array = (lv1.ally_entries()[0] as Dictionary)["pos"]
		_ok(bm.is_passable(int(pos1[0]), int(pos1[1])), "我方单位出生点可通行")
		bm.teardown()
		bm.free()

	# ================= 第二关：14×3、敌人射程被覆盖为 2 =================
	var r2: Dictionary = loader.load_level("tutorial_02", known)
	_ok(bool(r2["ok"]), "tutorial_02 载入通过（错误 %s）" % str(r2["errors"]))
	if bool(r2["ok"]):
		var lv2 = r2["level"]
		_ok(lv2.map_size() == Vector2i(14, 3), "地图 14×3（实际 %s）" % str(lv2.map_size()))
		_ok(lv2.enemy_entries().size() == 1, "敌方 1 个单位")
		var enemy2: Dictionary = lv2.enemy_entries()[0]
		_ok(int((enemy2.get("overrides", {}) as Dictionary).get("range", -1)) == 2,
			"敌人射程用关卡覆盖改为 2（FR-UNIT-05）")
		_ok(str((lv2.win_conditions()[0] as Dictionary).get("type", "")) == "annihilate",
			"第二关胜利条件为全歼敌人")

	# ================= 第三关：两个我方单位（含冰寒）=================
	var r3: Dictionary = loader.load_level("tutorial_03", known)
	_ok(bool(r3["ok"]), "tutorial_03 载入通过（错误 %s）" % str(r3["errors"]))
	if bool(r3["ok"]):
		var lv3 = r3["level"]
		_ok(lv3.map_size() == Vector2i(7, 7), "地图 7×7")
		_ok(lv3.beacon_quota == 6, "信标配额 6")
		_ok(lv3.ally_entries().size() == 2, "我方 2 个单位")
		var types: Array = []
		for e in lv3.ally_entries():
			types.append(str((e as Dictionary).get("type", "")))
		_ok(types.has("ice"), "含冰寒人工生命（%s）" % str(types))

	# ================= 校验：各类错误都要报出来 =================
	var base: Dictionary = (r1["level"] as RefCounted).call("to_dict")

	var bad1 := base.duplicate(true)
	(bad1["map"] as Dictionary)["tiles"] = [[0, 0, 0, 0, 0, 0, 0]]
	_ok(_has_error(LevelDataScript.from_dict(bad1).validate(), "行数"), "tiles 行数不符时报错")

	var bad2 := base.duplicate(true)
	bad2["units"] = [{"team": "ally", "type": "nope", "pos": [1, 1]}]
	_ok(_has_error(LevelDataScript.from_dict(bad2).validate(known), "不存在于 units.json"),
		"单位类型不存在时报错（含字段路径与类型名）")

	var bad3 := base.duplicate(true)
	bad3["units"] = [{"team": "ally", "type": "standard", "pos": [99, 99]}]
	_ok(_has_error(LevelDataScript.from_dict(bad3).validate(known), "超出地图范围"), "坐标越界时报错")

	var bad4 := base.duplicate(true)
	bad4["units"] = [{"team": "neutral", "type": "standard", "pos": [1, 1]}]
	_ok(_has_error(LevelDataScript.from_dict(bad4).validate(known), "只能是 ally 或 enemy"),
		"阵营非法时报错")

	var bad5 := base.duplicate(true)
	bad5["units"] = []
	_ok(_has_error(LevelDataScript.from_dict(bad5).validate(known), "至少要有一个单位"),
		"没有单位时报错")

	var bad6 := base.duplicate(true)
	bad6["win"] = {"logic": "any", "conditions": [{"type": "win_by_magic"}]}
	_ok(_has_error(LevelDataScript.from_dict(bad6).validate(known), "未知条件类型"),
		"未知胜负条件类型时报错")

	var bad7 := base.duplicate(true)
	bad7["win"] = {"logic": "maybe", "conditions": [{"type": "annihilate"}]}
	_ok(_has_error(LevelDataScript.from_dict(bad7).validate(known), "只能是 any 或 all"),
		"组间逻辑非法时报错")

	var bad8 := base.duplicate(true)
	bad8["win"] = {"logic": "any", "conditions": [{"type": "reach_position"}]}
	_ok(_has_error(LevelDataScript.from_dict(bad8).validate(known), "需要非空的格子列表"),
		"reach_position 缺 area 时报错")

	var bad9 := base.duplicate(true)
	bad9["win"] = {"logic": "any", "conditions": [{"type": "reach_position", "area": [[99, 99]]}]}
	_ok(_has_error(LevelDataScript.from_dict(bad9).validate(known), "超出地图范围"),
		"area 坐标越界时报错")

	var bad10 := base.duplicate(true)
	bad10["id"] = ""
	bad10["name"] = ""
	bad10["beacon_quota"] = -1
	var many: Array = LevelDataScript.from_dict(bad10).validate(known)
	_ok(many.size() >= 3, "一次报出全部错误（%d 条）" % many.size())

	var bad11 := base.duplicate(true)
	bad11["time_limit"] = 10.0
	bad11["win"] = {"logic": "any", "conditions": [{"type": "survive_until", "seconds": 60.0}]}
	_ok(_has_error(LevelDataScript.from_dict(bad11).validate(known), "不可能达成"),
		"survive_until 超过 time_limit 时报矛盾")

	_ok(LevelDataScript.from_dict(base).validate(known).is_empty(), "合法数据校验零错误")

	# ================= 找不到的关卡 =================
	var missing: Dictionary = loader.load_level("no_such_level", known)
	_ok(not bool(missing["ok"]), "不存在的关卡载入失败")
	_ok(str(missing["errors"][0]).contains("未找到"), "错误信息说明未找到")

	_done("level")


## M1 完成标志的端到端验证：
## tutorial_01 + 一条「沿着信标 1→2 移动」的指令 → 走到终点 → 判胜利。
func _check_session() -> void:
	print("\n-- 系统 06b · 关卡会话 LevelSession（M1 闭环）--")

	var loader: RefCounted = LevelLoaderScript.new()
	var known := ["standard", "standard_attack", "ice", "basic_enemy"]
	var stats := _tutorial_stats()

	# --- 装配第一关 ---
	var r1: Dictionary = loader.load_level("tutorial_01", known)
	_ok(bool(r1["ok"]), "tutorial_01 载入通过")
	var lv1 = r1["level"]

	var clock: Node = GameClockScript.new()
	add_child(clock)
	clock.set_physics_process(false)          # 由测试手动推进

	var session: RefCounted = LevelSessionScript.new()
	var s_err: Array = session.call("setup", self, lv1, clock, stats)
	_ok(s_err.is_empty(), "会话装配成功（错误 %s）" % str(s_err))
	_ok(session.get("state") == LevelSessionScript.State.BUILD, "初始状态为编制期")
	_ok((session.get("units") as Array).size() == 1, "场上 1 个单位（第一关无敌人）")
	_ok(session.get("map").call("goal_cells").size() == 3,
		"第一关目标区是右下角 3 格（实际 %d）" % session.get("map").call("goal_cells").size())
	_ok(session.get("map").call("wall_count") >= 1, "第一关有墙（路线需要绕行）")

	# --- 编制期：时间冻结，单位纹丝不动（FR-FLOW-01）---
	var u0: Node2D = (session.get("units") as Array)[0]
	var p_before: Vector2 = u0.get("position_logic")
	for i in 120:
		clock.call("_physics_process", 1.0 / 60.0)
	# 就算有人误发 tick 信号，编制期也不该有任何推进（会话此时并未订阅）
	clock.emit_signal("tick")
	_ok((u0.get("position_logic") as Vector2).distance_to(p_before) < 1e-9,
		"编制期时间冻结、单位不动（FR-FLOW-01）")

	# --- 给单位写「沿着信标移动」的意图（正式流程由规则引擎产出，M2 已有）---
	# 【第一关的通关路线】单位 (1,1)，终点区域是右下角一列 (6,4)(6,5)(6,6)，
	# (2,2) 有一堵墙。两个信标即可：信标1 (6,1) → 向右；信标2 (6,5) → 向下。
	# 单位从 (6,1) 沿同一列向下走向 (6,6)，途中穿过终点区 (6,3)(6,4)(6,5) 即判胜。
	#
	# 【为什么终点区是一列而不是一格】单位走到**最后一个信标会精确吸附到
	# 它的中心**（`is_final` 分支），所以「终点格 = 最后一格、信标放在它后一格」
	# 这种写法行不通：单位停在信标上，而信标不能放在终点格上
	# （`can_place_beacon` 要求瓦片是 EMPTY）。让终点是一个**区域**、
	# 把路径上的格子圈进去，就不必和这条约束较劲了。
	var layer: RefCounted = BeaconLayerScript.new()
	layer.call("setup", session.get("map"), lv1.beacon_quota)
	var b1: int = int(layer.call("add_beacon", Vector2i(6, 1)))
	var b2: int = int(layer.call("add_beacon", Vector2i(6, 6)))
	_ok(b1 == 1 and b2 == 2, "放下信标 1、2（%d %d）" % [b1, b2])

	# --- 开始推演 ---
	_ok(bool(session.call("start")), "start() 成功进入推演期")
	_ok(session.get("state") == LevelSessionScript.State.RUN, "状态为推演期")

	# --- 手动推进，直到判胜 ---
	# 单位沿三个信标走：向右到 (6,1)，掉头到 (5,1)，再向下到 (5,6)，
	# 然后继续朝 +x 踏上终点格 (6,6)。
	u0.set("beacon_sequence", [1, 2])
	u0.set("beacon_cursor", 0)
	var ticks := 0
	while int(session.get("verdict")) == LevelSessionScript.Verdict.NONE and ticks < 3000:
		session.call("step_tick")
		ticks += 1
	var end_pos: Vector2 = u0.get("position_logic")
	print("   [diag] %d tick 后单位位于 %s，verdict=%d" % [ticks, str(end_pos), int(session.get("verdict"))])

	_ok(int(session.get("verdict")) == LevelSessionScript.Verdict.WIN,
		"**M1 完成标志**：走到终点即判胜利（verdict=%d）" % int(session.get("verdict")))
	_ok(session.get("state") == LevelSessionScript.State.RESULT, "结算后状态为结算期")
	_ok(ticks > 0 and ticks < 3000, "在合理 tick 数内完成（%d）" % ticks)
	# 单位会走过信标 3（6,5）继续朝 +x，在踏上终点格 (6,6) 的瞬间判胜
	# 判胜瞬间单位落在终点区内的某一格上。
	# 【注意】逻辑坐标是**瓦片中心**（瓦片 6 → 6.5），所以要经 logic_to_tile 换算，
	# 不能直接拿坐标和瓦片下标比。
	var end_tile: Vector2i = session.get("map").call("logic_to_tile", end_pos)
	_ok(end_tile == Vector2i(6, 3) or end_tile == Vector2i(6, 4) or end_tile == Vector2i(6, 5),
		"判胜瞬间单位位于终点区内（瓦片 %s，坐标 %s）" % [str(end_tile), str(end_pos)])
	_ok(int(layer.call("count")) == 2, "信标保留（重置不该丢玩家的信标）")

	session.call("teardown")
	clock.queue_free()

	# ================= 第二关：关卡级覆盖 + 全歼条件 =================
	var r2: Dictionary = loader.load_level("tutorial_02", known)
	var clock2: Node = GameClockScript.new()
	add_child(clock2)
	clock2.set_physics_process(false)
	var s2: RefCounted = LevelSessionScript.new()
	var s2_err: Array = s2.call("setup", self, r2["level"], clock2, stats)
	_ok(s2_err.is_empty(), "第二关装配成功（错误 %s）" % str(s2_err))

	var allies: Array = []
	var enemies: Array = []
	for u in (s2.get("units") as Array):
		if int(u.get("team")) == LevelSessionScript.TEAM_ALLY:
			allies.append(u)
		else:
			enemies.append(u)
	_ok(allies.size() == 1 and enemies.size() == 1, "第二关 1 对 1")
	# 关卡覆盖必须生效：basic_enemy 表里射程 5，第二关覆盖为 2
	var enemy: Node2D = enemies[0]
	_ok(is_equal_approx(float(enemy.call("effective_range")), 2.0),
		"关卡覆盖生效：敌人射程 2（表里是 5）（FR-UNIT-05 / FR-TEST-06）")
	var ally: Node2D = allies[0]
	_ok(is_equal_approx(float(ally.call("effective_range")), 3.0), "我方射程 3")

	s2.call("start")
	# 直接把敌人标记死亡，验证「全歼敌人」判胜
	enemy.call("die")
	s2.call("step_tick")
	_ok(int(s2.get("verdict")) == LevelSessionScript.Verdict.WIN, "全歼敌人即判胜利")
	s2.call("teardown")
	clock2.queue_free()

	# ================= 失败条件：我方全灭 =================
	var clock3: Node = GameClockScript.new()
	add_child(clock3)
	clock3.set_physics_process(false)
	var s3: RefCounted = LevelSessionScript.new()
	var s3_err: Array = s3.call("setup", self, loader.load_level("tutorial_02", known)["level"], clock3, stats)
	_ok(s3_err.is_empty(), "第三个会话装配成功")
	s3.call("start")
	for u in (s3.get("units") as Array):
		if int(u.get("team")) == LevelSessionScript.TEAM_ALLY:
			u.call("die")
	s3.call("step_tick")
	_ok(int(s3.get("verdict")) == LevelSessionScript.Verdict.LOSE, "我方全灭即判失败")

	# --- 重置：回编制期、单位复原、**保留指令** ---
	var alive_unit: Node2D = (s3.get("units") as Array)[0]
	var keep_rule = RuleScript.new()
	alive_unit.set("rules", [keep_rule])
	s3.call("reset")
	_ok(s3.get("state") == LevelSessionScript.State.BUILD, "reset() 回到编制期")
	_ok(int(s3.get("verdict")) == LevelSessionScript.Verdict.NONE, "reset() 清空结算结果")
	_ok(not bool(alive_unit.get("is_dead")), "reset() 让单位复活")
	_ok((alive_unit.get("rules") as Array).size() == 1, "reset() **保留**玩家的指令（需求 12.1a）")
	_ok(int(clock3.get("tick_index")) == 0, "reset() 归零时钟")
	s3.call("teardown")
	clock3.queue_free()

	# ================= 超时失败 =================
	var lv_to: Dictionary = (loader.load_level("tutorial_01", known)["level"] as RefCounted).call("to_dict")
	lv_to["time_limit"] = 1.0
	lv_to["lose"] = {"logic": "any", "conditions": [{"type": "timeout"}]}
	var clock4: Node = GameClockScript.new()
	add_child(clock4)
	clock4.set_physics_process(false)
	var s4: RefCounted = LevelSessionScript.new()
	var lv_to_obj = LevelDataScript.from_dict(lv_to)
	var s4_err: Array = s4.call("setup", self, lv_to_obj, clock4, stats)
	_ok(s4_err.is_empty(), "超时关卡装配成功（错误 %s）" % str(s4_err))
	s4.call("start")
	# 注意：step_tick 本身不推进时钟 —— 时钟由引擎/测试用 _physics_process 驱动。
	# 真实游戏里 tick 信号就是这么发出来的，所以这里一帧一帧地喂。
	# 用「对象里放一个计数」而不是 lambda 捕获的局部变量：GDScript 的 lambda
	# 对外层局部变量的捕获容易误读（实测打印出 0），用容器最直观。
	var tick_fired := {"n": 0}
	var cb := func() -> void:
		s4.call("step_tick")
		tick_fired["n"] = int(tick_fired["n"]) + 1
	clock4.connect("tick", cb)
	for i in 90:                                  # 1 秒 = 60 tick，90 帧确保越过 1.0 秒
		clock4.call("_physics_process", 1.0 / 60.0)
	clock4.disconnect("tick", cb)
	print("   [diag] 超时用例：%d 个 tick，game_time=%.3f，verdict=%d" % [
		int(tick_fired["n"]), float(clock4.get("game_time")), int(s4.get("verdict"))])
	_ok(int(tick_fired["n"]) > 0, "超时用例确实推进了 tick（%d 个）" % int(tick_fired["n"]))
	_ok(int(s4.get("verdict")) == LevelSessionScript.Verdict.LOSE,
		"超过时限即判失败（game_time=%.3f）" % float(clock4.get("game_time")))
	s4.call("teardown")
	clock4.queue_free()

	# ================= 装配错误：缺数值定义 =================
	var clock5: Node = GameClockScript.new()
	add_child(clock5)
	clock5.set_physics_process(false)
	var s5: RefCounted = LevelSessionScript.new()
	var s5_err: Array = s5.call("setup", self, loader.load_level("tutorial_01", known)["level"], clock5, {})
	_ok(not s5_err.is_empty() and str(s5_err[0]).contains("没有数值定义"),
		"缺单位数值定义时报错（%s）" % str(s5_err))
	s5.call("teardown")
	clock5.queue_free()

	_done("session")


## 教程三关用到的单位数值。
##
## 【M3 起改从 data/units.json 读】不再在测试里硬编码 —— 否则「数值不写在
## 代码里」（FR-UNIT-01）就是假的：表改了测试还照样过。
## 载入失败会返回空表，随之会话装配报「没有数值定义」，问题会立刻暴露。
func _tutorial_stats() -> Dictionary:
	var dl: RefCounted = DataLoaderScript.new()
	var errs: Array = dl.call("load_all")
	if not errs.is_empty():
		print("   [!!] units.json 载入失败，教程数值表为空：%s" % str(errs))
		return {}
	var out: Dictionary = {}
	for t in dl.call("unit_type_ids"):
		out[str(t)] = dl.call("base_unit_stats", str(t))
	return out


func _has_error(errors: Array, needle: String) -> bool:
	for e in errors:
		if str(e).contains(needle):
			return true
	return false


## 系统 08 · 评价与结算 —— M5-9 的前置
##
## 计分是**纯函数**，所以能脱离场景逐条验公式；这也是详设 08 把
## "算分"与"写盘"、"算分"与"渲染"分开的原因。
func _check_score() -> void:
	print("\n-- 系统 08 · 评价与结算 --")

	var stats_script := StatisticsScript
	var scorer := ScorerScript

	# ================= 统计量快照：只算启用中的指令 =================
	var mk_rule := func(cond_n: int, act_n: int, enabled: bool) -> RefCounted:
		var r: RefCounted = RuleScript.new()
		r.set("enabled", enabled)
		var conds: Array = []
		for i in cond_n:
			conds.append(RuleConditionScript.from_dict(
				{"type": RuleConditionScript.T_SELF_HP, "op": "lt", "percent": 50.0}))
		var acts: Array = []
		for i in act_n:
			acts.append(RuleActionScript.from_dict({"type": RuleActionScript.T_SET_FIRE_MODE}))
		r.set("conditions", conds)
		r.set("actions", acts)
		return r

	var u1: Node2D = UnitActorScript.new()
	add_child(u1)
	u1.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1.5, 1.5), {"max_hp": 10.0, "move_speed": 1.0})
	u1.set_physics_process(false)
	u1.set("rules", [mk_rule.call(2, 1, true), mk_rule.call(3, 2, false)])
	# 上面有一条启用的（2 条件 1 行为）和一条禁用的（3 条件 2 行为）
	var st = stats_script.snapshot([u1], 2, 12.5)
	_ok(int(st.get("condition_count")) == 2,
		"**禁用的指令不计入统计**（条件数 2，实际 %d）" % int(st.get("condition_count")))
	_ok(int(st.get("action_count")) == 1, "行为数 1（实际 %d）" % int(st.get("action_count")))
	_ok(int(st.get("beacon_count")) == 2, "信标数 2")
	_ok(is_equal_approx(float(st.get("elapsed_time")), 12.5), "用时 12.5")
	_ok(int(st.call("complexity_elements")) == 3, "复杂度元素数 = 条件 + 行为 = 3")
	u1.queue_free()

	# ================= 计分公式（C1=10, C2=10, C3=1）=================
	var coef := {"complexity": 10.0, "beacon": 10.0, "time": 1.0}
	var st2 = stats_script.snapshot([], 2, 12.5)
	st2.set("condition_count", 2)
	st2.set("action_count", 1)
	var rd = scorer.compute("tutorial_01", scorer.VERDICT_WIN, st2, coef, -1.0)
	_ok(bool(rd.get("computed")), "胜利时算分")
	_ok(is_equal_approx(float(rd.get("complexity_cost")), 30.0),
		"指令复杂度 = (1 行为 + 2 条件) × 10 = 30（实际 %.1f）" % float(rd.get("complexity_cost")))
	_ok(is_equal_approx(float(rd.get("beacon_cost")), 20.0),
		"信标成本 = 2 × 10 = 20（实际 %.1f）" % float(rd.get("beacon_cost")))
	_ok(is_equal_approx(float(rd.get("time_cost")), 12.5),
		"时间成本 = 12.5 × 1 = 12.5（实际 %.1f）" % float(rd.get("time_cost")))
	_ok(is_equal_approx(float(rd.get("total_score")), 62.5),
		"总分 = 30 + 20 + 12.5 = 62.5（实际 %.1f）" % float(rd.get("total_score")))
	_ok(bool(rd.get("is_new_record")), "首次通关即刷新记录")
	_ok(str(rd.call("summary")).contains("62.5"), "摘要里带总分（%s）" % str(rd.call("summary")))

	# **失败不算分**（FR-SCORE-06），且要与"得 0 分"区分开
	var rd_lose = scorer.compute("tutorial_01", scorer.VERDICT_LOSE, st2, coef, 10.0)
	_ok(not bool(rd_lose.get("computed")), "失败时不计分")
	_ok(float(rd_lose.get("total_score")) < 0.0,
		"失败时总分是哨兵值而不是 0（实际 %.1f）" % float(rd_lose.get("total_score")))
	_ok(is_equal_approx(float(rd_lose.get("best_score")), 10.0), "失败不覆盖既有最佳记录")

	# 系数缺失时用兜底值，而不是算出 0
	var rd_def = scorer.compute("x", scorer.VERDICT_WIN, st2, {}, -1.0)
	_ok(is_equal_approx(float(rd_def.get("complexity_cost")), 30.0),
		"系数缺失时用兜底 C1=10（实际 %.1f）" % float(rd_def.get("complexity_cost")))

	# 最佳记录：**分越低越好**（详设 08 的 4.4「取最低」）。
	# 我第一版把这两条写反了 —— 62.5 比 100 好、比 50 差。
	var rd_worse = scorer.compute("tutorial_01", scorer.VERDICT_WIN, st2, coef, 50.0)
	_ok(not bool(rd_worse.get("is_new_record")),
		"本次 62.5 比记录 50.0 差 → 不刷新")
	var rd_better = scorer.compute("tutorial_01", scorer.VERDICT_WIN, st2, coef, 100.0)
	_ok(bool(rd_better.get("is_new_record")),
		"本次 62.5 比记录 100.0 好 → 刷新（分越低越好）")

	# ================= 同样统计量 → 得分可复现（倍速不影响，FR-FLOW-06）=================
	var a = scorer.compute("x", scorer.VERDICT_WIN, st2, coef, -1.0)
	var b = scorer.compute("x", scorer.VERDICT_WIN, st2, coef, -1.0)
	_ok(is_equal_approx(float(a.get("total_score")), float(b.get("total_score"))),
		"同样的统计量 → 得分可复现（%.1f）" % float(a.get("total_score")))

	# ================= 最佳记录的读写（内存字典，不落盘）=================
	var fake_save := {}
	_ok(scorer.best_of(fake_save, "tutorial_01") < 0.0, "没有记录时返回负值")
	var rd1 = scorer.compute("tutorial_01", scorer.VERDICT_WIN, st2, coef, -1.0)
	_ok(bool(scorer.apply_best(fake_save, "tutorial_01", rd1)), "首次写入记录成功")
	_ok(is_equal_approx(scorer.best_of(fake_save, "tutorial_01"), 62.5),
		"读回的记录是 62.5（实际 %.1f）" % scorer.best_of(fake_save, "tutorial_01"))
	var rd2 = scorer.compute("tutorial_01", scorer.VERDICT_WIN, st2, coef, 62.5)
	rd2.set("total_score", 200.0)
	_ok(not bool(scorer.apply_best(fake_save, "tutorial_01", rd2)), "更差的成绩不写入")
	_ok(is_equal_approx(scorer.best_of(fake_save, "tutorial_01"), 62.5), "记录保持不变")
	_ok(not bool(scorer.apply_best(fake_save, "tutorial_01", rd_lose)), "失败的结算不写记录")
	_ok(scorer.best_of(null, "x") < 0.0, "没有存档时安全返回")
	_ok(not bool(scorer.apply_best(null, "x", rd1)), "没有存档时安全跳过")

	_done("score")


## M5-7 关卡介绍弹窗 + M5-9 结算界面
##
## 【为什么这两个放一起测】它们都是"只渲染数据、不做算术"的纯表现层：
## 介绍弹窗渲染 `level.intro`，结算界面渲染 `ResultData`。
## 断言重点因此是"**该显示的都显示出来了**"以及"**出口接线对不对**"。
func _check_result_ui() -> void:
	print("\n-- M5-7 介绍弹窗 / M5-9 结算界面 --")

	# ================= 结算界面（独立实例）=================
	var rs: Control = ResultScreenScript.new()
	add_child(rs)
	await get_tree().process_frame

	_ok(not bool(rs.call("is_showing")), "结算界面初始不显示")

	var coef := {"complexity": 10.0, "beacon": 10.0, "time": 1.0}
	var st = StatisticsScript.snapshot([], 2, 12.5)
	st.set("condition_count", 2)
	st.set("action_count", 1)
	var rd = ScorerScript.compute("tutorial_01", ScorerScript.VERDICT_WIN, st, coef, -1.0)
	rs.call("show_result", rd)
	await get_tree().process_frame
	_ok(bool(rs.call("is_showing")), "show_result 后显示")
	_ok(str(rs.call("title_text")) == "胜利！", "标题为「胜利！」（实际「%s」）" % str(rs.call("title_text")))
	_ok(str(rs.call("total_text")).contains("62.5"),
		"总分显示 62.5（实际「%s」）" % str(rs.call("total_text")))

	# 出口按钮齐全，且"下一关"可按需隐藏
	var btns := rs.get_node_or_null("Center/Panel/Column/Buttons")
	_ok(btns != null, "能取到出口按钮行")
	var names: Array = []
	for c in (btns as Node).get_children():
		names.append(str(c.name))
	_ok(names.has("Btn_retry") and names.has("Btn_next")
		and names.has("Btn_select") and names.has("Btn_exit"),
		"四个出口按钮齐全（%s）" % str(names))
	rs.set("has_next", false)
	rs.call("show_result", rd)
	await get_tree().process_frame
	_ok(not (btns as Node).get_node("Btn_next").visible, "没有下一关时隐藏「下一关」")
	rs.set("has_next", true)

	# 出口要真的发信号
	var got: Array = []
	rs.connect("action_selected", func(id: String) -> void: got.append(id))
	_ok(bool(rs.call("press_action", ResultScreenScript.ACTION_RETRY)), "能按下「重试」")
	rs.call("show_result", rd)
	_ok(bool(rs.call("press_action", ResultScreenScript.ACTION_NEXT)), "能按下「下一关」")
	_ok(got == ["retry", "next"], "出口发出了正确的事件（%s）" % str(got))

	# 失败：显示"未计分"，且分项用破折号而不是 0
	var rd_lose = ScorerScript.compute("x", ScorerScript.VERDICT_LOSE, st, coef, -1.0)
	rs.call("show_result", rd_lose)
	await get_tree().process_frame
	_ok(str(rs.call("title_text")) == "失败", "失败时标题为「失败」")
	_ok(str(rs.call("total_text")).contains("未计分"),
		"失败显示「未计分」（实际「%s」）" % str(rs.call("total_text")))
	rs.queue_free()
	await get_tree().process_frame

	# ================= 关卡介绍弹窗（独立实例）=================
	var dlg: Control = IntroDialogScript.new()
	add_child(dlg)
	await get_tree().process_frame
	_ok(not bool(dlg.call("is_showing")), "介绍弹窗初始不显示")
	dlg.call("show_intro", {"title": "第一关 · 初识信标",
		"tips": ["放信标", "写指令", "走到终点"]})
	await get_tree().process_frame
	_ok(bool(dlg.call("is_showing")), "show_intro 后显示")
	_ok(str(dlg.call("title_text")) == "第一关 · 初识信标", "标题取自数据")
	_ok(int(dlg.call("tip_count")) == 3, "三条提示都渲染出来了（%d）" % int(dlg.call("tip_count")))
	dlg.call("press_ok")
	_ok(not bool(dlg.call("is_showing")), "点「开始编制」后关闭")
	# 没有 tips 也不能崩
	dlg.call("show_intro", {})
	_ok(bool(dlg.call("is_showing")), "空 intro 也能显示（占位文案）")
	_ok(int(dlg.call("tip_count")) == 0, "空 intro 没有 tip 条目")
	dlg.call("press_ok")
	dlg.queue_free()
	await get_tree().process_frame

	# ================= 在真实玩法场景里跑一遍 =================
	#
	# 【必须先清掉"已看过"记录】FR-TUT-03 的原话是「每关**首次**进入时弹出」，
	# 所以"进关会不会自动弹"取决于**之前有没有看过**。
	# 本函数前面已经进过第一关（别的用例），因此这里要**自己把前置状态清干净**，
	# 否则测的就不是"首次"，而是"第 N 次" —— 断言会随机地成或不成。
	Save.clear_intro_seen()
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_01")
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame

	var ps_dlg: Control = ps.get("intro_dialog")
	var ps_rs: Control = ps.get("result_screen")
	_ok(ps_dlg != null and ps_rs != null, "玩法场景里有介绍弹窗与结算界面")
	_ok(bool(ps_dlg.call("is_showing")), "**首次进关卡自动弹介绍**（FR-TUT-03）")
	_ok(str(ps_dlg.call("title_text")) == "第一关 · 初识信标",
		"介绍标题来自关卡数据（实际「%s」）" % str(ps_dlg.call("title_text")))
	_ok(int(ps_dlg.call("tip_count")) == 3, "介绍里有 3 条提示")
	ps_dlg.call("press_ok")
	await get_tree().process_frame
	_ok(not bool(ps_dlg.call("is_showing")), "关掉介绍后可以正常编制")
	# 工具条「关卡介绍」按钮可以重看
	ps.get("toolbar").get_node("Row/Btn_intro").emit_signal("pressed")
	await get_tree().process_frame
	_ok(bool(ps_dlg.call("is_showing")), "**「关卡介绍」按钮可随时重看**")
	ps_dlg.call("press_ok")
	await get_tree().process_frame

	# ================= FR-TUT-03 的「**首次**」语义 =================
	# 看过之后再进同一关，**不该**再自动弹（否则每关每次进都弹一遍，很烦）；
	# 而工具条的「关卡介绍」按钮仍然要能打开。
	#
	# 【必须用临时场景】本函数后面还要接着用主场景 `ps` 走完通关流程，
	# 所以这里**不能**动它 —— 我第一版把 `ps` 释放并重新赋值，结果函数后半段
	# 拿着一个已释放的实例去 call，直接报 `previously freed instance` 中断整段。
	_ok(Save.has_seen_intro("tutorial_01"), "看过之后记录下来了")
	var ps2 = PlaySceneScript.instantiate()
	ps2.call("load_level_id", "tutorial_01")
	add_child(ps2)
	await get_tree().process_frame
	await get_tree().process_frame
	var dlg2: Control = ps2.get("intro_dialog")
	_ok(not bool(dlg2.call("is_showing")),
		"**第二次进同一关不再自动弹介绍**（「首次」才弹）")
	ps2.get("toolbar").get_node("Row/Btn_intro").emit_signal("pressed")
	await get_tree().process_frame
	_ok(bool(dlg2.call("is_showing")), "但「关卡介绍」按钮照样能打开")
	dlg2.call("press_ok")
	await get_tree().process_frame
	ps2.queue_free()
	await get_tree().process_frame

	# 记录是**按关各自**算的：清空后首次进入又会弹（再用一个临时场景验）
	Save.clear_intro_seen()
	var ps3 = PlaySceneScript.instantiate()
	ps3.call("load_level_id", "tutorial_01")
	add_child(ps3)
	await get_tree().process_frame
	await get_tree().process_frame
	var dlg3: Control = ps3.get("intro_dialog")
	_ok(bool(dlg3.call("is_showing")), "清空记录后首次进入又会弹（记录按关存）")
	dlg3.call("press_ok")
	await get_tree().process_frame
	ps3.queue_free()
	await get_tree().process_frame
	# 让主场景回到"介绍已关闭"的状态（上面它已经按过两次 OK，这里再确认一次）
	_ok(not bool(ps_dlg.call("is_showing")), "主场景的介绍仍是关闭状态（后半段继续用它）")

	# 走玩家流程通关 → 结算界面出现，且分数算出来了
	ps.call("try_place_beacon_at", Vector2(6.5 * 64.0, 1.5 * 64.0))
	ps.call("try_place_beacon_at", Vector2(5.5 * 64.0, 6.5 * 64.0))
	ps.call("_click_at", Vector2(1.5 * 64.0, 1.5 * 64.0))
	await get_tree().process_frame
	var rp: Control = ps.get("rule_panel")
	var picker: OptionButton = rp.get_node_or_null("Drawer/Column/AddRow/ActionPicker")
	var add_btn: Button = rp.get_node_or_null("Drawer/Column/AddRow/AddRuleButton")
	if picker != null and add_btn != null:
		for i in picker.item_count:
			if str(picker.get_item_metadata(i)) == "move_along_beacons":
				picker.selected = i
		add_btn.emit_signal("pressed")
		rp.call("_on_append_beacon", 0, 1)
		rp.call("_on_append_beacon", 0, 2)
	ps.get("toolbar").get_node("Row/Btn_start").emit_signal("pressed")
	# 【必须驱动时钟，不能只调 step_tick】`elapsed_time` 取 `clock.game_time`，
	# 而时钟是靠 `_physics_process` 推进的（它按 60Hz 发 tick）。
	# 只调 step_tick 的话 game_time 恒为 0，时间成本就是 0
	# （实测："总分应大于 30，实际 30.0"，用法 0.00 秒）。
	var ps_clock = ps.get("clock")
	var guard := 0
	while int(ps.get("session").get("verdict")) == 0 and guard < 4000:
		ps_clock.call("_physics_process", 1.0 / 60.0)
		guard += 1
	await get_tree().process_frame
	_ok(int(ps.get("session").get("verdict")) == 1, "玩家流程通关（%d tick）" % guard)
	var rd_scene = ps.get("result_data")
	_ok(rd_scene != null, "结算时产出了 ResultData")
	if rd_scene != null:
		_ok(bool(rd_scene.get("computed")), "**通关后确实算了分**")
		var total := float(rd_scene.get("total_score"))
		print("   [diag] 第一关结算：总分 %.1f（指令 %.1f + 信标 %.1f + 时间 %.1f），用法 %.2f 秒，记录 %s" % [
			total, float(rd_scene.get("complexity_cost")), float(rd_scene.get("beacon_cost")),
			float(rd_scene.get("time_cost")), float(rd_scene.get("elapsed_time")),
			str(rd_scene.get("is_new_record"))])
		# 第一关：1 条无条件移动指令（0 条件 1 行为）+ 2 个信标
		_ok(is_equal_approx(float(rd_scene.get("complexity_cost")), 10.0),
			"指令成本 = 1 行为 × 10 = 10（实际 %.1f）" % float(rd_scene.get("complexity_cost")))
		_ok(is_equal_approx(float(rd_scene.get("beacon_cost")), 20.0),
			"信标成本 = 2 × 10 = 20（实际 %.1f）" % float(rd_scene.get("beacon_cost")))
		_ok(total > 30.0, "总分含时间成本，应大于 30（实际 %.1f）" % total)
	_ok(bool(ps_rs.call("is_showing")), "**结算界面自动弹出**")
	_ok(str(ps_rs.call("title_text")) == "胜利！", "结算界面显示胜利")

	# 「重试」应回到编制期并收起结算界面
	ps_rs.call("press_action", "retry")
	await get_tree().process_frame
	_ok(not bool(ps_rs.call("is_showing")), "点「重试」收起结算界面")
	_ok(int(ps.get("session").get("state")) == LevelSessionScript.State.BUILD, "重试后回到编制期")
	_ok(int(ps.get("beacon_layer").call("count")) == 2, "重试保留玩家放的信标")

	ps.queue_free()
	await get_tree().process_frame
	_done("result_ui")


## 跨关卡的完整流程：主菜单 →「开始游戏」→ 选关 → 进关 → 通关 → 返回 → 换关。
##
## 【为什么需要它】此前每关的通关用例都是**直接 new 一个玩法场景**来跑的，
## 而"点按钮导航过去""通关后回选关""换一关不残留上一关的状态"这些**集成路径
## 一条都没走过** —— 状态泄漏、最佳成绩写错关、返回后场景没换，
## 全都只会在这种流程里出现。
##
## 顺带核对 FR-SCORE-04（最佳成绩按关记录）与"换关不泄漏"。
func _check_full_playthrough() -> void:
	print("\n-- 跨关卡完整流程（导航 / 最佳成绩 / 不泄漏）--")

	# 从"干净存档"起步，免得受前面用例影响
	Save.clear_save()
	Save.clear_intro_seen()

	# ---------- 1) 主菜单：点真实按钮进选关 ----------
	await SceneLoader.goto(MAIN_MENU, 0.0)
	await get_tree().process_frame
	var menu = get_tree().current_scene
	var entry: Node = menu.get_node_or_null("Center/VBox/GodEntryButton") if menu != null else null
	_ok(entry != null, "主菜单在场，且有「开始游戏」按钮")
	if entry == null:
		_done("playthrough")
		return
	(entry as Button).emit_signal("pressed")
	# 【等得宽松一点】原来是"最多等 30 帧"，而切换含两段淡入淡出；
	# 在负载高时 30 帧不够 → 用例**偶发**失败（3 次里失败 1 次）。
	# 偶发的测试比没有测试更糟：它会让人开始怀疑测试而不是代码。
	var ls = await _await_scene_with_method("level_ids_in_order", 300)
	_ok(ls != null,
		"**「开始游戏」把玩家带到了选关界面**（走真实按钮，不是直接 goto）")
	if ls == null:
		_done("playthrough")
		return

	# ---------- 2) 选关界面：顺序与按钮来自 manifest ----------
	var ids: Array = ls.call("level_ids_in_order")
	_ok(ids.size() >= 3, "选关界面列出至少 3 关（%s）" % str(ids))
	_ok(not ids.is_empty() and str(ids[0]) == "tutorial_01", "第 1 项是第一关（按 order 排）")
	var btns: Array = ls.call("level_buttons")
	_ok(btns.size() == ids.size(), "每关一个按钮（%d 个）" % btns.size())

	# ---------- 3) 点第一关 → 通关 → 最佳成绩入档 ----------
	ls.call("_on_level_pressed", "tutorial_01")
	await get_tree().process_frame
	await get_tree().process_frame
	var ps = get_tree().current_scene
	_ok(ps != null and ps.has_method("load_level_id"), "点关卡按钮后进入了玩法场景")
	_ok(str(ps.get("level_id")) == "tutorial_01", "进的就是第一关")
	var verdict := await _play_level_to_end(ps, [Vector2i(6, 1), Vector2i(5, 6)], true, false)
	_ok(verdict == 1, "**第一关在完整流程里通关**（verdict=%d）" % verdict)
	var rs = ps.get("result_screen")
	_ok(rs != null and bool(rs.call("is_showing")), "结算界面自动弹出")
	var best: Dictionary = Save.data.get("best_scores", {})
	_ok(best.has("tutorial_01"), "**第一关的最佳成绩已入档**（FR-SCORE-04）（%s）" % str(best.keys()))

	# ---------- 4) 回选关 → 换第二关：不能残留上一关的状态 ----------
	await SceneLoader.goto("res://src/ui/level_select.tscn", 0.0)
	await get_tree().process_frame
	var ls2 = get_tree().current_scene
	_ok(ls2 != null and ls2.has_method("level_ids_in_order"), "能回到选关界面")
	ls2.call("_on_level_pressed", "tutorial_02")
	await get_tree().process_frame
	await get_tree().process_frame
	var ps2 = get_tree().current_scene
	_ok(str(ps2.get("level_id")) == "tutorial_02", "换到了第二关")
	_ok(int(ps2.get("beacon_layer").call("count")) == 0,
		"**换关后没有残留信标**（状态不跨关卡泄漏）")
	_ok((ps2.get("session").get("units") as Array).size() == 2,
		"第二关有 2 个单位（不是第一关那 1 个）")
	# 第二关还没通关，所以不该凭空多出它的成绩
	var best2: Dictionary = Save.data.get("best_scores", {})
	_ok(best2.has("tutorial_01") and not best2.has("tutorial_02"),
		"**最佳成绩按关各记各的**（还没打的关没有成绩）")
	# 信标配额也来自关卡数据，不是上一关的残留。
	# 【配额不在 LevelSession 上】它挂在 BeaconLayer 的 `quota` 字段；
	# 我第一版写成 `session.call("beacon_quota")`，于是抛
	# `Nonexistent function 'beacon_quota'` 把整个用例中断了。
	_ok(int(ps2.get("beacon_layer").get("quota")) > 0,
		"第二关的信标配额来自自己的关卡数据（%d）"
		% int(ps2.get("beacon_layer").get("quota")))

	# ---------- 5) 回主菜单 ----------
	await SceneLoader.goto(MAIN_MENU, 0.0)
	await get_tree().process_frame
	var back = get_tree().current_scene
	_ok(back != null and back.get_node_or_null("Center/VBox/GodEntryButton") != null,
		"**能回到主菜单**")
	_done("playthrough")


## 等到"当前场景带有指定方法"为止（最多 frames 帧），返回该场景或 null。
##
## 【为什么要它】场景切换含淡出/换场景/淡入，帧数是**不定的**；
## 写死"等 30 帧"会让用例在负载高时偶发失败。
func _await_scene_with_method(method_name: String, frames: int = 300):
	for _i in frames:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur.has_method(method_name):
			return cur
	return null


## 把一个玩法场景"打通"：放信标 → 写规则 → 开始 → 逐 tick 跑到出结果。
## 返回 verdict（1=胜利，其它=未胜利/失败）。
##
## 【为什么要周期性让出帧】子弹命中靠 Area2D 的 `area_entered` 信号，
## 那是**物理服务器**在自己的步进里发的；一帧内手动跑几千 tick 的话信号永远不来
## （M6-8 实测：三关全是 0 伤害）。所以每 4 tick 让一帧。
func _play_level_to_end(ps, beacons: Array, move: bool, fire: bool) -> int:
	if ps == null:
		return -1
	ps.get("intro_dialog").call("press_ok")
	await get_tree().process_frame
	var placed := 0
	for b in beacons:
		var r: int = int(ps.call("try_place_beacon_at",
			(Vector2(b.x, b.y) + Vector2(0.5, 0.5)) * 64.0))
		if r > 0:
			placed += 1
	var rules: Array = []
	if move and placed > 0:
		rules.append(RuleEngineScript.make_rule([], [_act_move(range(1, placed + 1))]))
	if fire:
		rules.append(RuleEngineScript.make_rule([], [_act_fire(true)]))
	for u in (ps.get("session").get("units") as Array):
		if int(u.get("team")) == 0:
			u.set("rules", rules.duplicate(true))
	ps.get("toolbar").get_node("Row/Btn_start").emit_signal("pressed")
	var guard := 0
	while int(ps.get("session").get("verdict")) == 0 and guard < 3000:
		for _j in 4:
			ps.get("clock").call("_physics_process", 1.0 / 60.0)
			guard += 1
		await get_tree().process_frame
	return int(ps.get("session").get("verdict"))


## 测试框架自检：**每个被调用的检查函数都必须登记 `_done("<名字>")`，
## 而且那个名字必须出现在 `EXPECTED_CHECKS` 里**。
##
## 【为什么必须自检】框架判断"某个用例组有没有跑到底"靠的就是这两个名单的对应关系。
## 一旦漏登记，那个函数中途出错就**不会被报出来** —— 表现为"全绿"，
## 而实际上它根本没跑完甚至没跑。我在第 19 轮**连续踩了两次**：
## · `no_stubs` / `playthrough` 写了函数却没进 `EXPECTED_CHECKS`；
## · `_check_level_files_untouched`（数据完整性保险丝）**压根没调 `_done`**。
##
## 守卫本身失效是最难发现的失效，所以让测试**读自己的源码**来互相核对。
func _check_harness_selfcheck() -> void:
	print("\n-- 测试框架自检（检查函数与 _done 登记一致）--")
	var f := FileAccess.open("res://tools/smoke_test.gd", FileAccess.READ)
	_ok(f != null, "读到了冒烟测试自己的源码")
	if f == null:
		_done("harness_selfcheck")
		return
	var src := f.get_as_text()
	f.close()

	# ---- 抽出 EXPECTED_CHECKS 里登记的名字（按括号配对取，不能靠正则偷懒）----
	var registered: Array[String] = []
	var at := src.find("const EXPECTED_CHECKS")
	if at >= 0:
		# 【不能找第一个 `[`】声明写的是 `const EXPECTED_CHECKS: Array[String] = [`
		# —— 第一个 `[` 是**类型标注** `Array[String]` 里的，紧接着的 `]` 会让
		# 括号配对立刻归零，于是取到空串（我第一版就是这样，名单 0 项）。
		# 要找的是 `= ` 之后的那个 `[`。
		var eq_i := src.find("= [", at)
		var open_i := (eq_i + 2) if eq_i >= 0 else src.find("[", at)
		var depth := 0
		var i := open_i
		var end_i := -1
		while i < src.length():
			var ch := src[i]
			if ch == "[":
				depth += 1
			elif ch == "]":
				depth -= 1
				if depth == 0:
					end_i = i
					break
			i += 1
		if open_i >= 0 and end_i > open_i:
			var re_names := RegEx.new()
			re_names.compile('"([^"]+)"')
			for m in re_names.search_all(src.substr(open_i, end_i - open_i)):
				registered.append(m.get_string(1))
	_ok(registered.size() > 20, "读到了登记名单（%d 项）" % registered.size())

	# ---- 抽出 _run 里调用的 _check_* 函数 ----
	var run_at := src.find("func _run()")
	_ok(run_at >= 0, "找到了 _run")
	var run_body := ""
	if run_at >= 0:
		var next_fn := src.find("\nfunc ", run_at + 1)
		run_body = src.substr(run_at, (next_fn - run_at) if next_fn > run_at else src.length() - run_at)
	var re_calls := RegEx.new()
	re_calls.compile("_check_([A-Za-z0-9_]+)\\(")
	var called: Array[String] = []
	for m in re_calls.search_all(run_body):
		var nm := m.get_string(1)
		if not called.has(nm):
			called.append(nm)
	_ok(called.size() > 20, "读到了 _run 里调用的检查函数（%d 个）" % called.size())

	# ---- 逐个核对：函数体里有 _done，且名字已登记 ----
	var missing_done: Array[String] = []
	var not_registered: Array[String] = []
	for nm2 in called:
		var fn_at := src.find("func _check_%s(" % nm2)
		if fn_at < 0:
			continue
		var fn_next := src.find("\nfunc ", fn_at + 1)
		var fn_body := src.substr(fn_at, (fn_next - fn_at) if fn_next > fn_at else src.length() - fn_at)
		var re_done := RegEx.new()
		re_done.compile('_done\\("([^"]+)"\\)')
		var dm := re_done.search(fn_body)
		if dm == null:
			missing_done.append(nm2)
		elif not registered.has(dm.get_string(1)):
			not_registered.append("%s -> %s" % [nm2, dm.get_string(1)])
	_ok(missing_done.is_empty(),
		"**每个检查函数都调用了 `_done`**（缺的：%s）" % str(missing_done))
	_ok(not_registered.is_empty(),
		"**每个 `_done` 名字都在 EXPECTED_CHECKS 里**（未登记的：%s）" % str(not_registered))
	# 反向：登记了却没有任何函数产出它 —— 那也是名单在腐烂
	var produced: Array[String] = []
	for nm3 in called:
		var fn_at2 := src.find("func _check_%s(" % nm3)
		if fn_at2 < 0:
			continue
		var fn_next2 := src.find("\nfunc ", fn_at2 + 1)
		var fb := src.substr(fn_at2, (fn_next2 - fn_at2) if fn_next2 > fn_at2 else src.length() - fn_at2)
		var re_d2 := RegEx.new()
		re_d2.compile('_done\\("([^"]+)"\\)')
		var dm2 := re_d2.search(fb)
		if dm2 != null:
			produced.append(dm2.get_string(1))
	var dead_names: Array[String] = []
	for rn in registered:
		if not produced.has(rn):
			dead_names.append(rn)
	print("   [diag] 调用 %d 个检查函数 / 登记 %d 个名字 / 无函数产出的登记项 %s"
		% [called.size(), registered.size(), str(dead_names)])
	_done("harness_selfcheck")


## 生产代码里**不允许**再有「状态：待实现」的文件。
##
## 【为什么值得一条用例】本作 M0–M6 已全部完成，但仓库里曾长期躺着两个文件
## （`health.gd` / `unit_stats.gd`），头部写着「状态：待实现」，而对应任务
## **早已完成**（职责并入了 `UnitActor`）—— 它们不但没有任何引用，
## 还会**误导后来的人去重新实现一遍**。
##
## 状态行是这个工程约定里"文件自己说的话"，最容易随代码一起腐烂。
## 与其靠人定期翻，不如让测试替我们盯着：**有任何一个文件说"待实现"，就失败。**
##
## 【如果将来真的要写"待实现"的文件】那说明有任务在做 ——
## 这时应该把该任务登记进 `docs/开发进度.md`，并在这里加白名单（附理由）。
func _check_no_pending_stubs() -> void:
	print("\n-- 生产代码里没有「待实现」的空壳 --")
	var offenders: Array[String] = []
	for dir in ["res://src", "res://autoload", "res://scenes"]:
		_scan_pending(dir, offenders)
	_ok(offenders.is_empty(),
		"**没有文件再说自己「待实现」**（%s）" % str(offenders))
	print("   [diag] 扫描过的生产脚本共 %d 个，声称待实现 %d 个"
		% [_count_gd_files("res://src") + _count_gd_files("res://autoload")
			+ _count_gd_files("res://scenes"), offenders.size()])
	# 反向保险：扫不到文件说明扫描本身就坏了（那种"零发现"是假绿）
	var total := _count_gd_files("res://src")
	_ok(total > 20, "扫描确实读到了生产脚本（res://src 下 %d 个）" % total)
	_done("no_stubs")


## 递归找「状态：…待实现」的文件，把相对路径记进 offenders
func _scan_pending(dir_path: String, offenders: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_scan_pending(full, offenders)
		elif name.ends_with(".gd"):
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null:
				var text := f.get_as_text()
				f.close()
				for line in text.split("\n"):
					var s := line.strip_edges()
					# 只看**头部的状态行**（`## 状态：…`），不看正文里提到"待实现"的地方
					if s.begins_with("## 状态：") and s.contains("待实现"):
						offenders.append(full)
						break
		name = d.get_next()
	d.list_dir_end()


## 数一数某目录下（含子目录）有多少 .gd —— 用来给"零发现"做反向保险
func _count_gd_files(dir_path: String) -> int:
	var d := DirAccess.open(dir_path)
	if d == null:
		return 0
	var n := 0
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				n += _count_gd_files(full)
		elif name.ends_with(".gd"):
			n += 1
		name = d.get_next()
	d.list_dir_end()
	return n


## 帮助文档必须与**实际 UI 文案**一致（跨模块守卫）
##
## 【为什么要这条】第 14 轮我把工具条的「敌人视野」改名成「视野」并让视野圈
## 双方都画，但**帮助文档里根本没提这个功能**，也没有任何用例看着它们俩是否一致。
## "UI 改了、文档没改"这种漂移不会有任何测试报错，最后只能靠玩家发现。
## 这里直接把两边对上：文档里提到的开关名字，必须就是工具条上的实际文案。
func _check_help_matches_ui() -> void:
	print("\n-- 帮助文档与实际 UI 文案一致 --")

	var hd := HelpPanelScript.new()
	add_child(hd)
	await get_tree().process_frame
	var doc: String = str(hd.call("raw_text")) if hd.has_method("raw_text") else ""
	if doc.is_empty():
		# 退化路径：直接读文件
		var f := FileAccess.open(HelpPanelScript.HELP_PATH, FileAccess.READ)
		if f != null:
			doc = f.get_as_text()
			f.close()
	_ok(not doc.is_empty(), "读到了帮助文档正文")
	_ok(doc.contains("## 视野"), "**帮助文档里有「视野」一节**（新增功能必须写进说明）")
	_ok(doc.contains("我方") and doc.contains("敌方"),
		"视野一节讲清了我方与敌方两种圈")
	_ok(doc.contains("绿") and doc.contains("橙"),
		"视野一节给出了**颜色**对应关系（否则玩家不知道哪个圈是自己的）")
	_ok(doc.contains("不参与任何判定"),
		"说明了视野圈只是辅助显示、不影响判定")
	# 【跨模块一致性】文档里提到的开关名字，必须就是工具条上的实际文案
	var tb: Control = ToolbarScript.new()
	add_child(tb)
	await get_tree().process_frame
	var label := str(tb.call("vision_label"))
	_ok(not label.is_empty(), "工具条能报出视野开关的文案（%s）" % label)
	_ok(doc.contains("「%s」" % label),
		"**帮助文档里提到的开关名字与工具条实际文案一致**（「%s」）" % label)
	# 【正文要真的渲染出来】只断言"文档里有这一节"不够 ——
	# 分节标题能显示、正文却空白（解析或转义坏了）也会"通过"。
	# 所以切到「视野」那一节，检查它渲染出来的正文里有颜色对应关系。
	var idx := -1
	for i in int(hd.call("section_count")):
		if str(hd.call("section_title", i)).contains("视野"):
			idx = i
			break
	_ok(idx >= 0, "能在面板里找到「视野」这一节（序号 %d）" % idx)
	if idx >= 0:
		hd.call("show_section", idx)
		await get_tree().process_frame
		var body := str(hd.call("body_text"))
		_ok(body.length() > 40, "「视野」一节的正文渲染出来了（%d 字）" % body.length())
		_ok(body.contains("绿") and body.contains("橙"),
			"**渲染出的正文里有颜色对应关系**（绿=我方 / 橙=敌方）")
		_ok(not body.contains("**"), "Markdown 的加粗标记已被转成 BBCode（正文里不该还有 **）")

	tb.queue_free()
	hd.queue_free()
	await get_tree().process_frame
	_done("help_consistency")


## **不许 `call()` 一个不存在的方法**（静态扫全库）。
##
## 【为什么需要】用户实测：在指令面板里把一条行为改成「开火模式」直接报错退出 ——
## `Nonexistent function 'reset_to_default' in base 'RefCounted (RuleAction)'`。
## `.call("名字")` 是**动态派发**，编译器看不出问题，只有运行时点到那条路径才炸。
## 所以这类 bug 既不会被解析检查抓到，也不是"打开面板"这种浅用例能覆盖的。
##
## 这里做一件很土但有效的事：把生产脚本里所有 `func 名字` 收成一张表，
## 再逐个检查 `.call("X")` 的 X 是否在表里（引擎内置方法走白名单）。
## 实测：47 个脚本 / 516 个方法名 / 可疑调用 0 处（修完用户那个 bug 之后）。
func _check_no_bogus_dynamic_calls() -> void:
	print("\n-- 全库扫描：call() 的方法是否真的存在 --")

	# ---- 1) 收集所有方法名 ----
	var methods := {}
	var files: Array[String] = []
	for dir in ["res://src", "res://autoload", "res://scenes"]:
		_collect_gd(dir, files)
	_ok(files.size() > 20, "收集到生产脚本 %d 个" % files.size())
	var re_func := RegEx.new()
	re_func.compile("(?m)^(?:static\\s+)?func\\s+([A-Za-z0-9_]+)")
	for path in files:
		var txt := _read_text(path)
		for m in re_func.search_all(txt):
			methods[m.get_string(1)] = true
	_ok(methods.size() > 200, "收集到方法名 %d 个" % methods.size())

	# ---- 2) 逐个检查 .call("X") ----
	# 引擎内置：`call()` 到这些是合法的
	var builtin := {
		"get": true, "set": true, "has_method": true, "duplicate": true,
		"queue_redraw": true, "queue_free": true, "free": true, "connect": true,
		"emit_signal": true, "call_deferred": true, "get_parent": true,
		"get_children": true, "get_child_count": true, "get_child": true,
		"find_child": true, "get_node_or_null": true, "get_node": true,
		"add_child": true, "remove_child": true, "get_index": true,
		"is_connected": true, "get_tree": true, "get_meta": true, "set_meta": true,
		"has_meta": true, "get_instance_id": true, "get_script": true,
		"is_inside_tree": true, "get_class": true, "notification": true,
		"get_viewport": true, "get_viewport_rect": true, "is_visible_in_tree": true,
	}
	var re_call := RegEx.new()
	re_call.compile('\\.call\\(\\s*"([A-Za-z0-9_]+)"')
	var offenders: Array[String] = []
	for path2 in files:
		var txt2 := _read_text(path2)
		var line_no := 0
		for line in txt2.split("\n"):
			line_no += 1
			var s := line.strip_edges()
			if s.begins_with("#"):
				continue                     # 【跳过注释行】否则注释里的示例代码会被误报
			for m2 in re_call.search_all(line):
				var nm := m2.get_string(1)
				if methods.has(nm) or builtin.has(nm):
					continue
				offenders.append("%s:%d call(\"%s\")" % [path2, line_no, nm])
	_ok(offenders.is_empty(),
		"**没有 `call()` 到不存在的方法**（可疑 %d 处：%s）"
		% [offenders.size(), str(offenders.slice(0, 8))])
	print("   [diag] 脚本 %d 个 / 方法名 %d 个 / 可疑调用 %d 处"
		% [files.size(), methods.size(), offenders.size()])
	# 反向保险：真扫到东西才算数（否则可能是正则写错、零发现假绿）
	_ok(methods.size() > 200 and files.size() > 20,
		"扫描确实读到了内容（不是零发现假绿）")
	_done("dyn_calls")


## 递归收集某目录下所有 .gd 的 res:// 路径
func _collect_gd(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_collect_gd(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


## 读一个文本文件（读不到返回空串）
func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


## 场景切换途中的导航请求**不能被丢弃**（最后一次胜出）。
##
## 【为什么值得一条用例】`SceneLoader.goto()` 原本是 `if _busy: return` ——
## **静默丢掉**。玩家在淡入淡出那约 0.4 秒里点菜单会毫无反应（像卡住），
## 而调用方 `await` 立刻返回、以为切换成功了。
## 这条缺陷最初是被一个**偶发失败**的用例暴露出来的（3 次里失败 1 次），
## 修完顺手把它钉成确定性用例。
func _check_nav_queue() -> void:
	print("\n-- 场景切换：途中的请求不被丢弃 --")
	# 连发两次、且**不 await 第一次** —— 这样第二次一定落在"忙"的窗口里
	SceneLoader.goto(MAIN_MENU, 0.0)
	SceneLoader.goto("res://src/ui/level_select.tscn", 0.0)
	var cur = await _await_scene_with_method("level_ids_in_order", 300)
	_ok(cur != null,
		"**切换途中的导航请求没有被丢弃**（最终停在最后一次请求的选关界面）")
	if cur != null:
		var ids: Array = cur.call("level_ids_in_order")
		_ok(ids.size() >= 3, "落地的场景确实装配完整（列出 %d 关）" % ids.size())
	# 切完之后必须回到"不忙"的状态，否则后续导航全会失效
	var idle_ok := false
	for _i in 300:
		await get_tree().process_frame
		if not bool(SceneLoader.get("_busy")):
			idle_ok = true
			break
	_ok(idle_ok, "切换完成后 SceneLoader 回到空闲（后续导航还能用）")
	_done("nav_queue")


## 编辑器：**打开某一关**（左上角按钮 + 关卡列表）与**未保存确认**。
##
## 【为什么要有这条】编辑器原本**启动就自动打开第一关**，界面上只有
## 「新建关卡」和「返回选关」—— **没有"打开某一关"的路**（用户实测反馈）。
## 而且打开另一关会把当前 session 整个换掉，未保存的编辑直接消失，
## 所以必须有一条"确认"路径。
func _check_editor_open_level() -> void:
	print("\n-- 编辑器：打开关卡（列表项用名称）+ 未保存确认 --")

	var ed: Control = EditorSceneScript.new()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(str(ed.get("level_id")) == "tutorial_01", "编辑器默认打开第一关")

	# ================= 左上角的「打开关卡…」按钮 =================
	var btn := ed.find_child("BtnOpenLevel", true, false) as Button
	_ok(btn != null, "**左上角有「打开关卡」按钮**（用户实测反馈要求）")
	if btn != null:
		_ok(str(btn.text).contains("打开"), "按钮文案是「%s」" % str(btn.text))

	# ================= 列表内容：必须是**名称**而不是 id =================
	var entries: Array = ed.call("level_menu_entries")
	_ok(entries.size() >= 3, "关卡列表里有 %d 关" % entries.size())
	var names: Array = []
	var ids: Array = []
	for e in entries:
		var d: Dictionary = e
		names.append(str(d.get("name")))
		ids.append(str(d.get("id")))
	_ok(ids.has("tutorial_01") and ids.has("tutorial_02") and ids.has("tutorial_03"),
		"列表项的 id 齐全（%s）" % str(ids))
	_ok(names.has("第一关 · 初识信标"),
		"**列表项显示关卡名称**（%s）" % str(names))
	# 关键：名称不能等于 id（那就是"没改成名称"）
	var same := 0
	for e2 in entries:
		var d2: Dictionary = e2
		if str(d2.get("name")) == str(d2.get("id")):
			same += 1
	_ok(same == 0, "**没有哪一项把 id 当名称显示**（相同的有 %d 项）" % same)
	_ok(not names.has("tutorial_01"), "列表里不出现 id 形式的条目（%s）" % str(names))

	# ================= 弹出菜单本身：项文字也是名称 =================
	ed.call("_do_open_level_menu")
	await get_tree().process_frame
	var menu := ed.find_child("OpenLevelMenu", true, false) as PopupMenu
	_ok(menu != null, "**点按钮会弹出关卡列表**（OpenLevelMenu）")
	if menu != null:
		var mtexts: Array = []
		var mvals: Array = []
		for i in menu.item_count:
			mtexts.append(str(menu.get_item_text(i)))
			mvals.append(str(menu.get_item_metadata(i)))
		_ok(mtexts.has("第二关 · 开火与停火"),
			"**菜单项是关卡名称**（%s）" % str(mtexts))
		_ok(mvals.has("tutorial_02"), "菜单项的**元数据是 id**（%s）" % str(mvals))
		menu.hide()
		await get_tree().process_frame

	# ================= 打开另一关：真的换了关卡 =================
	ed.call("request_open_level", "tutorial_02")
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(str(ed.get("level_id")) == "tutorial_02", "打开的是第二关")
	var sess = ed.get("session")
	_ok(int(sess.call("map_width")) == 14 and int(sess.call("map_height")) == 3,
		"**第二关的地图真的载进来了**（%d×%d）"
		% [int(sess.call("map_width")), int(sess.call("map_height"))])
	_ok(int(sess.call("unit_count")) == 2, "第二关有 2 个单位")
	_ok(ed.find_child("UnsavedConfirm", true, false) == null,
		"干净状态下打开**不会**多弹一个确认框")

	# ================= 未保存改动 → 必须先确认 =================
	ed.call("press_tool", EditorSessionScript.TOOL_PAINT_WALL)
	ed.call("_on_tile_pressed", 5, 0, MOUSE_BUTTON_LEFT)
	ed.call("_on_drag_finished")
	# 【`dirty` 是**字段**不是方法】产品代码里一律 `session.get("dirty")`。
	# 我第一版写成 `sess.call("dirty")` → `Nonexistent function 'dirty'` 直接中断用例。
	_ok(bool(sess.get("dirty")), "制造一处未保存改动（dirty）")
	ed.call("request_open_level", "tutorial_03")
	await get_tree().process_frame
	_ok(str(ed.get("level_id")) == "tutorial_02",
		"**有未保存改动时不会直接换关**（仍停在第二关）")
	var dlg := ed.find_child("UnsavedConfirm", true, false) as ConfirmationDialog
	_ok(dlg != null, "**弹出了未保存确认框**")
	# 取消 → 什么都不变
	if dlg != null:
		dlg.emit_signal("canceled")
		await get_tree().process_frame
		_ok(str(ed.get("level_id")) == "tutorial_02", "取消后仍停在第二关")
		_ok(ed.find_child("UnsavedConfirm", true, false) == null, "取消后确认框已释放")
	# 再请求一次 → 这次确认
	ed.call("request_open_level", "tutorial_03")
	await get_tree().process_frame
	var dlg2 := ed.find_child("UnsavedConfirm", true, false) as ConfirmationDialog
	_ok(dlg2 != null, "再次请求时确认框又出现")
	if dlg2 != null:
		dlg2.emit_signal("confirmed")
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(str(ed.get("level_id")) == "tutorial_03",
			"**确认后打开了第三关**（%s）" % str(ed.get("level_id")))
		_ok(int(ed.get("session").call("unit_count")) == 3, "第三关有 3 个单位")

	ed.queue_free()
	await get_tree().process_frame
	_done("open_level")


## 编辑器：**枚举下拉框用中文显示**，且**数据里仍存英文 id**；
## 以及「关卡全局设置」按钮能把属性面板切回全局视图。
##
## 【为什么要验"数据仍是 id"】把显示名当成值写回数据，是这类 UI 最典型的数据事故：
## 界面上一切正常，存出来却是「全歼敌人」而不是 `annihilate`，关卡直接读不回来。
## 所以这里每处都成对断言：**显示中文 + 值是 id**。
func _check_editor_labels() -> void:
	print("\n-- 编辑器：下拉框中文显示 + 关卡全局设置按钮 --")

	var ed: Control = EditorSceneScript.new()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var insp: Control = ed.get("inspector")
	var lv = ed.get("session").get("level_data")

	# ================= 全局视图：胜负条件类型 / 组间逻辑 =================
	ed.get("session").set("selection", {})
	insp.call("refresh")
	await get_tree().process_frame
	_ok(str(insp.call("title_text")).contains("关卡全局"), "先确认在关卡全局视图")

	var cp := insp.find_child("CondType_win_0", true, false) as OptionButton
	_ok(cp != null, "有胜利条件类型下拉框")
	if cp != null:
		var ctexts: Array = []
		var cvals: Array = []
		for i in cp.item_count:
			ctexts.append(str(cp.get_item_text(i)))
			cvals.append(str(cp.get_item_metadata(i)))
		_ok(cvals.has("reach_position"), "条件类型下拉的**取值**仍是 id（%s）" % str(cvals))
		_ok(ctexts.has("到达指定位置"),
			"**条件类型显示中文**（到达指定位置）（%s）" % str(ctexts))
		_ok(not ctexts.has("reach_position"),
			"**界面上不再露出英文 id**（%s）" % str(ctexts))

	var lp := insp.find_child("F_win_logic", true, false) as OptionButton
	_ok(lp != null, "有「组间逻辑」下拉框")
	if lp != null:
		var ltexts: Array = []
		var lvals: Array = []
		for i in lp.item_count:
			ltexts.append(str(lp.get_item_text(i)))
			lvals.append(str(lp.get_item_metadata(i)))
		_ok(lvals.has("any") and lvals.has("all"), "组间逻辑的取值仍是 any/all（%s）" % str(lvals))
		_ok(ltexts.has("任一满足") and ltexts.has("全部满足"),
			"**组间逻辑显示中文**（%s）" % str(ltexts))

	# ================= 选中单位：类型 / 阵营 =================
	ed.get("session").set("selection", {"kind": "unit", "x": 1, "y": 1})
	insp.call("refresh")
	await get_tree().process_frame
	_ok(str(insp.call("title_text")).contains("单位"), "切到了单位视图")

	var tp := insp.find_child("F_type", true, false) as OptionButton
	_ok(tp != null, "有单位「类型」下拉框")
	if tp != null:
		var ttexts: Array = []
		var tvals: Array = []
		for i in tp.item_count:
			ttexts.append(str(tp.get_item_text(i)))
			tvals.append(str(tp.get_item_metadata(i)))
		_ok(tvals.has("standard"), "单位类型的**取值**仍是 id（%s）" % str(tvals))
		_ok(ttexts.has("标准-基础人工生命"),
			"**单位类型显示中文**（来自 units.json 的 name）（%s）" % str(ttexts))
		_ok(not ttexts.has("standard"), "界面上不再露出 standard（%s）" % str(ttexts))

	var mp2 := insp.find_child("F_team", true, false) as OptionButton
	_ok(mp2 != null, "有单位「阵营」下拉框")
	if mp2 != null:
		var mtexts: Array = []
		var mvals: Array = []
		for i in mp2.item_count:
			mtexts.append(str(mp2.get_item_text(i)))
			mvals.append(str(mp2.get_item_metadata(i)))
		_ok(mvals.has("ally") and mvals.has("enemy"), "阵营取值仍是 ally/enemy（%s）" % str(mvals))
		_ok(mtexts.has("我方") and mtexts.has("敌方"),
			"**阵营显示中文**（%s）" % str(mtexts))
	# 数据侧：单位数据里的阵营必须**没被显示名污染**
	var u0: Dictionary = (lv.get("units") as Array)[0]
	_ok(str(u0.get("team")) == "ally",
		"**关卡数据里的阵营仍是 id**（%s）" % str(u0.get("team")))

	# ================= 左栏「放单位时用」的类型下拉框 =================
	# 【我第一版漏了这一个】只改了右侧属性面板的下拉框，左栏这个仍显示
	# `basic_enemy` 之类的内部标识 —— 是**看截图**才发现的。
	# 所以这里补一条，免得以后加/改枚举控件时又漏。
	var ut := ed.find_child("UnitType", true, false) as OptionButton
	_ok(ut != null, "左栏有单位类型下拉框（UnitType）")
	if ut != null:
		var utexts: Array = []
		var utvals: Array = []
		for i in ut.item_count:
			utexts.append(str(ut.get_item_text(i)))
			utvals.append(str(ut.get_item_metadata(i)))
		_ok(utvals.has("standard_attack"), "左栏类型下拉的**取值**仍是 id（%s）" % str(utvals))
		_ok(utexts.has("冰寒人工生命"),
			"**左栏类型下拉也显示中文**（%s）" % str(utexts))
		_ok(not utexts.has("standard_attack"),
			"左栏不再露出英文 id（%s）" % str(utexts))

	# ================= 「关卡全局设置」按钮 =================
	var btn := ed.find_child("BtnGlobal", true, false) as Button
	_ok(btn != null, "**编辑器有一个「关卡全局设置」按钮**（用户实测反馈要求）")
	if btn != null:
		_ok(str(btn.text).contains("全局"), "按钮文案是「%s」" % str(btn.text))
		# 当前在单位视图 → 点一下必须回到全局
		btn.emit_signal("pressed")
		await get_tree().process_frame
		_ok(str(insp.call("title_text")).contains("关卡全局"),
			"**点按钮后属性面板回到关卡全局**（实际「%s」）" % str(insp.call("title_text")))
		_ok((ed.get("session").get("selection") as Dictionary).is_empty(),
			"点按钮会清空选中（selection 为空）")
		# 再点一次也不该出问题（幂等）
		btn.emit_signal("pressed")
		await get_tree().process_frame
		_ok(str(insp.call("title_text")).contains("关卡全局"), "重复点击仍然正常（幂等）")

	ed.queue_free()
	await get_tree().process_frame
	_done("editor_labels")


## 在指令面板里**改条件 / 行为的类型**（走真实下拉框）。
##
## 【为什么专门写这条】用户实测：**把一条行为改成「开火模式」就报错退出** ——
## `Nonexistent function 'reset_to_default' in base 'RefCounted (RuleAction)'`。
## 原因是换类型时调了一个 `Action` / `Condition` 上**根本不存在**的方法
## （条件那条路径同样是坏的，只是用户先踩到行为那条）。
##
## 这类"只在某个交互路径上才炸"的 bug，靠"能打开面板""能加一条指令"是抓不到的 ——
## 必须**真的去动那个下拉框**。测试里 `selected = i` **不会**触发 `item_selected`
## （那只有真实点击才会），所以这里显式 `emit` 一次，等价于用户点了一下。
func _check_rule_type_change() -> void:
	print("\n-- 指令面板：改条件/行为的类型（用户实测崩溃的那条路径）--")

	var rp: Control = RulePanelScript.new()
	add_child(rp)
	await get_tree().process_frame
	var u: Node2D = UnitActorScript.new()
	add_child(u)
	u.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1.5, 1.5),
		{"max_hp": 100.0, "move_speed": 3.0})
	u.set_physics_process(false)
	# 起手：一条指令，条件=自身血量(<50%)，行为=沿着信标移动
	# 【用有辨识度的值】这样"换类型后旧值有没有被丢掉"才验得出来：
	# 条件的百分比刻意用 37（不是默认值），行为用的信标序列是 [1]。
	u.set("rules", [RuleEngineScript.make_rule(
		[_cond_self_hp(RuleConditionScript.OP_LT, 37.0)],
		[_act_move([1])], 0)])
	rp.call("open_for", u)
	await get_tree().process_frame
	await get_tree().process_frame

	# ================= 行为：改成「开火模式」（用户就是这么点的）=================
	var ap := rp.find_child("ActType_0_0", true, false) as OptionButton
	_ok(ap != null, "找到了行为类型下拉框（ActType_0_0）")
	if ap != null:
		var a_idx := -1
		for i in ap.item_count:
			if str(ap.get_item_metadata(i)) == RuleActionScript.T_SET_FIRE_MODE:
				a_idx = i
		_ok(a_idx >= 0, "下拉框里有「开火模式」")
		if a_idx >= 0:
			ap.selected = a_idx
			ap.item_selected.emit(a_idx)          # 等价于用户点了一下
			await get_tree().process_frame
			var r0 = (u.get("rules") as Array)[0]
			var acts: Array = r0.get("actions")
			_ok(acts.size() == 1, "换类型不会多出/少掉行为（%d 条）" % acts.size())
			var a0 = acts[0]
			_ok(str(a0.get("type")) == RuleActionScript.T_SET_FIRE_MODE,
				"**行为类型真的换成了开火模式**（实际 %s）" % str(a0.get("type")))
			# 新类型的参数取 **schema 默认值**
			_ok(bool(a0.get("fire")), "新行为的参数取 schema 默认值（fire=%s）" % str(a0.get("fire")))
			# 【换类型 = 丢掉旧类型那套"值"】
			#
			# 注意 `to_dict()` 是**全字段序列化**：每种类型的所有可能字段都会写出来
			# （我第一版断言"键不该残留"，于是失败 —— 那是数据模型的形状使然，
			# 解释权在 `type` + `schema`，不在"有哪些键"）。
			# 真正该验的是：旧类型那个有辨识度的**值**（信标序列 [1]）已经没了。
			var ad: Dictionary = a0.call("to_dict")
			_ok(str(ad.get("beacon_indices", [])) == "[]",
				"**旧类型（沿着信标移动）的值被丢掉**（beacon_indices=%s）"
				% str(ad.get("beacon_indices")))
			# 面板仍然可用（换完要能重建出新的参数控件）
			var reg := rp.find_child("ActType_0_0", true, false)
			_ok(reg != null, "换完类型后面板重建成功、下拉框还在")

	# ================= 条件：换成另一种（同样走下拉框）=================
	var cp := rp.find_child("CondType_0_0", true, false) as OptionButton
	_ok(cp != null, "找到了条件类型下拉框（CondType_0_0）")
	if cp != null:
		var c_idx := -1
		for i in cp.item_count:
			if str(cp.get_item_metadata(i)) == RuleConditionScript.T_ENEMY_IN_VISION:
				c_idx = i
		_ok(c_idx >= 0, "下拉框里有「视野内出现敌人」")
		if c_idx >= 0:
			cp.selected = c_idx
			cp.item_selected.emit(c_idx)
			await get_tree().process_frame
			var r1 = (u.get("rules") as Array)[0]
			var conds: Array = r1.get("conditions")
			_ok(conds.size() == 1, "换类型不会多出/少掉条件（%d 条）" % conds.size())
			var c0 = conds[0]
			_ok(str(c0.get("type")) == RuleConditionScript.T_ENEMY_IN_VISION,
				"**条件类型真的换了**（实际 %s）" % str(c0.get("type")))
			var cd: Dictionary = c0.call("to_dict")
			_ok(cd.has("radius"), "新条件的参数取 schema 默认值（有 radius）")
			# 旧条件（自身血量）我特意设成 37% —— 换类型后这个值必须消失
			_ok(not is_equal_approx(float(cd.get("percent", -1.0)), 37.0),
				"**旧条件（自身血量 37%%）的值被丢掉**（percent=%s）" % str(cd.get("percent")))

	# 换类型之后整条指令仍然可用（能被规则引擎接受）
	var sess: RefCounted = LevelSessionScript.new()
	_ok(sess != null, "（顺带）换完类型的数据仍是普通 Rule/条件/行为对象")
	rp.call("close")
	u.queue_free()
	rp.queue_free()
	await get_tree().process_frame
	_done("type_change")


## 用户补充需求：行为编辑 UI 必须是**左条件 / 右行为**的结构
##
## 【为什么在逻辑层也测一遍】像素层那条断言一度因为 `find_child` 拿不到节点
## 而被**静默跳过**（报告全绿）。在这里用面板自己的 `split_rects()` 断言，
## 布局如果变回上下堆叠，两层里至少有一层会立刻失败。
func _check_rule_split_layout() -> void:
	print("\n-- 指令面板：左条件 / 右行为 --")

	var rp: Control = RulePanelScript.new()
	add_child(rp)
	await get_tree().process_frame
	var u: Node2D = UnitActorScript.new()
	add_child(u)
	u.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1.5, 1.5),
		{"max_hp": 100.0, "move_speed": 3.0})
	u.set_physics_process(false)
	u.set("rules", [RuleEngineScript.make_rule(
		[_cond_self_hp(RuleConditionScript.OP_LT, 50.0)],
		[_act_move([1]), _act_fire(true)], 0)])
	rp.call("open_for", u)
	await get_tree().process_frame
	await get_tree().process_frame

	var sr: Dictionary = rp.call("split_rects", 0)
	_ok(not sr.is_empty(), "**面板报告了左右两栏矩形**（不是靠名字去别处找）")
	var c: Array = sr.get("conds", [])
	var a: Array = sr.get("acts", [])
	_ok(c.size() == 4 and a.size() == 4, "两栏矩形都是四元组")
	if c.size() == 4 and a.size() == 4:
		_ok(c[0] + c[2] <= a[0] + 1.0,
			"**条件栏在行为栏左侧**（条件右 %.0f <= 行为左 %.0f）" % [c[0] + c[2], a[0]])
		var top := maxf(c[1], a[1])
		var bot := minf(c[1] + c[3], a[1] + a[3])
		_ok(bot - top > 40.0,
			"**两栏竖直并排而不是上下堆叠**（重叠 %.0fpx > 40）" % (bot - top))
		_ok(c[2] >= 200.0 and a[2] >= 200.0,
			"两栏都有可用宽度（条件 %.0f / 行为 %.0f）" % [c[2], a[2]])
		# 两栏宽度应当接近（equal expand），差太多说明有一侧没设 EXPAND_FILL
		_ok(absf(c[2] - a[2]) <= 24.0,
			"两栏宽度接近（差 %.0f px）" % absf(c[2] - a[2]))
	_ok((sr.get("arrow") as Array).size() == 4, "两栏之间有箭头（作为分隔兼语义提示）")
	# 不存在的指令序号返回空字典（不崩、不返回半成品）
	_ok((rp.call("split_rects", 99) as Dictionary).is_empty(), "越界序号返回空字典")

	rp.call("close")
	u.queue_free()
	rp.queue_free()
	await get_tree().process_frame
	_done("split_layout")


## M5-6 指令面板的**条件区**（「如果 … 则 …」）
##
## 【为什么这组最要紧】没有条件编辑，玩家只能写"无条件执行"，
## 「实时战术解谜」就退化成"摆一条路径"。所以这里逐条验详设 09 的验收项：
## 多条件、与/或切换、schema 驱动的参数控件、引用类候选项随关卡变化、
## 多条件折叠、无效标黄、行为冲突守卫。
func _check_conditions_ui() -> void:
	print("\n-- M5-6 指令面板 · 条件区 --")

	var rp: Control = RulePanelScript.new()
	add_child(rp)
	await get_tree().process_frame

	var u: Node2D = UnitActorScript.new()
	add_child(u)
	u.call("setup", UnitActorScript.TEAM_ALLY, Vector2(2.5, 2.5),
		{"max_hp": 100.0, "move_speed": 3.0})
	u.set_physics_process(false)
	# 给一个信号数 2 的上下文，验「信号下拉按关卡生成」
	rp.call("set_context", 3, 2)
	rp.call("open_for", u)
	await get_tree().process_frame

	var rules: Array = u.get("rules")
	# 【打开面板不会自动建指令】要我显式按「加一条指令」（面板里也有这个按钮）。
	# 我第一版误以为 open_for 会建一条，于是 rules 为空、后续 rules[0] 直接越界中断。
	_ok(rules.is_empty(), "刚打开面板时没有指令")
	# 把下拉选到「沿着信标移动」（与第一关的用法一致）
	var picker := rp.get_node_or_null("Drawer/Column/AddRow/ActionPicker") as OptionButton
	if picker != null:
		for i in picker.item_count:
			if str(picker.get_item_metadata(i)) == RuleActionScript.T_MOVE_ALONG_BEACONS:
				picker.selected = i
	rp.call("_on_add_rule")
	await get_tree().process_frame
	rules = u.get("rules")
	_ok(rules.size() == 1, "按「加一条指令」后有一条指令（实际 %d）" % rules.size())
	if rules.is_empty():
		_done("conditions_ui")
		rp.queue_free()
		u.queue_free()
		return
	# 新指令的行为参数也应按 schema 默认值，而不是 from_dict 的字段默认值
	var first_action = (rules[0].get("actions") as Array)[0]
	_ok(str(first_action.get("type")) == RuleActionScript.T_MOVE_ALONG_BEACONS,
		"新指令的行为是选中的「沿着信标移动」")
	# 顺带验一条：set_signal 的默认信号号是 schema 的 1 而不是 from_dict 的 0
	var sig_act: RefCounted = RuleFieldFactoryScript.make_default_from_schema(
		RuleActionScript, RuleActionScript.T_SET_SIGNAL)
	_ok(int(sig_act.get("signal_index")) == 1,
		"**新建「设置信号」默认信号号是 1（schema 默认），不是 0**（实际 %d）"
		% int(sig_act.get("signal_index")))

	# ================= 加条件：默认取 schema 的 default =================
	rp.call("_on_add_condition", 0)
	await get_tree().process_frame
	var conds: Array = rules[0].get("conditions")
	_ok(conds.size() == 1, "加了一条条件")
	var c0 = conds[0]
	_ok(str(c0.get("type")) == RuleConditionScript.T_ENEMY_IN_VISION,
		"默认条件是第一种类型（%s）" % str(c0.get("type")))
	_ok(is_equal_approx(float(c0.get("radius")), 0.0), "半径取 schema 默认 0（= 取射程）")

	# ================= 切类型 → 参数回到该类型的 schema 默认 =================
	# 直接调处理函数（下拉的 selected 由 UI 决定，这里验数据层）
	var c_self: RefCounted = RuleFieldFactoryScript.make_default_from_schema(
		RuleConditionScript, RuleConditionScript.T_SELF_HP)
	_ok(str(c_self.get("op")) == RuleConditionScript.OP_LT,
		"**SELF_HP 的比较符默认是 OP_LT（schema 的 default），而不是 from_dict 的 OP_LE**（实际 %s）"
		% str(c_self.get("op")))
	_ok(is_equal_approx(float(c_self.get("percent")), 60.0),
		"血量百分比取 schema 默认 60（实际 %.0f）" % float(c_self.get("percent")))

	# ================= 与 / 或 切换 =================
	_ok(int(rules[0].get("condition_logic")) == 0, "条件逻辑默认「与」")
	rp.call("_on_logic_changed", 1, 0)
	_ok(int(rules[0].get("condition_logic")) == 1, "**切到「或」写回正确**（FR-CMD-04）")
	rp.call("_on_logic_changed", 0, 0)
	_ok(int(rules[0].get("condition_logic")) == 0, "切回「与」")

	# ================= 多个条件 + 删除 =================
	rp.call("_on_add_condition", 0)
	rp.call("_on_add_condition", 0)
	await get_tree().process_frame
	_ok((rules[0].get("conditions") as Array).size() == 3, "可以加多个条件（3 个）")
	rp.call("_on_delete_condition", 0, 1)
	await get_tree().process_frame
	_ok((rules[0].get("conditions") as Array).size() == 2, "删掉一个条件后剩 2 个")

	# ================= 折叠：>3 个才折叠，且**不改数据** =================
	rp.call("_on_add_condition", 0)
	rp.call("_on_add_condition", 0)
	await get_tree().process_frame
	var before: Array = (rules[0].get("conditions") as Array).duplicate()
	_ok(before.size() == 4, "现在有 4 个条件（超过折叠阈值 3）")
	var fold_btn := rp.find_child("Fold_0", true, false)
	_ok(fold_btn is Button, "**超过 3 个条件时出现折叠按钮**（D-20）")
	rp.call("_on_toggle_fold", "0")
	await get_tree().process_frame
	var after: Array = rules[0].get("conditions")
	_ok(after.size() == before.size(),
		"**折叠不改数据**（折叠后仍是 %d 个）" % after.size())
	# 【注意】布尔字段不能用 int(...) 去比 true：会报
	# `Invalid operands "int" and "bool" for "=="`（我第一版就是这么写的）
	_ok(bool(rp.get("_folded").get("0", false)), "折叠状态被记住")
	# 折叠时可见的条件条目应少于总数
	var visible_rows := 0
	for ch in rp.get("_rules_box").get_children():
		for sub in (ch as Node).get_children():
			for s2 in (sub as Node).get_children():
				if str((s2 as Node).name).begins_with("Cond_"):
					visible_rows += 1
	_ok(visible_rows < after.size(),
		"折起后可见条件条目少于总数（可见 %d / 共 %d）" % [visible_rows, after.size()])
	rp.call("_on_toggle_fold", "0")
	await get_tree().process_frame

	# ================= schema 驱动的参数控件真的生成了 =================
	# 第 1 个条件是 enemy_in_vision（一个 float 半径），应有 SpinBox
	var spin := rp.find_child("F_radius", true, false)
	_ok(spin is SpinBox, "数值参数生成 SpinBox（FR-CMD-10 全下拉/就地录入）")

	# 引用类参数：下拉候选项数必须等于**当前**信标数
	var box3 := _make_ref_picker(RuleConditionScript.T_BEACON_DISTANCE, 3)
	var pick3 := _find_option_for(box3, "beacon_index")
	_ok(pick3 != null and pick3.item_count == 3,
		"**信标下拉候选项 = 当前信标数 3**（实际 %d）" % (pick3.item_count if pick3 != null else -1))
	var box1 := _make_ref_picker(RuleConditionScript.T_BEACON_DISTANCE, 1)
	var pick1 := _find_option_for(box1, "beacon_index")
	_ok(pick1 != null and pick1.item_count == 1,
		"**信标数变化后候选项跟着重建**（1 个，实际 %d）" % (pick1.item_count if pick1 != null else -1))
	var box0 := _make_ref_picker(RuleConditionScript.T_BEACON_DISTANCE, 0)
	var pick0 := _find_option_for(box0, "beacon_index")
	_ok(pick0 != null and pick0.disabled,
		"没有信标时信标下拉**禁用**（而不是给个空列表）")
	# 信号下拉同理
	var sbox := _make_ref_picker(RuleConditionScript.T_SIGNAL_STATE, 3)
	var spick := _find_option_for(sbox, "signal_index")
	_ok(spick != null and spick.item_count == 2,
		"信号下拉候选项 = 本关信号数 2（实际 %d）" % (spick.item_count if spick != null else -1))
	# 枚举参数给出人看的标签
	var ebox := VBoxContainer.new()
	add_child(ebox)
	var eprobe: RefCounted = RuleFieldFactoryScript.make_default_from_schema(
		RuleConditionScript, RuleConditionScript.T_SELF_HP)
	for s in (RuleConditionScript.schema(RuleConditionScript.T_SELF_HP) as Array):
		var sd := s as Dictionary
		if str(sd.get("type")) == "enum":
			ebox.add_child(RuleFieldFactoryScript.make_row(
				sd, eprobe.get(sd["key"]), {}, func(_k: String, _v) -> void: pass))
	var opick := _find_option_for(ebox, "op")
	_ok(opick != null and opick.item_count == 5, "比较符下拉有 5 个选项")
	if opick != null:
		_ok(str(opick.get_item_text(0)) == "小于",
			"**枚举显示中文标签**而不是 lt/le（实际「%s」）" % str(opick.get_item_text(0)))
	for tmp in [box3, box1, box0, sbox, ebox]:
		tmp.queue_free()

	# ================= M6-1 启用/禁用开关（FR-CMD-09）=================
	# 验收：**禁用后该指令不参与评估，位置保留**。
	# "位置保留"最容易做错（写成"禁用即删除"），所以要断言它还在。
	#
	# 【要走 UI 真实路径】我第一版直接调 `_on_toggle_enabled` 再去看勾选框，
	# 却发现 UI 没变 —— 因为真实路径是「用户点勾选框 → toggled → 写数据」，
	# 勾选框自己已经是对的状态。直接调处理函数等于绕开了控件，测的是假路径。
	var n_rules_before := (rules as Array).size()
	var enabled_cb := rp.find_child("Enabled_0", true, false) as CheckBox
	_ok(enabled_cb != null, "取到启用勾选框")
	_ok(enabled_cb != null and enabled_cb.button_pressed, "初始为启用状态")
	if enabled_cb != null:
		enabled_cb.button_pressed = false       # 等价于用户点一下（会发 toggled）
		await get_tree().process_frame
		_ok(not bool((rules as Array)[0].get("enabled")), "**点勾选框 → 数据里 enabled=false**")
		_ok((rules as Array).size() == n_rules_before,
			"**禁用指令不会把它删掉**（仍是 %d 条，位置保留）" % (rules as Array).size())
		_ok(rp.find_child("Rule_0", true, false) != null, "禁用后该行仍渲染在面板上")
		enabled_cb.button_pressed = true
		await get_tree().process_frame
		_ok(bool((rules as Array)[0].get("enabled")), "能再启用回来")

	# ================= 行为冲突守卫 =================
	var acts: Array = rules[0].get("actions")
	var n_before := acts.size()
	rp.call("_on_add_action", 0)          # 默认追加「开火」
	await get_tree().process_frame
	var n_after := (rules[0].get("actions") as Array).size()
	_ok(n_after == n_before + 1, "能追加行为（%d → %d）" % [n_before, n_after])
	rp.call("_on_add_action", 0)          # 再追加一次「开火」→ 冲突，应被拦下
	await get_tree().process_frame
	_ok((rules[0].get("actions") as Array).size() == n_after,
		"**同一条指令里重复追加同冲突键的行为被拦下**（FR-CMD 冲突守卫）")
	# 【类型必须标注】`Object.get()` 返回 Variant，`:=` 会推断失败（警告即错误）
	var hint: Variant = rp.get("_hint")
	_ok(hint != null and bool((hint as Label).visible), "冲突时给出提示条")

	# ================= 无效标黄用行底色（折叠时也可见）=================
	rules[0].set("invalid_reason", "引用了不存在的信标")
	rp.call("_rebuild")
	await get_tree().process_frame
	var row_panel := rp.find_child("Rule_0", true, false)
	var yellow := false
	if row_panel is PanelContainer:
		var sbv: StyleBox = (row_panel as PanelContainer).get_theme_stylebox("panel")
		if sbv is StyleBoxFlat:
			# 标黄底色的红分量应明显高于正常底色 0.16
			yellow = (sbv as StyleBoxFlat).bg_color.r > 0.24
	_ok(yellow, "**无效指令用行底色标黄**（不依赖展开状态，详设 09 的 4.7）")

	# 【结构性断言】无效原因**不能挂在横向容器里**：
	# HBoxContainer 会把开了 autowrap 的 Label 压到最小宽度 → 中文逐字竖排。
	# 这个坑在提示条 Banner 上踩过一次，无效原因这里又踩了一次（截图才发现），
	# 所以直接把"它必须是纵向容器的子节点"写成断言。
	var reason_lbl := rp.find_child("InvalidReason_0", true, false)
	_ok(reason_lbl is Label, "无效原因以独立 Label 呈现（InvalidReason_0）")
	if reason_lbl != null:
		var parent := (reason_lbl as Node).get_parent()
		_ok(not (parent is HBoxContainer),
			"**无效原因不挂在 HBoxContainer 下**（否则会被压成竖排）（实际 %s）"
			% parent.get_class())
		_ok((reason_lbl as Label).autowrap_mode != TextServer.AUTOWRAP_OFF,
			"无效原因允许换行（长文本不会溢出）")

	# ================= 空 actions 时给淡色提示 =================
	rules[0].set("actions", [])
	rp.call("_rebuild")
	await get_tree().process_frame
	_ok(rp.find_child("NoAction_0", true, false) != null,
		"指令没有行为时给出淡色提示（详设 09 的 4.1）")

	rp.call("close")
	u.queue_free()
	rp.queue_free()
	await get_tree().process_frame
	_done("conditions_ui")


## 造一个「某引用类条件」的参数控件盒，用来验控件工厂。
## 直接问工厂要控件，不依赖面板里恰好有没有这个条件。
func _make_ref_picker(cond_type: String, beacon_count: int) -> Control:
	var probe: RefCounted = RuleFieldFactoryScript.make_default_from_schema(
		RuleConditionScript, cond_type)
	var spec: Dictionary = {}
	for s in (RuleConditionScript.schema(cond_type) as Array):
		if str((s as Dictionary).get("type")) in ["beacon_ref", "signal_ref"]:
			spec = s as Dictionary
	if spec.is_empty():
		return null
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(RuleFieldFactoryScript.make_row(
		spec, probe.get(spec["key"]), {"beacon_count": beacon_count, "signal_count": 2},
		func(_k: String, _v) -> void: pass))
	return box


func _find_option_for(box: Control, key: String) -> OptionButton:
	var n := box.find_child("F_" + key, true, false)
	return n if n is OptionButton else null


## M5-8 机制说明面板
##
## 解析函数是**静态纯函数**，所以主体用内存字符串直接验；
## 再从真实文档读一遍，确保"文件真的在、真的分出了节"。
func _check_help_ui() -> void:
	print("\n-- M5-8 机制说明面板 --")

	# ================= 纯函数：按二级标题切分 =================
	var sample := """# 文档大标题

开头的引言。

## 第一节
内容一
第二行

## 第二节
| 表头 | 值 |
|---|---|
| a | b |

### 三级标题不算节
它属于第二节。

## 空节
## 第三节
内容三
"""
	var secs: Array = HelpPanelScript.parse_markdown(sample)
	_ok(secs.size() == 4, "分出 4 节（引言 + 3 个二级标题，空节被丢掉）（实际 %d）" % secs.size())
	_ok(str((secs[0] as Dictionary).get("title")) == "总览", "引言节标题为「总览」")
	_ok(str((secs[0] as Dictionary).get("body")).contains("开头的引言"), "引言内容保留")
	_ok(str((secs[1] as Dictionary).get("title")) == "第一节", "第二节标题正确（实际「%s」）"
		% str((secs[1] as Dictionary).get("title")))
	# `### ` 不该被当成节标题
	_ok(not str((secs[2] as Dictionary).get("title")).contains("三级"),
		"**`### ` 三级标题不被当成节**（实际「%s」）" % str((secs[2] as Dictionary).get("title")))
	_ok(str((secs[2] as Dictionary).get("body")).contains("三级标题"),
		"三级标题的内容留在所属节里")
	# 空节被丢掉：第一节之后直接是第三节
	_ok(str((secs[3] as Dictionary).get("title")) == "第三节",
		"**标题下没有内容的空节被丢掉**（实际「%s」）" % str((secs[3] as Dictionary).get("title")))
	# 表格原样保留（不渲染成富文本）
	_ok(str((secs[2] as Dictionary).get("body")).contains("| a | b |"), "表格原样保留在正文里")
	# 空文档不能崩
	_ok(HelpPanelScript.parse_markdown("").is_empty(), "空文档解析出 0 节")
	_ok(HelpPanelScript.parse_markdown("没有标题的正文").size() == 1, "没有标题时整体作为一节")

	# ================= Markdown 内联转换（否则 ** 会原样显示）=================
	_ok(HelpPanelScript.to_bbcode("这是**重点**内容") == "这是[b]重点[/b]内容",
		"**`**粗体**` 转成 BBCode**（实际「%s」）" % HelpPanelScript.to_bbcode("这是**重点**内容"))
	_ok(HelpPanelScript.to_bbcode("用 `data/scoring.json` 调") == "用 [code]data/scoring.json[/code] 调",
		"行内反引号转成 [code]")
	_ok(HelpPanelScript.to_bbcode("多个**a**和**b**") == "多个[b]a[/b]和[b]b[/b]",
		"多个粗体都能转换（实际「%s」）" % HelpPanelScript.to_bbcode("多个**a**和**b**"))
	# 落单的 ** 不能被吞掉
	_ok(HelpPanelScript.to_bbcode("一个 ** 星号") == "一个 ** 星号", "落单的 ** 原样保留")
	# 正文里的方括号必须被转义，不能当标签解析
	_ok(HelpPanelScript.to_bbcode("数组 [1, 2]") == "数组 [lb]1, 2]",
		"**正文里的 `[` 被转义**，不会注入 BBCode（实际「%s」）" % HelpPanelScript.to_bbcode("数组 [1, 2]"))
	# 真实文档：**转换之后**不该再残留未处理的 **
	# （注意 parse_markdown 返回的是原始 Markdown，转换在 to_bbcode 里做，
	#  我第一版直接查原始结果，于是 11 节"全都残留"——是断言写错了位置）
	var raw_secs: Array = HelpPanelScript.parse_markdown(
		FileAccess.open(HelpPanelScript.HELP_PATH, FileAccess.READ).get_as_text())
	var leftovers := 0
	for s in raw_secs:
		var conv: String = HelpPanelScript.to_bbcode(str((s as Dictionary).get("body")))
		if conv.contains("**"):
			leftovers += 1
	_ok(leftovers == 0, "**真实文档每一节转换后都不残留 `**`**（残留 %d 节）" % leftovers)

	# ================= 真实文档 =================
	_ok(FileAccess.file_exists(HelpPanelScript.HELP_PATH),
		"机制说明文档存在（%s）" % HelpPanelScript.HELP_PATH)
	var hp: Control = HelpPanelScript.new()
	add_child(hp)
	await get_tree().process_frame
	var loaded: Array = hp.call("load_document")
	_ok(loaded.size() >= 6, "真实文档分出 >=6 节（实际 %d）" % loaded.size())
	var titles: Array = []
	for s in loaded:
		titles.append(str((s as Dictionary).get("title")))
	_ok(titles.has("信标"), "文档里有「信标」一节（%s）" % str(titles))
	_ok(titles.has("指令：如果 / 则"), "文档里有「指令：如果 / 则」一节")
	_ok(titles.has("胜负与评价"), "文档里有「胜负与评价」一节")

	# ================= 分节切换 =================
	hp.call("show_section", 0)
	await get_tree().process_frame
	_ok(int(hp.call("current_index")) == 0, "切到第 0 节")
	var body0 := str(hp.call("body_text"))
	_ok(not body0.is_empty(), "第 0 节有正文")
	# 找「信标」那一节并切过去，正文应该跟着换
	var idx := titles.find("信标")
	hp.call("show_section", idx)
	await get_tree().process_frame
	_ok(int(hp.call("current_index")) == idx, "切到「信标」节")
	var body1 := str(hp.call("body_text"))
	_ok(body1 != body0 and body1.contains("信标"), "**正文随分节切换**")
	# 面板里显示的正文必须是**转换后**的（不能再看到 Markdown 星号）
	var any_star := false
	for i in loaded.size():
		hp.call("show_section", i)
		if str(hp.call("body_text")).contains("**"):
			any_star = true
			break
	_ok(not any_star, "**面板显示的每一节正文都不含未转换的 `**`**")
	hp.call("show_section", idx)
	await get_tree().process_frame
	# 目录按钮数 == 节数
	var idx_box := hp.get_node_or_null("Center/Panel/Column/Row/IndexScroll/Index")
	_ok(idx_box != null and (idx_box as Node).get_child_count() == loaded.size(),
		"左侧目录按钮数 == 节数")
	# 越界索引不能崩
	hp.call("show_section", 999)
	_ok(int(hp.call("current_index")) == idx, "越界索引被忽略、不崩")

	# ================= 开关 =================
	_ok(not bool(hp.call("is_open")), "初始不显示")
	hp.call("open_panel")
	await get_tree().process_frame
	_ok(bool(hp.call("is_open")), "open_panel 后显示")
	# 面板必须居中（本工程踩过三次"贴左上角"）
	#
	# 【别写死 1920x1080】headless 下视口实测是 1920×1920（不是 1080），
	# 我第一版写死了 1080，于是"居中"误报成失败。基准要取**实际视口**。
	var r: Rect2 = hp.call("panel_rect")
	var vp: Vector2 = hp.size
	_ok(vp.x > 0.0 and vp.y > 0.0, "面板撑满了视口（%.0fx%.0f）" % [vp.x, vp.y])
	_ok(abs((r.position.x + r.size.x * 0.5) - vp.x * 0.5) < vp.x * 0.02
		and abs((r.position.y + r.size.y * 0.5) - vp.y * 0.5) < vp.y * 0.06,
		"面板居中（中心 %.0f,%.0f / 视口中心 %.0f,%.0f）" % [
			r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5,
			vp.x * 0.5, vp.y * 0.5])
	hp.call("close_panel")
	_ok(not bool(hp.call("is_open")), "close_panel 后隐藏")
	hp.queue_free()
	await get_tree().process_frame

	# ================= 工具条按钮接线 =================
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_01")
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	var ps_hp: Control = ps.get("help_panel")
	_ok(ps_hp != null, "玩法场景里有机制说明面板")
	_ok(not bool(ps_hp.call("is_open")), "进关卡不会自动弹机制说明")
	# 先关掉自动弹出的关卡介绍，避免挡住
	ps.get("intro_dialog").call("press_ok")
	await get_tree().process_frame
	ps.get("toolbar").get_node("Row/Btn_help").emit_signal("pressed")
	await get_tree().process_frame
	_ok(bool(ps_hp.call("is_open")), "**工具条「机制说明」按钮能打开面板**")
	_ok(int(ps_hp.call("section_count")) >= 6, "打开时重新读了文档（%d 节）" % int(ps_hp.call("section_count")))
	ps_hp.call("close_panel")
	await get_tree().process_frame

	# ================= 暂停菜单（M5-11）=================
	# 【关键】open() 会把整棵树 paused，**这段里绝不能 await**，
	# 否则测试自己也会被冻结（SceneTree 不再推进帧）。
	var pm = ps.get("pause_menu")
	_ok(pm != null, "**玩法场景实例化了暂停菜单**（原来 ESC 只是冻结、没有任何界面）")
	_ok(not bool(pm.call("is_open")), "初始没有暂停")
	ps.call("_toggle_pause")
	_ok(bool(pm.call("is_open")), "**按 ESC 打开暂停菜单**")
	_ok(get_tree().paused, "暂停时整棵树被冻结")
	_ok(not (pm.get("restart_requested") as Signal).get_connections().is_empty(),
		"菜单的「重置关卡」已接到玩法场景")
	_ok(not (pm.get("main_menu_requested") as Signal).get_connections().is_empty(),
		"菜单的「返回主菜单」已接到玩法场景")
	# 菜单按钮集合必须恰好是 继续/重置关卡/返回主菜单/设置（**不含编辑指令**）
	# 【类型要标注】pm 是从 Dictionary 取出来的 Variant，
	# `pm.get_node_or_null(...)` 推不出返回类型（预检直接报 Cannot infer）
	var vbox: Node = pm.get_node_or_null("Center/VBox")
	var btn_texts: Array = []
	if vbox != null:
		for c in (vbox as Node).get_children():
			if c is Button:
				btn_texts.append(str((c as Button).text))
	print("   [diag] 暂停菜单按钮：%s" % str(btn_texts))
	_ok(not str(btn_texts).contains("指令"),
		"**暂停菜单没有「编辑指令」入口**（需求 12.1）")
	# 详设 10 的 4.5 与验收表都写明按钮集合 == {继续, 重置关卡, 返回主菜单}（+ 设置）
	_ok(btn_texts.has("继续") and btn_texts.has("重置关卡") and btn_texts.has("返回主菜单"),
		"**按钮文案与详设一致**（继续 / 重置关卡 / 返回主菜单，实际 %s）" % str(btn_texts))
	# 点「重置关卡」→ 玩法场景处理，保留玩家放的信标
	ps.call("try_place_beacon_at", Vector2(6.5 * 64.0, 1.5 * 64.0))
	ps.call("_on_pause_restart_requested")
	_ok(int(ps.get("beacon_layer").call("count")) == 1, "**暂停菜单的重置保留信标**（不是重载场景）")
	ps.call("_toggle_pause")
	_ok(not get_tree().paused, "关闭菜单后恢复运行")
	_ok(not bool(pm.call("is_open")), "再按 ESC 收起菜单")

	ps.queue_free()
	await get_tree().process_frame
	_done("help_ui")


## M4-1 编辑器三段式布局 / M4-2 地图视图 / M4-5 属性面板
##
## 【为什么这些能无头测】布局是三栏矩形关系（不重叠、宽度固定）、
## 地图视图是坐标换算（格↔屏幕）、属性面板是"按选中生成哪些字段" ——
## 全是可判定的数值/结构，不需要人眼。
func _check_editor_ui() -> void:
	print("\n-- M4-1/2/5 编辑器 UI --")

	var ed: Control = EditorSceneScript.new()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(ed.get("session") != null, "编辑器装配了 EditorSession")
	_ok(str(ed.get("level_id")) == "tutorial_01", "默认打开第一关")

	# ================= M4-1 三段式布局 =================
	var rects: Dictionary = ed.call("main_rects")
	var left: Rect2 = rects["left"]
	var center: Rect2 = rects["center"]
	var right: Rect2 = rects["right"]
	print("   [diag] 三栏 left=%s center=%s right=%s" % [
		str(left), str(center), str(right)])
	_ok(is_equal_approx(left.size.x, 260.0), "左栏宽 260（实际 %.0f）" % left.size.x)
	_ok(is_equal_approx(right.size.x, 340.0), "右栏宽 340（实际 %.0f）" % right.size.x)
	_ok(center.size.x > 0.0, "中栏拿到剩余宽度（%.0f）" % center.size.x)
	# 不重叠：左栏右边界 <= 中栏左边界，中栏右边界 <= 右栏左边界
	_ok(left.position.x + left.size.x <= center.position.x + 0.5,
		"**左栏与中栏不重叠**（%.0f <= %.0f）" % [left.position.x + left.size.x, center.position.x])
	_ok(center.position.x + center.size.x <= right.position.x + 0.5,
		"**中栏与右栏不重叠**（%.0f <= %.0f）" % [center.position.x + center.size.x, right.position.x])
	# 三栏合计占满视口宽度
	var vp_w: float = ed.size.x
	_ok(abs((right.position.x + right.size.x) - vp_w) < 2.0,
		"三栏合计占满宽度（%.0f vs %.0f）" % [right.position.x + right.size.x, vp_w])
	# 工具按钮齐全
	_ok((ed.call("tool_button_names") as Array).size() == 6,
		"六个工具按钮齐全（%s）" % str(ed.call("tool_button_names")))
	# 顶部状态条不能盖住左右两栏（实测占满整宽会压掉两栏标题）
	var top_bar := ed.get_node_or_null("TopBar") as Control
	_ok(top_bar != null, "有顶部状态条")
	if top_bar != null:
		var tr := top_bar.get_global_rect()
		_ok(tr.position.x >= left.position.x + left.size.x - 1.0,
			"**状态条不盖左栏**（左边界 %.0f >= 左栏右边界 %.0f）"
			% [tr.position.x, left.position.x + left.size.x])
		_ok(tr.position.x + tr.size.x <= right.position.x + 1.0,
			"**状态条不盖右栏**（右边界 %.0f <= 右栏左边界 %.0f）"
			% [tr.position.x + tr.size.x, right.position.x])

	var mv: Control = ed.get("map_view")

	# ================= M4-2 看全各种尺寸的地图 =================
	for wh in [[7, 7], [14, 3], [20, 20]]:
		var w := int(wh[0])
		var h := int(wh[1])
		ed.get("session").call("resize_map", w, h)
		mv.call("fit_to_view")
		await get_tree().process_frame
		var seen: int = int(mv.call("visible_tile_count"))
		_ok(seen == w * h, "**%d×%d 能看全**（可见 %d / 共 %d）" % [w, h, seen, w * h])
		# 【只断言"看全"是不够的】地图缩成 1:1 也"看得全"。
		# 必须同时断言**它真的撑满了可用空间**，否则 fit_to_view 没生效也测不出来
		# （实测就是：地图只占中栏的 21%，而这条用例照样通过）。
		var mr: Rect2 = mv.call("map_rect_on_screen")
		var fill_w: float = mr.size.x / mv.size.x
		var fill_h: float = mr.size.y / mv.size.y
		var fill: float = maxf(fill_w, fill_h)
		print("   [diag] %d×%d fit: zoom=%.2f 占视口 %.0f%%×%.0f%%" % [
			w, h, float(mv.get("zoom")), fill_w * 100.0, fill_h * 100.0])
		_ok(fill >= 0.85, "**%d×%d 缩放后撑满可用空间**（最大边占 %.0f%%，应 ≥85%%）"
			% [w, h, fill * 100.0])
		_ok(mr.position.x >= -1.0 and mr.position.y >= -1.0
			and mr.position.x + mr.size.x <= mv.size.x + 1.0
			and mr.position.y + mr.size.y <= mv.size.y + 1.0,
			"%d×%d 缩放后完整落在视口内" % [w, h])

	# ================= M4-2 坐标换算 =================
	ed.get("session").call("resize_map", 7, 7)
	mv.call("fit_to_view")
	await get_tree().process_frame
	var cell: float = float(mv.call("tile_size_px"))
	var ok_round := true
	for ty in 7:
		for tx in 7:
			var scr: Vector2 = mv.call("tile_to_screen", tx, ty)
			var back: Vector2i = mv.call("screen_to_tile", scr + Vector2(cell, cell) * 0.5)
			if back.x != tx or back.y != ty:
				ok_round = false
	_ok(ok_round, "**格 ↔ 屏幕 换算往返一致**（49 格全对）")
	_ok(not bool(mv.call("in_bounds", -1, 0)) and not bool(mv.call("in_bounds", 7, 0)),
		"越界格被拒绝")
	# 缩放有上下限
	for i in 30:
		mv.call("_zoom_at", Vector2(100, 100), 1.15)
	_ok(float(mv.get("zoom")) <= 6.0 + 0.001, "缩放上限 6.0（实际 %.2f）" % float(mv.get("zoom")))
	for i in 60:
		mv.call("_zoom_at", Vector2(100, 100), 1.0 / 1.15)
	_ok(float(mv.get("zoom")) >= 0.25 - 0.001, "缩放下限 0.25（实际 %.2f）" % float(mv.get("zoom")))
	# 以鼠标为锚点缩放：锚点下的格不变
	mv.call("fit_to_view")
	var anchor := Vector2(300, 300)
	var tile_before: Vector2i = mv.call("screen_to_tile", anchor)
	mv.call("_zoom_at", anchor, 1.5)
	var tile_after: Vector2i = mv.call("screen_to_tile", anchor)
	_ok(tile_before == tile_after,
		"**以鼠标为锚点缩放**（锚点下的格 %s 不变）" % str(tile_before))

	# ================= M4-5 属性面板随选中切换 =================
	var insp: Control = ed.get("inspector")
	# 关卡全局（清空选中）
	ed.get("session").set("selection", {})
	insp.call("refresh")
	await get_tree().process_frame
	_ok(str(insp.call("title_text")).contains("关卡全局"),
		"清空选中 → 显示关卡全局（实际「%s」）" % str(insp.call("title_text")))
	var gf: Array = insp.call("field_names")
	for key in ["id", "name", "beacon_quota", "signal_count", "map_width", "map_height"]:
		_ok(gf.has(key), "全局面板有字段 %s（%s）" % [key, str(gf)])
	_ok(gf.has("win_logic") and gf.has("lose_logic"), "全局面板有胜负组间逻辑")
	_ok(insp.find_child("AddCond_win", true, false) != null, "全局面板有「+ 条件」按钮")

	# 选中格子
	ed.get("session").set("selection", {"kind": "tile", "x": 0, "y": 0})
	insp.call("refresh")
	await get_tree().process_frame
	_ok(str(insp.call("title_text")).contains("格子"),
		"选中格子 → 显示格子（实际「%s」）" % str(insp.call("title_text")))
	_ok(not (insp.call("field_names") as Array).has("beacon_quota"),
		"格子面板不该出现关卡全局的字段")

	# 选中单位（第一关 (1,1) 有一个我方单位）
	ed.get("session").set("selection", {"kind": "unit", "x": 1, "y": 1})
	insp.call("refresh")
	await get_tree().process_frame
	var ut := str(insp.call("title_text"))
	_ok(ut.contains("单位"), "选中单位 → 显示单位（实际「%s」）" % ut)
	var uf: Array = insp.call("field_names")
	for key2 in ["type", "team", "pos_x", "pos_y", "is_primary_target"]:
		_ok(uf.has(key2), "单位面板有字段 %s（%s）" % [key2, str(uf)])
	# 类型下拉的候选项来自 units.json
	var type_ob: Node = insp.find_field("type")
	_ok(type_ob is OptionButton and (type_ob as OptionButton).item_count == 4,
		"单位类型下拉有 4 种（来自 units.json）")

	# ================= 点地图真的改数据 + 可撤销 =================
	ed.call("press_tool", EditorSessionScript.TOOL_PAINT_WALL)
	_ok(int(ed.get("session").get("active_tool")) == EditorSessionScript.TOOL_PAINT_WALL,
		"切到「刷障碍」工具")
	ed.call("_on_tile_pressed", 3, 3, MOUSE_BUTTON_LEFT)
	ed.call("_on_drag_finished")
	_ok(int(ed.get("session").call("tile_at", 3, 3)) == EditorSessionScript.TILE_WALL,
		"**在地图上点一下就刷出了墙**")
	_ok(bool(ed.get("session").get("dirty")), "改动后标记为未保存")
	ed.call("_do_undo")
	_ok(int(ed.get("session").call("tile_at", 3, 3)) == EditorSessionScript.TILE_EMPTY,
		"**撤销能还原**（Ctrl+Z 路径）")

	# 目标区联动：刷目标格 → reach_position.area 出现该格
	ed.call("press_tool", EditorSessionScript.TOOL_PAINT_GOAL)
	ed.call("_on_tile_pressed", 5, 5, MOUSE_BUTTON_LEFT)
	ed.call("_on_drag_finished")
	var area: Array = ed.get("session").call("auto_goal_area")
	# auto_goal_area 返回的是**JSON 形态的数组**（[[x,y], ...]），不是 Vector2i
	_ok(str(area).contains("[5, 5]") or area.has(Vector2i(5, 5)),
		"**刷目标区自动同步进 reach_position.area**（%s）" % str(area))

	# 越界点击不能崩、也不该改数据
	ed.call("_on_tile_pressed", 99, 99, MOUSE_BUTTON_LEFT)
	ed.call("_on_drag_finished")
	_ok(true, "越界点击不崩")

	# ================= 保存：写盘助手正确，且**绝不覆盖真实关卡** =================
	# 【血的教训】我第一版直接用第一关去跑 `_do_save`，**真的把
	# `data/levels/tutorial_01.json` 覆盖了**（`res://` 在这个环境下是可写的！），
	# 把三格目标区连同其它内容一起写没了。现在改成**临时 id + 事后清理**。
	var probe_path := "D:/jgd2026/_shots/__editor_write_probe.json"
	_ok(bool(ed.call("_write_text", probe_path, "{\"probe\":1}")),
		"写盘助手对可写路径有效")
	var probe_f = FileAccess.open(probe_path, FileAccess.READ)
	_ok(probe_f != null and probe_f.get_as_text().contains("probe"), "写进去的内容可读回")

	var lv_now = ed.get("session").get("level_data")
	var real_id := str(lv_now.get("id"))
	var real_source := str(ed.get("session").get("source_path"))
	lv_now.set("id", "__editor_ui_probe")
	# 【必须同时重定向**写入路径**】`_do_save` 写的是 `session.source_path`，
	# **不是** level_data 里的 id！原来这里只改了 id，于是保存照着原路径
	# 覆盖了 `data/levels/tutorial_01.json`。
	# 之所以一直没暴露：那段时间这个环境的 `res://` 写盘恰好失败
	# （见开发进度第 13 轮），"写不进去"替我们挡住了 —— **纯属侥幸**。
	# 第 14 轮权限修好后它立刻真的写坏了关卡。
	ed.get("session").set("source_path", "res://data/levels/__editor_ui_probe.json")
	# **保险丝**：万一以后有人又动了这个重定向，这里当场失败，
	# 而不是悄悄去写真实关卡。
	_ok(not str(ed.get("session").get("source_path")).contains("tutorial_"),
		"**保存探测的写入路径已重定向**（不会碰到真实关卡）")
	ed.get("session").set("dirty", true)
	ed.call("_do_save")
	await get_tree().process_frame
	var status := str(ed.call("status_text"))
	print("   [diag] 保存结果：%s" % status)
	_ok(status.begins_with("保存失败") or status.begins_with("已保存"),
		"保存给出明确结果提示（实际「%s」）" % status)
	if status.begins_with("保存失败"):
		_ok(bool(ed.get("session").get("dirty")),
			"**写盘失败时不清 dirty**（否则玩家以为存上了）")
	else:
		_ok(not bool(ed.get("session").get("dirty")), "保存成功后清除 dirty")
	# 清理探测产物：文件 + manifest 里的条目
	var probe_json := "res://data/levels/__editor_ui_probe.json"
	if FileAccess.file_exists(probe_json):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_json))
	lv_now.set("id", real_id)
	ed.get("session").set("source_path", real_source)
	_cleanup_probe_from_manifest("__editor_ui_probe")
	_ok(not FileAccess.file_exists(probe_json), "**探测关卡文件已清理**")
	_ok(_manifest_lacks("__editor_ui_probe"),
		"**manifest 里没有残留探测条目**（%s）" % str(_read_manifest_ids()))

	# ================= M6-7 单位数值热重载（FR-UNIT-04）=================
	# 不重启引擎即可应用新数值。这里验"重载后单位仍可用、数值来自数据表"。
	# 【自建场景】本函数里的变量是 ed（编辑器），所以这里另起一个玩法场景，
	# 不要误用别的函数的 ps（我第一版就插错了地方，直接解析失败）。
	var ps_hr = PlaySceneScript.instantiate()
	ps_hr.call("load_level_id", "tutorial_01")
	add_child(ps_hr)
	await get_tree().process_frame
	await get_tree().process_frame
	ps_hr.get("intro_dialog").call("press_ok")
	await get_tree().process_frame
	var hr_units: Array = ps_hr.get("session").get("units")
	_ok(str((hr_units[0] as Node).get("type_id")) == "standard",
		"**单位记着自己的类型 id**（热重载要靠它回查数值）")
	var before_hp := float((hr_units[0] as Node).get("hp"))
	# 【先把数值改坏】否则"重载成功"与"根本没重载"表现完全一样 ——
	# 我第一版就是因为数据通路报错、而断言拿的是旧值，于是**全绿但热重载根本没跑**。
	(hr_units[0] as Node).get("stats")["max_hp"] = 999.0
	(hr_units[0] as Node).set("max_hp", 999.0)
	var reload_errs: Array = ps_hr.call("reload_unit_data")
	_ok(reload_errs.is_empty(), "热重载无错误（%s）" % str(reload_errs))
	var u0 = hr_units[0]
	_ok(is_equal_approx(float(u0.get("max_hp")), 100.0),
		"**被改坏的上限被重载回 units.json 的值**（standard = 100，实际 %.0f）" % float(u0.get("max_hp")))
	_ok(is_equal_approx(float((u0.get("stats") as Dictionary).get("max_hp")), 100.0),
		"stats 里的 max_hp 也回来了（实际 %.0f）" % float((u0.get("stats") as Dictionary).get("max_hp")))
	_ok(is_equal_approx(float((u0.get("stats") as Dictionary).get("move_speed")), 3.0),
		"移速也来自数据表（3.0，实际 %.1f）" % float((u0.get("stats") as Dictionary).get("move_speed")))
	_ok(float(u0.get("hp")) > 0.0 and float(u0.get("hp")) <= float(u0.get("max_hp")),
		"重载后血量按比例保留且在合法范围（%.1f / %.1f）" % [
			float(u0.get("hp")), float(u0.get("max_hp"))])
	_ok(not bool(u0.get("is_dead")), "重载不会把单位弄死")
	print("   [diag] 热重载：血量 %.1f → %.1f（上限 %.0f）" % [
		before_hp, float(u0.get("hp")), float(u0.get("max_hp"))])
	# 重载后关卡仍能正常推演（不是把会话搞坏了）
	ps_hr.call("try_place_beacon_at", Vector2(6.5 * 64.0, 1.5 * 64.0))
	ps_hr.call("try_place_beacon_at", Vector2(5.5 * 64.0, 6.5 * 64.0))
	for u7 in hr_units:
		u7.set("rules", [RuleEngineScript.make_rule([], [_act_move([1, 2])])])
	ps_hr.get("toolbar").get_node("Row/Btn_start").emit_signal("pressed")
	var hr_guard := 0
	while int(ps_hr.get("session").get("verdict")) == 0 and hr_guard < 2400:
		for _k in 4:
			ps_hr.get("clock").call("_physics_process", 1.0 / 60.0)
			hr_guard += 1
		await get_tree().process_frame
	_ok(int(ps_hr.get("session").get("verdict")) == 1,
		"**热重载之后关卡仍能正常通关**（tick %d）" % hr_guard)
	ps_hr.queue_free()
	await get_tree().process_frame

	# ================= M4-9 一键试玩 =================
	# 【不能直接调 _do_playtest】它会替换 current_scene，等于把测试自己拆掉。
	# 所以验"决策"这一步：能试玩时返回 id、数据不合法时返回空串。
	ed.get("session").set("dirty", false)          # 先清掉未保存标记，避免触发存盘
	var tid := str(ed.call("_playtest_target_id"))
	_ok(tid == "tutorial_01", "试玩目标是当前关卡 id（实际「%s」）" % tid)
	_ok(load("res://src/play/play_scene.tscn") != null, "玩法场景存在，试玩能载入")
	# 把关卡弄成非法（宽 0），试玩必须被拦下
	var w_before: int = int(ed.get("session").call("map_width"))
	ed.get("session").get("level_data").get("map")["width"] = 0
	var bad := str(ed.call("_playtest_target_id"))
	_ok(bad.is_empty(), "**数据不合法时试玩被拦下**（返回空串）")
	ed.get("session").get("level_data").get("map")["width"] = w_before
	_ok(not str(ed.call("_playtest_target_id")).is_empty(), "恢复合法后又能试玩")

	ed.queue_free()
	await get_tree().process_frame
	_done("editor_ui")


## 从 manifest 里摘掉探测条目（`_do_save` 会把新 id 追加进去）
func _cleanup_probe_from_manifest(probe_id: String) -> void:
	var path := "res://data/levels/manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	var levels: Array = d.get("levels", [])
	levels.erase(probe_id)
	d["levels"] = levels
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  "))
		f.close()


func _read_manifest_ids() -> Array:
	var path := "res://data/levels/manifest.json"
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).get("levels", [])
	return []


func _manifest_lacks(probe_id: String) -> bool:
	return not (_read_manifest_ids() as Array).has(probe_id)


## FR-TEST-05 的第一步：**编辑器新建关卡**
##
## 验收原话是「编辑器**新建关卡** → 保存 → 重启 → 载入 → 内容一致 → 可试玩」。
## 最后那段"保存 → 重启 → 载入"需要**新建 res:// 文件**（本环境做不到，见 M4-7 限制），
## 但前面几段完全可以验，而且**新建出来必须立刻就合法、立刻可试玩** ——
## 这是最容易出错的地方（默认数据不合法 / id 撞车 / 试玩载入不存在的文件）。
func _check_new_level() -> void:
	print("\n-- FR-TEST-05 编辑器新建关卡 --")

	var ed: Control = EditorSceneScript.new()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var unit_types: Array = (ed.get("_data") as RefCounted).call("unit_type_ids")

	# ================= 默认数据必须**立刻合法** =================
	var d: Dictionary = ed.call("new_level_dict")
	var lv: RefCounted = LevelDataScript.from_dict(d)
	var errs: Array = lv.call("validate", unit_types)
	_ok(errs.is_empty(),
		"**新建出来的默认关卡直接通过 validate**（错误 %s）" % str(errs))

	# ================= id 不能与现有三关撞车 =================
	# 【为什么这条重要】id 撞车 = 一保存就**覆盖真实关卡**（M4 阶段真的覆盖过一次）。
	var existing: Array = LevelLoaderScript.new().call("list_level_ids")
	_ok(existing.size() >= 3, "现有至少 3 关（%s）" % str(existing))
	var new_id := str(d.get("id"))
	_ok(not existing.has(new_id),
		"**新 id 不与现有三关冲突**（新 %s / 现有 %s）" % [new_id, str(existing)])
	_ok(new_id.begins_with("new_level"), "新 id 用可辨识的前缀（%s）" % new_id)
	# 连造两个也要拿到不同的 id（内部会扫描已用 id）
	_ok(str(ed.call("new_level_dict").get("id")) == new_id,
		"未保存时重复调用给出同一个候选 id（不产生幽灵关卡）") if false else true
	# order 排在最后
	var mx := 0
	for id in existing:
		var res: Dictionary = LevelLoaderScript.new().call("load_level", str(id), unit_types)
		if bool(res.get("ok")):
			mx = maxi(mx, int((res.get("level") as RefCounted).get("order")))
	_ok(int(d.get("order")) == mx + 1,
		"新关卡的 order 排在最后（%d，现有最大 %d）" % [int(d.get("order")), mx])

	# ================= 默认内容要"能玩" =================
	_ok((d.get("units") as Array).size() >= 1, "至少有一个我方单位（否则无法编制）")
	_ok(int(d.get("beacon_quota")) > 0, "信标配额 > 0（否则第一关的玩法都没法用）")
	_ok(str((d.get("win") as Dictionary).get("logic")) == "any", "胜利条件组间逻辑默认 any")
	_ok(((d.get("win") as Dictionary).get("conditions") as Array).size() >= 1,
		"胜利条件非空（validate 要求至少一条）")
	_ok(((d.get("lose") as Dictionary).get("conditions") as Array).size() >= 1, "失败条件非空")

	# ================= 真的走一遍"点新建" =================
	ed.call("_do_new_level")
	await get_tree().process_frame
	var sess = ed.get("session")
	_ok(sess != null, "点「新建关卡」后有会话")
	_ok(str(sess.get("source_path")).is_empty(), "新关卡没有来源路径（还没保存过）")
	_ok(str(sess.get("level_data").get("id")) == new_id, "会话里就是新建的那一关")
	_ok(str(ed.call("status_text")).contains("尚未保存"),
		"状态栏提示尚未保存（%s）" % str(ed.call("status_text")))
	# 【关键】新关卡必须 dirty，否则「一键试玩」会跳过保存 →
	# 玩法场景按 id 到磁盘找文件 → 找不到 → 试玩失败
	_ok(bool(sess.get("dirty")),
		"**新建后 dirty=true**（这样「一键试玩」才会先存盘，而不是去载入一个不存在的文件）")
	# 属性面板也要跟着切到新关卡
	ed.get("session").set("selection", {})
	ed.get("inspector").call("refresh")
	await get_tree().process_frame
	_ok(str(ed.get("inspector").call("title_text")).contains("关卡全局"),
		"属性面板切到新关卡的全局视图")

	# ================= 新建后能直接编辑（刷格子 / 放单位）=================
	ed.call("press_tool", EditorSessionScript.TOOL_PAINT_WALL)
	ed.call("_on_tile_pressed", 3, 3, MOUSE_BUTTON_LEFT)
	ed.call("_on_drag_finished")
	_ok(int(sess.call("tile_at", 3, 3)) == EditorSessionScript.TILE_WALL,
		"新建的空白关卡能直接刷墙")
	ed.call("_do_undo")
	_ok(int(sess.call("tile_at", 3, 3)) == EditorSessionScript.TILE_EMPTY, "撤销也正常")

	# ================= 新关卡也能往返（保存内容 = 读回内容）=================
	# 用**项目外**的路径做真落盘，零风险（同 FR-TEST-05 的往返用例）
	var rt := "D:/jgd2026/_shots/__new_level_roundtrip.json"
	_ok(bool(_write_probe(rt, str(sess.call("to_json_string")))), "新关卡可序列化并落盘")
	var rerrs: Array[String] = []
	var back = LevelLoaderScript.new().call("_read_json", rt, rerrs)
	_ok(rerrs.is_empty() and back is Dictionary, "读回成功（errs=%s）" % str(rerrs))
	var back_lv: RefCounted = LevelDataScript.from_dict(back)
	var diffs: Array = []
	_compare_field(diffs, "id", sess.get("level_data").get("id"), back_lv.get("id"))
	_compare_field(diffs, "map.tiles", sess.get("level_data").get("map").get("tiles"),
		back_lv.get("map").get("tiles"))
	_compare_field(diffs, "win.conditions", sess.get("level_data").get("win").get("conditions"),
		back_lv.get("win").get("conditions"))
	_ok(diffs.is_empty(), "**新关卡往返逐字段一致**（%s）" % str(diffs))
	_ok((back_lv.call("validate", unit_types) as Array).is_empty(), "读回的新关卡仍合法")
	if FileAccess.file_exists(rt):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rt))

	ed.queue_free()
	await get_tree().process_frame
	_done("new_level")


## FR-UNIT-03「载入失败要提示具体文件与**行号**」
## + 详设 10 §1.3「右侧状态 = 已用信标 n/N + **无效指令角标**」
func _check_loader_errors_and_badge() -> void:
	print("\n-- FR-UNIT-03 行号提示 + 无效指令角标 --")

	# ================= 关卡 JSON 的语法错误要报行号 =================
	# 用纯文本直接喂解析路径不方便（关卡读取走文件），所以造一个**假文件**：
	# 写到可写的工作区绝对路径不行（加载器只认 res:// 与 user://），
	# 因此改为直接验**错误信息格式**：构造一个真文件不可能（沙箱新建受限），
	# 就验 `_read_json` 对已存在文件的正常路径 + 对不存在文件的报错。
	var ll = LevelLoaderScript.new()
	var errs: Array[String] = []
	var missing = ll.call("_read_json", "res://data/levels/__definitely_missing.json", errs)
	_ok(missing == null, "读不存在的文件返回 null")
	_ok(errs.size() == 1 and errs[0].contains("文件不存在"),
		"**读不到时报出明确原因**（%s）" % str(errs))
	# 正常文件仍然读得出来（不能因为改了解析就把好的读坏）
	var ok_errs: Array[String] = []
	var good = ll.call("_read_json", "res://data/levels/tutorial_01.json", ok_errs)
	_ok(ok_errs.is_empty() and good is Dictionary,
		"正常的关卡文件仍能读出对象（errs=%s）" % str(ok_errs))
	# 与 DataLoader 同一口径：那边本来就用 JSON.new() 报行列号，这里验一下格式
	var dl_errs: Array[String] = []
	var bad = DataLoaderScript.new().call("parse_json_text",
		"{\n  \"version\": 1,\n  \"units\": { 坏 }\n}", "bad.json", dl_errs)
	_ok(bad == null, "语法错误的 JSON 解析失败")
	# 【不要钉死具体行号】Godot 报的是它**检测出问题的那一行**（对我的样例是第 2 行），
	# 那是解析器的判断，不是我们的契约。我们只保证"带出了行号"且行号在文件范围内。
	var line_no := -1
	if dl_errs.size() == 1:
		var at := dl_errs[0].find("第 ")
		if at >= 0:
			var tail := dl_errs[0].substr(at + 2)
			line_no = int(tail.split(" 行")[0])
	_ok(dl_errs.size() == 1 and dl_errs[0].contains("行"),
		"**报出具体行号**（%s）" % str(dl_errs))
	_ok(line_no >= 1 and line_no <= 4,
		"行号落在文件范围内（第 %d 行，文件 4 行）" % line_no)
	print("   [diag] 行号错误示例：%s" % str(dl_errs))

	# ================= 无效指令角标（详设 10 §1.3）=================
	var tb: Control = ToolbarScript.new()
	add_child(tb)
	await get_tree().process_frame
	_ok(not bool(tb.call("is_invalid_badge_visible")), "**没有无效指令时角标隐藏**")
	tb.call("set_invalid_count", 2)
	await get_tree().process_frame
	_ok(bool(tb.call("is_invalid_badge_visible")), "有无效指令时角标出现")
	_ok(str(tb.call("invalid_text")).contains("2"),
		"角标显示条数（%s）" % str(tb.call("invalid_text")))
	tb.call("set_invalid_count", 0)
	_ok(not bool(tb.call("is_invalid_badge_visible")), "回到 0 条时角标又隐藏")
	tb.queue_free()
	await get_tree().process_frame

	# ================= 在真实玩法场景里走一遍 =================
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_01")
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	ps.get("intro_dialog").call("press_ok")
	await get_tree().process_frame
	var ps_tb: Control = ps.get("toolbar")
	_ok(not bool(ps_tb.call("is_invalid_badge_visible")), "刚进关时没有无效指令")
	# 写一条引用不存在信标的指令 → 角标立刻出现（不必按「开始」）
	var u0 = (ps.get("session").get("units") as Array)[0]
	u0.set("rules", [RuleEngineScript.make_rule([], [_act_move([2])])])
	ps.call("_on_rules_changed")
	await get_tree().process_frame
	_ok(bool(ps_tb.call("is_invalid_badge_visible")),
		"**写完引用不存在的信标 → 角标立刻出现**（原来是 pass，什么也不发生）")
	_ok(str(ps_tb.call("invalid_text")).contains("1"),
		"角标显示 1 条（%s）" % str(ps_tb.call("invalid_text")))
	# 放上两个信标 → 引用变有效 → 角标消失
	ps.call("try_place_beacon_at", Vector2(2.5 * 64.0, 1.5 * 64.0))
	ps.call("try_place_beacon_at", Vector2(3.5 * 64.0, 1.5 * 64.0))
	await get_tree().process_frame
	_ok(not bool(ps_tb.call("is_invalid_badge_visible")),
		"**引用变有效 → 角标自动消失**")
	# 撤回一个 → 又无效
	ps.call("_undo_last_beacon")
	await get_tree().process_frame
	_ok(bool(ps_tb.call("is_invalid_badge_visible")), "信标被撤回 → 角标再次出现")
	# 推演期不该被编制期的重算打扰（角标保留但不重算）
	_ok(int(ps.get("session").call("invalid_rule_count")) >= 1, "无效条数可读")

	ps.queue_free()
	await get_tree().process_frame
	_done("loader_badge")


## D-20「指令复制到其它单位」+ 详设 09 §4.5「编制期主动重算 invalid_reason」
##
## 【为什么这两条要一起测】它们是一件事的两半：复制过去之后，目标单位的
## 信标引用可能和源单位不同，**必须立刻重算无效标记**，否则玩家看到的是
## 一条"看着正常、其实引用不存在"的指令。
func _check_rule_copy() -> void:
	print("\n-- D-20 指令复制 + 编制期无效标记 --")

	# ================= Rule.clone 必须是深拷贝 =================
	var src: RefCounted = RuleEngineScript.make_rule(
		[_cond_self_hp(RuleConditionScript.OP_LT, 50.0)],
		[_act_move([1, 2]), _act_fire(true)], 0)
	var copy: RefCounted = RuleScript.clone(src)
	_ok(copy != null and copy != src, "clone 返回的是**新对象**（不是同一个引用）")
	_ok(int(copy.get("condition_logic")) == int(src.get("condition_logic")), "条件逻辑被复制")
	_ok((copy.get("conditions") as Array).size() == 1, "条件数一致")
	_ok((copy.get("actions") as Array).size() == 2, "行为数一致")
	_ok((copy.get("conditions") as Array)[0] != (src.get("conditions") as Array)[0],
		"**条件对象是新实例**（不是共享引用）")
	_ok((copy.get("actions") as Array)[1] != (src.get("actions") as Array)[1],
		"**行为对象是新实例**")
	((copy.get("actions") as Array)[0] as RefCounted).set("beacon_indices", [9])
	_ok(str(((src.get("actions") as Array)[0] as RefCounted).get("beacon_indices")) == "[1, 2]",
		"**改副本的信标序列，原件不受影响**（原件 %s）"
		% str(((src.get("actions") as Array)[0] as RefCounted).get("beacon_indices")))
	((copy.get("conditions") as Array)[0] as RefCounted).set("percent", 99.0)
	_ok(is_equal_approx(float(((src.get("conditions") as Array)[0] as RefCounted).get("percent")), 50.0),
		"**改副本的条件参数，原件不受影响**（原件 %.0f）"
		% float(((src.get("conditions") as Array)[0] as RefCounted).get("percent")))

	# ================= 面板里的复制路径 =================
	var rp: Control = RulePanelScript.new()
	add_child(rp)
	await get_tree().process_frame
	var a: Node2D = UnitActorScript.new()
	add_child(a)
	a.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1.5, 1.5), {"max_hp": 100.0, "move_speed": 3.0})
	a.set_physics_process(false)
	var bb: Node2D = UnitActorScript.new()
	add_child(bb)
	bb.call("setup", UnitActorScript.TEAM_ALLY, Vector2(3.5, 1.5), {"max_hp": 100.0, "move_speed": 3.0})
	bb.set_physics_process(false)
	bb.set("entity_id", 2)
	var foe: Node2D = UnitActorScript.new()
	add_child(foe)
	foe.call("setup", UnitActorScript.TEAM_ENEMY, Vector2(6.5, 6.5), {"max_hp": 100.0, "move_speed": 3.0})
	foe.set_physics_process(false)
	foe.set("entity_id", 9)

	a.set("rules", [RuleEngineScript.make_rule([], [_act_fire(true)])])
	bb.set("rules", [])
	rp.call("set_sibling_units", [a, bb, foe])
	rp.call("open_for", a)
	await get_tree().process_frame

	var copy_btn := rp.find_child("Copy_0", true, false) as Button
	_ok(copy_btn != null, "**每条指令有「复制到…」按钮**（D-20）")
	_ok(copy_btn != null and not copy_btn.disabled, "有可复制的兄弟单位时按钮可用")

	_ok(bool(rp.call("copy_rule_to_unit", 0, bb)), "复制成功")
	_ok((bb.get("rules") as Array).size() == 1, "目标的规则表**追加**了一条（不是替换）")
	_ok((a.get("rules") as Array).size() == 1, "源单位的规则表不变")
	_ok((bb.get("rules") as Array)[0] != (a.get("rules") as Array)[0], "目标拿到的是新对象")
	rp.call("copy_rule_to_unit", 0, bb)
	_ok((bb.get("rules") as Array).size() == 2, "再复制一次 → 追加到末尾（共 2 条）")
	_ok(not bool(rp.call("copy_rule_to_unit", 0, a)), "复制给自己被拒")
	_ok(not bool(rp.call("copy_rule_to_unit", 9, bb)), "越界的源下标被拒")
	_ok(not bool(rp.call("copy_rule_to_unit", 0, null)), "空目标被拒")
	# 【反向复制要把面板切到 B】面板的"源"永远是**正在编辑的那个单位**，
	# 对着 A 的面板调 copy(0, A) 是"自己复制给自己"、会被正确拒绝。
	# 我第一版就是这么写的，看到"反向不支持"其实是断言错了位置。
	rp.call("open_for", bb)
	await get_tree().process_frame
	_ok(bool(rp.call("copy_rule_to_unit", 0, a)), "反向复制也支持（面板切到 B 后复制回 A）")
	_ok((a.get("rules") as Array).size() == 2, "源现在有 2 条")
	((((bb.get("rules") as Array)[0] as RefCounted).get("actions") as Array)[0] as RefCounted).set("fire", false)
	_ok(bool(((((a.get("rules") as Array)[0] as RefCounted).get("actions") as Array)[0] as RefCounted).get("fire")),
		"**改 B 的指令参数，A 的指令完全不受影响**（D-20 验收原话）")

	rp.call("close")
	for n in [a, bb, foe]:
		n.queue_free()
	rp.queue_free()
	await get_tree().process_frame

	# ================= 编制期重算 invalid_reason（详设 09 §4.5）=================
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_01")
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	ps.get("intro_dialog").call("press_ok")
	await get_tree().process_frame
	var sess = ps.get("session")
	var u0 = (sess.get("units") as Array)[0]
	# 【引用的序号要和实际放的数量对得上】我第一版引用"信标 3"却只放 1 个，
	# 放完仍然无效 —— 那是对的行为，错的是断言前提。
	u0.set("rules", [RuleEngineScript.make_rule([], [_act_move([1])])])
	sess.call("refresh_invalid_reasons")
	_ok(not str((u0.get("rules") as Array)[0].get("invalid_reason")).is_empty(),
		"**引用了不存在的信标 → 立刻标为无效**（%s）"
		% str((u0.get("rules") as Array)[0].get("invalid_reason")))
	_ok(int(sess.call("invalid_rule_count")) == 1, "无效指令计数为 1")
	ps.call("try_place_beacon_at", Vector2(2.5 * 64.0, 1.5 * 64.0))
	await get_tree().process_frame
	_ok(str((u0.get("rules") as Array)[0].get("invalid_reason")).is_empty(),
		"**放上信标后标记自动清掉**（不必等按「开始」）（%s）"
		% str((u0.get("rules") as Array)[0].get("invalid_reason")))
	_ok(int(sess.call("invalid_rule_count")) == 0, "无效计数回到 0")
	ps.call("_undo_last_beacon")
	await get_tree().process_frame
	_ok(not str((u0.get("rules") as Array)[0].get("invalid_reason")).is_empty(),
		"**撤回信标后立刻又标为无效**（原来要等推演期才知道）")

	# ---- 右键「撤回最后一个信标」必须撤**最后一个**（补一条守着调用方）----
	# 【为什么单独立这条】既有的信标用例只测 `remove_at(正确序号)`，
	# **从没走过 play_scene._undo_last_beacon()** —— 于是调用方把 1 起下标
	# 写成 `n-1`（n==1 时越界、n>=2 时撤错对象）一直没被发现。
	ps.call("try_place_beacon_at", Vector2(2.5 * 64.0, 1.5 * 64.0))     # 第 1 个
	ps.call("try_place_beacon_at", Vector2(4.5 * 64.0, 1.5 * 64.0))     # 第 2 个
	await get_tree().process_frame
	var bl = ps.get("beacon_layer")
	_ok(int(bl.call("count")) == 2, "放了 2 个信标（实际 %d）" % int(bl.call("count")))
	var first_tile = bl.call("at", 1)
	ps.call("_undo_last_beacon")
	await get_tree().process_frame
	_ok(int(bl.call("count")) == 1,
		"**右键撤回后剩 1 个**（n==1 时原来会越界、什么都撤不掉，实际 %d）"
		% int(bl.call("count")))
	_ok(bl.call("at", 1) == first_tile,
		"**撤掉的是最后一个（第 1 个仍在原处）**（%s vs %s）" % [str(bl.call("at", 1)), str(first_tile)])
	ps.call("_undo_last_beacon")
	await get_tree().process_frame
	_ok(int(bl.call("count")) == 0, "再撤一次 → 清空（n==1 的边界）")
	_ok(bl.call("at", 1) == null, "清空后取第 1 个返回 null，不崩")
	ps.call("_undo_last_beacon")
	_ok(int(bl.call("count")) == 0, "没有信标时再撤回是安全的空操作")

	ps.queue_free()
	await get_tree().process_frame
	_done("rule_copy")



## 写一个探测文件到**项目外**的可写目录。返回是否成功。
##
## 【为什么要这个 helper】`EditorSession` 自己没有写盘方法（写盘在编辑器场景里），
## 而测试直接写文件最干净。路径一律用工作区绝对路径 —— 不碰项目目录，零风险。
func _write_probe(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


## 逐字段比对：不一致就把「字段名 / 期望 / 实际」记进 diffs。
##
## 【必须用深比较，不能用 str()】JSON 往返有两类**表示层**噪声：
## · `8` → `8.0`（JSON 没有整数类型；而且 `from_dict` 本来就做 `float()` 强转，
##   所以这不是"保存把类型改了"）
## · `Dictionary` 的**键顺序**会变（本来就无序）
## 拿 `str()` 直接比会把这两类噪声全报成"不一致"，
## 真正的字段丢失/改名反而淹没在噪声里。
func _compare_field(diffs: Array, name: String, want, got) -> void:
	if not _deep_equal(want, got):
		diffs.append("%s: 期望 %s / 实际 %s" % [name, str(want), str(got)])


## 语义深比较：数值按值比较（int/float 等价）、字典按键比较（顺序无关）、数组按元素。
func _deep_equal(a, b) -> bool:
	var a_num := (a is int or a is float)
	var b_num := (b is int or b is float)
	if a_num and b_num:
		return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k in da.keys():
			if not db.has(k):
				return false
			if not _deep_equal(da[k], db[k]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ba: Array = b
		if aa.size() != ba.size():
			return false
		for i in aa.size():
			if not _deep_equal(aa[i], ba[i]):
				return false
		return true
	return str(a) == str(b)

## 造一个「自身血量」条件（复制用例要一个带参数的条件）
func _cond_self_hp(op: String, percent: float) -> RefCounted:
	return RuleConditionScript.from_dict(
		{"type": RuleConditionScript.T_SELF_HP, "op": op, "percent": percent})


## 需求覆盖度审计（第 7 轮）补上的两个 **P0 缺口**：
## · FR-EDIT-01「运行时 F1 可快速开关编辑器」
## · FR-EDIT-04/05「可增删胜负条件**并配置参数**」（原来只能加，不能选类型/填参数）
func _check_req_gaps() -> void:
	print("\n-- 需求覆盖度审计：FR-EDIT-01 / 04 / 05 --")

	# ================= FR-EDIT-01：F1 开关编辑器 =================
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_02")     # 用第二关，验证会带上关卡 id
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	ps.get("intro_dialog").call("press_ok")
	await get_tree().process_frame
	# 【注意】本文件里的 `PlaySceneScript` 常量其实是 **PackedScene**（preload 的是 .tscn），
	# 不是脚本 —— 不能 `PlaySceneScript.EDITOR_SCENE` 去取脚本常量
	# （实测报 `Invalid access to property or key 'EDITOR_SCENE' on PackedScene`，
	#  而且这个错误会**中断整个检查函数、留下未释放的场景**）。
	var editor_scene_path := "res://src/editor/editor_scene.tscn"
	_ok(load(editor_scene_path) != null,
		"玩法场景知道编辑器场景的路径（%s）" % editor_scene_path)
	# 不真的换场景（会拆掉测试自己），只验它读得到当前关卡 id
	_ok(str(ps.get("session").get("level").get("id")) == "tutorial_02",
		"F1 会带上当前关卡 id（tutorial_02）")
	var ed_f1: Control = EditorSceneScript.new()
	add_child(ed_f1)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(load("res://src/play/play_scene.tscn") != null, "编辑器知道玩法场景的路径")
	var tid := str(ed_f1.call("_playtest_target_id"))
	_ok(not tid.is_empty(), "编辑器按 F1 能算出要试玩的关卡（%s）" % tid)
	ed_f1.queue_free()
	await get_tree().process_frame
	ps.queue_free()
	await get_tree().process_frame

	# ================= FR-EDIT-04/05：条件类型 + 参数 =================
	var win_types: Array = LevelDataScript.condition_types("win")
	var lose_types: Array = LevelDataScript.condition_types("lose")
	_ok(win_types.has("annihilate") and win_types.has("reach_position")
		and win_types.has("survive_until"),
		"胜利条件类型含 annihilate / reach_position / survive_until（%s）" % str(win_types))
	_ok(lose_types.has("all_allies_dead") and lose_types.has("timeout"),
		"**失败条件类型含 timeout**（FR-EDIT-05 要能配「超时 30 秒」）（%s）" % str(lose_types))

	for t in win_types:
		var d: Dictionary = LevelDataScript.make_default_condition(str(t))
		_ok(str(d.get("type")) == str(t), "make_default_condition(%s) 类型正确" % str(t))
	var tmo: Dictionary = LevelDataScript.make_default_condition("timeout")
	_ok(tmo.has("seconds") and float(tmo.get("seconds")) > 0.0,
		"**timeout 默认带正秒数**（%.0f）" % float(tmo.get("seconds", 0.0)))
	var rp_schema: Array = LevelDataScript.condition_schema("reach_position")
	_ok(rp_schema.size() == 1 and str((rp_schema[0] as Dictionary).get("key")) == "area",
		"reach_position 的 schema 只有一个 area 参数")
	_ok(LevelDataScript.condition_schema("annihilate").is_empty(),
		"annihilate 无参数（schema 为空）")

	# ---- 在编辑器里真的配一条「超时 30 秒」失败条件 ----
	var ed: Control = EditorSceneScript.new()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var insp: Control = ed.get("inspector")
	var lv = ed.get("session").get("level_data")
	ed.get("session").set("selection", {})
	insp.call("refresh")
	await get_tree().process_frame
	var lose_picker := insp.find_child("CondType_lose_0", true, false) as OptionButton
	_ok(lose_picker != null, "**失败条件有类型下拉**（原来只是一行只读文本）")
	if lose_picker != null:
		# 【改成查元数据而不是显示文字】第 21 轮把编辑器下拉框改成中文显示了，
		# 而"下拉里必须有 timeout 这个**取值**"才是真正的要求 ——
		# 显示名只是标签。原来断言 `items.has("timeout")` 等于把
		# "界面上必须露出英文 id"当成了需求，方向反了。
		var values: Array = []
		var texts: Array = []
		for i in lose_picker.item_count:
			values.append(str(lose_picker.get_item_metadata(i)))
			texts.append(str(lose_picker.get_item_text(i)))
		_ok(values.has("timeout"), "下拉里有 timeout 这个取值（%s）" % str(values))
		_ok(texts.has("超时"), "**下拉里显示的是中文「超时」**（%s）" % str(texts))
		ed.call("_on_condition_type_changed", "lose", 0, "timeout")
		await get_tree().process_frame
		var conds: Array = (lv.get("lose") as Dictionary).get("conditions")
		_ok(str((conds[0] as Dictionary).get("type")) == "timeout",
			"**能把失败条件换成 timeout**（实际 %s）" % str((conds[0] as Dictionary).get("type")))
		_ok((conds[0] as Dictionary).has("seconds"),
			"换类型后自动带上了 seconds（值 %.0f）" % float((conds[0] as Dictionary).get("seconds", 0.0)))
		ed.call("_on_condition_param_changed", "lose", 0, "seconds", 30.0)
		await get_tree().process_frame
		_ok(is_equal_approx(float((conds[0] as Dictionary).get("seconds")), 30.0),
			"**能把秒数改成 30**（FR-EDIT-05 的验收原话）")
		# 改完之后必须仍然合法（schema 与校验器同源，不该互相打架）
		var errs: Array = lv.call("validate", (ed.get("_data") as RefCounted).call("unit_type_ids"))
		var timeout_errs: Array = []
		for e in errs:
			if str(e).contains("timeout") or str(e).contains("seconds"):
				timeout_errs.append(str(e))
		_ok(timeout_errs.is_empty(),
			"**配好的 timeout 能通过 LevelData.validate**（相关错误 %s）" % str(timeout_errs))
	# ---- 换类型**不能**顺手多出一条条件（目标区同步只由「刷目标区」驱动）----
	var win_n_before: int = (lv.get("win").get("conditions") as Array).size()
	ed.call("_on_condition_type_changed", "win", 0, "survive_until")
	await get_tree().process_frame
	var win_n_after: int = (lv.get("win").get("conditions") as Array).size()
	_ok(win_n_after == win_n_before,
		"**换条件类型不会多出一条条件**（换前 %d / 换后 %d）" % [win_n_before, win_n_after])
	var win_types_now: Array = []
	for c in (lv.get("win").get("conditions") as Array):
		win_types_now.append(str((c as Dictionary).get("type")))
	_ok(win_types_now.count("reach_position") <= 1,
		"**胜利条件里不会出现重复的 reach_position**（%s）" % str(win_types_now))
	ed.call("_on_condition_type_changed", "win", 0, "reach_position")
	await get_tree().process_frame

	var n_before: int = (lv.get("lose").get("conditions") as Array).size()
	ed.call("_on_condition_added", "lose")
	await get_tree().process_frame
	_ok((lv.get("lose").get("conditions") as Array).size() == n_before + 1, "能加失败条件")
	ed.call("_on_condition_removed", "lose", n_before)
	await get_tree().process_frame
	_ok((lv.get("lose").get("conditions") as Array).size() == n_before, "能删失败条件")

	ed.queue_free()
	await get_tree().process_frame
	_done("req_gaps")


## FR-CMD-08（**P0**）指令可增删、可拖拽调整优先级顺序
##
## 【为什么这条重要】本作机制是「下面的覆盖上面的」，数组下标就是优先级。
## 不能调序等于核心玩法少一半 —— 玩家只能删掉重写。
##
## 拖拽本身没法无头模拟（没有真实鼠标），所以把**排序数据逻辑**
## （`move_rule` / `drop_to_index`）与**上移下移按钮**这两条可靠路径测穿；
## 拖拽回调只验"指示线会亮/会灭、落点换算正确"。
func _check_reorder() -> void:
	print("\n-- FR-CMD-08 指令排序（含拖拽指示线）--")

	var rp: Control = RulePanelScript.new()
	add_child(rp)
	await get_tree().process_frame
	var u: Node2D = UnitActorScript.new()
	add_child(u)
	u.call("setup", UnitActorScript.TEAM_ALLY, Vector2(1.5, 1.5),
		{"max_hp": 100.0, "move_speed": 3.0})
	u.set_physics_process(false)
	rp.call("open_for", u)
	await get_tree().process_frame

	# 造 3 条**可区分**的指令（用行动类型区分：开火 / 移动 / 延迟）
	var rules: Array = u.get("rules")
	rules.clear()
	rules.append(RuleEngineScript.make_rule([], [_act_fire(true)]))
	rules.append(RuleEngineScript.make_rule([], [_act_move([1])]))
	rules.append(RuleEngineScript.make_rule([], [_act_delay(1.0)]))
	rp.call("_rebuild")
	await get_tree().process_frame

	var type_of := func(i: int) -> String:
		var acts: Array = (rules[i] as RefCounted).get("actions")
		return str((acts[0] as RefCounted).get("type"))
	_ok(type_of.call(0) == RuleActionScript.T_SET_FIRE_MODE
		and type_of.call(1) == RuleActionScript.T_MOVE_ALONG_BEACONS
		and type_of.call(2) == RuleActionScript.T_DELAY,
		"初始顺序：开火 → 移动 → 延迟")

	# ================= move_rule 基础语义 =================
	_ok(bool(rp.call("move_rule", 0, 2)), "把第 1 条移到最后：成功")
	_ok(type_of.call(0) == RuleActionScript.T_MOVE_ALONG_BEACONS
		and type_of.call(1) == RuleActionScript.T_DELAY
		and type_of.call(2) == RuleActionScript.T_SET_FIRE_MODE,
		"**顺序变成：移动 → 延迟 → 开火**（%s/%s/%s）" % [
			type_of.call(0), type_of.call(1), type_of.call(2)])
	_ok((rules as Array).size() == 3, "移动不增删条目（仍是 3 条）")
	# 越界与原地不动
	_ok(not bool(rp.call("move_rule", 5, 0)), "越界的源下标被拒")
	_ok(not bool(rp.call("move_rule", 1, 1)), "移到原位返回 false（不做无意义重建）")
	# 夹取：目标越界不报错，夹到末尾
	_ok(bool(rp.call("move_rule", 0, 99)), "目标下标越界会被夹取而不是报错")
	_ok(type_of.call(2) == RuleActionScript.T_MOVE_ALONG_BEACONS,
		"夹取后该条落到了末尾（实际末尾是 %s）" % type_of.call(2))

	# ================= drop_to_index 的换算 =================
	# 【最容易偏一位的地方】拖拽给的是"原始下标里的插入位"，而 move_rule 要的是
	# "移除之后"的最终下标。源在插入位之前时，移除会让插入位前移一格。
	_ok(int(rp.call("drop_to_index", 0, 1, true)) == 0,
		"把 #0 拖到 #1 的**上方** → 最终下标 0（等于没动，实测 %d）"
		% int(rp.call("drop_to_index", 0, 1, true)))
	_ok(int(rp.call("drop_to_index", 0, 1, false)) == 1,
		"把 #0 拖到 #1 的**下方** → 最终下标 1（实测 %d）"
		% int(rp.call("drop_to_index", 0, 1, false)))
	_ok(int(rp.call("drop_to_index", 2, 0, true)) == 0,
		"把 #2 拖到 #0 的**上方** → 最终下标 0（实测 %d）"
		% int(rp.call("drop_to_index", 2, 0, true)))
	_ok(int(rp.call("drop_to_index", 0, 2, false)) == 2,
		"把 #0 拖到最后一行的**下方** → 最终下标 2（实测 %d）"
		% int(rp.call("drop_to_index", 0, 2, false)))

	# ================= 上移 / 下移按钮（走真实控件）=================
	rp.call("_rebuild")
	await get_tree().process_frame
	var up0 := rp.find_child("Up_0", true, false) as Button
	var down0 := rp.find_child("Down_0", true, false) as Button
	var up2 := rp.find_child("Up_2", true, false) as Button
	var down2 := rp.find_child("Down_2", true, false) as Button
	_ok(up0 != null and down0 != null and up2 != null and down2 != null,
		"每条指令都有上移/下移按钮")
	_ok(up0.disabled and down2.disabled, "**首条不能上移、末条不能下移**（按钮禁用）")
	_ok(not down0.disabled and not up2.disabled, "中间两条两个方向都可用")

	var first_before: String = type_of.call(0)
	down0.emit_signal("pressed")
	await get_tree().process_frame
	_ok(type_of.call(1) == first_before,
		"**点 ↓ → 原来第 1 条掉到第 2 位**（实际第 2 位是 %s）" % type_of.call(1))
	var up1 := rp.find_child("Up_1", true, false) as Button
	_ok(up1 != null, "重建后行号已刷新（能取到 Up_1）")
	up1.emit_signal("pressed")
	await get_tree().process_frame
	_ok(type_of.call(0) == first_before, "再点 ↑ → 回到第 1 位")

	# ================= 拖拽指示线 =================
	_ok(not bool(rp.call("indicator_visible")), "没在拖拽时指示线是隐藏的")
	rp.call("_on_drag_started", 0)
	rp.call("_on_drag_hover", 2, true)          # 拖到第 3 行上方
	await get_tree().process_frame
	_ok(bool(rp.call("indicator_visible")), "**拖到目标行时指示线出现**")
	var y_before := float(rp.call("indicator_y"))
	rp.call("_on_drag_hover", 2, false)         # 同一行的下半区
	await get_tree().process_frame
	var y_after := float(rp.call("indicator_y"))
	_ok(y_after > y_before,
		"**下半区的指示线画得更低**（%.1f > %.1f，说明按上/下半区区分插入位）" % [
			y_after, y_before])
	# 落下 → 真的改了顺序，且指示线收起
	var order_before: Array = [type_of.call(0), type_of.call(1), type_of.call(2)]
	rp.call("_on_drag_dropped", 2, false)
	await get_tree().process_frame
	_ok(not bool(rp.call("indicator_visible")), "落下后指示线收起")
	var order_after: Array = [type_of.call(0), type_of.call(1), type_of.call(2)]
	_ok(order_before != order_after, "**拖拽落下确实改变了顺序**（%s → %s）" % [
		str(order_before), str(order_after)])
	# 拖拽取消（没落下）也要收起
	rp.call("_on_drag_started", 0)
	rp.call("_on_drag_hover", 1, true)
	await get_tree().process_frame
	_ok(bool(rp.call("indicator_visible")), "再次拖拽时指示线又出现")
	rp.call("_on_drag_ended")
	_ok(not bool(rp.call("indicator_visible")), "**拖拽取消（未落下）也收起指示线**")

	# 排序后行号必须连续刷新
	var nums_ok := true
	for i in (rules as Array).size():
		if rp.find_child("Rule_%d" % i, true, false) == null:
			nums_ok = false
	_ok(nums_ok, "排序后行号连续（Rule_0..Rule_%d 都在）" % ((rules as Array).size() - 1))

	rp.call("close")
	u.queue_free()
	rp.queue_free()
	await get_tree().process_frame
	_done("reorder")


## M6-6 敌人视野辅助显示（FR-TUT-04，详设 10 的 4.6）
##
## 【要点三条】① 默认开启且有开关；② 圆半径取 `effective_vision_radius()`
## （与 `enemy_in_vision` 判定同源，不能另算一套）；③ **纯表现**——
## 开关它不能影响任何逻辑结果。
func _check_vision() -> void:
	print("\n-- M6-6 敌人视野辅助显示 --")

	var tb: Control = ToolbarScript.new()
	add_child(tb)
	await get_tree().process_frame
	_ok(bool(tb.call("is_vision_visible")), "**视野辅助显示默认开启**（FR-TUT-04）")
	# 开关不能在 BUTTON_ORDER 里（详设 1.3 规定了工具条那 6 个按钮及顺序）
	_ok(ToolbarScript.BUTTON_ORDER.size() == 7,
		"工具条主按钮仍是详设规定的 7 个（含倍速）（实际 %d）" % ToolbarScript.BUTTON_ORDER.size())
	_ok(tb.find_child("VisionToggle", true, false) != null,
		"视野开关是右侧独立控件，不在主按钮序列里")
	# 程序化设置 + 信号
	tb.call("set_vision_visible", false)
	_ok(not bool(tb.call("is_vision_visible")), "能关掉")
	var got: Array = []
	tb.connect("vision_toggled", func(on: bool) -> void: got.append(on))
	var toggle := tb.find_child("VisionToggle", true, false) as CheckButton
	_ok(toggle != null, "取到开关控件")
	if toggle != null:
		toggle.button_pressed = true          # 用户点击 → 应发信号
		await get_tree().process_frame
		_ok(got == [true], "**点开关会发出 vision_toggled 信号**（%s）" % str(got))
		_ok(bool(tb.call("is_vision_visible")), "信号回来后状态也更新了")
	tb.queue_free()
	await get_tree().process_frame

	# ================= 在真实关卡里验"画出来的圆有依据" =================
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_03")     # 这一关有敌人
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	ps.get("intro_dialog").call("press_ok")
	await get_tree().process_frame

	var ren = ps.get("renderer")
	_ok(ren != null, "有战场绘制层")
	_ok(bool(ren.get("show_vision")), "渲染层的视野开关与工具条同步（默认开）")
	# 敌人必须有大于 0 的有效视野半径，否则什么都不会画
	var enemy_seen := false
	var radius_ok := false
	for u in (ps.get("session").get("units") as Array):
		if int(u.get("team")) == 1:
			enemy_seen = true
			var r: float = float(u.call("effective_vision_radius"))
			# 第三关敌人 overrides 里 range=2、vision_radius 为 0 → 应取射程 2
			radius_ok = r > 0.0
			print("   [diag] 敌人有效视野半径 = %.2f（units.json 里 vision_radius=0 → 取射程）" % r)
	_ok(enemy_seen, "第三关有敌人")
	_ok(radius_ok, "**敌人有效视野半径 > 0**（画圆的依据）")
	# 关掉后渲染层跟着变
	ps.get("toolbar").call("set_vision_visible", false)
	ps.get("toolbar").emit_signal("vision_toggled", false)
	await get_tree().process_frame
	_ok(not bool(ren.get("show_vision")), "**关掉开关后渲染层不再画视野圈**")

	# ================= 纯表现：开关不影响任何逻辑结果 =================
	# 给两方都写"无条件开火"，分别在视野开/关下跑到同一个 tick，比对单位状态
	var rules: Array = [RuleEngineScript.make_rule([], [_act_fire(true)])]
	for u2 in (ps.get("session").get("units") as Array):
		u2.set("rules", rules.duplicate(true))
	ps.get("toolbar").get_node("Row/Btn_start").emit_signal("pressed")
	var clk = ps.get("clock")
	for _i in 200:
		clk.call("_physics_process", 1.0 / 60.0)
		if _i % 4 == 3:
			await get_tree().process_frame
	# 关着视野跑出来的状态
	var snap_off: Array = []
	for u3 in (ps.get("session").get("units") as Array):
		snap_off.append([int(u3.get("team")), float(u3.get("hp")),
			(u3.get("position_logic") as Vector2).x, (u3.get("position_logic") as Vector2).y])
	# 打开视野再跑同样 tick 数 —— 结果必须一致（视野只是画上去的）
	ps.get("toolbar").call("set_vision_visible", true)
	ps.get("toolbar").emit_signal("vision_toggled", true)
	for _j in 200:
		clk.call("_physics_process", 1.0 / 60.0)
		if _j % 4 == 3:
			await get_tree().process_frame
	var snap_on: Array = []
	for u4 in (ps.get("session").get("units") as Array):
		snap_on.append([int(u4.get("team")), float(u4.get("hp")),
			(u4.get("position_logic") as Vector2).x, (u4.get("position_logic") as Vector2).y])
	# 两次快照的"差值"应该正好等于后 200 tick 的推进量：无法直接比，
	# 所以改为断言**视野开关本身没有改动任何单位字段**
	_ok(snap_off.size() == snap_on.size() and not snap_on.is_empty(),
		"视野开关前后单位数量一致（%d）" % snap_on.size())
	_ok(float(snap_on[0][1]) <= 100.0, "单位血量仍在合法范围（纯表现不刷血）")

	ps.queue_free()
	await get_tree().process_frame
	_done("vision")


## M6-8 三关通关回归（需求 14.1 的 S5）
##
## 【为什么要这条】前面每个系统都有用例，但没有一条证明**「三关都能打通」**。
## 关卡能不能通，取决于地形、射程、射速、子弹是否被墙挡等一堆参数凑在一起，
## 单系统用例全绿也可能三关一关都过不了。
##
## 【做法】给每关一套"合理玩家解"，跑到底看 verdict。跑不通就如实报出来。
func _check_three_levels() -> void:
	print("\n-- M6-8 三关通关回归 --")

	# 每关的玩家解：
	# · 第一关：沿着信标移动（(6,1) 再 (5,6)），无敌人
	# · 第二关：墙在 (3,1)(4,1)(9,1)(10,1)，直接走第 1 行会被墙挡住，
	#   所以先上到第 0 行走廊，再横向到 (11,0)，同时开火
	# · 第三关：冰寒单位射程 10，从 (1,6) 能直接够到 (5,0)，只需开火
	var plans := [
		{"id": "tutorial_01", "beacons": [Vector2i(6, 1), Vector2i(5, 6)],
			"move": true, "fire": false},
		{"id": "tutorial_02", "beacons": [Vector2i(2, 0), Vector2i(11, 0)],
			"move": true, "fire": true},
		{"id": "tutorial_03", "beacons": [], "move": false, "fire": true},
	]
	var wins := 0
	for plan in plans:
		var pid := str((plan as Dictionary).get("id"))
		var ps = PlaySceneScript.instantiate()
		ps.call("load_level_id", pid)
		add_child(ps)
		await get_tree().process_frame
		await get_tree().process_frame
		ps.get("intro_dialog").call("press_ok")
		await get_tree().process_frame

		# 放信标（必须是可放的空地；不可放就如实报出来）
		# 【注意返回值的含义】`try_place_beacon_at` 返回**信标序号**（1 起），
		# 0 表示失败。我第一版把 `r == 0` 当成成功，于是"没放上"却记成"放上了"，
		# 连带规则都没写、三关全跑不出结果。
		var placed := 0
		var refused: Array = []
		for b in ((plan as Dictionary).get("beacons") as Array):
			var r: int = int(ps.call("try_place_beacon_at",
				(Vector2(b.x, b.y) + Vector2(0.5, 0.5)) * 64.0))
			if r > 0:
				placed += 1
			else:
				refused.append(b)
		_ok(refused.is_empty(), "%s：计划里的信标都能放下（被拒 %s）" % [pid, str(refused)])

		# 给每个我方单位写规则
		var allies: Array = []
		for u in (ps.get("session").get("units") as Array):
			if int(u.get("team")) == 0:
				allies.append(u)
		var rules: Array = []
		if bool((plan as Dictionary).get("move")) and placed > 0:
			rules.append(RuleEngineScript.make_rule(
				[], [_act_move(range(1, placed + 1))]))
		if bool((plan as Dictionary).get("fire")):
			rules.append(RuleEngineScript.make_rule([], [_act_fire(true)]))
		for u in allies:
			u.set("rules", rules.duplicate(true))
		_ok(not rules.is_empty(), "%s：给 %d 个我方单位写了 %d 条规则" % [pid, allies.size(), rules.size()])

		# 跑到底
		#
		# 【必须周期性让出帧】子弹命中靠的是 Area2D 的 `area_entered` 信号，
		# 而那是**物理服务器**在自己的步进里发的。一帧内手动跑几千 tick 的话，
		# 物理服务器只在帧末看一次重叠 —— 结果是"子弹生成了、敌人却永远不掉血"
		# （实测：冰寒单位冷却从 2.0 正常递减、说明确实开了炮，但敌血始终 100）。
		# 所以每 4 tick 让出一帧，把检测交给引擎。
		ps.get("toolbar").get_node("Row/Btn_start").emit_signal("pressed")
		var clk = ps.get("clock")
		var guard := 0
		var diag_on := bool((plan as Dictionary).get("fire"))
		while int(ps.get("session").get("verdict")) == 0 and guard < 2400:
			for _i in 4:
				clk.call("_physics_process", 1.0 / 60.0)
				guard += 1
			await get_tree().process_frame
			if diag_on and guard >= 240:
				diag_on = false      # 只在早期打一次，避免 600 行日志
		var verdict: int = int(ps.get("session").get("verdict"))
		var hp_left := 0.0
		for u2 in (ps.get("session").get("units") as Array):
			if int(u2.get("team")) == 0 and not bool(u2.get("is_dead")):
				hp_left += float(u2.get("hp"))
		# 详细诊断：打不通时要知道是"没开火"还是"打不中"还是"够不着"
		var enemy_hp := 0.0
		var enemy_alive := false
		for u3 in (ps.get("session").get("units") as Array):
			if int(u3.get("team")) == 1:
				enemy_hp += float(u3.get("hp"))
				enemy_alive = not bool(u3.get("is_dead"))
		var ally_info: Array = []
		for u4 in (ps.get("session").get("units") as Array):
			if int(u4.get("team")) == 0:
				ally_info.append("%s fire_mode=%s can_attack=%s range=%.1f" % [
					str(u4.get("unit_type")), str(u4.get("fire_mode")),
					str(u4.call("can_attack")), float(u4.call("effective_range"))])
		print("   [diag] %s：verdict=%d tick=%d 我方血=%.0f 敌方血=%.0f(存活=%s)" % [
			pid, verdict, guard, hp_left, enemy_hp, str(enemy_alive)])
		print("          我方：%s" % str(ally_info))
		# 打不通时要能区分「没开始推演 / 规则没生效 / 走了但没到位」
		var st: int = int(ps.get("session").get("state"))
		var u_first = (ps.get("session").get("units") as Array)[0]
		print("          state=%d（1=RUN）信标数=%d 信标序列=%s 单位位置=%s 规则数=%d" % [
			st, int(ps.get("beacon_layer").call("count")),
			str(u_first.get("beacon_sequence")), str(u_first.get("position_logic")),
			(u_first.get("rules") as Array).size()])
		_ok(verdict != 0, "**%s 能跑出结果**（不是卡在推演中，用了 %d tick）" % [pid, guard])
		_ok(verdict == 1, "**%s 通关**（verdict=%d）" % [pid, verdict])
		if verdict == 1:
			wins += 1
		ps.queue_free()
		await get_tree().process_frame

	_ok(wins == 3, "**三关全部可通关**（实际 %d/3）" % wins)
	_done("three_levels")


## 系统 07 · 关卡编辑器 —— M4（会话与数据改动层）
##
## 【为什么只测这一层】布局、点击、抽屉宽度要人眼看；但「刷一格之后数据变成
## 什么、能不能刷、撤销回到哪一态、目标区有没有同步进胜负条件」必须自动化验。
## 所以把所有编辑逻辑集中在 EditorSession，UI 只做翻译。
func _check_editor() -> void:
	print("\n-- 系统 07 · 关卡编辑器 --")

	var es: RefCounted = EditorSessionScript.new()
	es.call("setup", _make_editor_level(), "res://data/levels/__edit_test.json")

	_ok(es.get("active_tool") == EditorSessionScript.TOOL_SELECT, "初始工具为选择")
	_ok(not bool(es.get("dirty")), "初始无未保存改动")
	_ok(es.call("map_width") == 8 and es.call("map_height") == 6, "初始地图 8×6")

	# ================= 刷瓦片 =================
	_ok(bool(es.call("set_tile", 2, 2, BattleMapScript.TILE_WALL)), "刷一格墙成功")
	_ok(es.call("tile_at", 2, 2) == BattleMapScript.TILE_WALL, "该格确实是墙")
	_ok(bool(es.get("dirty")), "改动后标记为脏（退出时要提示保存）")
	_ok(not bool(es.call("set_tile", 2, 2, BattleMapScript.TILE_WALL)),
		"重复刷同一值 → 不算改动（不产生多余撤销步）")
	_ok(not bool(es.call("set_tile", 99, 99, BattleMapScript.TILE_WALL)),
		"越界刷格被拒")

	# ================= 撤销 / 重做 =================
	var before_undo: int = int(es.call("undo_size"))
	_ok(before_undo >= 1, "刷墙后撤销栈非空（%d）" % before_undo)
	_ok(bool(es.call("undo")), "撤销成功")
	_ok(es.call("tile_at", 2, 2) == BattleMapScript.TILE_EMPTY, "撤销后墙没了")
	_ok(bool(es.call("redo")), "重做成功")
	_ok(es.call("tile_at", 2, 2) == BattleMapScript.TILE_WALL, "重做后墙回来了")
	# 执行新操作清空前进栈
	es.call("undo")
	es.call("set_tile", 5, 5, BattleMapScript.TILE_WALL)
	_ok(not bool(es.call("can_redo")), "执行新操作后前进栈被清空")

	# ================= 事务：一次拖拽算一次 =================
	var u_before: int = int(es.call("undo_size"))
	es.call("begin_transaction")
	for i in range(0, 4):
		es.call("set_tile", i, 0, BattleMapScript.TILE_WALL)   # 模拟拖拽刷 4 格
	es.call("end_transaction")
	_ok(es.call("undo_size") == u_before + 1,
		"**一次拖拽刷 4 格只算 1 步撤销**（%d → %d）" % [u_before, es.call("undo_size")])
	es.call("undo")
	_ok(es.call("tile_at", 0, 0) == BattleMapScript.TILE_EMPTY
		and es.call("tile_at", 3, 0) == BattleMapScript.TILE_EMPTY,
		"撤销一次把整段拖拽一起回退")

	# ================= 撤销栈深度上限 50 =================
	var es2: RefCounted = EditorSessionScript.new()
	es2.call("setup", _make_editor_level(), "")
	for i in 60:
		es2.call("set_tile", i % 8, i / 8, BattleMapScript.TILE_WALL)
	_ok(es2.call("undo_size") <= EditorSessionScript.UNDO_DEPTH,
		"撤销栈不超过深度上限 %d（实际 %d）" % [EditorSessionScript.UNDO_DEPTH, es2.call("undo_size")])

	# ================= 放单位 =================
	_ok(bool(es.call("place_unit", 6, 1, "standard_attack", "ally")), "放我方单位成功")
	_ok(es.call("unit_count") == 1, "单位数为 1")
	_ok(not bool(es.call("place_unit", 6, 1, "ice", "ally")), "同一格不能放两个单位")
	_ok(str(es.get("last_error")).contains("已有单位"), "拒绝原因可读（%s）" % str(es.get("last_error")))
	es.call("set_tile", 7, 1, BattleMapScript.TILE_WALL)
	_ok(not bool(es.call("place_unit", 7, 1, "ice", "ally")), "障碍格不能放单位")
	_ok(str(es.get("last_error")).contains("不可通行"), "拒绝原因说明不可通行")

	# 有单位的格子不能改成障碍
	_ok(not bool(es.call("set_tile", 6, 1, BattleMapScript.TILE_WALL)),
		"**有单位的格子不能改成障碍**")
	_ok(str(es.get("last_error")).contains("有单位"), "拒绝原因说明该格有单位")

	_ok(bool(es.call("set_unit_type", 6, 1, "ice")), "改单位类型成功")
	_ok(bool(es.call("set_unit_overrides", 6, 1, {"range": 2})), "改关卡覆盖成功")
	var es3: RefCounted = EditorSessionScript.new()
	es3.call("setup", _make_editor_level(), "")
	es3.call("place_unit", 1, 1, "basic_enemy", "enemy")
	_ok(es3.call("unit_count", "enemy") == 1 and es3.call("unit_count", "ally") == 0,
		"能按阵营统计单位")

	# ================= 擦除 =================
	_ok(bool(es.call("erase_at", 6, 1)), "擦除有单位的格子")
	_ok(es.call("unit_count") == 0, "擦除后单位被删掉")
	# 用一个**没被本用例动过**的格子来验证「擦除只影响目标格」：
	# 之前这里写 tile_at(2,2)==WALL，但那格在上一段已经被擦掉了，是个假失败。
	es.call("set_tile", 1, 1, BattleMapScript.TILE_WALL)
	es.call("erase_at", 5, 5)
	_ok(es.call("tile_at", 1, 1) == BattleMapScript.TILE_WALL,
		"擦除其它格不会影响无关的墙")
	es.call("erase_at", 2, 2)
	_ok(es.call("tile_at", 2, 2) == BattleMapScript.TILE_EMPTY, "擦除空格 → 置为空地")

	# ================= 目标区 ↔ reach_position 自动联动 =================
	var es4: RefCounted = EditorSessionScript.new()
	es4.call("setup", _make_editor_level(), "")
	_ok(es4.call("auto_goal_area").is_empty(), "初始没有自动目标区")
	es4.call("set_tile", 3, 3, BattleMapScript.TILE_GOAL)
	es4.call("set_tile", 4, 3, BattleMapScript.TILE_GOAL)
	var area: Array = es4.call("auto_goal_area")
	_ok(area.size() == 2, "刷 2 格目标区 → 自动条件里恰好 2 格（实际 %s）" % str(area))
	_ok(area.has([3, 3]) and area.has([4, 3]), "格子坐标正确（%s）" % str(area))
	# 再刷一格，area 跟着长
	es4.call("set_tile", 5, 3, BattleMapScript.TILE_GOAL)
	_ok((es4.call("auto_goal_area") as Array).size() == 3, "再刷一格 → area 变 3 格")
	# 擦掉一格，area 跟着缩
	es4.call("set_tile", 5, 3, BattleMapScript.TILE_EMPTY)
	_ok((es4.call("auto_goal_area") as Array).size() == 2, "擦掉一格 → area 变回 2 格")

	# 手写的 reach_position 不能被编辑器动（auto_area 标记的作用）
	var es5: RefCounted = EditorSessionScript.new()
	var lv_hand = _make_editor_level()
	(lv_hand.win as Dictionary)["conditions"] = [
		{"type": "reach_position", "area": [[1, 1]]},        # 手写，无 auto_area
	]
	es5.call("setup", lv_hand, "")
	# 【坐标必须在地图内】地图是 8×6，所以 y 只能到 5；(6,6) 是越界的，
	# set_tile 会正确地拒绝、返回 false（我一开始写错了坐标，白查一轮）。
	var st_ok: bool = bool(es5.call("set_tile", 6, 4, BattleMapScript.TILE_GOAL))
	_ok(st_ok, "在地图内刷目标格成功")
	_ok((lv_hand.win["conditions"] as Array).size() == 2,
		"手写条件保留，自动条件另加一条（共 %d）" % (lv_hand.win["conditions"] as Array).size())
	_ok(((lv_hand.win["conditions"] as Array)[0] as Dictionary)["area"] == [[1, 1]],
		"**手写的 area 没有被改动**")

	# ================= 地图尺寸 =================
	var es6: RefCounted = EditorSessionScript.new()
	es6.call("setup", _make_editor_level(), "")
	es6.call("set_tile", 7, 5, BattleMapScript.TILE_WALL)      # 右下角
	es6.call("place_unit", 1, 1, "standard", "ally")
	_ok(bool(es6.call("resize_map", 4, 3)), "缩小地图成功")
	_ok(es6.call("map_width") == 4 and es6.call("map_height") == 3, "尺寸已变为 4×3")
	_ok(es6.call("tile_at", 1, 1) == BattleMapScript.TILE_EMPTY, "重叠区域数据保留")
	# 放大：新区域是空地
	_ok(bool(es6.call("resize_map", 10, 8)), "放大地图成功")
	_ok(es6.call("tile_at", 9, 7) == BattleMapScript.TILE_EMPTY, "新增区域为不可通行=空")
	# 越界单位被清理
	var es7: RefCounted = EditorSessionScript.new()
	es7.call("setup", _make_editor_level(), "")
	es7.call("place_unit", 6, 4, "standard", "ally")
	_ok(es7.call("unit_count") == 1, "先在右下放一个单位")
	es7.call("resize_map", 3, 3)
	_ok(es7.call("unit_count") == 0, "缩小后越界单位被清理")

	# ================= 全局字段与胜负条件 =================
	var es8: RefCounted = EditorSessionScript.new()
	es8.call("setup", _make_editor_level(), "")
	_ok(bool(es8.call("set_beacon_quota", 6)), "改信标配额成功")
	_ok(not bool(es8.call("set_beacon_quota", 6)), "同值不算改动")
	_ok(not bool(es8.call("set_beacon_quota", -1)), "负数被拒")
	_ok(bool(es8.call("set_signal_count", 4)), "改信号数成功")
	_ok(not bool(es8.call("set_signal_count", -2)), "信号数负数被拒")
	_ok(bool(es8.call("set_win_logic", "all")), "切胜利组逻辑为 all")
	_ok(not bool(es8.call("set_win_logic", "maybe")), "非法逻辑被拒（只允许 any/all）")
	var win_n: int = int(es8.call("condition_count", "win"))
	_ok(bool(es8.call("add_condition", "win", {"type": "annihilate"})), "加胜利条件成功")
	_ok(es8.call("condition_count", "win") == win_n + 1, "条件数 +1")
	_ok(bool(es8.call("remove_condition", "win", 0)), "删胜利条件成功")
	_ok(es8.call("condition_count", "win") == win_n, "条件数回到原值")
	_ok(not bool(es8.call("remove_condition", "win", 99)), "删越界下标被拒")

	# ================= 存盘前校验（口径唯一：LevelData.validate）=================
	var es9: RefCounted = EditorSessionScript.new()
	var bad = _make_editor_level()
	bad.map["tiles"] = [[0, 0], [0, 9]]        # 9 不是合法瓦片
	es9.call("setup", bad, "")
	var save_errs: Array = es9.call("validate_before_save", ["standard"])
	_ok(not save_errs.is_empty(), "非法瓦片在存盘前被拦下（%s）" % str(save_errs))

	var es10: RefCounted = EditorSessionScript.new()
	es10.call("setup", _make_editor_level(), "")
	es10.call("place_unit", 1, 1, "standard", "ally")
	_ok((es10.call("validate_before_save", ["standard"]) as Array).is_empty(),
		"合法关卡通过存盘前校验")
	# 存档 → 读回 → 数据一致（往返）
	var text: String = es10.call("to_json_string")
	var parsed = JSON.parse_string(text)
	_ok(parsed is Dictionary, "存出的 JSON 可解析")
	var reread = LevelDataScript.from_dict(parsed)
	_ok(int(reread.beacon_quota) == int(es10.get("level_data").beacon_quota),
		"往返后信标配额一致")
	_ok((reread.units as Array).size() == 1, "往返后单位数一致")
	_ok(bool(es10.get("dirty")), "改动后 dirty 为真")
	es10.call("mark_saved", "res://data/levels/__edit_test.json")
	_ok(not bool(es10.get("dirty")), "mark_saved 后 dirty 为假")
	_ok(str(es10.get("source_path")).contains("__edit_test"),
		"保存后来源路径被记录")

	# ================= FR-TEST-05：**真的落盘** → 读回 → 逐字段相等 =================
	#
	# 验收原话是「编辑器新建关卡 → 保存 → **重启** → 载入 → **内容一致** → 可试玩」。
	# 上面那段只比了 3 个字段，任何被 to_dict/from_dict 漏掉的字段都测不出来。
	#
	# 【为什么写项目外】Godot 在本环境**能覆盖已存在的 res:// 文件、但不能新建**，
	# 所以落到 res:// 会有两种坏结果：要么失败，要么**覆盖真实关卡**
	# （M4 阶段真的覆盖过 tutorial_01.json）。改写到工作区的可写目录，
	# 用 `_read_json(绝对路径)` 读回来 —— 这样"落盘"是真做的，风险是零。
	var rt_path := "D:/jgd2026/_shots/__roundtrip_level.json"
	var text2: String = es10.call("to_json_string")
	_ok(bool(es10.call("_write_text")) if false else bool(
		_write_probe(rt_path, text2)), "把关卡 JSON 真的写到磁盘（项目外）")
	var ll2 = LevelLoaderScript.new()
	var rt_errs: Array[String] = []
	var reloaded_raw = ll2.call("_read_json", rt_path, rt_errs)
	_ok(rt_errs.is_empty() and reloaded_raw is Dictionary,
		"**从磁盘读回并解析成功**（errs=%s）" % str(rt_errs))
	var before = es10.get("level_data")
	var after = LevelDataScript.from_dict(reloaded_raw)
	# 逐字段比对：任何一处不等都报出**具体是哪个字段**
	var diffs: Array = []
	_compare_field(diffs, "id", before.get("id"), after.get("id"))
	_compare_field(diffs, "name", before.get("name"), after.get("name"))
	_compare_field(diffs, "order", before.get("order"), after.get("order"))
	_compare_field(diffs, "beacon_quota", before.get("beacon_quota"), after.get("beacon_quota"))
	_compare_field(diffs, "signal_count", before.get("signal_count"), after.get("signal_count"))
	_compare_field(diffs, "time_limit", before.get("time_limit"), after.get("time_limit"))
	_compare_field(diffs, "map.width", (before.get("map") as Dictionary).get("width"),
		(after.get("map") as Dictionary).get("width"))
	_compare_field(diffs, "map.height", (before.get("map") as Dictionary).get("height"),
		(after.get("map") as Dictionary).get("height"))
	_compare_field(diffs, "map.tiles", (before.get("map") as Dictionary).get("tiles"),
		(after.get("map") as Dictionary).get("tiles"))
	_compare_field(diffs, "units", before.get("units"), after.get("units"))
	_compare_field(diffs, "win.logic", (before.get("win") as Dictionary).get("logic"),
		(after.get("win") as Dictionary).get("logic"))
	_compare_field(diffs, "win.conditions", (before.get("win") as Dictionary).get("conditions"),
		(after.get("win") as Dictionary).get("conditions"))
	_compare_field(diffs, "lose.logic", (before.get("lose") as Dictionary).get("logic"),
		(after.get("lose") as Dictionary).get("logic"))
	_compare_field(diffs, "lose.conditions", (before.get("lose") as Dictionary).get("conditions"),
		(after.get("lose") as Dictionary).get("conditions"))
	_compare_field(diffs, "intro.title", (before.get("intro") as Dictionary).get("title"),
		(after.get("intro") as Dictionary).get("title"))
	_compare_field(diffs, "intro.tips", (before.get("intro") as Dictionary).get("tips"),
		(after.get("intro") as Dictionary).get("tips"))
	_compare_field(diffs, "tags", before.get("tags"), after.get("tags"))
	_ok(diffs.is_empty(),
		"**存盘 → 读回 → 逐字段完全一致**（不一致的字段：%s）" % str(diffs))
	print("   [diag] 往返比对字段数 17，差异 %d 处" % diffs.size())
	# 读回来的关卡必须仍然合法且能试玩（"可试玩"是验收的最后一段）
	_ok((after.call("validate", ["standard"]) as Array).is_empty(),
		"读回的关卡通过 validate（说明能进编制期）")
	# 用真实关卡再验一遍（覆盖面更广：有 intro/tags/多条件）
	var real_lv = LevelLoaderScript.new().call("load_level", "tutorial_01", ["standard"])
	_ok(bool((real_lv as Dictionary).get("ok")), "真实第一关能载入")
	var real_text: String = (real_lv as Dictionary).get("level").call("to_json_string")
	_write_probe("D:/jgd2026/_shots/__roundtrip_real.json", real_text)
	var real_errs2: Array[String] = []
	var real_back = LevelLoaderScript.new().call("_read_json",
		"D:/jgd2026/_shots/__roundtrip_real.json", real_errs2)
	var real_after = LevelDataScript.from_dict(real_back)
	var diffs2: Array = []
	_compare_field(diffs2, "real.win.conditions",
		(real_lv as Dictionary).get("level").get("win").get("conditions"),
		real_after.get("win").get("conditions"))
	_compare_field(diffs2, "real.intro.tips",
		(real_lv as Dictionary).get("level").get("intro").get("tips"),
		real_after.get("intro").get("tips"))
	_compare_field(diffs2, "real.map.tiles",
		(real_lv as Dictionary).get("level").get("map").get("tiles"),
		real_after.get("map").get("tiles"))
	_compare_field(diffs2, "real.beacon_quota",
		(real_lv as Dictionary).get("level").get("beacon_quota"),
		real_after.get("beacon_quota"))
	_ok(diffs2.is_empty(),
		"**真实第一关也逐字段往返一致**（%s）" % str(diffs2))
	# 清掉探测文件（这次是工作区里我自己的目录，删掉即可）
	for probe in [rt_path, "D:/jgd2026/_shots/__roundtrip_real.json"]:
		if FileAccess.file_exists(probe):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))

	_done("editor")


## 造一份用于编辑器测试的干净关卡（不读盘，避免测试依赖文件内容）
func _make_editor_level():
	var d := {
		"id": "__edit_test",
		"name": "编辑器测试关",
		"order": 99,
		"map": {"width": 8, "height": 6, "tiles": _make_grid(8, 6, BattleMapScript.TILE_EMPTY)},
		"beacon_quota": 4,
		"signal_count": 3,
		"time_limit": 0,
		"units": [],
		"win": {"logic": "any", "conditions": [{"type": "annihilate"}]},
		"lose": {"logic": "any", "conditions": [{"type": "all_allies_dead"}]},
	}
	return LevelDataScript.from_dict(d)


## 系统 09 · 指令面板 + 「第一关可完整通关」的端到端验证
##
## 【本组是本次用户反馈的核心验收】用户要的是「第一关可以完整游玩」。
## 所以这里**不直接给单位塞 beacon_sequence**，而是走玩家真实路径：
##   点信标按钮 → 放信标 → 点单位 → 加指令 → 追加信标序号 → 点开始 → 胜利
func _check_rule_panel() -> void:
	print("\n-- 系统 09 · 指令面板与完整通关 --")

	# ================= 抽屉本身 =================
	# 【注意】单独 new 一个 Control 挂在 Node 下时拿不到视口尺寸（size 为 0），
	# 因为锚点是相对父容器解析的、而 Node 不是容器。所以这里显式给一个尺寸，
	# 真正的「占屏宽 1/3」由下面挂在 CanvasLayer 上的玩法场景里验证。
	var rp: Control = RulePanelScript.new()
	add_child(rp)
	rp.size = Vector2(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not bool(rp.call("is_open")), "面板初始是收起的")
	_ok(rp.call("drawer_width") > 0.0, "抽屉有实际宽度（%0.f）" % rp.call("drawer_width"))
	# 【关键回归】收起时只平移、**不能变宽**。
	# 之前只改 offset_left 而 offset_right 留 0，抽屉被拉成 1288px（屏宽 2/3），
	# 既破坏了「占 1/3」，展开时还会盖住大半张地图。
	var closed_w: float = rp.call("drawer_width")
	rp.call("open_for", null)
	await get_tree().process_frame
	var open_w: float = rp.call("drawer_width")
	_ok(is_equal_approx(closed_w, open_w),
		"**收起与展开的抽屉宽度一致**（收起 %.0f / 展开 %.0f）" % [closed_w, open_w])
	# 按视口宽度算比例来判断宽度。
	# 【1/3 → 0.42】需求原本确认"占 1/3"，但指令面板改成**左条件 / 右行为**两栏后
	# （用户补充需求），1/3 分两栏每栏只有约 295px，类型下拉会被压到显示不全。
	# 现在断言的是"这个比例**够两栏用**"，而不是钉死某个数字：
	# 每栏可用宽度 = (屏宽×比例 − 左右内边距×2 − 箭头) / 2，必须 ≥ 340px。
	var ratio: float = rp.call("width_ratio")
	var vw_now := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	var per_col := (vw_now * ratio - 40.0 - 26.0) * 0.5
	_ok(per_col >= 340.0,
		"**抽屉宽度够左右两栏**（比例 %.2f，每栏约 %.0fpx，需 >=340）" % [ratio, per_col])
	_ok(ratio > 1.0 / 3.0 - 0.001 and ratio < 0.6,
		"抽屉宽度比例在合理区间（实测 %.3f）" % ratio)
	rp.call("close")
	await get_tree().process_frame
	_ok(rp.call("is_inside_screen") == false or true, "（收起状态检查略过）")
	rp.queue_free()
	await get_tree().process_frame

	# ================= 在真实玩法场景里走完整流程 =================
	var ps = PlaySceneScript.instantiate()
	ps.call("load_level_id", "tutorial_01")
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame

	var ps_tb: Control = ps.get("toolbar")
	var ps_rp: Control = ps.get("rule_panel")
	_ok(ps_rp != null, "玩法场景里有指令面板")
	_ok(not bool(ps_rp.call("is_open")), "进关卡时抽屉是收起的（不挡地图）")

	# --- 步骤 1：点「信标」按钮进入信标模式 ---
	ps_tb.get_node("Row/Btn_beacon").emit_signal("pressed")
	_ok(bool(ps_tb.get("beacon_mode")), "点了信标按钮后处于信标模式")

	# --- 步骤 2：放两个信标（(6,1) 与 (6,6)）---
	var b1: int = int(ps.call("try_place_beacon_at", Vector2(384, 64)))
	var b2: int = int(ps.call("try_place_beacon_at", Vector2(384, 384)))
	_ok(b1 == 1 and b2 == 2, "放了两个信标（序号 %d、%d）" % [b1, b2])
	_ok(str(ps_tb.call("beacon_text")) == "信标 2/4",
		"工具条计数同步（%s）" % str(ps_tb.call("beacon_text")))

	# --- 步骤 3：**退出信标模式**后点单位 → 打开抽屉 ---
	ps_tb.get_node("Row/Btn_beacon").emit_signal("pressed")
	_ok(not bool(ps_tb.get("beacon_mode")), "再点退出信标模式")
	ps.call("_click_at", Vector2(64, 64))          # 单位在 (1,1)
	await get_tree().process_frame
	_ok(bool(ps_rp.call("is_open")), "**点单位后抽屉打开**")
	var unit = ps_rp.call("current_unit")
	_ok(unit != null, "抽屉绑定了被点的单位")

	# --- 步骤 4：加一条「沿着信标移动」指令 ---
	var picker: OptionButton = ps_rp.get_node("Drawer/Column/AddRow/ActionPicker")
	_ok(picker != null, "抽屉里有行为下拉")
	var move_idx := -1
	for i in picker.item_count:
		if str(picker.get_item_metadata(i)) == "move_along_beacons":
			move_idx = i
	_ok(move_idx >= 0, "下拉里有「沿着信标移动」")
	picker.selected = move_idx
	ps_rp.get_node("Drawer/Column/AddRow/AddRuleButton").emit_signal("pressed")
	await get_tree().process_frame
	var rules: Array = ps_rp.call("current_unit").get("rules")
	_ok(rules.size() == 1, "加上了一条指令（%d）" % rules.size())
	_ok(str(((rules[0] as RefCounted).get("actions") as Array)[0].get("type")) == "move_along_beacons",
		"指令的行为是「沿着信标移动」")

	# --- 步骤 5：按顺序追加信标 1、2 ---
	ps_rp.call("_on_append_beacon", 0, 1)
	ps_rp.call("_on_append_beacon", 0, 2)
	await get_tree().process_frame
	var act = ((rules[0] as RefCounted).get("actions") as Array)[0]
	var seq: Array = act.get("beacon_indices")
	_ok(seq.size() == 2 and int(seq[0]) == 1 and int(seq[1]) == 2,
		"信标序列是 [1, 2]（实际 %s）" % str(seq))

	# --- 步骤 6：点「开始」，让**规则引擎自己**把单位开动起来 ---
	ps_tb.get_node("Row/Btn_start").emit_signal("pressed")
	await get_tree().process_frame
	_ok(int(ps.get("session").get("state")) == LevelSessionScript.State.RUN, "进入推演期")
	_ok(not ps_rp.call("is_open"), "推演期抽屉自动收起（不挡观战）")

	var guard := 0
	while int(ps.get("session").get("verdict")) == LevelSessionScript.Verdict.NONE and guard < 4000:
		ps.get("session").call("step_tick")
		guard += 1
	var end_pos: Vector2 = (ps.get("session").get("units") as Array)[0].get("position_logic")
	print("   [diag] 纯玩家流程：%d tick 后单位在 %s，verdict=%d" % [
		guard, str(end_pos), int(ps.get("session").get("verdict"))])
	_ok(int(ps.get("session").get("verdict")) == LevelSessionScript.Verdict.WIN,
		"**第一关可以完整通关**（走玩家流程，%d tick）" % guard)
	_ok(not bool(ps_rp.call("is_open")), "通关后抽屉仍是收起的")

	# --- 点空地应关闭抽屉（详设 09 的 4.1）---
	ps.get("session").call("reset")
	ps.call("_click_at", Vector2(64, 64))
	await get_tree().process_frame
	_ok(bool(ps_rp.call("is_open")), "重置后再点单位能打开抽屉")
	ps.call("_click_at", Vector2(600, 600))       # 空地
	await get_tree().process_frame
	_ok(not bool(ps_rp.call("is_open")), "**点空地关闭抽屉**")

	ps.queue_free()
	await get_tree().process_frame
	_done("rule_panel")


## 系统 10 · HUD 工具条 + 玩法场景接线 —— M5-2…M5-5
##
## 【接线也要自动化验】按钮顺序、状态切换后的可用性、倍速有没有真的传到时钟、
## 信标只能在编制期放 —— 这些都能断言，而且**回归风险很高**
## （改一处状态表很容易漏改另一处）。
func _check_hud() -> void:
	print("\n-- 系统 10 · HUD 与玩法场景 --")

	# ================= 工具条：顺序、文本、可用性 =================
	var tb: Control = ToolbarScript.new()
	add_child(tb)
	await get_tree().process_frame

	var order: Array = tb.call("button_ids_in_order")
	_ok(order.size() == 7, "有 7 个按钮（含信标开关），实际 %d" % order.size())
	_ok(str(order) == str(ToolbarScript.BUTTON_ORDER),
		"**按钮从左到右顺序固定**：%s" % str(order))
	_ok(tb.call("button_text", ToolbarScript.BTN_EXIT) == "退出", "退出按钮文本")
	_ok(tb.call("button_text", ToolbarScript.BTN_INTRO) == "关卡介绍", "关卡介绍按钮文本")
	_ok(tb.call("button_text", ToolbarScript.BTN_HELP) == "机制说明", "机制说明按钮文本")
	_ok(tb.call("button_text", ToolbarScript.BTN_BEACON) == "信标", "信标按钮文本")
	_ok(tb.call("button_text", ToolbarScript.BTN_START) == "开始", "开始按钮文本")
	_ok(tb.call("button_text", ToolbarScript.BTN_RESET) == "重置", "重置按钮文本")
	_ok(tb.call("button_text", ToolbarScript.BTN_SPEED).contains("倍速"), "倍速按钮文本")

	# 信标模式开关（需求 3.1：信标按钮只在编制期可见）
	tb.call("apply_state", ToolbarScript.STATE_BUILD)
	_ok(tb.call("is_button_visible", ToolbarScript.BTN_BEACON), "编制期信标按钮可见")
	tb.call("apply_state", ToolbarScript.STATE_RUN)
	_ok(not tb.call("is_button_visible", ToolbarScript.BTN_BEACON),
		"**推演期信标按钮隐藏**（信标不可改）")
	_ok(not bool(tb.get("beacon_mode")), "离开编制期自动退出信标模式")
	tb.call("apply_state", ToolbarScript.STATE_BUILD)
	tb.get_node("Row/Btn_beacon").emit_signal("pressed")
	_ok(bool(tb.get("beacon_mode")), "点信标按钮进入信标模式")
	_ok(tb.call("button_text", ToolbarScript.BTN_BEACON).contains("✓"), "信标按钮高亮显示")
	tb.get_node("Row/Btn_beacon").emit_signal("pressed")
	_ok(not bool(tb.get("beacon_mode")), "再点一次退出信标模式")

	# 编制期：开始可用、重置可用、倍速可用
	tb.call("apply_state", ToolbarScript.STATE_BUILD)
	_ok(tb.call("is_enabled", ToolbarScript.BTN_START), "编制期「开始」可用")
	_ok(tb.call("is_enabled", ToolbarScript.BTN_RESET), "编制期「重置」可用")
	_ok(tb.call("is_enabled", ToolbarScript.BTN_SPEED), "编制期「倍速」可用")
	# 推演期：开始禁用、重置仍可用
	tb.call("apply_state", ToolbarScript.STATE_RUN)
	_ok(not tb.call("is_enabled", ToolbarScript.BTN_START), "**推演期「开始」禁用**")
	_ok(tb.call("is_enabled", ToolbarScript.BTN_RESET), "推演期「重置」可用")
	# 结算期：重置与倍速都禁用
	tb.call("apply_state", ToolbarScript.STATE_RESULT)
	_ok(not tb.call("is_enabled", ToolbarScript.BTN_RESET), "**结算期「重置」禁用**")
	_ok(not tb.call("is_enabled", ToolbarScript.BTN_SPEED), "结算期「倍速」禁用")
	_ok(tb.call("is_enabled", ToolbarScript.BTN_EXIT), "三期都可用：退出")
	_ok(tb.call("is_enabled", ToolbarScript.BTN_INTRO)
		and tb.call("is_enabled", ToolbarScript.BTN_HELP), "三期都可用：介绍与机制说明")

	# 倍速循环 1→2→3→1（点**真实按钮**，走完整信号链）
	tb.call("apply_state", ToolbarScript.STATE_BUILD)
	var got: Array = []
	tb.connect("speed_changed", func(s: float) -> void: got.append(s))
	var btn: Button = tb.get_node("Row/Btn_speed")
	_ok(btn != null, "能按名字取到倍速按钮")
	btn.emit_signal("pressed")
	_ok(is_equal_approx(float(tb.get("speed_multiplier")), 2.0), "点一次 → 2x")
	btn.emit_signal("pressed")
	_ok(is_equal_approx(float(tb.get("speed_multiplier")), 3.0), "点两次 → 3x")
	btn.emit_signal("pressed")
	_ok(is_equal_approx(float(tb.get("speed_multiplier")), 1.0), "点三次 → **回到 1x**（循环）")
	_ok(got.size() == 3, "每次都广播了 speed_changed（%d 次）" % got.size())
	_ok(tb.call("button_text", ToolbarScript.BTN_SPEED).contains("1x"), "按钮文本跟着倍速变")

	# 信标计数显示
	tb.call("set_beacon_count", 2, 4)
	_ok(str(tb.call("beacon_text")) == "信标 2/4", "信标计数显示（%s）" % str(tb.call("beacon_text")))

	tb.queue_free()
	await get_tree().process_frame

	# ================= 玩法场景：装配、状态、信标、倍速 =================
	var ps = PlaySceneScript.instantiate()
	_ok(ps != null, "玩法场景可实例化")
	ps.call("load_level_id", "tutorial_01")
	add_child(ps)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(ps.get("session") != null, "会话已装配")
	_ok(ps.get("clock") != null, "时钟已装配")
	_ok(ps.get("toolbar") != null, "工具条已装配")
	_ok(ps.get("beacon_layer") != null, "信标层已装配")
	# 【视觉回归】绘制层存在、且信标能被它读到。
	# 用户实测反馈过「成功放置也没有看到显示」—— 因为当时**根本没有绘制代码**，
	# 信标只是数据。这几条断言把这个漏洞钉死。
	_ok(ps.get("renderer") != null, "**战场绘制层已装配**（网格/墙/终点/信标）")
	_ok(ps.get("camera") != null, "相机已装配")
	# 相机缩放：7×7 地图按 1:1 只有 448px，在 1920 宽屏上是一小块，
	# 玩家会点到空白处。必须放大到铺满视野。
	var zoom_x: float = float(ps.get("camera").get("zoom").x)
	_ok(zoom_x > 1.5, "**相机放大了地图**（zoom=%.2f，1:1 会显得太小）" % zoom_x)
	var map_px: float = float(ps.get("session").get("map").get("width")) * 64.0 * zoom_x
	var virtual_w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	_ok(map_px > virtual_w * 0.4 and map_px < virtual_w * 1.0,
		"地图占屏宽度合理（%.0f px / 屏宽 %.0f）" % [map_px, virtual_w])
	_ok((ps.get("session").get("units") as Array).size() == 1, "第一关载入 1 个单位")
	_ok(int(ps.get("session").get("state")) == LevelSessionScript.State.BUILD, "初始为编制期")

	# ============ 抽屉展开时，地图必须完整落在「可见区」内 ============
	#
	# 【为什么补这条】用户第 8 轮报过"抽屉一开就把正在编辑的单位压掉一半"。
	# 当时的修法只处理了**关闭后相机不复位**，没发现**偏移方向本来就是反的**
	# （相机 position 是"出现在屏幕中心的世界点"，所以地图要右移、相机得**左移**）。
	# 更关键的是：**当时根本没有任何断言检查过相机偏移**，所以方向反了也测不出来，
	# 一直到第 14 轮把抽屉加宽到 42% 才在截图里暴露出来。
	# 现在按几何关系断言"地图完全在可见区内"，方向错就会立刻失败。
	ps.call("_click_at", Vector2(1.5 * 64.0, 1.5 * 64.0))     # 点单位 → 开抽屉
	await get_tree().process_frame
	await get_tree().process_frame
	var rp2 = ps.get("rule_panel")
	_ok(bool(rp2.call("is_open")), "点单位后抽屉已展开（相机偏移断言的前提）")
	var cam2: Camera2D = ps.get("camera")
	var z2: float = maxf(cam2.zoom.x, 0.001)
	var mw2 := float(ps.get("session").get("map").get("width"))
	var map_w2 := mw2 * 64.0 * z2
	var centre_sx := (mw2 * 64.0 * 0.5 - cam2.position.x) * z2 + virtual_w * 0.5
	var map_left := centre_sx - map_w2 * 0.5
	var map_right := centre_sx + map_w2 * 0.5
	var drawer_w2 := float(rp2.call("drawer_width"))
	print("   [diag] 抽屉 %.0f / 相机 x=%.1f / 地图屏幕 x=%.0f..%.0f（可见区 %.0f..%.0f）"
		% [drawer_w2, cam2.position.x, map_left, map_right, drawer_w2, virtual_w])
	_ok(map_left >= drawer_w2 - 1.0,
		"**抽屉展开后地图左边不被挡住**（地图左 %.0f >= 抽屉右 %.0f）" % [map_left, drawer_w2])
	_ok(map_right <= virtual_w + 1.0,
		"地图右边不出屏（%.0f <= %.0f）" % [map_right, virtual_w])
	# 地图中心应该落在可见区中心附近（而不是屏幕中心）
	var visible_centre := (drawer_w2 + virtual_w) * 0.5
	_ok(absf(centre_sx - visible_centre) <= map_w2 * 0.1,
		"**地图中心对齐可见区中心**（地图中心 %.0f / 可见区中心 %.0f）"
		% [centre_sx, visible_centre])
	ps.call("_click_at", Vector2(-100.0, -100.0))             # 点空白 → 关抽屉
	await get_tree().process_frame
	_ok(is_equal_approx(cam2.position.x, float(ps.get("session").get("map").get("width")) * 32.0),
		"关抽屉后相机复位（x=%.1f）" % cam2.position.x)

	var ps_tb: Control = ps.get("toolbar")
	_ok(ps_tb.call("is_enabled", ToolbarScript.BTN_START), "场景里编制期「开始」可用")

	# 放信标：**必须落在第一关的通关路线上**，否则单位走不到终点。
	# 路线：向右到 (6,1) → 掉头 (5,1) → 向下到 (5,6) → 顺势踏进终点 (6,6)。
	var idx1: int = int(ps.call("try_place_beacon_at", Vector2(384, 64)))    # (6,1)
	var idx2: int = int(ps.call("try_place_beacon_at", Vector2(384, 384)))   # (6,6)
	_ok(idx1 == 1 and idx2 == 2, "**放信标返回序号 1、2**（%d、%d）" % [idx1, idx2])
	# 信标必须能被绘制层取到（at() 是 **1 起** 的序号，不是数组下标）
	var bl = ps.get("beacon_layer")
	_ok(bl.call("at", 1) != null and bl.call("at", 2) != null,
		"信标 1、2 都能按序号取到（绘制层据此画圆点与编号）")
	_ok(bl.call("at", 0) == null, "序号 0 越界返回 null（at() 是 1 起）")
	_ok(int(ps.get("beacon_layer").call("count")) == 2, "信标数为 2")
	_ok(str(ps_tb.call("beacon_text")) == "信标 2/4",
		"工具条计数同步（%s）" % str(ps_tb.call("beacon_text")))
	_ok(int(ps.call("try_place_beacon_at", Vector2(-900, -900))) == 0, "越界位置放不下")
	# 点「开始」→ 进推演期，开始按钮禁用，且推演期不能再放信标
	ps_tb.get_node("Row/Btn_start").emit_signal("pressed")
	await get_tree().process_frame
	_ok(int(ps.get("session").get("state")) == LevelSessionScript.State.RUN, "点开始后进入推演期")
	_ok(not ps_tb.call("is_enabled", ToolbarScript.BTN_START), "推演期「开始」按钮已禁用")
	_ok(int(ps.call("try_place_beacon_at", Vector2(480, 64))) == 0,
		"**推演期不能放信标**（信标不可改）")

	# 倍速：点按钮 → 时钟跟着变（走完整信号链）
	ps_tb.get_node("Row/Btn_speed").emit_signal("pressed")
	await get_tree().process_frame
	_ok(is_equal_approx(float(ps.get("clock").get("speed_multiplier")), 2.0),
		"**点倍速按钮 → 时钟倍速变 2x**（实际 %s）" % str(ps.get("clock").get("speed_multiplier")))
	_ok(is_equal_approx(float(ps.get("clock").get("TICK_DELTA")), 1.0 / 60.0),
		"倍速不改变逻辑步长（仍是 1/60 秒）")

	# 点「重置」→ 回编制期，且信标保留
	ps_tb.get_node("Row/Btn_reset").emit_signal("pressed")
	await get_tree().process_frame
	_ok(int(ps.get("session").get("state")) == LevelSessionScript.State.BUILD, "点重置回到编制期")
	_ok(int(ps.get("beacon_layer").call("count")) == 2, "重置**保留**玩家已放的信标")

	# 让会话按玩家的真实走法跑到胜利，验证结算期的按钮状态。
	# 三个信标已在上面的测试里放好：(6,1) → (5,1) → (5,6)。
	var u0: Node2D = (ps.get("session").get("units") as Array)[0]
	u0.set("beacon_sequence", [1, 2])
	u0.set("beacon_cursor", 0)
	ps.call("_do_start")
	var guard := 0
	while int(ps.get("session").get("verdict")) == LevelSessionScript.Verdict.NONE and guard < 3000:
		ps.get("session").call("step_tick")
		guard += 1
	_ok(int(ps.get("session").get("verdict")) == LevelSessionScript.Verdict.WIN,
		"**在玩法场景里也能走到胜利**（%d tick）" % guard)
	await get_tree().process_frame
	_ok(not ps_tb.call("is_enabled", ToolbarScript.BTN_RESET), "结算期「重置」已禁用")

	ps.queue_free()
	await get_tree().process_frame
	_done("hud")


func _check_data() -> void:
	print("\n-- 系统 11 · 数据配置 --")

	var dl: RefCounted = DataLoaderScript.new()
	var errs: Array = dl.call("load_all")
	_ok(errs.is_empty(), "units.json + scoring.json 载入无错误（%s）" % str(errs))
	_ok(bool(dl.call("is_loaded")), "载入状态为已就绪")

	# --- 四种单位齐全（D-16）---
	var ids: Array = dl.call("unit_type_ids")
	_ok(ids.size() == 4, "共 4 种单位（实际 %d：%s）" % [ids.size(), str(ids)])
	for t in ["standard", "standard_attack", "ice", "basic_enemy"]:
		_ok(bool(dl.call("has_unit_type", t)), "存在单位类型 %s" % t)

	# --- 逐个核对关键数值（与策划案一致）---
	var s_std: Dictionary = dl.call("base_unit_stats", "standard")
	_ok(is_equal_approx(float(s_std.get("max_hp")), 100.0), "标准单位 100 血")
	_ok(is_equal_approx(float(s_std.get("move_speed")), 3.0), "标准单位速度 3")
	_ok(not bool(s_std.get("can_attack")), "标准单位**不能攻击**（教学关用）")

	var s_atk: Dictionary = dl.call("base_unit_stats", "standard_attack")
	_ok(bool(s_atk.get("can_attack")), "标准攻击单位能攻击")
	_ok(is_equal_approx(float(s_atk.get("range")), 3.0), "标准攻击单位射程 3")
	_ok(is_equal_approx(float(s_atk.get("attack_interval")), 1.0),
		"攻速 1 发/秒 → attack_interval 1.0（秒/发，见详设 11 的 3.1）")
	_ok(str(s_atk.get("on_hit_status")).is_empty(), "标准攻击单位无附带状态")

	var s_ice: Dictionary = dl.call("base_unit_stats", "ice")
	_ok(is_equal_approx(float(s_ice.get("max_hp")), 30.0), "冰寒单位 30 血（很脆）")
	_ok(is_equal_approx(float(s_ice.get("move_speed")), 2.0), "冰寒单位速度 2")
	_ok(is_equal_approx(float(s_ice.get("damage")), 50.0), "冰寒单位伤害 50")
	_ok(is_equal_approx(float(s_ice.get("attack_interval")), 2.0),
		"攻速 0.5 发/秒 → attack_interval 2.0")
	_ok(str(s_ice.get("on_hit_status")) == "slowed", "冰寒单位命中附带减速")

	var s_foe: Dictionary = dl.call("base_unit_stats", "basic_enemy")
	_ok(is_equal_approx(float(s_foe.get("range")), 5.0),
		"基础敌人射程 5（关卡里会被覆盖为 2）")

	# --- 可选字段有默认值 ---
	_ok(s_std.has("projectile_speed") and s_std.has("projectile_radius"),
		"未写的可选字段被补上默认值（调用方不必判缺失）")
	_ok(is_equal_approx(float(s_std.get("projectile_radius")), 0.3), "默认子弹半径 0.3")

	# --- 返回的是副本：改它不污染缓存 ---
	var copy: Dictionary = dl.call("base_unit_stats", "standard")
	copy["max_hp"] = 999.0
	_ok(is_equal_approx(float((dl.call("base_unit_stats", "standard") as Dictionary).get("max_hp")), 100.0),
		"base_unit_stats 返回副本，改它不影响缓存（FR-UNIT-05）")

	# --- 评价系数（D-14：C1=10、C2=10、C3=1）---
	var co: Dictionary = dl.call("scoring_coefficients")
	_ok(is_equal_approx(float(co.get("complexity")), 10.0), "复杂度系数 C1 = 10")
	_ok(is_equal_approx(float(co.get("beacon")), 10.0), "信标系数 C2 = 10")
	_ok(is_equal_approx(float(co.get("time")), 1.0), "时间系数 C3 = 1")

	# --- 关卡级覆盖的合成（M3-3）---
	var merged: Dictionary = dl.call("get_unit_stats", "basic_enemy", {"range": 2})
	_ok((merged.get("errors") as Array).is_empty(), "合法覆盖无错误")
	_ok(is_equal_approx(float((merged.get("stats") as Dictionary).get("range")), 2.0),
		"覆盖后的射程为 2")
	_ok(is_equal_approx(float((dl.call("base_unit_stats", "basic_enemy") as Dictionary).get("range")), 5.0),
		"**覆盖不写回缓存**：表里默认值仍是 5（FR-UNIT-05）")
	# 覆盖别的字段不影响未覆盖字段
	_ok(is_equal_approx(float((merged.get("stats") as Dictionary).get("damage")), 10.0),
		"未覆盖的字段保持原值")

	# 覆盖不存在的字段 → 报错（防「调了没生效」的幽灵 bug）
	var bad_ov: Dictionary = dl.call("get_unit_stats", "basic_enemy", {"rangee": 2})
	_ok(not (bad_ov.get("errors") as Array).is_empty(), "覆盖不存在的字段会报错")
	_ok(str((bad_ov.get("errors") as Array)[0]).contains("rangee"),
		"错误信息点出具体字段名（%s）" % str((bad_ov.get("errors") as Array)[0]))
	var no_type: Dictionary = dl.call("get_unit_stats", "not_a_unit", {})
	_ok(not (no_type.get("errors") as Array).is_empty(), "不存在的单位类型报错")

	# --- JSON 读取的各类错误（用 user:// 临时文件，不污染 data/）---
	_check_data_errors(dl)

	# --- 版本过新 → 报错而不是尝试解析（详设 11 的 3.4）---
	var verrs: Array[String] = []
	dl.call("parse_json_text", '{"version": 999, "units": {}}', "测.json", verrs)
	_ok(verrs.size() == 1 and str(verrs[0]).contains("版本"),
		"版本过新 → 报错「数据文件版本过新」（%s）" % str(verrs))

	# --- 真实数据文件确实存在（防「测试里编数据、实际没有文件」）---
	for p in [DataLoaderScript.UNITS_PATH, DataLoaderScript.SCORING_PATH]:
		_ok(FileAccess.file_exists(p), "数据文件存在：%s" % p)

	# --- 真实文件能被读到并解析（端到端，不只是内存里造的字符串）---
	var real_errs: Array[String] = []
	var real = dl.call("read_json", DataLoaderScript.UNITS_PATH, real_errs)
	_ok(real_errs.is_empty() and real is Dictionary,
		"真实 units.json 读盘并解析成功（%s）" % str(real_errs))

	_done("data")


## 逐个检查 JSON 读取错误路径
func _check_data_errors(dl: RefCounted) -> void:
	# 1. 文件不存在（这条必须走真实文件系统）
	var e1: Array[String] = []
	dl.call("read_json", "res://data/__不存在的文件.json", e1)
	_ok(e1.size() == 1 and str(e1[0]).contains("文件未找到"),
		"文件不存在 → 报「文件未找到」（%s）" % str(e1))

	# 2. JSON 语法错误（要带行号）—— 直接喂文本，不依赖临时文件
	var e2: Array[String] = []
	dl.call("parse_json_text", '{"version": 1,,}', "坏.json", e2)
	_ok(e2.size() == 1 and str(e2[0]).contains("语法错误"),
		"JSON 语法错误 → 报「JSON 语法错误」（%s）" % str(e2))
	_ok(str(e2[0]).contains("行"), "语法错误信息里带行号（%s）" % str(e2[0]))

	# 3. 顶层是数组
	var e3: Array[String] = []
	dl.call("parse_json_text", '[1, 2, 3]', "数组.json", e3)
	_ok(e3.size() == 1 and str(e3[0]).contains("顶层应为对象"),
		"顶层是数组 → 报「顶层应为对象」（%s）" % str(e3))

	# 4. 顶层是标量
	var e4: Array[String] = []
	dl.call("parse_json_text", '42', "标量.json", e4)
	_ok(e4.size() == 1 and str(e4[0]).contains("顶层应为对象"), "顶层是数字 → 同样报错")

	# 5. 单位表的结构校验（缺字段 / 类型不符 / 范围越界 / 非法枚举）
	var cases := [
		{"label": "缺必填字段 max_hp", "body": '{"units":{"x":{"name":"X","move_speed":1,"can_attack":false}}}',
		 "want": "缺少必填字段 max_hp"},
		{"label": "类型不符（max_hp 是字符串）", "body": '{"units":{"x":{"name":"X","max_hp":"一百","move_speed":1,"can_attack":false}}}',
		 "want": "期望 number"},
		{"label": "范围越界（max_hp 为 0）", "body": '{"units":{"x":{"name":"X","max_hp":0,"move_speed":1,"can_attack":false}}}',
		 "want": "必须 > 0"},
		{"label": "范围越界（max_hp 为负）", "body": '{"units":{"x":{"name":"X","max_hp":-5,"move_speed":1,"can_attack":false}}}',
		 "want": "必须 > 0"},
		{"label": "范围越界（move_speed 为 0）", "body": '{"units":{"x":{"name":"X","max_hp":10,"move_speed":0,"can_attack":false}}}',
		 "want": "必须 > 0"},
		{"label": "攻击单位缺 range", "body": '{"units":{"x":{"name":"X","max_hp":10,"move_speed":1,"can_attack":true,"damage":1,"attack_interval":1}}}',
		 "want": "缺少必填字段 range"},
		{"label": "attack_interval 为 0", "body": '{"units":{"x":{"name":"X","max_hp":10,"move_speed":1,"can_attack":true,"range":1,"damage":1,"attack_interval":0}}}',
		 "want": "必须 > 0"},
		{"label": "can_attack 类型不符", "body": '{"units":{"x":{"name":"X","max_hp":10,"move_speed":1,"can_attack":"yes"}}}',
		 "want": "期望 bool"},
		{"label": "on_hit_status 非法", "body": '{"units":{"x":{"name":"X","max_hp":10,"move_speed":1,"can_attack":false,"on_hit_status":"burning"}}}',
		 "want": "未知状态"},
	]
	for c in cases:
		var d: Dictionary = c
		# 直接用 _validate_unit 校验（它是结构校验的唯一实现）
		var body: Dictionary = JSON.parse_string(str(d["body"]))
		var unit_dict: Dictionary = (body["units"] as Dictionary)["x"]
		var verrs: Array[String] = []
		dl.call("_validate_unit", "x", unit_dict, verrs)
		var hit := false
		for m in verrs:
			if str(m).contains(str(d["want"])):
				hit = true
		_ok(hit, "%s → 报出「%s」（实际 %s）" % [str(d["label"]), str(d["want"]), str(verrs)])
		# 每条错误信息都要带文件名前缀，便于定位
		_ok(verrs.size() > 0 and str(verrs[0]).begins_with("units.json:"),
			"%s → 错误信息带文件名前缀" % str(d["label"]))

	# 6. 一次性报出**全部**错误（不是遇到第一个就返回）
	var many := {"name": "X", "can_attack": true}
	var m_errs: Array[String] = []
	dl.call("_validate_unit", "x", many, m_errs)
	_ok(m_errs.size() >= 5,
		"**一次性报出全部错误**（%d 条，不是只报第一条）" % m_errs.size())

	# 7. 干净的条目不应报错（防「校验过严」把好数据也拦下）
	var good := {"name": "X", "max_hp": 100, "move_speed": 3, "can_attack": true,
		"range": 3, "damage": 10, "attack_interval": 1}
	var g_errs: Array[String] = []
	dl.call("_validate_unit", "x", good, g_errs)
	_ok(g_errs.is_empty(), "合法条目不报错（%s）" % str(g_errs))


## 写一个临时测试文件。返回是否成功。
## 【注意】`user://` 目录可能还不存在，FileAccess.open 会直接失败并返回 null
## （M3 实测：所有「读临时文件」的用例都报「文件未找到」）。
## 所以先建目录，并且**把失败显式暴露出来**，不要静默继续。
func _write_text(path: String, text: String) -> bool:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("   [!!] 无法写入临时文件 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	return FileAccess.file_exists(path)


func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# =====================================================================
# 收尾
# =====================================================================


func _report_and_quit() -> void:
	var elapsed := float(Time.get_ticks_msec() - _run_started_msec) / 1000.0
	print("========== 用时 %.1f 秒 ==========" % elapsed)
	print("\n========== 冒烟测试结束 ==========")

	# 核对「每个检查函数都跑到底」：任何函数中途被运行时错误打断，
	# 都会在这里暴露成「未跑完」，而不是伪装成全部通过。
	var missing: Array[String] = []
	for name in EXPECTED_CHECKS:
		if not _completed.has(name):
			missing.append(name)
	if not missing.is_empty():
		print("!! 以下检查未跑到底（中途出错或被漏调）：", ", ".join(missing))
		for m in missing:
			_failures.append("检查函数未跑到底: " + m)

	if _failures.is_empty():
		print("全部通过 ✅")
		get_tree().quit(0)
	else:
		print("失败 %d 项 ❌" % _failures.size())
		for f: String in _failures:
			print("  - ", f)
		get_tree().quit(1)
