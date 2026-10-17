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
