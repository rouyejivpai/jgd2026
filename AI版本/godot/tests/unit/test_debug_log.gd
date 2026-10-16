extends GutTest
## 01 §11 DebugLog：行格式、文件写入、数量上限

const TEST_DIR: String = "user://test_logs"


func after_each() -> void:
	DebugLog.end("test")
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute("%s/%s" % [TEST_DIR, f])


func test_format_event_line() -> void:
	var e: Dictionary = { "type": SimTypes.EventType.RULE_CHANGED, "time": 12.4333, "unit": 3, "rule": 1 }
	assert_eq(DebugLog.format_event(e), "t=12.433 | rule_changed | rule=1 unit=3")


func test_world_events_written_to_file() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_01")
	var path: String = DebugLog.begin("level_01", TEST_DIR)
	assert_ne(path, "")
	assert_true(DebugLog.is_open())
	var lines: int = 0
	for i: int in 90:
		w.step()
		for e: Dictionary in w.take_events():
			DebugLog.write_event(e)
			lines += 1
	DebugLog.end("test")
	assert_false(DebugLog.is_open())
	var text: String = FileAccess.get_file_as_string(path)
	assert_true(text.begins_with("# level=level_01"))
	assert_true(text.contains(" | attack_fired | "), "前 3 秒应有攻击事件")
	assert_eq(text.split("\n", false).size(), lines + 2, "头尾各一行注释")


func test_prune_keeps_at_most_max_files() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for i: int in DebugLog.MAX_FILES + 5:
		var f: FileAccess = FileAccess.open("%s/sim_20000101_0000%02d.log" % [TEST_DIR, i], FileAccess.WRITE)
		f.close()
	DebugLog.begin("level_01", TEST_DIR)
	DebugLog.end("test")
	assert_eq(DirAccess.get_files_at(TEST_DIR).size(), DebugLog.MAX_FILES)
	assert_false(FileAccess.file_exists("%s/sim_20000101_000000.log" % TEST_DIR), "最旧的被删除")
