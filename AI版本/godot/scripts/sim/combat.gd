class_name Combat
extends RefCounted
## 普通攻击（01 §6.7、策划 5.1）：结算即命中，伤害 = attack，无防御/闪避；
## 结算时检查目标存活且在射程内；攻速 0 永不攻击；切换规则不重置冷却。


## 第五阶段：读决策的攻击部分（旧口径下与主决策相同）；原因码写到攻击组（双组口径）或唯一的 reason（旧口径）
static func try_attack(unit: SimUnit, d: SimDecision, world: SimWorld) -> void:
	var t: int = d.attack_action_type()
	if t != SimTypes.ActionType.ATTACK and t != SimTypes.ActionType.CHASE_ATTACK:
		return
	if d.attack_target < 0 or unit.attack_speed <= 0.0:
		return
	var target: SimUnit = world.get_unit(d.attack_target)
	if target == null or not target.alive:
		return
	if unit.pos.distance_to(target.pos) > unit.attack_range + SimTypes.DIST_EPS:
		if t == SimTypes.ActionType.ATTACK:
			_set_reason(unit, SimTypes.ReasonCode.TARGET_OUT_OF_RANGE)
		return
	if StatusSystem.attack_blocked(world, unit):
		_set_reason(unit, SimTypes.ReasonCode.PARALYZED)
		return
	if unit.cooldown > SimTypes.TIME_EPS:
		_set_reason(unit, SimTypes.ReasonCode.COOLDOWN)
		return
	world.queue_damage(unit.id, target.id, unit.attack, true)
	unit.cooldown = 1.0 / unit.attack_speed
	world.emit_event(SimTypes.EventType.ATTACK_FIRED, { "source": unit.id, "target": target.id, "damage": unit.attack })


static func _set_reason(unit: SimUnit, code: int) -> void:
	if unit.dual_rules:
		unit.attack_reason = code
	else:
		unit.reason = code
