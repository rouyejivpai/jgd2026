extends GutTest
## P8 艺术字（10 §1.5、决策 ⑭）：ArtText 静止态只有底字；主标题按 motion 播放光晕与扫光、总闸关闭时冻结；
## 文字换艺术字按 data/art_text.json 查找，字形高 = 布局 ref_ink 高；没有素材的文字保留普通文字。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")

var _saved_enabled: bool = true


func before_each() -> void:
	_saved_enabled = UiKit.motion_enabled
	UiKit.motion_enabled = true


func after_each() -> void:
	UiKit.motion_enabled = _saved_enabled


func _layer(a: ArtText, i: int) -> TextureRect:
	return a.get_child(i) as TextureRect


func test_title_static_at_t0_then_animates() -> void:
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(2)
	var title: Control = (menu.get("nodes") as Dictionary)["game_title_art"] as Control
	var a: ArtText = title.get_node_or_null(ArtText.NODE_NAME) as ArtText
	assert_not_null(a, "主标题挂上艺术字")
	assert_true(a.is_animated(), "R6a 有 motion：光晕 + 扫光")
	assert_eq(title.self_modulate.a, 0.0, "原标题图透明（由艺术字底字代替，同一张图）")
	assert_almost_eq(a.size, title.size, Vector2(0.5, 0.5), "铺满标题节点")
	a.t = 1.8 - 1.0 / 60.0                       # 半周期：envelope 峰值
	await wait_process_frames(1)
	var glow: TextureRect = _layer(a, 1)
	assert_true(glow.visible, "峰值时光晕可见")
	assert_gt(float((glow.material as ShaderMaterial).get_shader_parameter("opacity")), 0.9, "opacity = 0.95 × envelope")
	UiKit.motion_enabled = false
	await wait_process_frames(1)
	assert_false(glow.visible, "总闸关闭：冻结在静止态（只有底字）")
	assert_false(_layer(a, 2).visible, "扫光隐藏")


func test_static_package_shows_base_only() -> void:
	var a: ArtText = ArtText.create(ArtText.dir_for_text("战斗胜利"), 60.0)
	assert_not_null(a)
	add_child_autofree(a)
	assert_false(a.is_animated(), "R6b 静态交付：不播放")
	assert_almost_eq(a.ink_local().size.y, 60.0, 0.5, "字形可见高缩放到指定高")
	for c: Node in a.get_children():
		if c != a.get_child(0):
			assert_false((c as Control).visible, "除底字外的图层在静止态隐藏")


func test_attach_follows_ref_ink_and_falls_back() -> void:
	var l := Label.new()
	l.text = "墙缝"
	add_child_autofree(l)
	var a: ArtText = ArtText.attach(l, "chapter", "level_title")
	assert_not_null(a, "有素材的关卡名换艺术字")
	var ink: Array = (UiKit.layout_element("chapter", "level_title").get("data", {}) as Dictionary)["ref_ink"] as Array
	assert_almost_eq(a.ink_local().size.y, float(ink[3]), 0.5, "字形高 = 布局 ref_ink 高")
	assert_eq(l.self_modulate.a, 0.0, "原文字透明")
	l.text = "不存在的关卡名"
	assert_null(ArtText.attach(l, "chapter", "level_title"), "没有素材 → 不换")
	assert_eq(l.self_modulate.a, 1.0, "恢复普通文字")
	assert_null(l.get_node_or_null(ArtText.NODE_NAME), "旧艺术字已移除")
