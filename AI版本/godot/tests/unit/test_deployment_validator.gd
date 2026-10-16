extends GutTest
## 05 §2 test_deployment_validator：开始前部署校验与存档配置校验（01 §6.11、§10）

const SaveManagerScript: GDScript = preload("res://scripts/autoloads/save_manager.gd")


func _codes(problems: Array[Dictionary], slot_id: String = "") -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in problems:
		if slot_id == "" or str(p["slot"]) == slot_id:
			out.append(str(p["code"]))
	return out


## 全部解锁（只测"本关是否允许"时使用）
func _all_unlocked() -> Dictionary:
	return {
		"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
		"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
		"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
	}


func _validate(level_id: String, deploy: Dictionary, unlocks: Dictionary, rules_override: Dictionary = {}) -> Array[Dictionary]:
	var level: LevelDefinition = DataRegistry.get_level(level_id)
	return DeploymentValidator.validate(level, SimFactory.make_config(level, deploy, rules_override), unlocks, DataRegistry.get_units())


func test_unplaced_slot_blocks_start() -> void:
	# 第七关仍为 fixed：槽位必须全部部署
	var problems: Array[Dictionary] = _validate("level_07", { "slot_bulwark": Vector2i(3, 4), "slot_striker": Vector2i(3, 3) }, _all_unlocked())
	assert_eq(str(_codes(problems)), str(["SLOT_NOT_PLACED"]))
	assert_eq(str(problems[0]["slot"]), "slot_lancer")
	assert_true(DeploymentValidator.has_blocking(problems))
	var none: Array[Dictionary] = _validate("level_01", { "slot_striker_a": Vector2i(2, 2), "slot_striker_b": Vector2i(2, 4) }, DataRegistry.get_initial_unlocks())
	assert_eq(none.size(), 0, "free 关：推荐部署 + 推荐指令无问题")


# ---- 07 §4.1 free 模式：人数、预算、形态 ----
func _free_config(units: Array) -> Dictionary:
	var config: Dictionary = {}
	for i: int in units.size():
		var u: Array = units[i] as Array
		config["u%d" % (i + 1)] = { "form": str(u[0]), "index": i, "pos": u[1] as Vector2i, "rules": SimFactory.to_rules([SimFactory.r_idle()]) }
	return config


func test_free_mode_min_units_budget_and_forms() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_02")    # budget 10，bulwark/striker，max 3
	var empty: Array[Dictionary] = DeploymentValidator.validate(level, {}, _all_unlocked(), DataRegistry.get_units())
	assert_eq(str(_codes(empty)), str(["TOO_FEW_UNITS"]), "空场不能开始（min_units = 1）")
	var over: Array[Dictionary] = DeploymentValidator.validate(level, _free_config([["bulwark", Vector2i(3, 3)], ["bulwark", Vector2i(3, 2)], ["striker", Vector2i(1, 2)]]),
		_all_unlocked(), DataRegistry.get_units())
	assert_eq(str(_codes(over)), str(["BUDGET_EXCEEDED"]), "4+4+3 = 11 > 10")
	assert_eq(str(over[0]["what"]), "11/10")
	var swift: Array[Dictionary] = DeploymentValidator.validate(level, _free_config([["swift", Vector2i(3, 3)]]), _all_unlocked(), DataRegistry.get_units())
	assert_eq(str(_codes(swift)), str(["FORM_NOT_AVAILABLE"]), "快速形态不在第二关 available_forms 中")
	var locked: Array[Dictionary] = DeploymentValidator.validate(level, _free_config([["bulwark", Vector2i(3, 3)]]),
		DataRegistry.get_initial_unlocks(), DataRegistry.get_units())
	assert_eq(str(_codes(locked)), str(["FORM_NOT_AVAILABLE"]), "承伤形态未解锁")
	var ok: Array[Dictionary] = DeploymentValidator.validate(level, _free_config([["bulwark", Vector2i(3, 3)], ["striker", Vector2i(1, 2)]]),
		_all_unlocked(), DataRegistry.get_units())
	assert_eq(ok.size(), 0, "合法的自主出场")


## 10 §5.5：指令 Cost 计入预算（fixture：把 attack 的 cost 临时设为 3；commands.json 本身全 0）
func test_command_cost_exceeds_budget() -> void:
	var raw: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/commands.json")) as Dictionary).duplicate(true)
	for e: Variant in raw["actions"] as Array:
		if str((e as Dictionary)["id"]) == "attack":
			(e as Dictionary)["cost"] = 3
	var cat: CommandCatalog = CommandCatalog.from_dict(raw, "fixture_commands")
	var level: LevelDefinition = DataRegistry.get_level("level_02")    # budget 10
	var config: Dictionary = _free_config([["bulwark", Vector2i(3, 3)], ["striker", Vector2i(1, 2)]])   # 形态 4 + 3 = 7
	for uid: String in config.keys():
		(config[uid] as Dictionary)["rules"] = SimFactory.to_rules([SimFactory.r_attack_in_range()])
	assert_eq(DeploymentValidator.validate(level, config, _all_unlocked(), DataRegistry.get_units()).size(), 0, "不传目录 = 指令 Cost 按 0")
	assert_eq(DeploymentValidator.validate(level, config, _all_unlocked(), DataRegistry.get_units(), DataRegistry.get_commands()).size(), 0, "commands.json 全 0：与第二阶段一致")
	var over: Array[Dictionary] = DeploymentValidator.validate(level, config, _all_unlocked(), DataRegistry.get_units(), cat)
	assert_eq(str(_codes(over)), str(["BUDGET_EXCEEDED"]), "7 + 3 + 3 = 13 > 10")
	assert_eq(str(over[0]["what"]), "13/10")
	(config["u2"] as Dictionary)["rules"] = SimFactory.to_rules([SimFactory.r_idle()])
	assert_eq(DeploymentValidator.validate(level, config, _all_unlocked(), DataRegistry.get_units(), cat).size(), 0, "7 + 3 = 10 ≤ 10")


func test_out_of_zone_and_excluded_cell() -> void:
	var problems: Array[Dictionary] = _validate("level_07",
		{ "slot_bulwark": Vector2i(6, 6), "slot_striker": Vector2i(2, 4), "slot_lancer": Vector2i(1, 5) }, _all_unlocked())
	assert_eq(str(_codes(problems, "slot_bulwark")), str(["OUT_OF_ZONE"]))
	assert_eq(str(_codes(problems, "slot_striker")), str(["CELL_BLOCKED"]), "第七关 (2,4) 为保护对象，不可部署")
	assert_eq(_codes(problems, "slot_lancer").size(), 0)


func test_overlap() -> void:
	var problems: Array[Dictionary] = _validate("level_01", { "slot_striker_a": Vector2i(2, 2), "slot_striker_b": Vector2i(2, 2) }, DataRegistry.get_initial_unlocks())
	assert_true(_codes(problems).has("CELL_OCCUPIED"))


func test_rule_not_allowed_in_level() -> void:
	var farthest: Dictionary = SimFactory.r_attack_in_range("farthest")
	var problems: Array[Dictionary] = _validate("level_01", { "slot_striker_a": Vector2i(2, 2), "slot_striker_b": Vector2i(2, 4) },
		_all_unlocked(), { "slot_striker_a": [farthest] })
	assert_eq(str(_codes(problems)), str(["RULE_NOT_ALLOWED"]), "第一关只允许 nearest")
	assert_eq(str(problems[0]["what"]), "farthest")
	assert_eq(int(problems[0]["index"]), 1)


func test_rule_locked() -> void:
	# 第三关允许 target_distance / retreat / chase / follow_route，但初始解锁中没有
	var unlocks: Dictionary = DataRegistry.get_initial_unlocks()
	unlocks["forms"] = ["striker", "swift"]          # 只测指令解锁，形态视为已解锁
	var problems: Array[Dictionary] = _validate("level_03", DataRegistry.get_level("level_03").recommended_deploy, unlocks)
	var whats: Array[String] = []
	for p: Dictionary in problems:
		assert_eq(str(p["code"]), "RULE_LOCKED")
		whats.append(str(p["what"]))
	assert_true(whats.has("target_distance"))
	assert_true(whats.has("retreat"))
	assert_true(whats.has("chase"))
	assert_true(whats.has("follow_route"))


func test_invalid_saved_config_flagged_not_deleted() -> void:
	var sm: Node = SaveManagerScript.new()
	var save: Dictionary = SaveManagerScript.call("new_save", DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels()) as Dictionary
	var cfg: Dictionary = { "next_uid": 4, "units": [
		{ "uid": "u1", "form": "striker", "pos": [2, 2], "rules": [SimFactory.r_attack_in_range("farthest")] },
		{ "uid": "u2", "form": "striker", "pos": [2, 4], "rules": [{ "conditions": [], "action": { "type": "teleport" } }] },
		{ "uid": "u3", "form": "ghost", "pos": [1, 3], "rules": [] },
	] }
	(save["level_configs"] as Dictionary)["level_01"] = cfg
	var snapshot: Dictionary = cfg.duplicate(true)
	var levels: Dictionary = {}
	for lid: String in DataRegistry.get_level_list():
		levels[lid] = DataRegistry.get_level(lid)
	var invalid: Dictionary = sm.call("validate_level_configs", save, levels, DataRegistry.get_units()) as Dictionary
	assert_true(invalid.has("level_01"), "标记为 invalid")
	var codes: Array[String] = []
	codes.assign((invalid["level_01"] as Array).map(func(p: Dictionary) -> String: return str(p["code"])))
	assert_true(codes.has("RULE_NOT_ALLOWED"))
	assert_true(codes.has("RULE_INVALID"))
	assert_true(codes.has("FORM_NOT_AVAILABLE"), "free 关：未知形态")
	assert_eq_deep((save["level_configs"] as Dictionary)["level_01"] as Dictionary, snapshot)
	# fixed 关：未知槽位
	(save["level_configs"] as Dictionary)["level_07"] = { "units": [{ "uid": "slot_ghost", "slot": "slot_ghost", "form": "striker", "pos": [1, 3], "rules": [] }] }
	invalid = sm.call("validate_level_configs", save, levels, DataRegistry.get_units()) as Dictionary
	assert_true(str(invalid.get("level_07", [])).contains("SLOT_UNKNOWN"))
	sm.free()


## 存档 v1 → v2（07 §4.2）：free 关槽位配置转为 u1、u2…；fixed 关 uid = 槽位；无法转换的保留在 legacy_v1 并标记 invalid
func test_save_v1_migrates_to_unit_list() -> void:
	var sm: Node = SaveManagerScript.new()
	var v1: Dictionary = { "version": 1, "progress": {}, "unlocks": { "forms": ["striker", "bulwark"], "slots": 2 }, "hints_seen": {}, "settings": {},
		"level_configs": {
			"level_02": {
				"slot_bulwark": { "pos": [3, 3], "rules": [SimFactory.r_idle()] },
				"slot_striker_a": { "pos": [1, 2], "rules": [] },
				"slot_striker_b": { "rules": [SimFactory.r_idle()] },
			},
			"level_07": { "slot_bulwark": { "pos": [3, 4], "rules": [] }, "slot_lancer": { "rules": [SimFactory.r_idle()] } },
		} }
	var v2: Dictionary = sm.call("migrate", v1) as Dictionary
	assert_eq(int(v2["version"]), SaveManager.SAVE_VERSION, "迁移到当前存档版本")
	assert_false((v2["unlocks"] as Dictionary).has("slots"), "unlocks.slots 废弃")
	var l2: Dictionary = (v2["level_configs"] as Dictionary)["level_02"] as Dictionary
	var units: Array = l2["units"] as Array
	assert_eq(units.size(), 2, "已部署的两名转为 u1、u2")
	assert_eq(str((units[0] as Dictionary)["uid"]), "u1")
	assert_eq(str((units[0] as Dictionary)["form"]), "bulwark")
	assert_eq(str((units[1] as Dictionary)["form"]), "striker")
	assert_true(l2.has("legacy_v1"), "未部署而无法放进 free 关的条目：原数据保留")
	var l7: Dictionary = (v2["level_configs"] as Dictionary)["level_07"] as Dictionary
	assert_eq(str(((l7["units"] as Array)[1] as Dictionary)["uid"]), "slot_lancer", "fixed 关 uid = 槽位，未部署的槽位保留指令")
	assert_false(l7.has("legacy_v1"))
	var levels: Dictionary = {}
	for lid: String in DataRegistry.get_level_list():
		levels[lid] = DataRegistry.get_level(lid)
	var invalid: Dictionary = sm.call("validate_level_configs", v2, levels, DataRegistry.get_units()) as Dictionary
	assert_true(str(invalid.get("level_02", [])).contains("SAVE_MIGRATION_FAILED"), "迁移不完整 → 标记 invalid，不删除")
	var c := BattleController.new()
	add_child_autofree(c)
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = _all_unlocked()
	c.setup(DataRegistry.get_level("level_02"), l2)
	GameState.unlocks = saved_unlocks
	assert_eq(str(c.uids()), str(["u1", "u2"]))
	assert_eq(c.placements["u1"], Vector2i(3, 3))
	assert_eq(c.next_uid, 3)
	sm.free()
