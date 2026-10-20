class_name CreditsCard
extends Control
## 片尾结束卡（2026-10-20 起与名单对话框同一套装饰；2026-10-21 用户改为致玩家的一封短信，重新排版成左右两栏）：
## 左栏（信，左对齐）——
## · 英文小标「THANK YOU FOR PLAYING」（Cinzel，加字距，暗玫灰）；
## · 标题「非常感谢您的游玩！」（思源宋体粗体，剧情说话人配色），左右两片银白弯刃（assets/credits/name_blade_l/r.png）；
## · 一道两端渐隐的银粉分隔线，正中一枚小菱；
## · 正文一段（思源宋体，剧情正文配色，加大行距）；
## · 落款一句（思源宋体粗体，暗金）。
## 右栏——群二维码（黑底白码，透明底），四角银色荆棘角花（assets/ui/gothic/tut_corner.png），下方加群提示。
## 两栏之间一道上下渐隐的竖向细光。文字全部来自 strings.json 的 ui.credits_*。
## items() 按出场顺序返回各块，由 CreditsRoll 依次淡入。

const TITLE_EN_SIZE: int = 18
const TITLE_SIZE: int = 54
const BODY_SIZE: int = 25
const FAREWELL_SIZE: int = 29
const JOIN_SIZE: int = 24
const BLADE_HEIGHT: float = 86.0
const LETTER_WIDTH: float = 800.0
const BODY_LINE_SPACING: int = 14
const DIVIDER_HEIGHT: float = 22.0
const QR_SIDE: float = 330.0
const QR_PAD: float = 30.0               ## 角花离二维码的距离
const CORNER_SCALE: float = 1.1
const COLUMN_GAP: int = 64
const RULE_SIZE: Vector2 = Vector2(2.0, 520.0)   ## 两栏之间的竖线
const FAREWELL_COLOR: Color = Color(0.86, 0.73, 0.47)   ## 暗金（比 Palette.ALCHEMY_GOLD 略亮，压在纯黑上）

var _items: Array[Control] = []


## texts：title / title_en / body / farewell / join
func build(texts: Dictionary, qr_tex: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)

	# 左栏：信
	var letter := VBoxContainer.new()
	letter.custom_minimum_size = Vector2(LETTER_WIDTH, 0.0)
	letter.add_theme_constant_override("separation", 14)
	letter.alignment = BoxContainer.ALIGNMENT_CENTER
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(letter)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.add_child(head)
	var en := _label(str(texts.get("title_en", "")).to_upper(), TITLE_EN_SIZE, CreditsBubble.ROLE_COLOR, _spaced(CreditsBubble.CINZEL, 7))
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(en)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_row)
	title_row.add_child(_blade(CreditsBubble.BLADE_L))
	var t := _label(str(texts.get("title", "")), TITLE_SIZE, CreditsBubble.NAME_COLOR, CreditsBubble.SERIF_BOLD)
	t.add_theme_constant_override("shadow_outline_size", 10)
	title_row.add_child(t)
	title_row.add_child(_blade(CreditsBubble.BLADE_R))
	var divider := Control.new()
	divider.custom_minimum_size = Vector2(LETTER_WIDTH, DIVIDER_HEIGHT)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(_draw_divider.bind(divider))
	letter.add_child(divider)
	var body := _label(str(texts.get("body", "")), BODY_SIZE, CreditsBubble.TEXT_COLOR, CreditsBubble.SERIF)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # 按 ICU 断行：标点不落到行首
	body.custom_minimum_size = Vector2(LETTER_WIDTH, 0.0)
	body.add_theme_constant_override("line_spacing", BODY_LINE_SPACING)
	letter.add_child(body)
	var farewell := _label(str(texts.get("farewell", "")), FAREWELL_SIZE, FAREWELL_COLOR, CreditsBubble.SERIF_BOLD)
	farewell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var spacer := Control.new()                               # 正文与落款之间多留一点
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.add_child(spacer)
	letter.add_child(farewell)

	# 两栏之间的竖线
	var rule := Control.new()
	rule.custom_minimum_size = RULE_SIZE
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(_draw_rule.bind(rule))
	row.add_child(rule)

	# 右栏：二维码 + 加群提示
	var qr_col := VBoxContainer.new()
	qr_col.add_theme_constant_override("separation", 6)
	qr_col.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(qr_col)
	var holder := Control.new()
	var side: float = QR_SIDE + QR_PAD * 2.0
	holder.custom_minimum_size = Vector2(side, side)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qr_col.add_child(holder)
	var qr := TextureRect.new()
	qr.texture = qr_tex
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr.position = Vector2(QR_PAD, QR_PAD)
	qr.size = Vector2(QR_SIDE, QR_SIDE)
	qr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(qr)
	var corner: Texture2D = Art.texture(CreditsBubble.CORNER)
	if corner != null:
		var cs: Vector2 = corner.get_size() * CORNER_SCALE
		for fx: bool in [false, true]:
			for fy: bool in [false, true]:
				var c := TextureRect.new()
				c.texture = corner
				c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				c.flip_h = fx
				c.flip_v = fy
				c.size = cs
				c.position = Vector2(side - cs.x if fx else 0.0, side - cs.y if fy else 0.0)
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(c)
	var join := _label(str(texts.get("join", "")), JOIN_SIZE, CreditsBubble.TEXT_COLOR, CreditsBubble.SERIF)
	qr_col.add_child(join)
	_items = [head, divider, body, farewell, rule, qr_col]


func items() -> Array[Control]:
	return _items


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", CreditsBubble.SHADOW)
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
	var w: float = BLADE_HEIGHT * 0.5
	if t.texture != null:
		w = BLADE_HEIGHT * float(t.texture.get_width()) / float(t.texture.get_height())
	t.custom_minimum_size = Vector2(w, BLADE_HEIGHT)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## 分隔线：左端起亮、向右渐隐（信左对齐），左端一枚小菱
func _draw_divider(c: Control) -> void:
	var w: float = c.size.x
	var y: float = c.size.y * 0.5
	var sheen: Color = CreditsBubble.SHEEN
	var k: float = 8.0
	var start: float = k * 2.2
	c.draw_polyline_colors(PackedVector2Array([Vector2(start, y), Vector2(w * 0.35, y), Vector2(w, y)]),
		PackedColorArray([sheen, Color(sheen, 0.7), Color(sheen, 0.0)]), 1.5, true)
	var mid := Vector2(k * 0.8, y)
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0.0, -k), mid + Vector2(k * 0.62, 0.0), mid + Vector2(0.0, k), mid + Vector2(-k * 0.62, 0.0)]), Color(0.93, 0.86, 0.9, 0.9))


## 两栏之间：上下渐隐的竖向细光
func _draw_rule(c: Control) -> void:
	var h: float = c.size.y
	var x: float = c.size.x * 0.5
	var sheen: Color = CreditsBubble.SHEEN
	c.draw_polyline_colors(PackedVector2Array([Vector2(x, 0.0), Vector2(x, h * 0.5), Vector2(x, h)]),
		PackedColorArray([Color(sheen, 0.0), Color(sheen, 0.6), Color(sheen, 0.0)]), 1.2, true)
