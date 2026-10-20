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
var _saved_revealed: Variant
var _saved_autosave: bool


func before_each() -> void:
	_saved_progress = GameState.progress
	_saved_level = GameState.current_level_id
	_saved_region = GameState.current_region_id
	_saved_revealed = SaveManager.data.get("regions_revealed", null)
	_saved_autosave = SaveManager.autosave
	SaveManager.autosave = false          # 一级地图会记揭开记录：测试里不写盘
	SELECT_SCRIPT.set("chapter_index", -1)


func after_each() -> void:
	GameState.progress = _saved_progress
	GameState.current_level_id = _saved_level
	GameState.current_region_id = _saved_region
	SaveManager.autosave = _saved_autosave
	if _saved_revealed == null:
		SaveManager.data.erase("regions_revealed")
	else:
		SaveManager.data["regions_revealed"] = _saved_revealed


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


func _world(completed: Array, revealed: Variant) -> Control:
	GameState.progress = { "completed": completed, "unlocked_levels": [] }
	GameState.current_region_id = ""
	if revealed == null:
		SaveManager.data.erase("regions_revealed")
	else:
		SaveManager.data["regions_revealed"] = revealed
	var w: Control = WORLD_SCENE.instantiate() as Control
	add_child_autofree(w)
	w.set("navigate", false)
	return w


static func _plate(w: Control, rid: String) -> Label:
	return w.find_child("Plate_" + rid, true, false) as Label


## 2026-10-20：没有右侧详情面板；未解锁区域的名牌是空的、压着锁；点已解锁区域直接进入
func test_world_map_locked_plates_and_enter() -> void:
	var w: Control = _world(_levels(1, 7), ["withered_farm"])
	var entered: Array[String] = []
	w.connect("region_entered", func(rid: String) -> void: entered.append(rid))
	await wait_process_frames(2)
	assert_eq((w.get("hotspots") as Dictionary).size(), 7, "七个区域热区")
	assert_null(w.find_child("EnterButton", true, false), "不再有「进入」按钮")
	assert_eq((w.get("revealing") as Array).size(), 0, "都已揭开，不播解锁动画")
	assert_string_contains(_plate(w, "withered_farm").text, "枯骨农田")
	assert_string_contains(_plate(w, "withered_farm").text, "1/4")
	assert_eq(_plate(w, "grey_thorn").text, "", "未解锁区域看不见名字")
	assert_true((w.find_child("Lock_grey_thorn", true, false) as Control).visible, "锁压在名牌上")
	assert_false((w.find_child("Lock_withered_farm", true, false) as Control).visible)
	assert_eq(str(w.get("frontier")), "withered_farm", "下一个要去的区域")
	((w.get("hotspots") as Dictionary)["grey_thorn"] as Button).pressed.emit()
	assert_eq(entered.size(), 0, "未解锁区域不能进入")
	((w.get("hotspots") as Dictionary)["bone_workshop"] as Button).pressed.emit()
	assert_eq(entered, ["bone_workshop"] as Array[String])
	assert_eq(GameState.current_region_id, "bone_workshop")
	var r: Rect2 = w.call("map_rect") as Rect2
	assert_almost_eq(r.get_center().x, w.get_viewport_rect().size.x * 0.5, 1.0, "地图水平居中")
	for rid: String in ORDER:
		assert_true(r.has_point(w.call("region_screen_pos", rid) as Vector2), "图标在地图内：" + rid)


## 刚解锁的区域：进场先按锁住显示、记入揭开记录，动画结束后名牌写上区域名
func test_world_map_reveal_newly_unlocked() -> void:
	var w: Control = _world(_levels(1, 6), [])
	await wait_process_frames(2)
	assert_eq(w.get("revealing") as Array, ["withered_farm"] as Array[String] if UiKit.motion_enabled else [] as Array[String])
	assert_true((SaveManager.revealed_regions() as Array).has("withered_farm"), "揭开记录在动画开始时写入")
	if UiKit.motion_enabled:
		assert_eq(_plate(w, "withered_farm").text, "", "动画前仍是空名牌")
		w.call("skip_reveals")
	assert_string_contains(_plate(w, "withered_farm").text, "枯骨农田")
	assert_false((w.find_child("Lock_withered_farm", true, false) as Control).visible)
	assert_eq(_plate(w, "bone_workshop").text.contains("人偶工坊"), true, "开局区域不播动画")


## 旧存档没有揭开记录：只给最新解锁的区域补播一次
func test_world_map_reveal_seeds_old_save() -> void:
	var w: Control = _world(_levels(1, 10), null)
	await wait_process_frames(2)
	assert_eq(w.call("pending_reveals") as Array, [] as Array[String], "补种后不再待揭开")
	var seen: Array = SaveManager.revealed_regions() as Array
	assert_true(seen.has("withered_farm") and seen.has("grey_thorn"))
	if UiKit.motion_enabled:
		assert_eq(w.get("revealing") as Array, ["grey_thorn"] as Array[String], "只播最新的灰棘林")
	w.call("skip_reveals")


## 连跳几关、一次解锁多个区域：全部记入揭开记录，只给最后一个播动画，其余直接显示为已解锁
func test_world_map_multiple_unlocks_reveal_only_last() -> void:
	var w: Control = _world(_levels(1, 10), [])
	await wait_process_frames(2)
	var seen: Array = SaveManager.revealed_regions() as Array
	assert_true(seen.has("withered_farm") and seen.has("grey_thorn"), "两个区域都记入揭开记录")
	assert_string_contains(_plate(w, "withered_farm").text, "枯骨农田", "前面的区域直接解锁")
	assert_false((w.find_child("Lock_withered_farm", true, false) as Control).visible)
	assert_eq(w.get("revealing") as Array, ["grey_thorn"] as Array[String] if UiKit.motion_enabled else [] as Array[String], "只给最后一个播")
	w.call("skip_reveals")

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
	# 2026-10-20：详情面板可收起，节点平铺整张区域地图；设计坐标（1920×1080）下名牌不进左右羽化边（FEATHER_PX）
	var design: Vector2 = UiKit.design_size("chapter")
	var half_plate: float = UiKit.layout_rect("chapter", "plate", design).size.x * 0.5
	var feather: float = float((load("res://scripts/screens/level_select.gd") as GDScript).get_script_constant_map()["FEATHER_PX"])
	var wc: ChapterDef = DataRegistry.world_chapter()
	for rid: String in ORDER:
		var k: float = 1080.0 / (wc.region(rid)["map_size"] as Vector2).y
		var w: float = (wc.region(rid)["map_size"] as Vector2).x * k
		var xs: Array[float] = []
		for n: Dictionary in wc.region_nodes(rid):
			var x: float = (n["pos"] as Vector2).x * k
			xs.append(x)
			assert_true(x - half_plate >= feather and x + half_plate <= w - feather, "%s 节点 %s 在地图内、不进羽化边" % [rid, str(n["id"])])
		assert_gt(xs.max() - xs.min(), w * 0.6, "%s 节点平铺整张地图（不挤在面板左侧）" % rid)


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
