class_name Combat
extends RefCounted
## 普通攻击（01 §6.7、策划 5.1）：结算即命中，伤害 = attack，无防御/闪避；
## 结算时检查目标存活且在射程内；攻速 0 永不攻击；切换规则不重置冷却。


static func try_attack(unit: SimUnit, d: SimDecision, world: SimWorld) -> void:
	var t: int = d.action_type()
	if t != SimTypes.ActionType.ATTACK and t != SimTypes.ActionType.CHASE_ATTACK:
		return
	if d.target < 0 or unit.attack_speed <= 0.0:
		return
	var target: SimUnit = world.get_unit(d.target)
	if target == null or not target.alive:
		return
	if unit.pos.distance_to(target.pos) > unit.attack_range + SimTypes.DIST_EPS:
		if t == SimTypes.ActionType.ATTACK:
			unit.reason = SimTypes.ReasonCode.TARGET_OUT_OF_RANGE
		return
	if StatusSystem.attack_blocked(world, unit):
		unit.reason = SimTypes.ReasonCode.PARALYZED
		return
	if unit.cooldown > SimTypes.TIME_EPS:
		unit.reason = SimTypes.ReasonCode.COOLDOWN
		return
	world.queue_damage(unit.id, target.id, unit.attack, true)
	unit.cooldown = 1.0 / unit.attack_speed
	world.emit_event(SimTypes.EventType.ATTACK_FIRED, { "source": unit.id, "target": target.id, "damage": unit.attack })
