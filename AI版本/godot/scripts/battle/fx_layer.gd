extends Node2D
## 特效层（01 §8 FXLayer）。M2 占位：弹道为一条短亮线段，飞行 0.15 s，仅表现（生命变化不等待弹道）。
## M5：延迟爆炸落点标记（BlastMarker）。M7：弹道贴图（assets/sprites/projectiles，缺失时回退亮线段）。

const PROJECTILE_TIME: float = 0.15
const PROJECTILE_LEN: float = 18.0
const PROJECTILE_TEXTURE_SCALE: float = 0.75

var _markers: Dictionary = {}   ## blast_id -> BlastMarker


## texture：弹道贴图（visuals.projectile，缺失时为 null，画一条亮线段）
func spawn_projectile(from: Vector2, to: Vector2, color: Color, texture: Texture2D = null) -> void:
	var p := Node2D.new()
	p.position = from
	p.rotation = (to - from).angle()
	if texture != null:
		var s := Sprite2D.new()
		s.texture = texture
		s.scale = Vector2(PROJECTILE_TEXTURE_SCALE, PROJECTILE_TEXTURE_SCALE)
		p.add_child(s)
	else:
		p.draw.connect(func() -> void:
			p.draw_line(Vector2(-PROJECTILE_LEN, 0.0), Vector2.ZERO, Color(color, 0.3), 4.0)
			p.draw_line(Vector2(-PROJECTILE_LEN * 0.5, 0.0), Vector2.ZERO, color, 2.0))
	add_child(p)
	var t: Tween = p.create_tween()
	t.tween_property(p, "position", to, PROJECTILE_TIME)
	t.tween_callback(p.queue_free)


func spawn_blast_marker(world: SimWorld, blast_id: int, screen_pos: Vector2, radius_cells: float, delay: float) -> void:
	var m := BlastMarker.new()
	add_child(m)
	m.setup(world, blast_id, screen_pos, radius_cells, delay)
	_markers[blast_id] = m


func detonate_marker(blast_id: int) -> void:
	var raw: Variant = _markers.get(blast_id, null)
	if raw != null and is_instance_valid(raw):
		(raw as BlastMarker).detonate()
	_markers.erase(blast_id)


func clear() -> void:
	_markers.clear()
	for c: Node in get_children():
		c.queue_free()
