extends Sprite2D
## BackdropLayer（07 §1.1）：整幅纯背景，始终铺满视口（按 cover 规则等比放大、居中裁边），不参与任何交互。
## 10 §6.4：绘制宽度 = 视口宽 + 2·PAN_MAX（cover 缩放、中心对齐），随镜头横移 pan_x 整体平移，偏移在 ±PAN_MAX 内不露底。
## 资源 backdrop（1920×1080）未到位前，关卡 scene.backdrop 指向第一阶段的 8 张背景作占位（07 P1-5）。
## 文件缺失时隐藏（只剩 BG_DEEP 底色）。
## 10 §7（P7，R4）：关卡有障碍块清单（scene.obstacles）时 backdrop 是按玩法矩形标线图画的对齐底图，按设计坐标 1:1 居中铺
## （与 Playfield 同一换算，地面与网格逐格对齐），不再为镜头横移放大；横移时两侧露出底色。

## 2026-10-18 区域底图：整张图同时承担地面，LightLayer 的 CanvasModulate（约 0.35 倍亮度）会把它压到几乎全黑，
## 这里只对底图提亮补偿，单位光照与场景氛围不变
const BRIGHTNESS: float = 1.45

var level: LevelDefinition = null
var pan_x: float = 0.0
## 第四阶段：与地图层同一视图变换（BattleRoot.set_view）：缩放中心 c、倍率 zoom、偏移 pan
var view_center: Vector2 = Vector2.ZERO
var view_zoom: float = 1.0
var pan_y: float = 0.0


## 返回是否成功加载
func setup(p_level: LevelDefinition) -> bool:
	level = p_level
	var tex: Texture2D = Art.texture(level.scene_backdrop)
	visible = tex != null
	if tex == null:
		return false
	texture = tex
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	centered = true
	region_enabled = false
	material = null
	self_modulate = Color(BRIGHTNESS, BRIGHTNESS, BRIGHTNESS, 1.0)
	if not get_viewport().size_changed.is_connected(fit):
		get_viewport().size_changed.connect(fit)
	fit()
	return true


func fit() -> void:
	if texture == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var ts: Vector2 = texture.get_size()
	var k: float = maxf((vp.x + 2.0 * UiKit.PAN_MAX) / ts.x, vp.y / ts.y)
	if level != null and level.scene_obstacles != "":
		k = Playfield.DESIGN_SIZE.y / ts.y
	scale = Vector2(k, k) * view_zoom
	var c: Vector2 = view_center if view_center != Vector2.ZERO else vp * 0.5
	position = c + (vp * 0.5 - c) * view_zoom - Vector2(pan_x, pan_y)


func set_pan(x: float) -> void:
	pan_x = x
	fit()


func set_view(center: Vector2, zoom: float, pan: Vector2) -> void:
	view_center = center
	view_zoom = zoom
	pan_x = pan.x
	pan_y = pan.y
	fit()


## 当前绘制矩形（视口像素，测试用）
func drawn_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var sz: Vector2 = texture.get_size() * scale
	return Rect2(position - sz * 0.5, sz)
