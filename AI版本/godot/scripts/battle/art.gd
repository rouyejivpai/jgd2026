class_name Art
extends RefCounted
## 美术资源访问（M7）：文件存在才加载（资源由资源生产流程陆续放入 assets/），缺失时返回 null，调用方回退占位绘制。

const SHADER_DIR: String = "res://assets/shaders/"
const SPRITE_DIR: String = "res://assets/sprites/"
const LIGHT_TEXTURE_SIZE: int = 256

static var _cache: Dictionary = {}
static var _light_texture: GradientTexture2D = null


## 路径可为 res:// 全路径或相对 assets/sprites/ 的路径；"none" / "" 返回 null
static func texture(path: String) -> Texture2D:
	if path == "" or path == "none":
		return null
	var full: String = path if path.begins_with("res://") else SPRITE_DIR + path
	if _cache.has(full):
		return _cache[full] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(full):
		tex = load(full) as Texture2D
	_cache[full] = tex
	return tex


## 形态 / 单位的精灵贴图（units.json visuals.sprite），缺失为 null（10 §4 拖拽虚影）
static func unit_texture(unit_id: String) -> Texture2D:
	var udef: UnitDefinition = DataRegistry.get_unit(unit_id)
	return texture(str(udef.visuals.get("sprite", ""))) if udef != null else null


static func shader(name: String) -> Shader:
	return load(SHADER_DIR + name + ".gdshader") as Shader


static func material(shader_name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(shader_name)
	return m


## PointLight2D 用的径向软光纹理（程序生成，不依赖 vfx/soft_circle.png）
static func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = LIGHT_TEXTURE_SIZE
		t.height = LIGHT_TEXTURE_SIZE
		_light_texture = t
	return _light_texture


static func color_from_hex(hex: String, fallback: Color) -> Color:
	return Color.html(hex) if Color.html_is_valid(hex) else fallback
