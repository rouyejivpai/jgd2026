extends Node2D
## 选中单位的视野环与射程环（01 §8 RangeLayer，策划已定：两者样式不同）。
## range_ring.gdshader：视野 = 虚线细环（style 0）；射程 = 15% 填充 + 实线环（style 1）。

const FEATHER_PX: float = 4.0

var view: UnitView = null
var _vision: ColorRect
var _range: ColorRect


func _ready() -> void:
	_vision = _make_ring(0)
	_range = _make_ring(1)
	_vision.visible = false
	_range.visible = false


func _make_ring(style: int) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = Art.material("range_ring")
	(r.material as ShaderMaterial).set_shader_parameter("style", style)
	add_child(r)
	return r


func show_for(v: UnitView) -> void:
	view = v
	_refresh()


func _process(_delta: float) -> void:
	if view != null and not is_instance_valid(view):
		view = null
		_refresh()
	elif view != null:
		_place(_vision, view.unit.vision)
		_place(_range, view.unit.attack_range)


func _refresh() -> void:
	var ok: bool = view != null and is_instance_valid(view) and view.unit != null
	_vision.visible = ok and view.unit.vision > 0.0
	_range.visible = ok and view.unit.attack_range > 0.0
	if not ok:
		return
	var c: Color = Palette.BONE if view.unit.faction == SimTypes.Faction.ALLY else Palette.WARN_RED
	(_vision.material as ShaderMaterial).set_shader_parameter("color", c)
	(_range.material as ShaderMaterial).set_shader_parameter("color", c)
	_place(_vision, view.unit.vision)
	_place(_range, view.unit.attack_range)


func _place(r: ColorRect, radius_cells: float) -> void:
	var radius_px: float = radius_cells * float(SimTypes.TILE_SIZE)
	var half: float = radius_px + FEATHER_PX * 2.0
	r.size = Vector2(half, half) * 2.0
	r.position = view.position - Vector2(half, half)
	var m: ShaderMaterial = r.material as ShaderMaterial
	m.set_shader_parameter("radius_px", radius_px)
	m.set_shader_parameter("quad_px", half)
	m.set_shader_parameter("feather_px", FEATHER_PX * 0.5)
