class_name SimUnit
extends RefCounted
## 单位运行数据（01 §6.4）。数值从 UnitDefinition 复制，运行中只由模拟核心修改。

var id: int = -1
var def: UnitDefinition = null
var spawn_id: String = ""               ## 槽位 id 或 initial_units id
var display_name: String = ""
var faction: int = SimTypes.Faction.NEUTRAL
var kind: int = SimTypes.UnitKind.UNIT
var max_hp: float = 1.0
var attack: float = 0.0
var attack_speed: float = 0.0
var move_speed: float = 0.0
var vision: float = 0.0
var attack_range: float = 0.0
var pos: Vector2 = Vector2.ZERO         ## 连续坐标（格单位，策划坐标系）
var hp: float = 1.0
var alive: bool = true
var cooldown: float = 0.0
var rules: Array[RuleDef] = []
var current_rule: int = -1
var current_target: int = -1
var current_action: int = SimTypes.ActionType.IDLE
var lock_target: int = -1               ## first_seen 锁定
var reason: int = SimTypes.ReasonCode.OK
var rule_fail_reasons: Dictionary = {}  ## 规则下标 -> 未成立原因码（本步）
var path: Array[Vector2i] = []
var path_goal: Vector2i = Vector2i(-1, -1)
var path_age: int = 0
var route_index: int = 0
var seen_order: Dictionary = {}         ## 对立单位 id -> 进入视野序号
var trait_state: Dictionary = {}        ## trait_id -> 剩余冷却
var tags: Array[String] = []
var counts_for_annihilate: bool = true
## 07 §3：个人信标（按放置顺序 = 字母顺序；删除后字母不重排）。元素 { "id": String, "cell": Vector2i }
var beacons: Array[Dictionary] = []
## follow_beacons 游标：当前前往的信标下标与方向（pingpong 用 -1/+1）；被抢占时保留，-1 = 尚未开始
var beacon_index: int = -1
var beacon_dir: int = 1
## 第四阶段：沿信标被其他指令（如覆盖的撤离）打断后恢复时，先回到离信标路线最近的一点（格），到达后继续；(-1,-1) = 无
var beacon_rejoin: Vector2i = Vector2i(-1, -1)
## 上一步的行为类型（判断"恢复"用）
var last_action: int = SimTypes.ActionType.IDLE
## wait 的边沿触发状态（07 §3.4）：规则下标 -> { "armed": bool, "remaining": float（< 0 = 未在计时）}
var wait_state: Dictionary = {}
## 异常状态：状态 id（vulnerable / paralysis / slow）-> 剩余秒数。再次施加刷新时长，不叠加。
var statuses: Dictionary = {}


func has_status(s: String) -> bool:
	return float(statuses.get(s, 0.0)) > SimTypes.TIME_EPS


func add_status(s: String, seconds: float) -> void:
	statuses[s] = maxf(float(statuses.get(s, 0.0)), seconds)


static func create(p_def: UnitDefinition, p_faction: int, p_pos: Vector2, p_rules: Array[RuleDef]) -> SimUnit:
	var u := SimUnit.new()
	u.def = p_def
	u.display_name = p_def.display_name
	u.faction = p_faction
	u.kind = p_def.kind
	u.max_hp = p_def.max_hp
	u.attack = p_def.attack
	u.attack_speed = p_def.attack_speed
	u.move_speed = p_def.move_speed
	u.vision = p_def.vision
	u.attack_range = p_def.attack_range
	u.pos = p_pos
	u.hp = p_def.max_hp
	u.rules = p_rules
	return u


func cell() -> Vector2i:
	return SimTypes.pos_to_cell(pos)


func is_structure() -> bool:
	return kind == SimTypes.UnitKind.STRUCTURE


## 信标在序列中的下标，不存在为 -1
func beacon_slot(beacon_id: String) -> int:
	for i: int in beacons.size():
		if str(beacons[i]["id"]) == beacon_id:
			return i
	return -1


## 当前 wait 剩余秒数（未在等待为 -1），供 UI 显示
func wait_remaining() -> float:
	if current_action != SimTypes.ActionType.WAIT or not wait_state.has(current_rule):
		return -1.0
	return float((wait_state[current_rule] as Dictionary)["remaining"])


## 记录决策；规则或目标变化时发事件（01 §6.2 第 6 步）
func apply_decision(d: SimDecision, world: SimWorld) -> void:
	var prev_rule: int = current_rule
	var prev_target: int = current_target
	last_action = current_action
	current_rule = d.rule_index
	current_target = d.target
	current_action = d.action_type()
	reason = d.reason
	if prev_rule != current_rule:
		world.emit_event(SimTypes.EventType.RULE_CHANGED, { "unit": id, "rule_index": current_rule, "reason": reason })
	if prev_target != current_target:
		world.emit_event(SimTypes.EventType.TARGET_CHANGED, { "unit": id, "target": current_target })
