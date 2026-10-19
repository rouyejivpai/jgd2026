extends Node2D
## 特效层（01 §8 FXLayer）。M5：延迟爆炸落点标记（BlastMarker）。
## 2026-10-19 战斗打击感：射弹 / 斩击 / 受击碎屑 / 击败爆散全部由 CombatFx 程序绘制（己方金色、敌方暗红），
## 不再用 assets/sprites/projectiles 贴图。生命变化不等待特效；受击表现由 BattleRoot 推迟到命中时刻播放。

var ground: Node2D = null       ## GroundFx：碎屑落地后转交（BattleRoot 设置）
var _markers: Dictionary = {}   ## blast_id -> BlastMarker
var _debris: CombatFx.DebrisFlight = null


## 射弹：from → to（本层坐标），沿随机弧线飞行。on_impact 在弹头到达时调用（受击表现）；bend_side 见 CombatFx.Projectile
func spawn_projectile(from: Vector2, to: Vector2, ally: bool, shape: int, size: float = 1.0, on_impact: Callable = Callable(), bend_side: float = 0.0) -> void:
	var p := CombatFx.Projectile.new()
	p.bend_side = bend_side
	p.from = from
	p.to = to
	p.ally = ally
	p.shape = shape
	p.size = size
	p.on_impact = on_impact
	add_child(p)


## 斩击：center = 目标胸口（本层坐标）；toward = 攻击者 → 目标方向
## kind：0 横斩，1 竖斩，2 斜斩，-1 随机
func spawn_slash(center: Vector2, ally: bool, size: float, toward: Vector2, kind: int = -1) -> void:
	add_child(CombatFx.Slash.make(center, ally, size, toward, kind))


## 灰黑碎屑：从 feet 上方 height 处背离攻击者（dir）抛飞，落地后交给 GroundFx
func spawn_debris(feet: Vector2, height: float, dir: Vector2, count: int, power: float = 1.0) -> void:
	if _debris == null or not is_instance_valid(_debris) or _debris.is_queued_for_deletion():
		_debris = CombatFx.DebrisFlight.new()
		_debris.name = "Debris"
		add_child(_debris)
	_debris.ground = ground
	_debris.add(feet, height, dir, count, power)


## 击败：胸口处爆散（阵营色火花 + 冲击环 + 闪光）+ 大量碎屑
func spawn_death_burst(feet: Vector2, height: float, dir: Vector2, ally: bool, size: float) -> void:
	add_child(CombatFx.DeathBurst.make(feet - Vector2(0.0, height), dir, ally, size))
	spawn_debris(feet, height, dir, 26, 1.6)
	spawn_debris(feet, height * 0.6, -dir, 8, 0.8)


## 光柱（出场 / 部署落位 / 遗物生效）：kind 见 CombatFx.Pillar
func spawn_pillar(feet: Vector2, ally: bool, size: float, kind: String) -> void:
	add_child(CombatFx.Pillar.make(feet, ally, size, kind))


## 延迟爆炸落点预警（ally = 施放者为己方：金色，否则红色）
func spawn_blast_marker(world: SimWorld, blast_id: int, screen_pos: Vector2, radius_cells: float, delay: float, ally: bool = false) -> void:
	var m := BlastMarker.new()
	add_child(m)
	m.setup(world, blast_id, screen_pos, radius_cells, delay, ally)
	_markers[blast_id] = m


func detonate_marker(blast_id: int) -> void:
	var raw: Variant = _markers.get(blast_id, null)
	if raw != null and is_instance_valid(raw):
		(raw as BlastMarker).detonate()
	_markers.erase(blast_id)


func clear() -> void:
	_markers.clear()
	_debris = null
	for c: Node in get_children():
		c.queue_free()
