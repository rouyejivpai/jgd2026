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
	assert_eq(int(loaded["version"]), 4, "存档 v4（10 §6.3：信标数字编号）")
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
	assert_eq(int(out["version"]), 4)
	var u: Dictionary = (((out["level_configs"] as Dictionary)["level_03"] as Dictionary)["units"] as Array)[0] as Dictionary
	assert_eq(str((u["beacons"] as Array).map(func(b: Dictionary) -> String: return str(b["id"]))), str(["1", "3"]), "信标 id A→1、C→3（不重排）")
	var rules: Array = u["rules"] as Array
	assert_eq(str((((rules[0] as Dictionary)["conditions"] as Array)[0] as Dictionary)["beacon"]), "3", "at_beacon C → 3")
	assert_eq(str(((rules[1] as Dictionary)["action"] as Dictionary)["from"]), "1", "follow_beacons.from A → 1")
	assert_eq_deep(rules[2], (unit["rules"] as Array)[2])
	assert_eq(DataReader.cell(u["pos"], "test"), Vector2i(2, 1), "其余字段不动")
	# 迁移后的配置可被控制器读入，信标与引用一致、无失效问题
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level("level_03"), ((out["level_configs"] as Dictionary)["level_03"] as Dictionary))
	assert_eq(c.get_beacons("u1").size(), 2)
	assert_eq(c.load_problems.size(), 0, "迁移后引用的信标都存在")
	# 已是 v4 的存档不再改动
	var again: Dictionary = _sm.call("migrate", JSON.parse_string(JSON.stringify(out)) as Dictionary) as Dictionary
	assert_eq_deep(again["level_configs"], out["level_configs"])
