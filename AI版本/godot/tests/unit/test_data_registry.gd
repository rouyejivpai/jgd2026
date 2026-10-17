extends GutTest
## 05 §2 test_data_registry：数据加载与 D01–D05 校验

const DataRegistryScript: GDScript = preload("res://scripts/autoloads/data_registry.gd")


## 读取关卡原始 JSON（深拷贝，可随意修改）
func _raw_level(level_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % level_id))
	return (parsed as Dictionary).duplicate(true)


## 构建并交叉校验一个关卡字典，返回新增错误条目
func _validate_level_dict(d: Dictionary) -> Array[String]:
	var before: int = DataReader.messages.size()
	var L: LevelDefinition = LevelDefinition.from_dict(d, "test")
	DataValidator.validate_level(L, DataRegistry.get_units(), DataRegistry.get_level_list())
	var out: Array[String] = []
	for i: int in range(before, DataReader.messages.size()):
		out.append(DataReader.messages[i])
	return out


func _handle_errors() -> void:
	for e: Object in get_errors():
		e.set("handled", true)


func _any_contains(lines: Array[String], needle: String) -> bool:
	for l: String in lines:
		if l.contains(needle):
			return true
	return false


func test_all_shipped_data_loads_without_errors() -> void:
	var reg: Node = DataRegistryScript.new()
	var ok: bool = bool(reg.call("load_all"))
	assert_true(ok)
	assert_false(bool(reg.get("has_errors")))
	assert_eq((reg.call("get_level_list") as Array).size(), 38, "第一章 8 关 + 30 关战役")
	reg.free()
	assert_false(DataRegistry.has_errors, "autoload 启动加载无错误")


func test_unknown_enum_is_error() -> void:
	var before: int = DataReader.error_count
	RuleDef.from_dict({ "conditions": [], "action": { "type": "fly" } }, "test")
	assert_gt(DataReader.error_count, before, "未知行为 fly → 报错")
	assert_true(DataReader.messages[DataReader.messages.size() - 1].contains("fly"))
	_handle_errors()


func test_missing_route_is_error() -> void:
	var d: Dictionary = _raw_level("level_03")
	var ru: Dictionary = ((d["recommended"] as Dictionary)["units"] as Array)[1] as Dictionary
	(((ru["rules"] as Array)[1] as Dictionary)["action"] as Dictionary)["route_id"] = "nowhere"
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "nowhere"), "route_id 不存在 → D02 报错")
	_handle_errors()


func test_out_of_bounds_is_error() -> void:
	var d: Dictionary = _raw_level("level_01")
	((d["initial_units"] as Array)[0] as Dictionary)["pos"] = [99, 99]
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "D03"), "坐标越界 → D03 报错")
	_handle_errors()


func test_blocked_on_deploy_is_error() -> void:
	var d: Dictionary = _raw_level("level_03")
	((d["grid"] as Dictionary)["blocked"] as Array).append([1, 0])   # (1,0) 是部署格
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "与障碍重叠"), "障碍与部署区重叠 → D03 报错")
	_handle_errors()


func test_hints_count_and_fail_feedback_keys() -> void:
	var d: Dictionary = _raw_level("level_07")
	(d["hints"] as Array).pop_back()
	(d["fail_feedback"] as Dictionary).erase("lose_protect_dead")
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "hints 必须恰好 4 条"), "D05 提示条数")
	assert_true(_any_contains(errs, "lose_protect_dead"), "D05 失败反馈键")
	_handle_errors()


# ---- 第二阶段 07 §2：recommended.units 与废弃字段 ----
func test_recommended_units_parsed() -> void:
	var L: LevelDefinition = DataRegistry.get_level("level_02")
	assert_eq(L.recommended_units.size(), 3)
	var ru: RecommendedUnitDef = L.get_recommended("slot_bulwark")
	assert_eq(ru.form, "bulwark")
	assert_eq(ru.pos, Vector2i(3, 3))
	# 第五阶段：旧单列表推荐指令在加载时折算为双组——攻击(射程内) + 停止镜像、追击 + 攻击（关闭）、停止 + 停火镜像
	assert_eq(L.rules_format, "legacy")
	var types: Array = ru.rules.map(func(r: RuleDef) -> String: return SimTypes.action_to_string(r.action.type))
	assert_eq(types, ["attack", "idle", "chase", "attack", "idle", "hold_fire"], "推荐指令折算为双组")
	assert_false(ru.rules[2].enabled, "第二关推荐指令中的追击默认关闭（拆分后两条都关闭）")
	assert_false(ru.rules[3].enabled)
	assert_eq(L.recommended_deploy.get("slot_bulwark"), Vector2i(3, 3), "派生的推荐部署")
	for s: SlotDef in DataRegistry.get_level("level_07").slots:
		assert_false("rules" in s, "SlotDef 不再携带指令")


func test_roster_parsed() -> void:
	var L2: LevelDefinition = DataRegistry.get_level("level_02")
	assert_true(L2.is_free())
	assert_eq(L2.roster_budget, 10)
	assert_eq(str(L2.available_forms), str(["bulwark", "striker"]))
	assert_eq([L2.min_units, L2.max_units], [1, 3])
	assert_eq(L2.slots.size(), 0, "free 关没有固定槽位")
	var L7: LevelDefinition = DataRegistry.get_level("level_07")
	assert_false(L7.is_free(), "第七关保持 fixed")
	assert_eq(L7.slots.size(), 3)
	assert_eq(DataRegistry.get_unit("bulwark").cost, 4)
	assert_eq(DataRegistry.get_unit("raider").cost, -1, "敌方没有 cost")


func test_deprecated_slots_and_budget_fit() -> void:
	var d: Dictionary = _raw_level("level_01")
	d["slots"] = []
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "DEPRECATED_FIELD slots"), "旧 slots 字段报错")
	var d2: Dictionary = _raw_level("level_02")
	(d2["roster"] as Dictionary)["budget"] = 8
	errs = _validate_level_dict(d2)
	assert_true(_any_contains(errs, "超出预算"), "推荐阵型放不进预算 → 数据错误")
	_handle_errors()


func test_deprecated_slot_rules_warns_but_is_ignored() -> void:
	var d: Dictionary = _raw_level("level_07")
	((((d["roster"] as Dictionary)["fixed_slots"]) as Array)[0] as Dictionary)["rules"] = [SimFactory.r_idle()]
	var warn_before: int = DataReader.warnings.size()
	var errs: Array[String] = _validate_level_dict(d)
	assert_eq(errs.size(), 0, "slots[].rules 不是错误")
	assert_gt(DataReader.warnings.size(), warn_before)
	assert_true(DataReader.warnings[DataReader.warnings.size() - 1].contains("DEPRECATED_FIELD"))


func test_deprecated_recommended_deploy_is_error() -> void:
	var d: Dictionary = _raw_level("level_01")
	d["recommended_deploy"] = { "slot_striker_a": [2, 2] }
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "DEPRECATED_FIELD"), "旧字段 recommended_deploy 报错")
	_handle_errors()


func test_recommended_out_of_zone_and_slot_checks() -> void:
	var d: Dictionary = _raw_level("level_07")      # fixed 关按槽位核对
	var units: Array = (d["recommended"] as Dictionary)["units"] as Array
	(units[0] as Dictionary)["pos"] = [9, 3]
	(units[1] as Dictionary)["slot"] = "slot_nowhere"
	var errs: Array[String] = _validate_level_dict(d)
	assert_true(_any_contains(errs, "不在部署区"), "推荐位置不在部署区 → D04")
	assert_true(_any_contains(errs, "slot_nowhere"), "推荐槽位不存在")
	var d1: Dictionary = _raw_level("level_02")     # free 关按形态核对
	(((d1["recommended"] as Dictionary)["units"] as Array)[0] as Dictionary)["form"] = "swift"
	errs = _validate_level_dict(d1)
	assert_true(_any_contains(errs, "available_forms"), "推荐形态不在本关可用形态中")
	_handle_errors()
