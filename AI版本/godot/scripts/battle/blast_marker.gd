class_name BlastMarker
extends Node2D
## 延迟爆炸落点标记（01 §8 BlastMarker）：blast_marker.gdshader 绘制红环与随倒计时收缩的填充，上方倒计时数字（Cinzel）；
## 到期闪光 + PointLight2D 脉冲后消失。落点固定在放置时的位置（不追踪目标），只读 SimWorld.blasts 的剩余时间。

const NUMBER_FONT: FontVariation = preload("res://assets/fonts/Cinzel-Bold.tres")
const FLASH_SECONDS: float = 0.35
const FLASH_LIGHT_ENERGY: float = 1.6
const QUAD_MARGIN_PX: float = 8.0
const TICK_INTERVAL: float = 0.5
const TICK_INTERVAL_FAST: float = 0.2

var blast_id: int = 0
var world: SimWorld = null
var radius_px: float = 0.0
var delay: float = 1.0
var _remaining: float = 0.0
var _flash_left: float = -1.0
var _quad: ColorRect
var _mat: ShaderMaterial
var _light: PointLight2D
var _next_tick: float = 0.0       ## 下一次预警滴答的剩余时间阈值


func setup(p_world: SimWorld, p_blast_id: int, screen_pos: Vector2, radius_cells: float, p_delay: float) -> void:
	world = p_world
	blast_id = p_blast_id
	position = screen_pos
	radius_px = radius_cells * float(SimTypes.TILE_SIZE)
	delay = maxf(p_delay, SimTypes.TIME_EPS)
	_remaining = p_delay
	_next_tick = p_delay - TICK_INTERVAL
	var half: float = radius_px + QUAD_MARGIN_PX
	_quad = ColorRect.new()
	_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad.size = Vector2(half, half) * 2.0
	_quad.position = -Vector2(half, half)
	_mat = Art.material("blast_marker")
	_mat.set_shader_parameter("radius_px", radius_px)
	_mat.set_shader_parameter("quad_px", half)
	_mat.set_shader_parameter("color", Palette.WARN_RED)
	_quad.material = _mat
	_quad.show_behind_parent = true
	add_child(_quad)
	_light = PointLight2D.new()
	_light.texture = Art.light_texture()
	_light.texture_scale = radius_px * 2.6 / float(Art.LIGHT_TEXTURE_SIZE)
	_light.color = Palette.WARN_RED
	_light.energy = 0.0
	add_child(_light)


## 到期：播放闪光后释放
func detonate() -> void:
	_flash_left = FLASH_SECONDS
	_quad.visible = false


func _process(delta: float) -> void:
	if _flash_left >= 0.0:
		_flash_left -= delta
		_light.energy = FLASH_LIGHT_ENERGY * maxf(_flash_left, 0.0) / FLASH_SECONDS
		if _flash_left < 0.0:
			queue_free()
	else:
		var b: SimBlast = _find()
		if b == null:
			queue_free()      # 世界被重建（重置）等情况
			return
		_remaining = b.remaining
		if _remaining <= _next_tick:   # 预警滴答：最后 1 秒加速
			AudioManager.play_sfx("blast_warn_tick")
			_next_tick -= TICK_INTERVAL_FAST if _remaining <= 1.0 else TICK_INTERVAL
		_mat.set_shader_parameter("t", clampf(_remaining / delay, 0.0, 1.0))
	queue_redraw()


func _find() -> SimBlast:
	if world == null:
		return null
	for b: SimBlast in world.blasts:
		if b.id == blast_id:
			return b
	return null


func _draw() -> void:
	if _flash_left >= 0.0:
		var k: float = 1.0 - _flash_left / FLASH_SECONDS
		draw_circle(Vector2.ZERO, radius_px * (1.0 + 0.25 * k), Color(Palette.FLESH_HI, 0.6 * (1.0 - k)))
		draw_arc(Vector2.ZERO, radius_px * (1.0 + 0.4 * k), 0.0, TAU, 64, Color(Palette.WARN_RED, 1.0 - k), 6.0)
		return
	var text: String = "%.1f" % maxf(_remaining, 0.0)
	draw_string(NUMBER_FONT, Vector2(-60.0, -radius_px * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 30, Palette.BONE)
