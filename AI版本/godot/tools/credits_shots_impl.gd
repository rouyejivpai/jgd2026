extends RefCounted
## credits_shots.gd 的实现（运行时加载，可引用自动加载）。不读写存档。

const TIMEOUT_FRAMES: int = 6000

var _tree: SceneTree = null
var _out: String = ""


func run(tree: SceneTree) -> void:
	_tree = tree
	_out = ProjectSettings.globalize_path("res://").path_join("../docs/screenshots/credits").simplify_path()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await tree.process_frame
	SceneRouter.goto_credits()
	for i: int in 120:
		await tree.process_frame
	var roll: CreditsRoll = tree.current_scene as CreditsRoll
	if roll == null:
		push_error("[credits_shots] current scene is not CreditsRoll")
		return
	var hero: Node2D = roll.get_node("Hero") as Node2D
	var crew: Array[Node] = roll.get_node("Crew").get_children()
	var view: Vector2 = roll.get_viewport_rect().size
	var marks: Array = [
		["01_enter", 260.0],
		["02_center", view.x * 0.5 + 40.0],
		["03_first_talk", (crew[0] as Node2D).position.x - 60.0],
		["04_mid", (crew[3] as Node2D).position.x + 40.0],
		["05_long_name", (crew[5] as Node2D).position.x + 10.0],
		["06_last", (crew[crew.size() - 1] as Node2D).position.x + 120.0],
	]
	for m: Array in marks:
		if not await _until(func() -> bool: return hero.position.x >= float(m[1])):
			push_error("[credits_shots] timeout before %s" % m[0])
			return
		await _shot(str(m[0]))
	if not await _until(func() -> bool: return roll.stage == CreditsRoll.Stage.EXIT and hero.position.x > (roll.get_node("Camera") as Camera2D).position.x + view.x * 0.3):
		push_error("[credits_shots] timeout before exit")
		return
	await _shot("07_exit")
	if not await _until(func() -> bool: return roll.get("_can_leave") == true):
		push_error("[credits_shots] timeout before card")
		return
	await _shot("08_card")
	print("[credits_shots] done -> %s" % _out)


func _until(cond: Callable) -> bool:
	for i: int in TIMEOUT_FRAMES:
		if cond.call():
			return true
		await _tree.process_frame
	return false


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = _tree.root.get_texture().get_image()
	if _tree.root.use_hdr_2d:
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png(_out.path_join(name + ".png"))
	print("[credits_shots] %s" % name)
