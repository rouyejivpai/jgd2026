extends GutTest
## 2026-10-21 04.zip 剧情选择：主菜单「剧情」图鉴——一段都没看过时禁用；第一页按主线关卡顺序只列看过至少一段的关卡；
## 点关卡进「开头 / 结尾」两卡页（没看过的锁定）；点卡播剧情时浮层暂隐、播完回来；回放不改 stories_seen；返回逐页退出。
## 2026-10-21：第一页最前「原初」（开场动画，常驻解锁 → 「剧情」按钮不再因没看过剧情而禁用），最后「致谢」（片尾名单，触发关通关后解锁）。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const LevelSelectScript := preload("res://scripts/screens/level_select.gd")

var _saved_data: Dictionary


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data["stories_seen"] = {}
	SaveManager.data["progress"] = { "completed": [], "unlocked_levels": [] }
	GameState.sync_from_save()
	GameState.story_gallery_return = false


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.sync_from_save()
	GameState.story_gallery_return = false


func _menu() -> Control:
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	return menu


func _ids() -> Array[String]:
	return DataRegistry.world_chapter().level_ids()


func test_opening_and_credits_entries() -> void:
	var menu: Control = _menu()
	assert_false(((menu.get("nodes") as Dictionary)["btn_story"] as Button).disabled, "没看过剧情也能进图鉴（原初常驻）")
	var entries: Array = menu.call("gallery_entries")
	assert_eq(entries.map(func(e: Dictionary) -> String: return str(e.get("scene", ""))), ["opening", "credits"], "只有原初与致谢")
	assert_false(bool(entries[0].get("locked", false)), "原初初始解锁")
	assert_true(bool(entries[1]["locked"]), "没通关：致谢锁定")
	(GameState.progress["completed"] as Array).append(str(CreditsRoll.load_data()["trigger_level"]))
	entries = menu.call("gallery_entries")
	assert_false(bool(entries.back()["locked"]), "通关后致谢解锁")


func test_gallery_pages_and_playback() -> void:
	var ids: Array[String] = _ids()
	SaveManager.mark_story_seen(ids[0] + "_intro")
	SaveManager.mark_story_seen(ids[0] + "_win")
	SaveManager.mark_story_seen(ids[2] + "_intro")
	var menu: Control = _menu()
	assert_false(((menu.get("nodes") as Dictionary)["btn_story"] as Button).disabled)
	menu.call("open_gallery")
	var pick: StorySelect = menu.get("story_select") as StorySelect
	assert_true(pick.visible)
	assert_eq(pick.size, menu.size, "浮层铺满界面")
	var levels: Array = pick.current_entries().map(func(e: Dictionary) -> String: return str(e.get("level", e.get("scene"))))
	assert_eq(levels, ["opening", ids[0], ids[2], "credits"], "原初 + 看过的关卡（按主线顺序）+ 致谢")
	pick.cards()[2].pressed.emit()
	assert_eq(pick.page_count(), 2, "点关卡进第二页")
	assert_eq(pick.cards().size(), 2)
	assert_false(pick.cards()[0].disabled, "开头看过")
	assert_true(pick.cards()[1].disabled, "结尾没看过：锁定")
	var seen_before: Dictionary = (SaveManager.data["stories_seen"] as Dictionary).duplicate()
	pick.cards()[0].pressed.emit()
	var player: StoryPlayer = menu.get("_story") as StoryPlayer
	assert_true(player.visible, "播放剧情")
	assert_eq(player.current_story, ids[2] + "_intro")
	assert_false(pick.visible, "播放时浮层暂隐")
	player.close()
	assert_true(pick.visible, "播完回到两卡页")
	assert_eq(pick.page_count(), 2)
	assert_eq_deep(SaveManager.data["stories_seen"], seen_before)
	pick.back_page()
	assert_eq(pick.page_count(), 1, "返回到图鉴第一页")
	pick.back_page()
	assert_false(pick.visible, "再返回关闭")


func test_long_title_falls_back_to_short() -> void:
	var menu: Control = _menu()
	var pick: StorySelect = menu.get("story_select") as StorySelect
	pick.open("t", [{ "title": "26 人偶失败品「一」", "short_title": "人偶失败品「一」" }, { "title": "01 落子", "short_title": "落子" }])
	var l0: Label = pick.cards()[0].get_node("Title") as Label
	var l1: Label = pick.cards()[1].get_node("Title") as Label
	assert_eq(l0.text, "人偶失败品「一」", "放不下时只放关名")
	assert_eq(l1.text, "01 落子")
	var f: Font = l0.get_theme_font("font")
	assert_lte(f.get_string_size(l0.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l0.get_theme_font_size("font_size")).x, l0.size.x + 0.5, "缩字后放得下")


## 2026-10-21：最终关 Boss 换阶段的战中剧情（<id>_phase2）也进回放：开头 / 战中 / 结尾三卡；其它关没有战中剧情仍是两卡
func test_final_level_lists_mid_battle_story() -> void:
	SaveManager.mark_story_seen("level_c30_phase2")
	var entries: Array = LevelSelectScript.replay_entries("level_c30")
	assert_eq(entries.map(func(e: Dictionary) -> String: return str(e["story"])),
		["level_c30_intro", "level_c30_phase2", "level_c30_win"], "开头 / 战中 / 结尾")
	assert_eq(str(entries[1]["title"]), DataRegistry.get_string("ui.replay_phase"))
	assert_eq(entries.map(func(e: Dictionary) -> bool: return bool(e["locked"])), [true, false, true], "只看过战中剧情")
	assert_eq(LevelSelectScript.replay_entries("level_c01").size(), 2, "无战中剧情的关仍是两卡")
	var menu: Control = _menu()
	var levels: Array = (menu.call("gallery_entries") as Array).map(func(e: Dictionary) -> String: return str(e.get("level", "")))
	assert_has(levels, "level_c30", "只看过战中剧情也列入图鉴")
