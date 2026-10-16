class_name FailDiagnosis
extends RefCounted
## 失败说明分类（03 §7 第六关"三类失败说明"）：在战斗中观察事件与每个 tick，结算时给出文案。
## 逃离类失败（reach_zone）分三类，文案键为 "<lose id>:<类别>"，关卡未提供时退回 "<lose id>" 总说明。
##   front_not_held：逃离目标以外的敌人攻击过非承伤（己方最大生命者以外）的单位——前排没留住
##   out_of_range  ：逃离目标始终没进入任何会出手的己方单位射程
##   wrong_target  ：进过射程，但火力没落在它身上（筛选选中了别的敌人）

const FRONT_NOT_HELD: String = "front_not_held"
const OUT_OF_RANGE: String = "out_of_range"
const WRONG_TARGET: String = "wrong_target"

var level: LevelDefinition = null
var escort_hit_backline: bool = false
var escapee_in_range: bool = false
var escapee_targeted: bool = false


func _init(p_level: LevelDefinition) -> void:
	level = p_level


func reset() -> void:
	escort_hit_backline = false
	escapee_in_range = false
	escapee_targeted = false


func observe_event(e: Dictionary, world: SimWorld) -> void:
	if int(e["type"]) != SimTypes.EventType.ATTACK_FIRED:
		return
	var src: SimUnit = world.get_unit(int(e["source"]))
	var dst: SimUnit = world.get_unit(int(e["target"]))
	if src != null and dst != null and src.faction == SimTypes.Faction.ENEMY and dst.faction == SimTypes.Faction.ALLY \
			and not is_escapee(src) and dst.max_hp < _tank_hp(world):
		escort_hit_backline = true


func observe_tick(world: SimWorld) -> void:
	for o: ObjectiveDef in level.lose:
		if o.type != SimTypes.ObjectiveType.REACH_ZONE:
			continue
		var esc: SimUnit = world.get_spawn(o.target)
		if esc == null or not esc.alive:
			continue
		for u: SimUnit in world.units:
			if u.faction == SimTypes.Faction.ALLY and u.alive and can_attack(u) and u.pos.distance_to(esc.pos) <= u.attack_range + SimTypes.DIST_EPS:
				escapee_in_range = true
				if u.current_target == esc.id:
					escapee_targeted = true


func category() -> String:
	if escort_hit_backline:
		return FRONT_NOT_HELD
	if not escapee_in_range:
		return OUT_OF_RANGE
	return WRONG_TARGET


## 结算失败原因文案
func fail_text(world: SimWorld) -> String:
	var key: String = world.result_objective
	for o: ObjectiveDef in level.lose:
		if o.id == key and o.type == SimTypes.ObjectiveType.REACH_ZONE:
			var sub: String = "%s:%s" % [key, category()]
			if level.fail_feedback.has(sub):
				return str(level.fail_feedback[sub])
	return str(level.fail_feedback.get(key, level.fail_feedback.get("default", "")))


func is_escapee(u: SimUnit) -> bool:
	for o: ObjectiveDef in level.lose:
		if o.type == SimTypes.ObjectiveType.REACH_ZONE and o.target == u.spawn_id:
			return true
	return false


static func can_attack(u: SimUnit) -> bool:
	if u.attack_speed <= 0.0:
		return false
	for r: RuleDef in u.rules:
		if r.enabled and (r.action.type == SimTypes.ActionType.ATTACK or r.action.type == SimTypes.ActionType.CHASE_ATTACK):
			return true
	return false


static func _tank_hp(world: SimWorld) -> float:
	var m: float = 0.0
	for u: SimUnit in world.units:
		if u.faction == SimTypes.Faction.ALLY and u.kind == SimTypes.UnitKind.UNIT:
			m = maxf(m, u.max_hp)
	return m
