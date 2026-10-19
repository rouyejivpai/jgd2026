class_name ObstacleProps
extends Node2D
## 立体地块物件（用户 2026-10-20）：场上的东西分两类——标志（障碍格标志、出生点 / 目标 / 逃离区标志、各色发光边线）
## 仍由 GridOverlay 平画在地面；实际存在的立体物（地形效果格的物件图：危险区 = 裂甲菌簇、缓滞带 = 僵骨地刺、净化台 = 静息祭坛）
## 在这里竖立绘制：挂在 UnitLayer 下并开启 y_sort，与角色一样按脚底 y 排序（角色站在物件后一格会被挡住下半身）。
## 单件单薄的（菌簇、地刺）每格摆成一丛：CLUMPS 的件数、在格内错落（落点 + 抖动、高度 / 倾斜 / 翻转 / 明暗随机），连起来像花丛草丛；
## 祭坛本身厚实，每格一件。用户 2026-10-20：地形物件可以轻微出框（落点铺到格边、件宽越出格线 0.1–0.2 格），相邻格连成一片，减少一格一框的僵硬感。这些地块可以行走，所以各件都落在格子后半（脚底 y 在格中心之上）：
## 站在该格上的角色总是压在物件前面，血条（在脚底下方）不会被物件挡住。
## 用户 2026-10-20：第一章手绘障碍块里属于立体物的（荆棘窝 / 荆棘带、碎石带、碎骨木板堆）也在这里竖立成丛：obstacles.json 的块带
## "upright": "<样式名>" 时 GroundLayer 不再平贴该块，改在所占每格按 UPRIGHT 的样式摆一丛（多张变体图轮换）。障碍格不可行走，
## 落点铺满整格（前后都放），件宽越出格线一点；裂石地板这类地面标志不带 upright，仍平贴。
## 随机按关卡 id + 格坐标定种子，每次进关摆放相同。只碰表现，不碰模拟。坐标为 UnitLayer 局部（每格 TILE_SIZE），与 UnitView 相同。

const OBJECT_DIR: String = "tile_objects/%s.png"    ## 与 GridOverlay.TILE_OBJECT_DIR 同一套物件图
## 每种地块：count = 每格件数 [min, max]；height = 每件显示高度范围（格）；tilt_deg = 随机倾斜上限
const CLUMPS: Dictionary = {
	"hazard": { "count": [3, 4], "height": [0.58, 0.84], "tilt_deg": 11.0 },
	"mire": { "count": [2, 3], "height": [0.5, 0.7], "tilt_deg": 9.0 },
	"shrine": { "count": [1, 1], "height": [1.0, 1.0], "tilt_deg": 0.0 },
}
## 每格 n 件时的基准落点（格，相对格中心；y 负 = 靠后）。全部在格中心之后，两侧铺到格边（件宽再越出格线一点），
## 后排居中、两侧略靠前，看上去是一丛而不是一排
const SLOTS: Array = [
	[],
	[Vector2(0.0, -0.12)],
	[Vector2(-0.26, -0.2), Vector2(0.27, -0.1)],
	[Vector2(-0.33, -0.12), Vector2(0.02, -0.3), Vector2(0.33, -0.16)],
	[Vector2(-0.37, -0.08), Vector2(-0.12, -0.32), Vector2(0.16, -0.26), Vector2(0.38, -0.1)],
]
## 障碍格竖立样式（obstacles.json 块的 upright 字段）：files = 变体图（相对 assets/sprites/），每格各件轮换取用；
## size = 每件长边（宽、高取大者）的显示尺寸范围（格），矮宽的变体不会被拉高；其余同 CLUMPS。
## tools/validate_data.py 按本表的样式名与 files 校验（解析本文件），新增样式在这里登记
const UPRIGHT: Dictionary = {
	"thorn": { "files": ["obstacle_props/thorn_1.png", "obstacle_props/thorn_2.png", "obstacle_props/thorn_3.png", "obstacle_props/thorn_4.png"], "count": [3, 4], "size": [0.9, 1.15], "tilt_deg": 7.0 },
	"rubble": { "files": ["obstacle_props/rubble_1.png", "obstacle_props/rubble_2.png", "obstacle_props/rubble_3.png", "obstacle_props/rubble_4.png"], "count": [3, 3], "size": [0.82, 1.08], "tilt_deg": 3.0 },
	"bones": { "files": ["obstacle_props/bones_1.png", "obstacle_props/bones_2.png", "obstacle_props/bones_3.png", "obstacle_props/bones_4.png"], "count": [2, 3], "size": [0.82, 1.05], "tilt_deg": 5.0 },
}
## 障碍格每格 n 件时的基准落点（格，相对格中心）：前后两排铺满整格，后排靠两侧、前排居中错开
const BLOCK_SLOTS: Array = [
	[],
	[Vector2(0.0, 0.08)],
	[Vector2(-0.24, -0.16), Vector2(0.24, 0.14)],
	[Vector2(-0.3, -0.2), Vector2(0.3, -0.14), Vector2(0.02, 0.22)],
	[Vector2(-0.3, -0.26), Vector2(0.28, -0.22), Vector2(-0.2, 0.18), Vector2(0.3, 0.24)],
]
const BLOCK_JITTER: Vector2 = Vector2(0.1, 0.08)   ## 障碍格落点抖动（格），前后都可
const JITTER: Vector2 = Vector2(0.1, 0.08)   ## 落点抖动（格）；y 向抖动只往后，不越过格中心
const TINT: Color = Color(1.2, 1.2, 1.2, 1.0)   ## 略提亮抵消 CanvasModulate 的压暗（同 GridOverlay.TILE_OBJECT_TINT）
const SHADE_RANGE: Vector2 = Vector2(0.9, 1.04)
const SHADOW_ALPHA: float = 0.45         ## 接地阴影（中心处叠加后的不透明度）
const SHADOW_RINGS: int = 3
const SHADOW_FLATTEN: float = 0.34       ## 椭圆纵横比
const SHADOW_WIDTH: float = 0.4          ## 阴影半宽 = 件宽 × 该值

static var _content_cache: Dictionary = {}   ## Texture2D → Rect2i（不透明像素外接框，画布像素）

var level: LevelDefinition = null
var _items: Array[Dictionary] = []


func setup(p_level: LevelDefinition) -> void:
	level = p_level
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for ch: Node in get_children():
		ch.queue_free()
	_items = layout(level)
	for it: Dictionary in _items:
		var tex: Texture2D = it["tex"] as Texture2D
		var s := Sprite2D.new()
		s.texture = tex
		s.offset = Vector2(0.0, tex.get_size().y * 0.5 - float(content_rect(tex).end.y))    # 节点原点 = 脚底（不透明像素的下沿）
		s.position = it["foot"] as Vector2
		s.scale = Vector2(float(it["scale"]), float(it["scale"]))
		s.flip_h = bool(it["flip"])
		s.rotation = float(it["tilt"])
		s.modulate = it["tint"] as Color
		add_child(s)
	queue_redraw()


## 是否有任何地块用竖立物件表现（GridOverlay 据此不再平画这些物件图）
static func has_objects(p_level: LevelDefinition) -> bool:
	for kind: String in p_level.tiles.keys():
		if CLUMPS.has(kind) and Art.texture(OBJECT_DIR % kind) != null and not (p_level.tiles[kind] as Array).is_empty():
			return true
	return false


## 样式的全部变体贴图（缺图的跳过）；未登记的样式返回空
static func upright_textures(style: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for f: Variant in (UPRIGHT.get(style, {}) as Dictionary).get("files", []) as Array:
		var tex: Texture2D = Art.texture(str(f))
		if tex != null:
			out.append(tex)
	return out


## 全部竖立件：{ kind, cell, tex, foot（本层局部）, scale, flip, tilt（弧度）, tint, shadow_rx }，按脚底 y 升序；
## kind = 地形效果格种类，或障碍格的 "obstacle:<样式>"
static func layout(p_level: LevelDefinition) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: float = float(SimTypes.TILE_SIZE)
	_layout_obstacles(p_level, out)
	for kind: String in p_level.tiles.keys():
		var cd: Dictionary = CLUMPS.get(kind, {}) as Dictionary
		var tex: Texture2D = Art.texture(OBJECT_DIR % kind) if not cd.is_empty() else null
		if tex == null:
			continue
		var used: Rect2i = content_rect(tex)
		var count: Array = cd["count"] as Array
		var height: Array = cd["height"] as Array
		for cell: Vector2i in p_level.tiles[kind] as Array[Vector2i]:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%s:%d:%d" % [p_level.id, kind, cell.x, cell.y])
			var n: int = clampi(rng.randi_range(int(count[0]), int(count[1])), 1, SLOTS.size() - 1)
			var center: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), p_level.height)
			for i: int in n:
				var k: float = rng.randf_range(float(height[0]), float(height[1])) * t / maxf(float(used.size.y), 1.0)
				var jitter := Vector2(rng.randf_range(-JITTER.x, JITTER.x), rng.randf_range(-JITTER.y, 0.0))
				var shade: float = rng.randf_range(SHADE_RANGE.x, SHADE_RANGE.y)
				out.append({
					"kind": kind,
					"cell": cell,
					"tex": tex,
					"foot": center + ((SLOTS[n] as Array)[i] as Vector2 + jitter) * t,
					"scale": k,
					"flip": n > 1 and rng.randf() < 0.5,
					"tilt": deg_to_rad(rng.randf_range(-float(cd["tilt_deg"]), float(cd["tilt_deg"]))),
					"tint": Color(TINT.r * shade, TINT.g * shade, TINT.b * shade, 1.0),
					"shadow_rx": float(used.size.x) * k * SHADOW_WIDTH,
				})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["foot"] as Vector2).y < (b["foot"] as Vector2).y)
	return out


## 带 upright 的障碍块：所占每格摆一丛，件数 / 高度 / 倾斜按样式，变体图在一格内轮换（起点随机），同格不重样
static func _layout_obstacles(p_level: LevelDefinition, out: Array[Dictionary]) -> void:
	var t: float = float(SimTypes.TILE_SIZE)
	for pc: Dictionary in p_level.obstacle_pieces:
		var style: String = str(pc.get("upright", ""))
		var texs: Array[Texture2D] = upright_textures(style)
		if texs.is_empty():
			continue
		var sd: Dictionary = UPRIGHT[style] as Dictionary
		var count: Array = sd["count"] as Array
		var size: Array = sd["size"] as Array
		for cell: Vector2i in pc["cells"] as Array[Vector2i]:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:obstacle:%s:%d:%d" % [p_level.id, style, cell.x, cell.y])
			var n: int = clampi(rng.randi_range(int(count[0]), int(count[1])), 1, BLOCK_SLOTS.size() - 1)
			var center: Vector2 = SimTypes.sim_to_screen(SimTypes.cell_center(cell), p_level.height)
			var first: int = rng.randi_range(0, texs.size() - 1)
			for i: int in n:
				var tex: Texture2D = texs[(first + i) % texs.size()]
				var used: Rect2i = content_rect(tex)
				var k: float = rng.randf_range(float(size[0]), float(size[1])) * t / maxf(float(maxi(used.size.x, used.size.y)), 1.0)
				var jitter := Vector2(rng.randf_range(-BLOCK_JITTER.x, BLOCK_JITTER.x), rng.randf_range(-BLOCK_JITTER.y, BLOCK_JITTER.y))
				var shade: float = rng.randf_range(SHADE_RANGE.x, SHADE_RANGE.y)
				out.append({
					"kind": "obstacle:" + style,
					"cell": cell,
					"tex": tex,
					"foot": center + ((BLOCK_SLOTS[n] as Array)[i] as Vector2 + jitter) * t,
					"scale": k,
					"flip": rng.randf() < 0.5,
					"tilt": deg_to_rad(rng.randf_range(-float(sd["tilt_deg"]), float(sd["tilt_deg"]))),
					"tint": Color(TINT.r * shade, TINT.g * shade, TINT.b * shade, 1.0),
					"shadow_rx": float(used.size.x) * k * SHADOW_WIDTH,
				})


## 接地阴影：本节点自身的绘制在 y 排序中先于所有子件与角色（本节点 y = 0），所以阴影总在物件与角色之下
func _draw() -> void:
	for it: Dictionary in _items:
		var rx: float = float(it["shadow_rx"])
		draw_set_transform(it["foot"] as Vector2, 0.0, Vector2(1.0, SHADOW_FLATTEN))
		for r: int in SHADOW_RINGS:
			var f: float = 1.0 - float(r) / float(SHADOW_RINGS) * 0.45
			draw_circle(Vector2.ZERO, rx * f, Color(0.0, 0.0, 0.0, SHADOW_ALPHA / float(SHADOW_RINGS)))
	draw_set_transform(Vector2.ZERO)


## 贴图不透明像素的外接框（画布像素）；读不到图像时按整张画布
static func content_rect(tex: Texture2D) -> Rect2i:
	if _content_cache.has(tex):
		return _content_cache[tex] as Rect2i
	var r := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		r = img.get_used_rect()
	_content_cache[tex] = r
	return r
