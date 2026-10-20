extends GutTest
## 开场动画（data/opening.json）：数据与画面齐全；时间表单调；整段推进只结束一次；长按 Esc 满 HOLD_TO_SKIP 才跳过；碎裂事件换图。
## 测试关掉 _process、由测试手动 step；auto_reveal = false，不真的切场景。

const OPENING_SCENE: PackedScene = preload("res://scenes/screens/opening.tscn")
const Opening := preload("res://scripts/screens/opening.gd")

var _op: Control


func before_each() -> void:
	_op = OPENING_SCENE.instantiate() as Control
	_op.set("auto_reveal", false)
	add_child_autofree(_op)
	_op.set_process(false)
	_op.set("_finished", false)            # 无动效环境下 _ready 会排队直接结束，这里撤销
	_op.call("_enter_panel", 0)


func _panels() -> Array:
	return _op.get("panels") as Array


func test_data_and_art_exist() -> void:
	var panels: Array = _panels()
	assert_gt(panels.size(), 10)
	for p: Variant in panels:
		var d: Dictionary = p as Dictionary
		assert_gt((d.get("lines", []) as Array).size(), 0)
		var names: Array = [str(d.get("image", ""))]
		for ev: Variant in d.get("events", []) as Array:
			names.append(str((ev as Dictionary).get("image", "")))
		for n: Variant in names:
			if str(n) != "":
				assert_true(ResourceLoader.exists("res://assets/cg/opening/%s.png" % n), "missing art %s" % n)


func test_plan_is_monotonic() -> void:
	for p: Variant in _panels():
		var plan: Dictionary = Opening.plan_panel(p as Dictionary, 11.0)
		var starts: PackedFloat32Array = plan["starts"]
		var ends: PackedFloat32Array = plan["ends"]
		for i: int in starts.size():
			assert_lt(starts[i], ends[i])
			if i > 0:
				assert_gt(starts[i], ends[i - 1])
		assert_gt(float(plan["out_end"]), ends[ends.size() - 1])


func test_runs_to_end_once() -> void:
	var guard: int = 0
	while not bool(_op.get("_finished")) and guard < 30 * 60 * 8:
		_op.call("step", 1.0 / 30.0)
		guard += 1
	assert_true(bool(_op.get("_finished")))
	assert_eq(int(_op.get("_index")), _panels().size())


func test_short_escape_does_not_skip() -> void:
	_op.call("set_escape_held", true)
	_op.call("step", Opening.HOLD_TO_SKIP * 0.5)
	_op.call("set_escape_held", false)
	_op.call("step", 0.1)
	assert_false(bool(_op.get("_skipping")))
	assert_almost_eq(float(_op.get("_esc_held")), 0.0, 0.0001)


func test_long_escape_skips() -> void:
	_op.call("set_escape_held", true)
	for i: int in int(ceil(Opening.HOLD_TO_SKIP * 30.0)) + 1:
		_op.call("step", 1.0 / 30.0)
	assert_true(bool(_op.get("_skipping")))
	for i: int in int(ceil(Opening.SKIP_FADE * 30.0)) + 1:
		_op.call("step", 1.0 / 30.0)
	assert_true(bool(_op.get("_finished")))


func test_shatter_event_swaps_art() -> void:
	var idx: int = -1
	var panels: Array = _panels()
	for i: int in panels.size():
		if str((panels[i] as Dictionary).get("image", "")) == "p09":
			idx = i
	assert_gt(idx, -1)
	_op.call("_enter_panel", idx)
	var plan: Dictionary = _op.get("_plan")
	var starts: PackedFloat32Array = plan["starts"]
	_op.call("step", starts[1] + 0.05)
	var tex: Texture2D = _op.get("_tex_a")
	assert_true(tex != null and tex.resource_path.ends_with("p09b.png"))


## 运镜单向：每幅画的取景中心在 x / y 上都不折返，取景矩形始终在原图内
func test_camera_moves_one_way() -> void:
	var ts := Vector2(1680.0, 820.0)
	for p: Variant in _panels():
		var d: Dictionary = p as Dictionary
		if str(d.get("image", "")) == "":
			continue
		var prev: Vector2 = Opening.camera_rect(d, 0.0, ts).get_center()
		var dir := Vector2.ZERO
		for k: int in range(1, 101):
			var r: Rect2 = Opening.camera_rect(d, k / 100.0, ts)
			assert_true(r.position.x >= -0.01 and r.position.y >= -0.01 and r.end.x <= ts.x + 0.01 and r.end.y <= ts.y + 0.01,
				"%s frame inside image" % d["image"])
			var c: Vector2 = r.get_center()
			var dv: Vector2 = c - prev
			for axis: int in 2:
				if absf(dv[axis]) > 0.0001:
					var sgn: float = signf(dv[axis])
					assert_true(dir[axis] == 0.0 or dir[axis] == sgn, "%s camera reverses on axis %d" % [d["image"], axis])
					dir[axis] = sgn
			prev = c
