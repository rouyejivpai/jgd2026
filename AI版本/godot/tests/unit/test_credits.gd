extends GutTest
## 片尾开发者名单（data/credits.json + CreditsRoll）：触发关卡、成员条目、资源与界面文字齐全；场景能独立搭起来（9 位开发者 + 主角 + 对话框）。


func test_trigger_level() -> void:
	assert_true(CreditsRoll.plays_after("level_c30"), "第 30 关胜利剧情后接名单")
	assert_false(CreditsRoll.plays_after("level_c29"))


func test_data_complete() -> void:
	var d: Dictionary = CreditsRoll.load_data()
	assert_not_null(DataRegistry.get_level(str(d.get("trigger_level", ""))), "trigger_level 是存在的关卡")
	assert_not_null(Art.unit_texture(str(d.get("hero_form", ""))), "人偶图存在")
	assert_not_null(Art.texture(str(d.get("qr", ""))), "群二维码存在")
	var members: Array = d.get("members", []) as Array
	assert_eq(members.size(), 9)
	for m: Variant in members:
		var e: Dictionary = m as Dictionary
		for key: String in ["role", "name", "message"]:
			assert_ne(str(e.get(key, "")), "", "%s 缺 %s" % [e, key])
		var avatar: String = str(e.get("avatar", ""))
		if avatar != "":
			assert_not_null(Art.texture(avatar), "头像不存在：%s" % avatar)


func test_ui_strings() -> void:
	for key: String in ["ui.credits_thanks", "ui.credits_letter", "ui.credits_farewell", "ui.credits_join", "ui.credits_thanks_en", "ui.credits_skip", "ui.credits_return"]:
		assert_ne(DataRegistry.get_string(key), key, key)


func test_scene_builds() -> void:
	var roll: CreditsRoll = (load(SceneRouter.CREDITS_SCENE) as PackedScene).instantiate() as CreditsRoll
	add_child_autofree(roll)
	await wait_process_frames(2)
	assert_eq(roll.get_node("Crew").get_child_count(), 9)
	assert_not_null(roll.get_node_or_null("Hero"))
	assert_eq(roll.get_node("Bubbles").get_child_count(), 9)
	assert_eq(roll.stage, CreditsRoll.Stage.WALK)
