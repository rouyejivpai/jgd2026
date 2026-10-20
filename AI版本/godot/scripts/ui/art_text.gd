class_name ArtText
extends Control
## 艺术字（10 §1.5、决策 ⑭；R6 资源 assets/ui/<界面>/art_text/<id>/）：按素材包 manifest.json 叠出 base（底字）、
## glow（光晕，screen 混合）与 frames（扫光覆盖帧，source-over），动效参数取 manifest 元素的 motion 字段（数据，非代码常量）。
## - 静止态（t = 0 或 UiKit.motion_enabled = false）：只显示 base，与设计图一致；glow / 扫光隐藏。
## - 没有 motion 字段的包（R6b 静态交付）只显示 base。
## 用法：
##   ArtText.attach(label, screen, layout_id, variant)  文字换艺术字：按 data/art_text.json 的 texts 表用 label.text 找素材包；
##       找到则 label 自身文字透明，艺术字作为其子节点，字形可见外框（alpha > 128）的高 = 布局 data.ref_ink 的高，
##       竖直中心对齐 ref_ink，水平按布局 align（left 对齐左缘、center / right 对齐 label 文字区）；找不到则恢复 label 文字。
##   ArtText.fill(node, key)  图片节点换艺术字（如主界面标题图）：素材包按 node 宽等比铺满，node 自身贴图透明。
##   ArtText.create(dir, ink_h)  直接建一个（如战斗开始提示），返回的节点 size = 缩放后的包尺寸。

const CONFIG: String = "res://data/art_text.json"
const SCREEN_SHADER: Shader = preload("res://assets/shaders/art_text_screen.gdshader")
const NODE_NAME: String = "ArtText"
const ALPHA_INK: float = 128.0 / 255.0

static var _config: Dictionary = {}
static var _ink_cache: Dictionary = {}       ## base 路径 → 字形可见外框（贴图像素）

var dir: String = ""
var motion: Dictionary = {}
var scale_k: float = 1.0
var t: float = 0.0
var _base: TextureRect
var _glow: TextureRect = null
var _sweep: TextureRect = null
var _frames: Array[Texture2D] = []


static func config() -> Dictionary:
	if _config.is_empty() and FileAccess.file_exists(CONFIG):
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) as Dictionary
		var fx: String = DataRegistry.FIXTURE_ROOT.path_join("art_text.json")     # 第一章关卡名艺术字（只在测试 / 工具运行时叠加）
		if DataRegistry.fixtures_enabled() and FileAccess.file_exists(fx):
			var texts: Dictionary = (_config.get("texts", {}) as Dictionary).duplicate()
			texts.merge((JSON.parse_string(FileAccess.get_file_as_string(fx)) as Dictionary).get("texts", {}) as Dictionary)
			_config["texts"] = texts
	return _config


## 文字 → 素材包目录（variant 非空时先找「文字@variant」）；没有则 ""
static func dir_for_text(text: String, variant: String = "") -> String:
	var texts: Dictionary = config().get("texts", {}) as Dictionary
	if variant != "" and texts.has(text + "@" + variant):
		return str(texts[text + "@" + variant])
	return str(texts.get(text, ""))


static func _manifest(p_dir: String) -> Dictionary:
	var path: String = p_dir.path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return {}
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not m is Dictionary or ((m as Dictionary).get("elements", []) as Array).is_empty():
		return {}
	return ((m as Dictionary)["elements"] as Array)[0] as Dictionary


## base 贴图的字形可见外框（贴图像素）
static func ink_rect(base: Texture2D) -> Rect2:
	var key: String = base.resource_path
	if _ink_cache.has(key):
		return _ink_cache[key] as Rect2
	var img: Image = base.get_image()
	if img.is_compressed():
		img.decompress()
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > ALPHA_INK:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var r := Rect2(Vector2(lo), Vector2(hi - lo + Vector2i.ONE)) if hi.x >= 0 else Rect2(Vector2.ZERO, base.get_size())
	_ink_cache[key] = r
	return r


## 建一个艺术字：字形可见高缩放到 ink_h（≤ 0 时 1:1）；包无效返回 null
static func create(p_dir: String, ink_h: float = 0.0) -> ArtText:
	var e: Dictionary = _manifest(p_dir)
	if e.is_empty():
		return null
	var a := ArtText.new()
	a.name = NODE_NAME
	a.dir = p_dir
	a.motion = e.get("motion", {}) as Dictionary
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer: Variant in e.get("layers", []) as Array:
		var ld: Dictionary = layer as Dictionary
		var tex: Texture2D = load(p_dir.path_join(str(ld["file"]))) as Texture2D
		if tex == null:
			continue
		match str(ld.get("id", "")):
			"base":
				a._base = a._layer(tex, ld)
			"glow":
				a._glow = a._layer(tex, ld)
				var mat := ShaderMaterial.new()
				mat.shader = SCREEN_SHADER
				a._glow.material = mat
	if a._base == null:
		a.free()
		return null
	var fr: Dictionary = e.get("frames", {}) as Dictionary
	if not fr.is_empty() and not a.motion.is_empty():
		a.motion = a.motion.duplicate()
		a.motion["fps"] = float(fr.get("fps", 30.0))
		for f: Variant in fr.get("files", []) as Array:
			var ft: Texture2D = load(p_dir.path_join(str(f))) as Texture2D
			if ft != null:
				a._frames.append(ft)
		if not a._frames.is_empty():
			a._sweep = a._layer(a._frames[0], fr)
	a.scale_k = ink_h / ink_rect(a._base.texture).size.y if ink_h > 0.0 else 1.0
	a._apply_scale()
	a._show_static()
	return a


func _layer(tex: Texture2D, ld: Dictionary) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var off: Array = ld.get("offset", [0, 0]) as Array
	var sz: Array = ld.get("size", [tex.get_width(), tex.get_height()]) as Array
	r.set_meta(&"px", Rect2(float(off[0]), float(off[1]), float(sz[0]), float(sz[1])))
	add_child(r)
	return r


func _apply_scale() -> void:
	size = _base.texture.get_size() * scale_k
	for c: Node in get_children():
		var r: Rect2 = (c as Control).get_meta(&"px") as Rect2
		(c as Control).position = r.position * scale_k
		(c as Control).size = r.size * scale_k


## 字形可见外框（本节点局部坐标）
func ink_local() -> Rect2:
	var r: Rect2 = ink_rect(_base.texture)
	return Rect2(r.position * scale_k, r.size * scale_k)


func is_animated() -> bool:
	return not motion.is_empty() and (_glow != null or _sweep != null)


func _show_static() -> void:
	if _glow != null:
		_glow.visible = false
	if _sweep != null:
		_sweep.visible = false
	set_process(is_animated() and UiKit.motion_enabled)


## 动效（R6a motion.md）：phase = t mod duration；envelope = sin(π·phase/duration)²；
## 光晕 opacity = glow_peak_opacity × envelope（screen）；扫光帧按 fps 取帧（透明度已烘焙，不再乘 envelope）
func _process(delta: float) -> void:
	if not UiKit.motion_enabled:
		_show_static()
		return
	t += delta
	var dur: float = maxf(float(motion.get("duration", 1.0)), 0.01)
	var phase: float = fmod(t, dur)
	var env: float = pow(sin(PI * phase / dur), 2.0)
	if _glow != null:
		_glow.visible = env > 0.0
		(_glow.material as ShaderMaterial).set_shader_parameter("opacity", float(motion.get("glow_peak_opacity", 1.0)) * env)
	if _sweep != null:
		var fps: float = float(motion.get("fps", float(_frames.size()) / dur))
		_sweep.texture = _frames[int(phase * fps) % _frames.size()]
		_sweep.visible = true


## 文字换艺术字（见文件头）
static func attach(label: Label, screen: String, layout_id: String, variant: String = "") -> ArtText:
	var old: Node = label.get_node_or_null(NODE_NAME)
	if old != null:
		old.free()
	var p_dir: String = dir_for_text(label.text, variant)
	var e: Dictionary = UiKit.layout_element(screen, layout_id)
	var ink: Array = (e.get("data", {}) as Dictionary).get("ref_ink", []) as Array
	var a: ArtText = create(p_dir, float(ink[3])) if p_dir != "" and ink.size() == 4 else null
	label.self_modulate.a = 0.0 if a != null else 1.0
	if a == null:
		return null
	var d: Vector2 = UiKit.design_size(screen)
	var text_r: Rect2 = UiKit.layout_text_rect(screen, layout_id, d)
	var ref := Rect2(float(ink[0]), float(ink[1]), float(ink[2]), float(ink[3]))
	ref.position -= text_r.position                                  # ref_ink 相对 label 文字区
	var il: Rect2 = a.ink_local()
	var x: float = ref.position.x - il.position.x
	match str(e.get("align", "left")):
		"center":
			x = text_r.size.x * 0.5 - il.get_center().x
		"right":
			x = text_r.size.x - il.end.x
	a.position = Vector2(x, ref.get_center().y - il.get_center().y)
	label.add_child(a)
	return a


## 图片节点换艺术字（见文件头）：config nodes 表 key → 素材包
static func fill(node: Control, key: String) -> ArtText:
	var p_dir: String = str((config().get("nodes", {}) as Dictionary).get(key, ""))
	var a: ArtText = create(p_dir) if p_dir != "" else null
	if a == null:
		return null
	a.scale_k = node.size.x / a._base.texture.get_size().x
	a._apply_scale()
	node.self_modulate.a = 0.0
	node.add_child(a)
	return a
