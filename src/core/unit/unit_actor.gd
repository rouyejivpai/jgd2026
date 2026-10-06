class_name UnitActor
extends CharacterBody2D
## 详细设计：[docs/design/04-单位与移动.md](../../docs/design/04-单位与移动.md)
##
## 单位是**没有智能的执行器**：持有自己的数值与规则表，每 tick 接收规则引擎
## 产出的意图（Intent），把它们落成**匀速直线移动**与**开火意图**，撞墙时
## 干脆地停住。不做任何自主决策（不索敌、不规避、不寻路）——需求 FR-CBT-08。
##
## 【坐标】对外一律用 `position_logic`（格坐标，1 瓦片 = 1 距离）。
## `global_position` 是像素坐标，只在物理与渲染层出现。

const MovementScript := preload("res://src/core/unit/movement.gd")
const HurtboxScript := preload("res://src/core/unit/hurtbox.gd")

const DEFAULT_TILE_PX := 64.0
const DEFAULT_MOVE_SPEED := 3.0
const SIZE_IN_TILES := 0.8      # 单位碰撞盒 0.8×0.8 格（需求 6.5）
const HURTBOX_RADIUS := 0.4     # 格

## 调试开关：打印碰撞层套用过程
var _trace_layers := false

## 物理层号（见 project.godot 的 [layer_names]）
const LAYER_UNIT_BODY := 1
const LAYER_OBSTACLE := 2
const LAYER_HURTBOX_ALLY := 5
const LAYER_HURTBOX_ENEMY := 6

## 阵营（与 src/core/types.gd 一致）
const TEAM_ALLY := 0
const TEAM_ENEMY := 1

# --- 身份与状态 -------------------------------------------------------------
var entity_id := 0
var team := TEAM_ALLY
var is_dead := false

## 单位数值（`Dictionary`，来自 `units.json` 的字段 + 关卡级 overrides）。
## 【不必再包一层类】详设 04 原计划在 M3 换成 `UnitStats` 类，实现时确认没有收益：
## 全程只有「读字段 + 算 effective_*」两种用法，包类只会到处转发。
## 该计划文件 `unit_stats.gd` 从未实现、已删除（见详设 04 的说明）。
## 对外只通过 move_speed() / can_attack() / effective_range() 读取，换实现不影响调用方。
## 单位类型 id（= units.json 里的键）。
## 【为什么要有】热重载（FR-UNIT-04）要按类型重新取数值，而 `stats` 里
## 没有回指类型的字段 —— 单位不知道自己是谁，就没法重载。
var type_id := ""
## 该单位的数值覆盖（来自关卡数据 `units[].overrides`）。
## 【同 type_id 的理由】热重载要按「类型 + 覆盖」重算数值，
## 而覆盖项原本只存在关卡数据里、单位自己拿不到 —— 不存这一份就没法重载。
var overrides: Dictionary = {}

## 【buff 接口预留】(D-28)：关卡数据里 `units[].buffs` 会原样放到这里。
##
## 【必须是真实属性】`Object.set()` 对**不存在的属性是静默失败**（本工程踩过），
## 所以预留接口不能只写个约定 —— 得先有属性，`set()` 才真的存得住。
## 当前**没有任何地方读它**，也就不会有任何行为变化。
var buffs: Array = []
var stats: Dictionary = {}

var hp := 0.0
var max_hp := 0.0
## 减速状态：**只有一层**，固定降到 50%，无持续时间（D-06）
var is_slowed := false

## 玩家的指令表。**归属玩家，重置关卡时保留**。
var rules: Array = []

# --- 意图（由规则引擎写入，由本单位落地）-----------------------------------
## 当前的目标信标序列（值拷贝）与游标
var beacon_sequence: Array = []
var beacon_cursor := 0
## 开火/停火意图（持续型）
var fire_mode := false
## 延迟阻塞剩余秒数（阻塞期间不动也不开火）
var delay_remaining := 0.0
## 开火冷却剩余秒数。由系统 05 维护；**只在想开火时递减**（详设 05 的 4.1）
var cooldown_remaining := 0.0
## 本 tick 是否撞墙（调试与视觉用）
var was_blocked := false

## 出生点的逻辑坐标，重置关卡时回到这里
var spawn_logic_position := Vector2.ZERO

## 1 格等于多少像素
var tile_px := DEFAULT_TILE_PX

## 场景装配点（由 LevelSession 注入）
var battle_map = null
## 实体注册表（死亡时用它注销自己）
var battle_state = null

var _shape_node: CollisionShape2D = null
var _body_node: Polygon2D = null
var _hurtbox: Area2D = null


func _ready() -> void:
	_ensure_nodes()
	_apply_physics_layers()


## 逻辑坐标（格）。**这是权威位置**，1 瓦片 = 1 距离，逻辑层一律用它。
##
## 为什么不直接 `return global_position / tile_px`：物理位置是像素级 float32，
## 「除以 64 再乘 64」的往返会丢掉尾数，最后一段残余位移（1e-3 格 = 0.06 px）
## 会直接归零，单位就卡在离信标一两步处不动（M1-4 实测踩到）。
## 所以逻辑坐标单独存，`global_position` 只是它的渲染/物理投影。
##
## 【不要给它写 setter】GD4 里 setter 内没有可用的 `field` 关键字
## （本工程 4.7.2 会报 "Identifier field not declared"），写成
## `position_logic = value` 又是自我递归。所以改为**显式同步**：
## 任何改动逻辑位置的地方都要跟一次 `_sync_transform()`，
## 或者直接用 `set_logic_position()`。
var position_logic := Vector2.ZERO


## 逻辑位置 → 像素变换。改动 position_logic 之后必须调它。
func _sync_transform() -> void:
	global_position = position_logic * tile_px


## 外部设置逻辑位置的唯一入口（会自动同步像素变换）
func set_logic_position(p: Vector2) -> void:
	position_logic = p
	_sync_transform()


## 建立一个可用的单位。返回自身，方便链式调用。
func setup(p_team: int, pos_logic: Vector2, p_stats: Dictionary) -> void:
	team = p_team
	spawn_logic_position = pos_logic
	stats = p_stats.duplicate(true)
	max_hp = float(stats.get("max_hp", 100.0))
	hp = max_hp
	is_slowed = false
	is_dead = false
	_ensure_nodes()
	_apply_physics_layers()
	set_logic_position(pos_logic)
	_refresh_visual()


# ---------------------------------------------------------------------------
# 数值读取（对外只暴露 effective_* 计算值，不直接读全局表）
# ---------------------------------------------------------------------------

func move_speed() -> float:
	var base := float(stats.get("move_speed", DEFAULT_MOVE_SPEED))
	# 减速不叠加：只生效一层，固定降到 50%（D-06）
	return base * (0.5 if is_slowed else 1.0)


func can_attack() -> bool:
	return bool(stats.get("can_attack", false))


func effective_range() -> float:
	return float(stats.get("range", 0.0))


## 视野半径：0 表示取射程（需求 6.4 默认）
func effective_vision_radius() -> float:
	var v := float(stats.get("vision_radius", 0.0))
	return v if v > 0.0 else effective_range()


## 减速：只置一个开关，不叠加层数（D-06）
func set_slowed() -> void:
	is_slowed = true


# ---------------------------------------------------------------------------
# 节点装配
# ---------------------------------------------------------------------------

func _ensure_nodes() -> void:
	if _body_node == null:
		_body_node = get_node_or_null("Body") as Polygon2D
		if _body_node == null:
			_body_node = Polygon2D.new()
			_body_node.name = "Body"
			var h := tile_px * SIZE_IN_TILES * 0.5
			_body_node.polygon = PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
			add_child(_body_node)

	if _shape_node == null:
		_shape_node = get_node_or_null("Shape") as CollisionShape2D
		if _shape_node == null:
			_shape_node = CollisionShape2D.new()
			_shape_node.name = "Shape"
			var rect := RectangleShape2D.new()
			rect.size = Vector2(SIZE_IN_TILES, SIZE_IN_TILES) * tile_px
			_shape_node.shape = rect
			add_child(_shape_node)

	if _hurtbox == null:
		_hurtbox = get_node_or_null("Hurtbox") as Area2D
		if _hurtbox == null:
			_hurtbox = HurtboxScript.new()
			_hurtbox.name = "Hurtbox"
			var cs := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = HURTBOX_RADIUS * tile_px
			cs.shape = circle
			_hurtbox.add_child(cs)
			add_child(_hurtbox)
		# Team 定了就立刻让 Hurtbox 自己套层；它还会在自己的 _ready 里再套一次，
		# 那次一定在引擎的 Area2D 初始化之后，所以不会被清掉（见 hurtbox.gd 说明）。
		if _hurtbox.has_method("configure"):
			_hurtbox.call("configure", team)


func _apply_physics_layers() -> void:
	# 单位本体在本体层，掩码**只含障碍** —— 所以单位之间互不碰撞（D-08），
	# 避免两个单位挤在路口互相卡死（本作单位不会自己绕路）。
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(LAYER_UNIT_BODY, true)
	set_collision_mask_value(LAYER_OBSTACLE, true)

	if _hurtbox != null:
		# 层的最终归属由 Hurtbox 自己负责（见 hurtbox.gd 的说明），
		# 这里只在 team 变化时通知它一下。
		if _hurtbox.has_method("configure"):
			_hurtbox.call("configure", team)
		if _trace_layers:
			print("      [ua] apply_layers: team=%d hurtbox_layer=%d" % [
				team, int(_hurtbox.collision_layer)])


func _refresh_visual() -> void:
	if _body_node == null:
		return
	if is_dead:
		_body_node.color = Color(0.45, 0.45, 0.5, 1.0)   # 尸体变灰
	elif team == TEAM_ALLY:
		_body_node.color = Color(0.35, 0.8, 1.0, 1.0)
	else:
		_body_node.color = Color(1.0, 0.4, 0.4, 1.0)


## 取 Hurtbox（子弹命中判定用）
func hurtbox() -> Area2D:
	return _hurtbox


# ---------------------------------------------------------------------------
# 意图落地（tick 编排的第 3 步）
# ---------------------------------------------------------------------------

## 应用规则引擎产出的意图。intent 为 null 时只做计时器递减。
func apply_intents(intent, tick_delta: float) -> void:
	if is_dead:
		return

	if intent != null:
		# 1. 延迟请求：取 max，**不叠加**（详设 02 的决策 3）
		if intent.delay_request != null:
			delay_remaining = maxf(delay_remaining, float(intent.delay_request))

		# 2. 移动意图
		if intent.move_intent != null:
			var new_seq: Array = intent.move_intent
			if not _same_sequence(new_seq, beacon_sequence):
				# 序列变了才重置游标；**值相等则保持游标**
				# 这是详设 02 的 4.3「值相等则保持序号」的落地处，两处必须一致。
				beacon_sequence = new_seq.duplicate()
				beacon_cursor = 0

		# 3. 开火意图
		if intent.fire_intent != null:
			fire_mode = bool(intent.fire_intent)

	# 4. 延迟计时器递减（同一 tick 内就扣掉一段）
	delay_remaining = maxf(0.0, delay_remaining - tick_delta)


func _same_sequence(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


## 当前该走向哪个信标；没有目标时返回 null。
func current_beacon_target() -> Variant:
	if beacon_cursor < 0 or beacon_cursor >= beacon_sequence.size():
		return null
	if battle_map == null:
		return null
	var idx := int(beacon_sequence[beacon_cursor])
	if battle_map.has_method("has_beacon") and not bool(battle_map.call("has_beacon", idx)):
		return null
	if battle_map.has_method("beacon_logic_position"):
		var p = battle_map.call("beacon_logic_position", idx)
		if p is Vector2:
			return p
	return null


# ---------------------------------------------------------------------------
# 移动（tick 编排的第 4 步）
# ---------------------------------------------------------------------------

## 到达判定的**精确**阈值：残余位移小于它即认定「已站在信标中心」。
##
## 与 MovementScript.ARRIVE_EPSILON（0.15）分工不同，不要合并：
## · ARRIVE_EPSILON 是「原始位置是否已经贴着目标」的宽容判定
## · 本阈值用在**吸附之后**的复查上，量级要小得多
const SNAP_EPSILON := 0.01


func step_movement(tick_delta: float) -> void:
	was_blocked = false
	if is_dead:
		return
	if delay_remaining > 0.0:
		return                                   # 阻塞：原地不动

	var target = current_beacon_target()
	if target == null:
		return                                   # 没有目标：停在原地，不漂移

	var target_logic := target as Vector2
	var plan := MovementScript.compute_step(position_logic, target_logic,
		move_speed(), tick_delta)
	if bool(plan["arrived"]):
		beacon_cursor += 1                       # 已经站在信标上，切下一个
		return
	if bool(plan["is_final"]):
		# 最后一段：**直接吸附到信标中心**
		#
		# 为什么不走物理：位置字段以格为单位存精确值，而物理是像素级的。
		# 最后一段的残余位移可能只有 1e-3 格（0.06 px），经
		# 「global_position / tile_px * tile_px」的往返会归零，
		# 单位便卡在离信标一两步处永远不动（M1-4 实测：x 停在 2.899999）。
		position_logic = target_logic
		_sync_transform()
		beacon_cursor += 1
		return

	var motion_logic: Vector2 = plan["motion_logic"]
	var motion_px: Vector2 = motion_logic * tile_px
	# 显式标注：move_and_collide 返回 Variant，而本项目警告即错误
	var col: KinematicCollision2D = move_and_collide(motion_px)
	if col != null:
		was_blocked = true                       # 撞墙即停；下一 tick 仍朝同一信标，于是贴墙停住
	# 逻辑位置由**请求的逻辑位移**累加，绝不从像素反推：
	# 像素是 float32，每步都做一次 global_position / tile_px 会把尾数磨掉，
	# 单位就永远走不到信标（M1-4 实测：卡在 2.899999）。
	# 撞墙时按物理实际走到的距离折回，保证逻辑坐标与像素不脱节。
	var actual_px: Vector2 = col.get_travel() if col != null else motion_px
	position_logic += actual_px / tile_px


# ---------------------------------------------------------------------------
# 开火意图（由系统 05 询问，本系统不自己开火）
# ---------------------------------------------------------------------------

func wants_to_fire() -> bool:
	return fire_mode and not is_dead and delay_remaining <= 0.0 and can_attack()


# ---------------------------------------------------------------------------
# 死亡与重置
# ---------------------------------------------------------------------------

## 标记死亡并退出一切查询。**尸体节点保留**到重置或本局结束（详设 04 的 4.4）。
func die() -> void:
	if is_dead:
		return
	is_dead = true
	if battle_state != null and battle_state.has_method("unregister_unit"):
		battle_state.call("unregister_unit", entity_id)
	if _hurtbox != null:
		_hurtbox.monitoring = false
		_hurtbox.collision_layer = 0
	set_collision_layer_value(LAYER_UNIT_BODY, false)
	_refresh_visual()
	EventBus.unit_died.emit(entity_id, team, position_logic)


## 重置关卡：回到出生点、满血、清状态。
## **不清 rules 与信标**（玩家的指令要保留，需求 12.1a）。
func reset() -> void:
	set_logic_position(spawn_logic_position)
	hp = max_hp
	is_slowed = false
	is_dead = false
	fire_mode = false
	beacon_sequence = []
	beacon_cursor = 0
	delay_remaining = 0.0
	cooldown_remaining = 0.0
	was_blocked = false
	if _hurtbox != null:
		_hurtbox.monitoring = true
	_apply_physics_layers()
	_refresh_visual()
