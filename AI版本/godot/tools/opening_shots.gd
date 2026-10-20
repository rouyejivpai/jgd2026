extends SceneTree
## 开场动画截图：每幅画在最后一句打完时截一张，外加碎裂中途一张（需要真实窗口，不要 --headless）。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/opening_shots.gd -- [--out=tools/_work/opening_shots]
## （-s 入口脚本编译时看不到自动加载，场景运行时加载。）

var _out: String = "res://tools/_work/opening_shots"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1920, 1080)
	var op: Control = (load("res://scenes/screens/opening.tscn") as PackedScene).instantiate() as Control
	op.set("auto_reveal", false)
	root.add_child(op)
	await process_frame
	op.set_process(false)
	op.set("_finished", false)
	op.set("_hint_t", 0.0)
	var panels: Array = op.get("panels") as Array
	for i: int in panels.size():
		op.call("_enter_panel", i)
		var plan: Dictionary = op.get("_plan")
		var typed: PackedFloat32Array = plan["typed"]
		var target: float = typed[typed.size() - 1] + 0.3
		var t: float = 0.0
		while t < target:
			op.call("step", 1.0 / 30.0)
			t += 1.0 / 30.0
			if str((panels[i] as Dictionary).get("image", "")) == "p09" and absf(t - ((plan["starts"] as PackedFloat32Array)[1] + 0.55)) < 0.017:
				await _shot("%02d_shatter" % i)
		await _shot("%02d" % i)
	quit()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))
