class_name Projectile
extends Area2D
## 详细设计：[docs/design/05-战斗.md](../../docs/design/05-战斗.md) 4.2-4.4
##
## 有飞行时间的实体子弹。**不预判**（朝开火瞬间目标所在方向直线飞），
## 飞满射程 / 撞障碍 / 命中目标 → 三者任一即销毁。
##
## 【碰撞分层让四条保证免费成立】见详设 05 第 3 章：
## · 我方子弹掩码 = 2(障碍) + 6(敌方 Hurtbox) → **不伤害友军，也不会撞到友军就消失**
## · 敌方子弹掩码 = 2(障碍) + 5(我方 Hurtbox) → 不伤害敌人
## · 任何子弹掩码都不含 3/4 → **子弹互不碰撞**
## 因此本文件里**不需要任何阵营判断代码**。

const LAYER_OBSTACLE := 2
const LAYER_BULLET_ALLY := 3
const LAYER_BULLET_ENEMY := 4
const LAYER_HURTBOX_ALLY := 5
const LAYER_HURTBOX_ENEMY := 6

const TEAM_ALLY := 0
const TEAM_ENEMY := 1

var team := TEAM_ALLY
var direction := Vector2.RIGHT
var speed := 12.0
var damage := 10.0
var radius := 0.3
var remaining_range := 3.0
var on_hit_status := ""

## 已飞行距离（逻辑单位）
var traveled := 0.0
## 是否已结算过（防同一 tick 多次命中）
var consumed := false
var tile_px := 64.0

## 实体注册表（销毁时用它注销）
var battle_state = null

## 逻辑坐标（格）。权威值独立存，像素只是投影（与 UnitActor 同一约定）。
var position_logic := Vector2.ZERO


func _ready() -> void:
	_ensure_nodes()
	_apply_layers()
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


## 配置一颗子弹。调用方负责 add_child 之后再调它（或先调再 add_child 都行，
## 因为 _ready 会重新套一次层与信号）。
func setup(p_team: int, from_logic: Vector2, dir: Vector2, p_speed: float,
		p_range: float, p_damage: float, p_radius: float, p_status: String,
		p_tile_px: float, p_battle_state) -> void:
	team = p_team
	direction = dir.normalized() if dir.length() > 0.0001 else Vector2.RIGHT
	speed = p_speed
	remaining_range = p_range
	damage = p_damage
	radius = p_radius
	on_hit_status = p_status
	tile_px = p_tile_px
	battle_state = p_battle_state
	traveled = 0.0
	consumed = false
	position_logic = from_logic
	_ensure_nodes()
	_apply_layers()
	global_position = position_logic * tile_px


func _ensure_nodes() -> void:
	# 尺寸依赖 radius，所以 setup 之后要重建/更新形状
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "Shape"
		add_child(cs)
	var circle := CircleShape2D.new()
	circle.radius = radius * tile_px
	cs.shape = circle

	var dot := get_node_or_null("Dot") as Polygon2D
	if dot == null:
		dot = Polygon2D.new()
		dot.name = "Dot"
		add_child(dot)
	var r := radius * tile_px
	dot.polygon = PackedVector2Array([
		Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	dot.color = Color(1, 0.95, 0.5) if team == TEAM_ALLY else Color(1, 0.5, 0.2)


func _apply_layers() -> void:
	# 层：按阵营进 3 或 4
	collision_layer = 0
	if team == TEAM_ALLY:
		set_collision_layer_value(LAYER_BULLET_ALLY, true)
	else:
		set_collision_layer_value(LAYER_BULLET_ENEMY, true)
	# 掩码：障碍 + **对侧** Hurtbox（这就是「不伤害友军」的全部实现）
	collision_mask = 0
	set_collision_mask_value(LAYER_OBSTACLE, true)
	if team == TEAM_ALLY:
		set_collision_mask_value(LAYER_HURTBOX_ENEMY, true)
	else:
		set_collision_mask_value(LAYER_HURTBOX_ALLY, true)
	monitoring = true
	monitorable = false


## 推进一 tick。飞满射程即销毁。
func step(tick_delta: float) -> void:
	if consumed:
		return
	var step_len := speed * tick_delta
	traveled += step_len
	if traveled >= remaining_range:
		if trace:
			print("      [proj] 飞满射程销毁: traveled=%.3f range=%.3f pos=%s" % [
				traveled, remaining_range, str(position_logic)])
		destroy()
		return
	position_logic += direction * step_len
	global_position = position_logic * tile_px


# ---------------------------------------------------------------------------
# 命中
# ---------------------------------------------------------------------------

## 命中敌方 Hurtbox（掩码已保证只会是对侧）
func _on_area_entered(area: Area2D) -> void:
	if consumed:
		return
	var victim := _unit_of_hurtbox(area)
	if victim == null:
		return
	if bool(victim.get("is_dead")):
		return                                  # 已死目标不再结算（防同一 tick 重复计伤）
	consumed = true
	_apply_damage(victim)
	destroy()


## 撞到障碍 → 销毁（掩码含层 2）
func _on_body_entered(body: Node) -> void:
	if consumed:
		return
	if trace:
		print("      [proj] body_entered: %s (layer=%d)" % [body.name, int(body.get("collision_layer"))])
	if body is StaticBody2D:
		consumed = true
		destroy()


func _unit_of_hurtbox(area: Area2D) -> Node:
	var p := area.get_parent()                  # Hurtbox 是单位的子节点
	if p != null and p.has_method("die"):
		return p
	return null


## 伤害与状态：存储归系统 04，这里只调用它的接口（详设 05 的 2.3）
func _apply_damage(victim: Node) -> void:
	var before := float(victim.get("hp"))
	victim.set("hp", before - damage)
	if trace:
		print("      [proj] 命中 %s (id=%s team=%s): hp %.1f → %.1f" % [
			victim.name, str(victim.get("entity_id")), str(victim.get("team")),
			before, float(victim.get("hp"))])
	if on_hit_status == "slowed":
		victim.call("set_slowed")               # 减速**不叠加**（D-06）
	if float(victim.get("hp")) <= 0.0:
		victim.call("die")


## 调试开关
var trace := false


func destroy() -> void:
	# 【consumed 必须在这里也置位】queue_free() 是帧末才生效的，在那之前
	# `is_instance_valid(self)` 仍然为 true。所以「子弹是否已销毁」要问本字段，
	# 不能只问节点有效性（M2 实测：飞满射程后 is_instance_valid 仍是 true）。
	consumed = true
	if battle_state != null and battle_state.has_method("unregister_projectile"):
		battle_state.call("unregister_projectile", self)
	if is_inside_tree():
		queue_free()


## 是否已经销毁（立即可信，不受 queue_free 延迟影响）
func is_destroyed() -> bool:
	return consumed
