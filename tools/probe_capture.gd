extends Node
## 临时探针：验证「Godot 能在非 headless 下渲染并写出 PNG 吗」以及「写到哪里可以」。
## 这两条是「截图 + 像素断言」方案成立的前提。用完即删。
##
## 为什么先做这个：沙箱禁止子进程写 v0.0.1（之前 Godot 连 res://.godot/ 都写不了），
## 所以必须先把「哪个输出路径可写」测出来，否则整套方案不成立。

const RED := Color(1, 0, 0, 1)
const BLUE := Color(0, 0, 1, 1)

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# 造一块确定可见的内容：左上红、右下蓝，中心留默认底色
	var layer := CanvasLayer.new()
	add_child(layer)

	var left := ColorRect.new()
	left.color = RED
	left.position = Vector2(0, 0)
	left.size = Vector2(200, 200)
	layer.add_child(left)

	var right := ColorRect.new()
	right.color = BLUE
	right.position = Vector2(1720, 880)
	right.size = Vector2(200, 200)
	layer.add_child(right)

	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	print("PROBE 尺寸=", img.get_size())

	# 采几个点，确认「确实渲染出了我们放的东西」
	var p_red := img.get_pixel(50, 50)
	var p_blue := img.get_pixel(1800, 950)
	print("PROBE 左上(50,50)=", p_red, "  应为红=", p_red.is_equal_approx(RED))
	print("PROBE 右下(1800,950)=", p_blue, "  应为蓝=", p_blue.is_equal_approx(BLUE))

	# 逐条试输出路径：哪个能写出来
	var targets := [
		"res://.screens/__probe_res.png",
		"user://__probe_user.png",
		"D:/jgd2026/_logs/__probe_abs.png",
		"D:\\jgd2026\\_logs\\__probe_abs2.png",
	]
	for t in targets:
		# 【类型必须显式标注】targets 是 Variant 元素，`:=` 会触发
		# "Cannot infer the type" 而这就是警告即错误（本工程的老坑）。
		var path: String = str(t)
		var dir: String = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			var mk: int = DirAccess.make_dir_recursive_absolute(dir)
			print("PROBE mkdir ", dir, " -> ", mk)
		var err: int = img.save_png(path)
		print("PROBE save ", path, " -> err=", err, " (0=OK)")

	# 兜底方案：把 PNG 以 base64 打到 stdout，由外部解码落盘。
	# 这样完全不依赖 Godot 的写权限。
	var buf := img.save_png_to_buffer()
	print("PROBE base64_len=", Marshalls.raw_to_base64(buf).length())
	print("PROBE 完成")

	get_tree().quit()
