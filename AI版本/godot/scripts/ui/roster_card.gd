class_name RosterCard
extends Button
## 底栏出场卡（07 §5）：free 关 = 一种形态（头像 / 名称 / Cost），拖到玩法区新建单位，预算或人数不够时禁用；
## fixed 关 = 一个固定槽位（第一阶段行为），拖到部署区放置，点击选中已放置的该单位。
## 10 §4：头像 = portraits/<form>.png 经 ui/portrait_mask.png 裁圆；拖拽虚影 = 该形态精灵 60% 透明，高 cell_px × 1.6、锚点在脚底，
## 落点合法叠金色、非法叠红色（MapInput 调 tint_preview）。
## 第三阶段 P6（批准整图 ui_01）：卡面 = 该形态的卡片切片（头像已画在切片上），名称 / COST / 费用为子 Label，
## 位置取 data/ui_layout/battle_hud.json 的 card_name / card_cost_label / card_cost_value（相对其参照卡 data.card 的偏移）；
## 切片只有一态，按下 / 禁用用同一张贴图调色（布局 card_* 的 data.tint）；名称超出时自动滚动（ScrollText）。

const CARD_SIZE: Vector2 = Vector2(168.0, 96.0)
const ICON_PX: int = 64
const PORTRAIT_MASK: String = "ui/portrait_mask.png"
const PREVIEW_ALPHA: float = 0.6
const PREVIEW_HEIGHT_CELLS: float = 1.6
const SPRITE_FEET_RATIO: float = 232.0 / 256.0   ## 04 §2.1：256 画布、脚底在底部 24 px 处
const PREVIEW_TINT_LEGAL: Color = Color(1.0, 0.86, 0.45)   ## 金色调制
const PREVIEW_TINT_ILLEGAL: Color = Color(1.0, 0.35, 0.3)  ## 红色调制

const SKIN: String = "battle_hud"
const SKIN_TEXTS: Array[String] = ["card_name", "card_cost_label", "card_cost_value"]

static var _icon_cache: Dictionary = {}
static var _preview_sprite: WeakRef = null

var form: String = ""                    ## free 关
var slot_id: String = ""                 ## fixed 关
var controller: BattleController = null
var locked: bool = false                 ## 补足五个卡位的「未解锁」卡（不可交互）


## 拖拽虚影：形态精灵 60% 透明，高度 = cell_px × 1.6，脚底对准鼠标；无精灵时退回半透明方块
static func make_preview(p_form: String, cell_px: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = Art.unit_texture(p_form)
	var body: Control
	if tex != null:
		var h: float = cell_px * PREVIEW_HEIGHT_CELLS
		var w: float = h * tex.get_size().x / maxf(tex.get_size().y, 1.0)
		var sprite := TextureRect.new()
		sprite.texture = tex
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.size = Vector2(w, h)
		sprite.position = Vector2(-w * 0.5, -h * SPRITE_FEET_RATIO)
		body = sprite
	else:
		var dot := ColorRect.new()
		dot.color = Palette.BONE
		dot.size = Vector2(cell_px, cell_px) * 0.45
		dot.position = -dot.size * 0.5
		body = dot
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.modulate = Color(1.0, 1.0, 1.0, PREVIEW_ALPHA)
	holder.add_child(body)
	_preview_sprite = weakref(body)
	return holder


## 当前拖拽虚影的落点调制：1 合法（金）、-1 非法（红）、0 无（矩形外）
static func tint_preview(state: int) -> void:
	var body: Control = _preview_sprite.get_ref() as Control if _preview_sprite != null else null
	if body == null:
		return
	var c: Color = Color.WHITE
	if state > 0:
		c = PREVIEW_TINT_LEGAL
	elif state < 0:
		c = PREVIEW_TINT_ILLEGAL
	body.modulate = Color(c, PREVIEW_ALPHA)


## 第四阶段：拖拽虚影在战场内隐藏（改由 DeployZone 在吸附格画虚影），出战场（拖回 / 移除）时显示
static func show_preview(on: bool) -> void:
	var body: Control = _preview_sprite.get_ref() as Control if _preview_sprite != null else null
	if body != null:
		body.visible = on


## 当前拖拽虚影（测试用；无则 null）
static func current_preview() -> Control:
	return _preview_sprite.get_ref() as Control if _preview_sprite != null else null


## 圆形头像图标：portraits/<form>.png × portrait_mask.png 的 alpha；缺头像时为 null（按钮不显示图标）
static func portrait_icon(p_form: String) -> Texture2D:
	if _icon_cache.has(p_form):
		return _icon_cache[p_form] as Texture2D
	var out: Texture2D = null
	var udef: UnitDefinition = DataRegistry.get_unit(p_form)
	var tex: Texture2D = Art.texture(str(udef.visuals.get("portrait", ""))) if udef != null else null
	var mask_tex: Texture2D = Art.texture(PORTRAIT_MASK)
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
			if mask_tex != null and mask_tex.get_image() != null:
				var mask: Image = mask_tex.get_image()
				if mask.is_compressed():
					mask.decompress()
				mask.convert(Image.FORMAT_RGBA8)
				mask.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_BILINEAR)
				for y: int in ICON_PX:
					for x: int in ICON_PX:
						var c: Color = img.get_pixel(x, y)
						c.a *= mask.get_pixel(x, y).a
						img.set_pixel(x, y, c)
			out = ImageTexture.create_from_image(img)
	_icon_cache[p_form] = out
	return out


func setup_form(p_form: String, p_controller: BattleController) -> void:
	form = p_form
	controller = p_controller
	var udef: UnitDefinition = DataRegistry.get_unit(form)
	text = DataRegistry.get_string("ui.card_cost").format({ "name": udef.display_name, "cost": udef.cost })
	if not UiKit.ui_layout(SKIN).is_empty():
		text = udef.display_name
	_common()


func setup_slot(p_slot_id: String, p_controller: BattleController) -> void:
	slot_id = p_slot_id
	controller = p_controller
	form = controller.form_of(slot_id)
	text = controller.label_of(slot_id)
	pressed.connect(_on_pressed)
	_common()


func _common() -> void:
	focus_mode = Control.FOCUS_NONE
	if UiKit.ui_layout(SKIN).is_empty():         # 没有换皮布局时退回第二阶段的程序化卡片
		custom_minimum_size = CARD_SIZE
		icon = portrait_icon(form)
		expand_icon = false
		icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_constant_override("icon_max_width", ICON_PX)
	else:
		var udef: UnitDefinition = DataRegistry.get_unit(form)
		var title: String = text.get_slice("\n", 0) if slot_id == "" else text
		text = ""
		_apply_skin(card_file(form), title, str(udef.cost) if udef != null else "")
	refresh()


## 形态 → 卡片切片（布局 card_* 的 data.reference_form）；没有该形态的切片时用第一张并告警
static func card_file(p_form: String) -> String:
	var first: String = ""
	for e: Dictionary in UiKit.layout_elements(SKIN):
		var d: Dictionary = e.get("data", {}) as Dictionary
		if str(e["id"]).begins_with("card_") and d.has("reference_form"):
			if first == "":
				first = str(e["file"])
			if str(d["reference_form"]) == p_form:
				return str(e["file"])
	push_warning("形态 %s 没有卡片切片，暂用 %s" % [p_form, first])
	return first


## 「未解锁」卡：补足五个卡位，不可交互
static func make_locked_card() -> Control:
	var c := RosterCard.new()
	c.name = "LockedCard"
	c.locked = true
	c.disabled = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_mode = Control.FOCUS_NONE
	c.set_meta(&"no_motion", true)
	c._apply_skin(card_file("locked"), DataRegistry.get_string("ui.locked"), DataRegistry.get_string("ui.card_locked_value"))
	return c


## 卡面样式（四态同一张切片，按 data.tint 调色）与三个文字 Label
func _apply_skin(file: String, title: String, cost: String) -> void:
	var tex: Texture2D = load(file) as Texture2D
	var tint: Dictionary = {}
	for e: Dictionary in UiKit.layout_elements(SKIN):
		if str(e["id"]) == "card_1":
			tint = (e.get("data", {}) as Dictionary).get("tint", {}) as Dictionary
	for st: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		var key: String = "pressed" if st == "hover_pressed" else st
		if tint.has(key):
			sb.modulate_color = Color(str(tint[key]))
		add_theme_stylebox_override(st, sb)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texts: Dictionary = { "card_name": title, "card_cost_label": DataRegistry.get_string("ui.card_cost_label"), "card_cost_value": cost }
	for id: String in SKIN_TEXTS:
		var e: Dictionary = UiKit.layout_element(SKIN, id)
		var l := Label.new()
		l.name = "Text_" + id
		l.theme_type_variation = StringName(str(e.get("theme_type", "")))
		l.horizontal_alignment = UiKit.text_align(str(e.get("align", "center")))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		l.text = str(texts[id])
		add_child(l, false, Node.INTERNAL_MODE_BACK)
		var r: Rect2 = UiKit.layout_rect(SKIN, id, UiKit.design_size(SKIN))
		var ref: Rect2 = UiKit.layout_rect(SKIN, str((e.get("data", {}) as Dictionary).get("card", "card_1")), UiKit.design_size(SKIN))
		l.position = r.position - ref.position
		l.size = r.size
		if str(e.get("overflow", "")) == "auto":
			ScrollText.wrap(l, ScrollText.Mode.AUTO)


## 卡面文字（测试与截图用）：名称 / COST / 费用
func skin_text(id: String) -> String:
	for n: Node in get_children(true):
		var l: Label = n as Label if n is Label else (n.get_child(0) as Label if n is ScrollText else null)
		if l != null and String(l.name) == "Text_" + id:
			return l.text
	return ""


func refresh() -> void:
	if controller == null:
		return
	var deploy: bool = controller.phase == SimTypes.Phase.DEPLOY or controller.boss_pending   # Boss 换阶段暂停可补增援
	if slot_id != "":
		disabled = not deploy
		modulate = Color(1.0, 1.0, 1.0, 0.55) if controller.placements.has(slot_id) else Color.WHITE
		return
	disabled = not controller.can_add_form(form)
	tooltip_text = ""
	if deploy and disabled:
		if controller.placements.size() >= controller.level.max_units:
			tooltip_text = DataRegistry.get_string("ui.roster_full").format({ "n": controller.level.max_units })
		else:
			tooltip_text = DataRegistry.get_string("ui.budget_short")


func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Dictionary = drag_payload()
	if payload.is_empty():
		return null
	set_drag_preview(make_preview(form, _cell_px()))
	AudioManager.play_sfx("ui_drag_pick", "UI")
	return payload


## 当前关卡每格像素（BattleRoot.cell_px；控制器挂在 BattleRoot 下）
func _cell_px() -> float:
	var root: Node = controller.get_parent() if controller != null else null
	if root != null and root.has_method("cell_screen_px"):
		return float(root.call("cell_screen_px"))
	return float(int(root.get("cell_px"))) if root != null and root.get("cell_px") != null else float(SimTypes.TILE_SIZE)


## 拖拽数据：fixed = { slot_id, from_map: false }；free = { form }；不可拖时为空
func drag_payload() -> Dictionary:
	if controller == null or (controller.phase != SimTypes.Phase.DEPLOY and not controller.boss_pending) or disabled:
		return {}
	if slot_id != "":
		return { "slot_id": slot_id, "from_map": false }
	return { "form": form }


func _on_pressed() -> void:
	if controller != null and controller.placements.has(slot_id):
		EventBus.unit_selected.emit(controller.unit_id_of_slot(slot_id))
