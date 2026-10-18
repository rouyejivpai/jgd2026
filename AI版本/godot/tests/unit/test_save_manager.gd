extends GutTest
## 05 §2 test_save_manager：读写往返、原子写、解锁累加（01 §10）

const SaveManagerScript: GDScript = preload("res://scripts/autoloads/save_manager.gd")
const TEST_DIR: String = "user://test_tmp"
const TEST_PATH: String = "user://test_tmp/save_test.json"

var _sm: Node


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_cleanup()


func after_each() -> void:
	_cleanup()
	_sm.free()


func _cleanup() -> void:
	for p: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _new_save() -> Dictionary:
	return SaveManagerScript.call("new_save", DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels()) as Dictionary


func test_roundtrip() -> void:
	var d: Dictionary = _new_save()
	(d["level_configs"] as Dictionary)["level_02"] = { "units": [{ "uid": "u1", "form": "bulwark", "pos": [3, 3], "rules": [SimFactory.r_attack_in_range()], "beacons": [] }], "next_uid": 2 }
	(d["hints_seen"] as Dictionary)["level_02"] = 1
	d["settings"] = { "master": 0.8, "music": 0.7, "sfx": 0.9, "fullscreen": true, "target_lines": true }
	assert_eq(int(_sm.call("save_to", d, TEST_PATH)), OK)
	var loaded: Dictionary = _sm.call("load_from", TEST_PATH) as Dictionary
	var expected: Dictionary = _sm.call("migrate", JSON.parse_string(JSON.stringify(d)) as Dictionary) as Dictionary
	assert_eq_deep(loaded, expected)
	assert_eq(int(loaded["version"]), 5, "存档 v5（第五阶段：指令双组口径）")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "提交后不留临时文件")


func test_atomic_write_tmp_rename() -> void:
	var a: Dictionary = _new_save()
	assert_eq(int(_sm.call("save_to", a, TEST_PATH)), OK)
	var b: Dictionary = _new_save()
	(b["progress"] as Dictionary)["completed"] = ["level_01"]
	assert_eq(int(_sm.call("write_tmp", b, TEST_PATH)), OK)     # 模拟：写完 tmp 后中断，未 rename
	var loaded: Dictionary = _sm.call("load_from", TEST_PATH) as Dictionary
	assert_eq(((loaded["progress"] as Dictionary)["completed"] as Array).size(), 0, "旧档仍可读且未被破坏")
	assert_eq(int(_sm.call("commit_tmp", TEST_PATH)), OK)
	loaded = _sm.call("load_from", TEST_PATH) as Dictionary
	assert_eq(((loaded["progress"] as Dictionary)["completed"] as Array).size(), 1, "提交后为新档")


func test_unlock_accumulates() -> void:
	var d: Dictionary = _new_save()
	var rewards: Dictionary = DataRegistry.get_level("level_02").rewards
	SaveManagerScript.call("apply_rewards", d, "level_02", rewards)
	SaveManagerScript.call("apply_rewards", d, "level_02", rewards)
	var unlocks: Dictionary = d["unlocks"] as Dictionary
	assert_eq((unlocks["conditions"] as Array).count("target_distance"), 1, "不重复")
	assert_eq((unlocks["actions"] as Array).count("retreat"), 1)
	assert_true((unlocks["actions"] as Array).has("attack"), "保留初始解锁")
	assert_eq((unlocks["forms"] as Array).count("swift"), 1)
	assert_eq((unlocks["presets"] as Array).count("preset.follow_route"), 1)
	var progress: Dictionary = d["progress"] as Dictionary
	assert_eq((progress["completed"] as Array).count("level_02"), 1)
	assert_eq((progress["unlocked_levels"] as Array).count("level_03"), 1)
	SaveManagerScript.call("apply_rewards", d, "level_03", DataRegistry.get_level("level_03").rewards)
	assert_true((unlocks["selectors"] as Array).has("farthest"), "累加后续关卡奖励")
	assert_true((unlocks["selectors"] as Array).has("nearest"))


## 10 §6.3：v3 → v4 把旧字母信标（列表 id、at_beacon.beacon、follow_beacons.from）改为数字，其余不动
func test_v3_to_v4_migrates_beacon_letters() -> void:
	var d: Dictionary = _new_save()
	d["version"] = 3
	var unit: Dictionary = { "uid": "u1", "form": "striker", "pos": [2, 1], "beacons": [{ "id": "A", "cell": [3, 1] }, { "id": "C", "cell": [13, 1] }],
		"rules": [
			{ "enabled": true, "condition_mode": "all", "conditions": [{ "type": "at_beacon", "beacon": "C" }], "action": { "type": "wait", "seconds": 2.0 } },
			{ "enabled": true, "condition_mode": "all", "conditions": [], "action": { "type": "follow_beacons", "mode": "loop", "from": "A" } },
			{ "enabled": true, "condition_mode": "all", "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "attack" } },
		] }
	(d["level_configs"] as Dictionary)["level_03"] = { "units": [unit], "next_uid": 2 }
	var out: Dictionary = _sm.call("migrate", JSON.parse_string(JSON.stringify(d)) as Dictionary) as Dictionary
	assert_eq(int(out["version"]), 5)
	var u: Dictionary = (((out["level_configs"] as Dictionary)["level_03"] as Dictionary)["units"] as Array)[0] as Dictionary
	assert_eq(str((u["beacons"] as Array).map(func(b: Dictionary) -> String: return str(b["id"]))), str(["1", "3"]), "信标 id A→1、C→3（不重排）")
	var rules: Array = u["rules"] as Array
	assert_eq(str((((rules[0] as Dictionary)["conditions"] as Array)[0] as Dictionary)["beacon"]), "3", "at_beacon C → 3")
	assert_eq(str(((rules[1] as Dictionary)["action"] as Dictionary)["from"]), "1", "follow_beacons.from A → 1")
	# v5：等待原样；沿信标 + 停火镜像；攻击 + 停止镜像（旧单列表口径折算为双组）
	assert_eq(rules.map(func(r: Dictionary) -> String: return str((r["action"] as Dictionary)["type"])), ["wait", "follow_beacons", "hold_fire", "attack", "idle"])
	assert_eq_deep(rules[3], (unit["rules"] as Array)[2])
	assert_eq(DataReader.cell(u["pos"], "test"), Vector2i(2, 1), "其余字段不动")
	# 迁移后的配置可被控制器读入，信标与引用一致、无失效问题
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level("level_03"), ((out["level_configs"] as Dictionary)["level_03"] as Dictionary))
	assert_eq(c.get_beacons("u1").size(), 2)
	assert_eq(c.load_problems.size(), 0, "迁移后引用的信标都存在")
	# 已是 v5 的存档不再改动
	var again: Dictionary = _sm.call("migrate", JSON.parse_string(JSON.stringify(out)) as Dictionary) as Dictionary
	assert_eq_deep(again["level_configs"], out["level_configs"])


## 第五阶段 v4 → v5：玩家指令折算为双组口径；已解锁「追击并攻击」→ 补「追击」「攻击」与追击解锁键；补齐新版初始解锁
func test_v4_to_v5_migrates_rules_and_unlocks() -> void:
	var d: Dictionary = _new_save()
	d["version"] = 4
	d["unlocks"] = { "forms": ["striker"], "presets": ["preset.chase_attack_nearest_visible"], "conditions": ["always"], "selectors": ["nearest"], "actions": ["chase_attack"] }
	var unit: Dictionary = { "uid": "u1", "form": "striker", "pos": [2, 2], "beacons": [], "rules": [
		SimFactory.r_chase_attack_visible(), SimFactory.r_idle(),
		{ "conditions": [{ "type": "target_distance", "op": "<", "value": 2.0 }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "retreat" }, "override": true },
	] }
	(d["level_configs"] as Dictionary)["level_01"] = { "units": [unit], "next_uid": 2 }
	var out: Dictionary = _sm.call("migrate", JSON.parse_string(JSON.stringify(d)) as Dictionary) as Dictionary
	assert_eq(int(out["version"]), 5)
	var rules: Array = ((((out["level_configs"] as Dictionary)["level_01"] as Dictionary)["units"] as Array)[0] as Dictionary)["rules"] as Array
	assert_eq(rules.map(func(r: Dictionary) -> String: return str((r["action"] as Dictionary)["type"])),
		["retreat", "hold_fire", "chase", "attack", "idle", "hold_fire"], "覆盖指令先排到前面再展开；追击并攻击 = 追击 + 攻击")
	for r: Variant in rules:
		assert_false((r as Dictionary).has("override"), "override 已折算为顺序并清除")
	var ul: Dictionary = out["unlocks"] as Dictionary
	assert_true((ul["actions"] as Array).has("chase") and (ul["actions"] as Array).has("attack"))
	assert_true((ul["presets"] as Array).has("preset.chase_nearest_visible"))
	for sel: String in DataRegistry.get_initial_unlocks()["selectors"] as Array:
		assert_true((ul["selectors"] as Array).has(sel), "补齐新版初始解锁：" + sel)
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(out)) as Dictionary
	var again: Dictionary = _sm.call("migrate", reloaded.duplicate(true)) as Dictionary
	assert_eq_deep(again["level_configs"], reloaded["level_configs"])   # v5 不再重复折算


## 主菜单「继续游戏」：只改过设置不算进度；通关、关卡配置、已播剧情任一非空即有进度
func test_has_progress() -> void:
	_sm.set("data", _new_save())
	assert_false(bool(_sm.call("has_progress")), "新存档无进度")
	((_sm.get("data") as Dictionary)["settings"] as Dictionary)["music"] = 0.3
	assert_false(bool(_sm.call("has_progress")), "只改设置不算进度")
	((_sm.get("data") as Dictionary)["stories_seen"] as Dictionary)["story_intro"] = true
	assert_true(bool(_sm.call("has_progress")), "看过剧情算进度")
	_sm.set("data", _new_save())
	SaveManagerScript.call("apply_rewards", _sm.get("data"), "level_01", DataRegistry.get_level("level_01").rewards)
	assert_true(bool(_sm.call("has_progress")), "通关算进度")


## 主菜单「新游戏」：删除存档（含残留 .tmp）后按初始解锁新建并写盘，设置保留
func test_clear_all_wipes_progress_keeps_settings() -> void:
	var d: Dictionary = _new_save()
	SaveManagerScript.call("apply_rewards", d, "level_02", DataRegistry.get_level("level_02").rewards)
	(d["level_configs"] as Dictionary)["level_02"] = { "units": [], "next_uid": 1 }
	(d["hints_seen"] as Dictionary)["level_02"] = 2
	(d["recommend_used"] as Dictionary)["level_02"] = true
	(d["stories_seen"] as Dictionary)["story_intro"] = true
	d["settings"] = { "master": 0.4, "fullscreen": false }
	assert_eq(int(_sm.call("save_to", d, TEST_PATH)), OK)
	assert_eq(int(_sm.call("write_tmp", d, TEST_PATH)), OK)       # 残留的 .tmp 也要清掉，否则读档时会被拿来恢复
	_sm.set("data", _sm.call("load_from", TEST_PATH))
	_sm.set("invalid_configs", { "level_02": [{}] })
	assert_true(bool(_sm.call("has_progress")))
	assert_eq(int(_sm.call("clear_all", TEST_PATH)), OK)
	assert_false(bool(_sm.call("has_progress")), "清档后无进度")
	assert_true((_sm.get("invalid_configs") as Dictionary).is_empty(), "失效配置标记一并清除")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "不留临时文件")
	var loaded: Dictionary = _sm.call("load_from", TEST_PATH) as Dictionary
	var fresh: Dictionary = _new_save()
	for key: String in ["progress", "unlocks", "level_configs", "hints_seen", "recommend_used", "stories_seen"]:
		assert_eq_deep(loaded[key], fresh[key])
	assert_eq_deep(loaded["settings"], { "master": 0.4, "fullscreen": false })
