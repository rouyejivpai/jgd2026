class_name SimDecision
extends RefCounted
## RuleEvaluator 的输出：本步执行哪条指令、对谁、做什么。
## 第五阶段：rule_index / target / action / reason 为移动部分（旧口径 = 唯一生效的指令）；attack_* 为攻击部分，
## 由 Combat 读取。旧口径下攻击类行为（attack / chase_attack）的 attack_* 与主字段相同，其余为空。

var rule_index: int = -1
var target: int = -1
var action: ActionDef = null            ## 无匹配时为 null（= 待机）
var reason: int = SimTypes.ReasonCode.OK
var attack_rule_index: int = -1
var attack_target: int = -1
var attack_action: ActionDef = null     ## 无匹配时为 null（= 不攻击）
var attack_reason: int = SimTypes.ReasonCode.OK


func action_type() -> int:
	return action.type if action != null else SimTypes.ActionType.IDLE


func attack_action_type() -> int:
	return attack_action.type if attack_action != null else SimTypes.ActionType.HOLD_FIRE


## 旧口径：攻击类行为同时作为攻击部分
func mirror_attack_part() -> void:
	var t: int = action_type()
	if t == SimTypes.ActionType.ATTACK or t == SimTypes.ActionType.CHASE_ATTACK:
		attack_rule_index = rule_index
		attack_target = target
		attack_action = action
		attack_reason = reason
