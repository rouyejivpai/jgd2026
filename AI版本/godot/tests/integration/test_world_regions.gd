extends GutTest
## 2026-10-18 分区域：腐土平原七个区域（人偶工坊 6 关，其余各 4 关，按 c01…c30 顺序），一级地图选区域、区域地图选关。

const WORLD_SCENE: PackedScene = preload("res://scenes/screens/world_map.tscn")
const SELECT_SCENE: PackedScene = preload("res://scenes/screens/level_select.tscn")
const SELECT_SCRIPT: GDScript = preload("res://scripts/screens/level_select.gd")
const ORDER: Array[String] = ["bone_workshop", "withered_farm", "grey_thorn", "holy_bell", "flesh_swamp", "warped_corridor", "bone_greenhouse"]
const TITLES: Array[String] = ["人偶工坊", "枯骨农田", "灰棘林", "圣钟城废墟", "肉巢沼泽", "畸变回廊", "骨花温室"]

var _saved_progress: Dictionary
var _saved_level: String
var _saved_region: String


func before_each() -> void:
	_saved_progress = GameState.progress
	_saved_level = GameState.current_level_id
	_saved_region = GameState.current_region_id
	SELECT_SCRIPT.set("chapter_index", -1)


func after_each() -> void:
	GameState.progress = _saved_progress
	GameState.current_level_id = _saved_level
	GameState.current_region_id = _saved_region


static func _levels(from: int, to: int) -> Array:
	var out: Array = []
	for i: int in range(from, to + 1):
		out.append("level_c%02d" % i)
	return out


func test_seven_regions_in_order_with_level_counts() -> void:
	var wc: ChapterDef = DataRegistry.world_chapter()
	assert_not_null(wc, "有一级地图的章节")
	assert_eq(wc.id, "chapter_02")
	assert_eq(wc.regions.map(func(r: Dictionary) -> String: return str(r["id"])), ORDER)
	assert_eq(wc.regions.map(func(r: Dictionary) -> String: return str(r["title"])), TITLES)
	var counts: Array = ORDER.map(func(rid: String) -> int: return wc.region_level_ids(rid).size())
	assert_eq(counts, [6, 4, 4, 4, 4, 4, 4])
	assert_eq(wc.region_level_ids("bone_workshop")[0], "level_c01", "第一关 = 人偶工坊第一关")
	assert_eq(wc.region_level_ids("withered_farm")[0], "level_c07", "第七关 = 枯骨农田第一关")
	assert_eq(wc.region_of_level("level_c30"), "bone_greenhouse", "最终战并入骨花温室")
	for rid: String in ORDER:
		assert_true(wc.region_has_map(rid), "区域地图：" + rid)
		assert_not_null(Art.texture(str(wc.region(rid)["map"])), "区域地图可加载：" + rid)
	assert_not_null(Art.texture(str(wc.world["map"])), "一级地图可加载")


func test_region_unlock_follows_level_chain() -> void:
	var wc: ChapterDef = DataRegistry.world_chapter()
	var ini: Array = DataRegistry.get_initial_levels()
	assert_true(wc.region_unlocked("bone_workshop", [], ini))
	assert_false(wc.region_unlocked("withered_farm", [], ini))
	assert_eq(wc.region_requirement("withered_farm"), "level_c06", "通关人偶工坊末关解锁枯骨农田")
	assert_true(wc.region_unlocked("withered_farm", _levels(1, 6), ini))
	assert_eq(wc.region_progress("bone_workshop", _levels(1, 6)), Vector2i(6, 6))
	assert_eq(wc.region_progress("withered_farm", _levels(1, 8)), Vector2i(2, 4))


func test_world_map_select_and_enter() -> void:
	GameState.progress = { "completed": _levels(1, 7), "unlocked_levels": [] }
	GameState.current_region_id = ""
	var w: Control = WORLD_SCENE.instantiate() as Control
	add_child_autofree(w)
	w.set("navigate", false)
	var entered: Array[String] = []
	w.connect("region_entered", func(rid: String) -> void: entered.append(rid))
	await wait_process_frames(2)
	assert_eq((w.get("hotspots") as Dictionary).size(), 7, "七个区域热区")
	assert_eq(str(w.get("selected_id")), "withered_farm", "默认选中最新可挑战的区域")
	assert_string_contains(str(w.call("status_text", "withered_farm")), "送它出去", "下一关")
	w.call("select_region", "grey_thorn")
	var enter: Button = w.find_child("EnterButton", true, false) as Button
	assert_true(enter.disabled, "未解锁区域不能进入")
	assert_string_contains(str(w.call("status_text", "grey_thorn")), DataRegistry.get_level("level_c10").title, "写明前置关卡")
	w.call("enter_region", "grey_thorn")
	assert_eq(entered.size(), 0)
	w.call("select_region", "bone_workshop")
	assert_eq(str(w.call("status_text", "bone_workshop")), DataRegistry.get_string("ui.region_all_done"))
	((w.get("hotspots") as Dictionary)["bone_workshop"] as Button).pressed.emit()      # 再点已选中的已解锁区域 = 进入
	assert_eq(entered, ["bone_workshop"] as Array[String])
	assert_eq(GameState.current_region_id, "bone_workshop")
	var r: Rect2 = w.call("map_rect") as Rect2
	for rid: String in ORDER:
		assert_true(r.has_point(w.call("region_screen_pos", rid) as Vector2), "图标在地图内：" + rid)


func test_level_select_shows_only_current_region() -> void:
	GameState.progress = { "completed": _levels(1, 7), "unlocked_levels": [] }
	GameState.current_level_id = ""
	GameState.current_region_id = "withered_farm"
	var sel: Control = SELECT_SCENE.instantiate() as Control
	add_child_autofree(sel)
	sel.set("navigate", false)
	await wait_process_frames(2)
	assert_eq(str(sel.get("region_id")), "withered_farm")
	var ids: Array = (sel.get("node_buttons") as Dictionary).keys()
	ids.sort()
	assert_eq(ids, _levels(7, 10), "只显示本区域四关")
	assert_eq(str(sel.call("map_path")), str(DataRegistry.world_chapter().region("withered_farm")["map"]))
	assert_eq(str(sel.get("selected_id")), "level_c08", "默认选中本区最新可挑战关")
	# 设计坐标（1920×1080）下，各区域节点连同名牌都在详情面板左侧，不需横移就能全部看到
	var design: Vector2 = UiKit.design_size("chapter")
	var panel_left: float = UiKit.layout_rect("chapter", "panel_top", design).position.x
	var half_plate: float = UiKit.layout_rect("chapter", "plate", design).size.x * 0.5
	var wc: ChapterDef = DataRegistry.world_chapter()
	for rid: String in ORDER:
		var k: float = 1080.0 / (wc.region(rid)["map_size"] as Vector2).y
		for n: Dictionary in wc.region_nodes(rid):
			var x: float = (n["pos"] as Vector2).x * k
			assert_true(x - half_plate >= 0.0 and x + half_plate <= panel_left, "%s 节点 %s 在可见区" % [rid, str(n["id"])])


func test_level_select_region_follows_last_level() -> void:
	GameState.current_region_id = ""
	GameState.current_level_id = "level_c27"
	var sel: Control = SELECT_SCENE.instantiate() as Control
	add_child_autofree(sel)
	sel.set("navigate", false)
	await wait_process_frames(2)
	assert_eq(str(sel.get("region_id")), "bone_greenhouse", "从关卡返回：显示该关所在区域")
	assert_eq((sel.get("node_buttons") as Dictionary).size(), 4)


## 2026-10-18 BGM：主界面 / 一级地图 / 选关共用 menu_main；每个区域的普通关用 region_<区域 id>，首领关（c30）用 boss_01
func test_bgm_per_region_and_menu() -> void:
	assert_not_null(load(AudioManager.BGM_DIR + "menu_main.mp3") as AudioStream, "主界面 / 选关曲")
	var wc: ChapterDef = DataRegistry.world_chapter()
	for rid: String in ORDER:
		var track: String = "region_" + rid
		assert_not_null(load(AudioManager.BGM_DIR + track + ".mp3") as AudioStream, "区域曲：" + track)
		for lid: String in wc.region_level_ids(rid):
			var L: LevelDefinition = DataRegistry.get_level(lid)
			var expect: String = "boss_01" if bool(wc.node_of_level(lid).get("boss", false)) else track
			assert_eq(L.bgm, expect, "%s 的 BGM" % lid)
