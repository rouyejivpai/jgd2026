extends GutTest
## 第五阶段：教学与解锁配置器（tools/config_editor.tscn）——载入 teaching.json、编辑引导步骤 / 目标、解锁覆盖与恢复、
## 提示覆盖、拾取结果回填、校验、保存（写到 user:// 临时文件，不动正式数据）。

const EDITOR_SCENE: PackedScene = preload("res://tools/config_editor.tscn")
const TMP_PATH: String = "user://test_teaching.json"


func before_each() -> void:
	GameState.config_editor_state = {}
	GameState.tutorial_pick_result = {}
	GameState.tutorial_pick = {}


func after_each() -> void:
	GameState.config_editor_state = {}
	GameState.tutorial_pick_result = {}
	GameState.tutorial_preview = {}
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))


func _editor() -> Control:
	var e: Control = EDITOR_SCENE.instantiate() as Control
	add_child_autofree(e)                       # 载入正式 teaching.json
	e.set("teaching_path", TMP_PATH)            # 保存写到临时文件
	return e


func _steps(e: Control) -> Array:
	return e.call("_steps_of") as Array


func test_loads_levels_and_tutorials() -> void:
	var e: Control = _editor()
	await wait_process_frames(1)
	assert_eq((e.get("level_ids") as Array).size(), DataRegistry.get_level_list().size(), "列出全部关卡（现有编号顺序）")
	e.call("_select_level", "level_c01")
	assert_eq(_steps(e).size(), DataRegistry.get_teaching().tutorial_steps("level_c01").size())
	assert_eq(e.call("validate_doc"), [] as Array[String], "现有 teaching.json 校验通过")


func test_edit_steps_and_targets() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_02")
	assert_eq(_steps(e).size(), 0, "第二关还没有引导")
	e.call("add_step")
	e.call("add_step")
	assert_eq(_steps(e).size(), 2)
	(e.get("_f_text") as TextEdit).text = "放下单位"
	(e.get("_f_text") as TextEdit).text_changed.emit()
	var adv: OptionButton = e.get("_f_advance") as OptionButton
	for i: int in adv.item_count:
		if str(adv.get_item_metadata(i)) == "event":
			adv.select(i)
			adv.item_selected.emit(i)
	e.call("add_target", "deploy_zone")
	e.call("add_target", "cells")
	(e.get("_t_cells") as LineEdit).text = "3,2; 4,2"
	(e.get("_t_cells") as LineEdit).text_changed.emit("3,2; 4,2")
	var s: Dictionary = _steps(e)[1] as Dictionary
	assert_eq(str(s["text"]), "放下单位")
	assert_eq(str(s["advance"]), "event")
	assert_eq(str(s["event"]), "deployed", "选「等待事件」时写入当前事件")
	assert_eq(s["targets"], [{ "kind": "deploy_zone" }, { "kind": "cells", "cells": [[3, 2], [4, 2]] }])
	e.call("move_step", -1)
	assert_eq(str((_steps(e)[0] as Dictionary)["text"]), "放下单位", "上移")
	e.call("delete_target")
	assert_eq((_steps(e)[0] as Dictionary)["targets"], [{ "kind": "deploy_zone" }])
	assert_true(bool(e.get("dirty")))
	assert_eq(e.call("validate_doc"), [] as Array[String])


func test_validation_reports_bad_step() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_02")
	e.call("add_step")
	e.call("add_target", "cell")
	(e.get("_t_cells") as LineEdit).text = "99,99"
	(e.get("_t_cells") as LineEdit).text_changed.emit("99,99")
	var msgs: Array[String] = e.call("validate_doc") as Array[String]
	assert_eq(msgs.size(), 1, "越界地块被指出")
	e.call("save_doc")
	assert_false(FileAccess.file_exists(TMP_PATH), "有问题时不保存")


func test_unlock_override_and_reset() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_02")
	var boxes: Dictionary = (e.get("_unlock_boxes") as Dictionary)["allowed.selectors"] as Dictionary
	var cb: CheckBox = boxes["most_damage"] as CheckBox
	assert_false(cb.button_pressed)
	cb.button_pressed = true
	var entry: Dictionary = ((e.get("doc") as Dictionary)["levels"] as Dictionary)["level_02"] as Dictionary
	assert_true(((entry["allowed"] as Dictionary)["selectors"] as Array).has("most_damage"), "勾选写入覆盖")
	assert_string_contains(str(e.call("unlock_table_markdown")), "造成伤害最高", "总览表用生效值")
	e.call("reset_unlock_override")
	assert_false(entry.has("allowed"), "恢复关卡原值")
	e.call("_select_level", "level_07")
	assert_true(((e.get("_unlock_boxes") as Dictionary)["allowed.actions"]["attack"] as CheckBox).disabled, "第七关冻结")


func test_hint_override() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_02")
	(e.get("_mech_custom") as CheckBox).button_pressed = true
	(e.get("_mech_text") as TextEdit).text = "新的机制提示"
	(e.get("_mech_text") as TextEdit).text_changed.emit()
	var entry: Dictionary = ((e.get("doc") as Dictionary)["levels"] as Dictionary)["level_02"] as Dictionary
	assert_eq(str(entry["mechanic_hint"]), "新的机制提示")
	(e.get("_mech_custom") as CheckBox).button_pressed = false
	assert_false(entry.has("mechanic_hint"), "不勾 = 用关卡原文")


func test_pick_result_fills_target_and_keeps_unsaved_edits() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/teaching.json")) as Dictionary
	((doc["levels"] as Dictionary)["level_c02"] as Dictionary)["test"] = false
	GameState.config_editor_state = { "doc": doc, "dirty": true, "level": "level_c02", "tab": 0, "step": 3, "pick_step": 3, "pick_target": 0 }
	GameState.tutorial_pick_result = { "kind": "ui", "node": "StartButton" }
	var e: Control = _editor()
	await wait_process_frames(1)
	assert_eq(str(e.get("cur_level")), "level_c02", "回到拾取前的关卡")
	assert_false(bool(((e.get("doc") as Dictionary)["levels"] as Dictionary)["level_c02"]["test"]), "未保存的编辑保留")
	assert_eq(((_steps(e)[3] as Dictionary)["targets"] as Array)[0], { "kind": "ui", "node": "StartButton" }, "拾取结果替换选中的目标")
	assert_true(GameState.tutorial_pick_result.is_empty())


func test_save_writes_clean_json() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_02")
	e.call("add_step")
	e.call("save_doc")
	assert_true(FileAccess.file_exists(TMP_PATH))
	var text: String = FileAccess.get_file_as_string(TMP_PATH)
	var saved: Dictionary = JSON.parse_string(text) as Dictionary
	assert_true((saved["levels"] as Dictionary).has("level_02"))
	assert_false(text.contains("14.0"), "整数写成整数（坐标 / 数值）")
	assert_false(bool(e.get("dirty")))


# ---- 关卡配置页 / 配置包（数值策划 → 程序）----
func _page(e: Control) -> ScrollContainer:
	return e.get("_level_page") as ScrollContainer


func _lv_entry(e: Control, lid: String) -> Dictionary:
	return ((e.get("doc") as Dictionary)["levels"] as Dictionary).get(lid, {}) as Dictionary


func test_level_config_roster_override_and_revert() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_c05")
	var budget: SpinBox = (_page(e).get("_roster_spins") as Dictionary)["budget"] as SpinBox
	assert_eq(int(budget.value), 6, "回填关卡原值")
	budget.value = 9
	assert_eq(_lv_entry(e, "level_c05")["roster"], { "budget": 9 }, "只记录有差异的键")
	budget.value = 6
	assert_false(_lv_entry(e, "level_c05").has("roster"), "改回原值 = 移除覆盖")
	assert_eq(e.call("validate_doc"), [] as Array[String])


func test_level_config_units_and_validation() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_c05")
	var page: ScrollContainer = _page(e)
	assert_eq(int(page.get("cur_unit")), 0)
	var on: CheckBox = (page.get("_u_stat_on") as Dictionary)["attack"] as CheckBox
	var val: SpinBox = (page.get("_u_stat_val") as Dictionary)["attack"] as SpinBox
	on.button_pressed = true
	val.value = 30
	var units: Array = _lv_entry(e, "level_c05")["initial_units"] as Array
	assert_eq(float(((units[0] as Dictionary)["overrides"] as Dictionary)["attack"]), 30.0, "属性覆盖写入")
	assert_eq(float(((units[0] as Dictionary)["overrides"] as Dictionary)["max_hp"]), 130.0, "原有覆盖保留")
	assert_eq(((units[0] as Dictionary)["rules"] as Array).size(), 2, "敌人指令原样保留")
	page.call("add_unit")
	assert_eq((_lv_entry(e, "level_c05")["initial_units"] as Array).size(), 3, "新增单位")
	assert_eq(e.call("validate_doc"), [] as Array[String], "新增单位合法（用形态默认指令）")
	(page.get("_u_x") as SpinBox).value = 99
	var msgs: Array[String] = e.call("validate_doc") as Array[String]
	assert_gt(msgs.size(), 0, "单位放到地图外被指出")
	page.call("delete_unit")
	assert_eq(e.call("validate_doc"), [] as Array[String])


func test_level_config_objective_numbers() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_c09")
	var box: VBoxContainer = _page(e).get("_obj_box") as VBoxContainer
	await wait_process_frames(1)
	var spins: Array = box.find_children("*", "SpinBox", true, false)
	assert_gt(spins.size(), 0, "survive 显示坚持秒数")
	(spins[0] as SpinBox).value = 77
	var win: Array = (_lv_entry(e, "level_c09")["objectives"] as Dictionary)["win"] as Array
	assert_eq(float((win[0] as Dictionary)["seconds"]), 77.0)
	assert_eq(e.call("validate_doc"), [] as Array[String])


func test_frozen_level_is_read_only() -> void:
	var e: Control = _editor()
	e.call("_select_level", "level_07")
	assert_false((_page(e).get("_u_x") as SpinBox).editable, "第七关只读")
	assert_true(((_page(e).get("_forms") as Dictionary).values()[0] as CheckBox).disabled)


func test_preview_level_uses_unsaved_override() -> void:
	assert_eq(DataRegistry.preview_level("level_c05", { "roster": { "budget": 9 } }), [] as Array[String])
	assert_eq(DataRegistry.get_level("level_c05").roster_budget, 9, "试玩用未保存的配置")
	assert_true(DataRegistry.preview_active)
	assert_gt(DataRegistry.preview_level("level_c05", { "deploy_zone": { "rect": [0, 0, 99, 99] } }).size(), 0, "非法配置不替换")
	DataRegistry.load_all()
	assert_eq(DataRegistry.get_level("level_c05").roster_budget, 6, "回到配置器即还原")
	assert_false(DataRegistry.preview_active)


func test_export_then_import_pack() -> void:
	var dir: String = ProjectSettings.globalize_path("user://test_packs")
	DirAccess.make_dir_recursive_absolute(dir)
	var e: Control = _editor()
	e.set("export_dir", dir)
	e.call("_select_level", "level_c05")
	((_page(e).get("_roster_spins") as Dictionary)["budget"] as SpinBox).value = 8
	(e.get("_pack_note") as LineEdit).text = "测试：第5关预算 8"
	var path: String = str(e.call("export_pack"))
	assert_true(FileAccess.file_exists(path), "导出配置包")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	assert_eq(str(pack["format"]), "rengong-shenling-level-config")
	assert_true((pack["levels"] as Array).has("level_c05"))
	# 程序侧导入：teaching_path 指向临时副本，备份与 CHANGELOG 也用临时位置
	var tmp_teaching: String = "user://test_teaching_import.json"
	var f: FileAccess = FileAccess.open(tmp_teaching, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://data/teaching.json"))
	f.close()
	var log_path: String = ProjectSettings.globalize_path("user://test_changelog.md")
	var lf: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	lf.store_string("| 日期 | 文件 | 改动 | 原因 | 结果 |\n")
	lf.close()
	var e2: Control = _editor()
	e2.set("teaching_path", tmp_teaching)
	e2.set("backup_dir", dir.path_join("备份"))
	e2.set("changelog_path", log_path)
	var read: Dictionary = e2.call("read_pack", path) as Dictionary
	assert_true(bool(read["ok"]), str(read["error"]))
	var summary: String = "\n".join(read["summary"] as PackedStringArray)
	assert_string_contains(summary, "level_c05")
	assert_string_contains(summary, "出场")
	assert_true(bool(e2.call("apply_pack", read)))
	var applied: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(tmp_teaching)) as Dictionary
	assert_eq(int(((applied["levels"] as Dictionary)["level_c05"] as Dictionary)["roster"]["budget"]), 8, "写入 teaching.json")
	assert_eq(DirAccess.get_files_at(dir.path_join("备份")).size(), 1, "导入前备份")
	assert_string_contains(FileAccess.get_file_as_string(log_path), "测试：第5关预算 8", "CHANGELOG 记一行")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_teaching))
	DirAccess.remove_absolute(log_path)
	for d: String in [dir.path_join("备份"), dir]:
		for fn: String in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(fn))
		DirAccess.remove_absolute(d)


func test_import_rejects_bad_packs() -> void:
	var e: Control = _editor()
	var p1: String = ProjectSettings.globalize_path("user://bad_pack_1.json")
	var f: FileAccess = FileAccess.open(p1, FileAccess.WRITE)
	f.store_string("{\"hello\": 1}")
	f.close()
	assert_false(bool((e.call("read_pack", p1) as Dictionary)["ok"]), "不是配置包")
	var p2: String = ProjectSettings.globalize_path("user://bad_pack_2.json")
	f = FileAccess.open(p2, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "format": "rengong-shenling-level-config", "version": 1,
		"teaching": { "levels": { "level_c05": { "deploy_zone": { "rect": [0, 0, 99, 99] } } } } }))
	f.close()
	var r: Dictionary = e.call("read_pack", p2) as Dictionary
	assert_false(bool(r["ok"]), "校验不通过的配置包拒绝导入")
	assert_string_contains(str(r["error"]), "校验未通过")
	DirAccess.remove_absolute(p1)
	DirAccess.remove_absolute(p2)
