extends Node
## 把几个界面各截一张图到 res://.screens/，用来肉眼确认布局没写错。
## 只在需要时手动跑：
##   godot --path <项目目录> --resolution 1920x1080 res://tools/capture_screens.tscn

const OUT_DIR := "res://.screens"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await _settle()
	await _shot("01_main_menu")

	var settings: Node = menu.get_node("SettingsMenu")
	settings.open()
	await _settle()
	await _shot("02_settings")
	settings.close()
	menu.queue_free()
	await _settle()

	var game: Node = load("res://scenes/game/game_scene.tscn").instantiate()
	add_child(game)
	await _settle()
	await _shot("03_game")

	var pause: Node = game.get_node("PauseMenu")
	pause.open()
	await _settle()
	await _shot("04_pause")
	pause.close()
	game.queue_free()
	await _settle()

	print("截图完成 -> ", OUT_DIR)
	get_tree().quit()

func _settle() -> void:
	for i in 12:
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	var err := img.save_png(path)
	print("截图 %s 错误码 %d 尺寸 %s" % [shot_name, err, str(img.get_size())])

	# 顺手打点统计：不用眼睛也能判断"到底画出来东西没有"
	var mid := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	var corner := img.get_pixel(4, 4)
	var seen := {}
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			seen[img.get_pixel(x, y).to_rgba32()] = true
	print("   中心 %s / 左上角 %s / 抽样唯一色数 %d" % [str(mid), str(corner), seen.size()])
	print("   中心与左上角是否相同: %s" % str(mid.to_rgba32() == corner.to_rgba32()))
