class_name CreditsBubble
extends Control
## 片尾名单的对话框（2026-10-20；同日按用户「不要素的线框图」改用游戏现有切图装饰）：
## · 底板：剧情对话框同色的紫黑玻璃底（上亮下暗的微光 + 柔和投影），底边一道两端渐隐的银粉细光（同 toast_bg）；
## · 四角：教学框的银色荆棘角花（assets/ui/gothic/tut_corner.png，左上 / 右下各一）；
## · 名牌：英文职位（Cinzel 小号大写、加字距）在上；中文职位 + 名字（同剧情说话人：思源宋体粗体）夹在剧情名牌的两片银白弯刃之间
##   （assets/credits/name_blade_l/r.png，tools/credits/cut_ornaments.py 从剧情对话框切图抠出）；
## · 正文：对玩家说的话（思源宋体，同剧情正文配色），逐字显示；
## · 尾巴：剧情「继续」吊坠（assets/ui/gothic/dialogue_next.png）挂在底边正中，尖端指向开发者头顶。
## 本节点的 position 就是吊坠尖（放在开发者头顶上方）；挂在跟随镜头的 CanvasLayer 上，按世界坐标摆放、随镜头平移。

const WIDTH: float = 380.0               ## 正文换行宽度
const WIDE_WIDTH: float = 450.0          ## 长句（超过 LONG_CHARS 字）用的换行宽度
const LONG_CHARS: int = 40
const PAD: Vector2 = Vector2(30.0, 18.0)
const ROLE_EN_SIZE: int = 14
const ROLE_SIZE: int = 19
const NAME_SIZE: int = 30
const TEXT_SIZE: int = 23
const BLADE_HEIGHT: float = 46.0
const TAIL_SCALE: float = 0.72
const TAIL_OVERLAP: float = 0.42         ## 吊坠高度中压进底板的比例（圆球骑在底边上）
const CORNER_SCALE: float = 0.85
const CORNER_INSET: Vector2 = Vector2(-9.0, -9.0)
const CHARS_PER_SECOND: float = 22.0
const POP_SECONDS: float = 0.35
const FADE_SECONDS: float = 0.6
const RISE_PX: float = 14.0
const BG_TOP: Color = Color(0.235, 0.17, 0.25, 0.93)       ## 剧情对话框的紫灰（上）
const BG_BOTTOM: Color = Color(0.13, 0.085, 0.13, 0.95)    ## → 紫黑（下）
const SHEEN: Color = Color(0.93, 0.82, 0.9, 0.55)          ## 底边细光 / 顶边高光
const ROLE_COLOR: Color = Color("#B9A3B5")
const NAME_COLOR: Color = Color("#F5F2F5")
const TEXT_COLOR: Color = Color("#E6E0E8")
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.7)
const BLADE_L: String = "res://assets/credits/name_blade_l.png"
const BLADE_R: String = "res://assets/credits/name_blade_r.png"
const CORNER: String = "res://assets/ui/gothic/tut_corner.png"
const TAIL: String = "res://assets/ui/gothic/dialogue_next.png"
const SERIF: FontFile = preload("res://assets/fonts/NotoSerifSC-Regular.otf")
const SERIF_BOLD: FontFile = preload("res://assets/fonts/NotoSerifSC-Bold.otf")
const CINZEL: FontFile = preload("res://assets/fonts/Cinzel-Regular.ttf")

var _panel: PanelContainer
var _deco: Control
var _tail: TextureRect
var _message: Label
var _typing: bool = false
var _shown: bool = false


func setup(member: Dictionary, _font: Font = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)             # 底色由 _deco 画渐变；这里只要投影与内边距
	box.set_corner_radius_all(6)
	box.content_margin_left = PAD.x
	box.content_margin_right = PAD.x
	box.content_margin_top = PAD.y
	box.content_margin_bottom = PAD.y + 10.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", box)
	_deco = Control.new()                                  # 渐变底板：画在面板之前（面板本身透明，文字在上）
	_deco.name = "Plate"
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_plate)
	add_child(_deco)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	var role_en: String = str(member.get("role_en", "")).to_upper()
	if role_en != "":
		var en := _label(role_en, ROLE_EN_SIZE, ROLE_COLOR, _spaced(CINZEL, 4))
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en.modulate.a = 0.85
		col.add_child(en)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(_blade(BLADE_L))
	var role := _label(str(member.get("role", "")), ROLE_SIZE, ROLE_COLOR, SERIF)
	role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(role)
	var name_label := _label(str(member.get("name", "")), NAME_SIZE, NAME_COLOR, SERIF_BOLD)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	head.add_child(_blade(BLADE_R))
	_message = _label(str(member.get("message", "")), TEXT_SIZE, TEXT_COLOR, SERIF)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # 按 ICU 断行：句号等标点不落到行首
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size = Vector2(WIDE_WIDTH if _message.text.length() > LONG_CHARS else WIDTH, 0.0)
	_message.add_theme_constant_override("line_spacing", 6)
	_message.visible_ratio = 0.0
	col.add_child(_message)
	var corner_tex: Texture2D = Art.texture(CORNER)
	for flip: bool in [false, true]:
		if corner_tex == null:
			break
		var c := Sprite2D.new()
		c.name = "CornerBR" if flip else "CornerTL"
		c.texture = corner_tex
		c.centered = false
		c.scale = Vector2.ONE * CORNER_SCALE
		if flip:
			c.rotation = PI
		_deco.add_child(c)
	var tail_tex: Texture2D = Art.texture(TAIL)
	if tail_tex != null:
		_tail = TextureRect.new()
		_tail.name = "Pendant"
		_tail.texture = tail_tex
		_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tail.size = tail_tex.get_size() * TAIL_SCALE
		_tail.position = Vector2(-_tail.size.x * 0.5, -_tail.size.y)
		add_child(_tail)
	_panel.resized.connect(_place_panel)        # 自动换行要等排版后才知道真实高度：每次尺寸变化都重新让面板底边压住吊坠
	_panel.reset_size()
	_place_panel()


func _place_panel() -> void:
	var sz: Vector2 = _panel.size
	var tail_h: float = _tail.size.y if _tail != null else 18.0
	_panel.position = Vector2(-sz.x * 0.5, -sz.y - tail_h * (1.0 - TAIL_OVERLAP))
	_deco.position = _panel.position
	_deco.size = sz
	var tl: Node2D = _deco.get_node_or_null("CornerTL") as Node2D
	var br: Node2D = _deco.get_node_or_null("CornerBR") as Node2D
	if tl != null:
		tl.position = CORNER_INSET
	if br != null:
		br.position = sz - CORNER_INSET
	_deco.queue_redraw()


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


func _spaced(base: Font, spacing: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = spacing
	return v


func _blade(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.texture(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w: float = 22.0
	if t.texture != null:
		w = BLADE_HEIGHT * float(t.texture.get_width()) / float(t.texture.get_height())
	t.custom_minimum_size = Vector2(w, BLADE_HEIGHT)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## 紫黑玻璃底板：上下渐变 + 顶边一道淡高光 + 底边两端渐隐的银粉细光
func _draw_plate() -> void:
	var sz: Vector2 = _deco.size
	_deco.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0.0), sz, Vector2(0.0, sz.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	_fade_line(1.0, sz.x, Color(SHEEN, 0.22), 1.0)
	_fade_line(sz.y - 1.0, sz.x, SHEEN, 1.5)


func _fade_line(y: float, w: float, c: Color, width: float) -> void:
	var pts := PackedVector2Array([Vector2(0.0, y), Vector2(w * 0.5, y), Vector2(w, y)])
	_deco.draw_polyline_colors(pts, PackedColorArray([Color(c, 0.0), c, Color(c, 0.0)]), width, true)


## 弹出：淡入 + 由小变大 + 上浮，然后逐字显示正文
func pop() -> void:
	if _shown:
		return
	_shown = true
	_typing = true
	scale = Vector2(0.85, 0.85)
	var target_y: float = position.y
	position.y += RISE_PX
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, POP_SECONDS)
	t.tween_property(self, "scale", Vector2.ONE, POP_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "position:y", target_y, POP_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func fade() -> void:
	_typing = false
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)


func is_shown() -> bool:
	return _shown


func _process(delta: float) -> void:
	if not _typing:
		return
	var total: int = maxi(_message.get_total_character_count(), 1)
	_message.visible_ratio = minf(1.0, _message.visible_ratio + delta * CHARS_PER_SECOND / float(total))
	if _message.visible_ratio >= 1.0:
		_typing = false
