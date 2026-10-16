class_name SimDecision
extends RefCounted
## RuleEvaluator 的输出：本步执行哪条指令、对谁、做什么。

var rule_index: int = -1
var target: int = -1
var action: ActionDef = null            ## 无匹配时为 null（= 待机）
var reason: int = SimTypes.ReasonCode.OK


func action_type() -> int:
	return action.type if action != null else SimTypes.ActionType.IDLE
