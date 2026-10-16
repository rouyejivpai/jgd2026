extends SceneTree
## 生成 assets/themes/main_theme.tres（颜色全部取自 Palette 常量，04_资源需求.md §2.9）。
## UI 贴图（assets/sprites/ui/button_*.png、panel_dark.png）就位后重新运行即可切换为贴图样式。
## 用法（在 godot/ 目录）：Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/make_theme.gd

const PaletteScript: GDScript = preload("res://assets/themes/palette.gd")
const THEME_PATH: String = "res://assets/themes/main_theme.tres"
const FONT_BODY: String = "res://assets/fonts/NotoSerifSC-Regular.otf"
const FONT_TITLE: String = "res://assets/fonts/NotoSerifSC-Bold.otf"
const FONT_SMALL: String = "res://assets/fonts/NotoSansSC-Regular.otf"
const FONT_NUMBER: String = "res://assets/fonts/Cinzel-Regular.ttf"
const SIZE_BODY: int = 18
const SIZE_TITLE: int = 28
const SIZE_SMALL: int = 14


func _init() -> void:
	var theme: Theme = Theme.new()
	theme.default_font = load(FONT_BODY) as Font
	theme.default_font_size = SIZE_BODY

	theme.set_color("font_color", "Label", PaletteScript.BONE)

	theme.set_color("font_color", "Button", PaletteScript.BONE)
	theme.set_color("font_hover_color", "Button", PaletteScript.ALCHEMY_GOLD)
	theme.set_color("font_focus_color", "Button", PaletteScript.BONE)
	theme.set_color("font_pressed_color", "Button", PaletteScript.BONE)
	theme.set_color("font_hover_pressed_color", "Button", PaletteScript.ALCHEMY_GOLD)
	theme.set_color("font_disabled_color", "Button", PaletteScript.BONE_DIM)
	# 04 §2.7：button_*.png（192×56，9 宫格 16）存在时用贴图，否则用调色板纯色框
	theme.set_stylebox("normal", "Button", _tex_or("button_normal", 16, _box(PaletteScript.FLESH, PaletteScript.BONE)))
	theme.set_stylebox("hover", "Button", _tex_or("button_hover", 16, _box(PaletteScript.FLESH_HI, PaletteScript.ALCHEMY_GOLD)))
	theme.set_stylebox("pressed", "Button", _tex_or("button_pressed", 16, _box(PaletteScript.VIOLET_DEEP, PaletteScript.ALCHEMY_GOLD)))
	theme.set_stylebox("hover_pressed", "Button", _tex_or("button_pressed", 16, _box(PaletteScript.VIOLET_DEEP, PaletteScript.ALCHEMY_GOLD)))
	theme.set_stylebox("disabled", "Button", _tex_or("button_disabled", 16, _box(PaletteScript.VIOLET_MUTE, PaletteScript.BONE_DIM)))
	var focus: StyleBoxFlat = _box(PaletteScript.FLESH, PaletteScript.ALCHEMY_GOLD)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)

	# panel_dark.png（96×96，9 宫格 24）存在时用贴图
	var panel: StyleBox = _tex_or("panel_dark", 24, _box(PaletteScript.VIOLET_DEEP, PaletteScript.BONE_DIM))
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# 下拉弹窗 / 悬浮提示 / 标签页 / 数字输入
	theme.set_stylebox("panel", "PopupMenu", _box(PaletteScript.VIOLET_DEEP, PaletteScript.ALCHEMY_GOLD))
	theme.set_stylebox("hover", "PopupMenu", _box(PaletteScript.FLESH, PaletteScript.FLESH))
	theme.set_color("font_color", "PopupMenu", PaletteScript.BONE)
	theme.set_color("font_hover_color", "PopupMenu", PaletteScript.ALCHEMY_GOLD)
	theme.set_color("font_disabled_color", "PopupMenu", PaletteScript.BONE_DIM)
	theme.set_stylebox("panel", "TooltipPanel", _box(PaletteScript.BG_DEEP, PaletteScript.ALCHEMY_GOLD))
	theme.set_color("font_color", "TooltipLabel", PaletteScript.BONE)
	var tab_sel: StyleBoxFlat = _box(PaletteScript.VIOLET_DEEP, PaletteScript.ALCHEMY_GOLD)
	var tab_un: StyleBoxFlat = _box(PaletteScript.BG_DEEP, PaletteScript.VIOLET_MUTE)
	theme.set_stylebox("tab_selected", "TabContainer", tab_sel)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_un)
	theme.set_stylebox("tab_hovered", "TabContainer", _box(PaletteScript.VIOLET_DEEP, PaletteScript.BONE_DIM))
	theme.set_stylebox("panel", "TabContainer", _box(PaletteScript.VIOLET_DEEP, PaletteScript.VIOLET_MUTE))
	theme.set_color("font_selected_color", "TabContainer", PaletteScript.ALCHEMY_GOLD)
	theme.set_color("font_unselected_color", "TabContainer", PaletteScript.BONE_DIM)
	theme.set_color("font_hovered_color", "TabContainer", PaletteScript.BONE)
	theme.set_stylebox("normal", "LineEdit", _box(PaletteScript.BG_DEEP, PaletteScript.BONE_DIM))
	theme.set_stylebox("focus", "LineEdit", _box(PaletteScript.BG_DEEP, PaletteScript.ALCHEMY_GOLD))
	theme.set_color("font_color", "LineEdit", PaletteScript.BONE)
	theme.set_color("font_color", "CheckBox", PaletteScript.BONE)
	theme.set_color("font_color", "CheckButton", PaletteScript.BONE)

	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", load(FONT_TITLE) as Font)
	theme.set_font_size("font_size", "TitleLabel", SIZE_TITLE)

	theme.set_type_variation("SmallLabel", "Label")
	theme.set_font("font", "SmallLabel", load(FONT_SMALL) as Font)
	theme.set_font_size("font_size", "SmallLabel", SIZE_SMALL)
	theme.set_color("font_color", "SmallLabel", PaletteScript.BONE_DIM)

	theme.set_type_variation("NumberLabel", "Label")
	theme.set_font("font", "NumberLabel", load(FONT_NUMBER) as Font)

	var err: Error = ResourceSaver.save(theme, THEME_PATH)
	print("[make_theme] save %s -> %s" % [THEME_PATH, error_string(err)])
	quit(0 if err == OK else 1)


## ui/<file_name>.png 存在时返回 9 宫格 StyleBoxTexture，否则返回 fallback
func _tex_or(file_name: String, margin: int, fallback: StyleBox) -> StyleBox:
	var path: String = "res://assets/sprites/ui/%s.png" % file_name
	if not ResourceLoader.exists(path):
		return fallback
	var sb := StyleBoxTexture.new()
	sb.texture = load(path) as Texture2D
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(12)
	return sb


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(12)
	return box
