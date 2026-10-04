class_name LevelStatistics
extends RefCounted
## 详细设计：[docs/design/08-评价与结算.md](../../docs/design/08-评价与结算.md) 3.1 / 4.1
##
## 一局的统计量。**结算时一次性快照**，不是每 tick 累加 —— 因为规则表可能在
## 编制期才最终确定，逐 tick 累加会把中途被改掉的指令算进去。

## 条件总数：**全部 enabled 指令**里的条件个数（含被覆盖而未生效的指令）
var condition_count := 0
## 行为总数，口径同上
var action_count := 0
## 本局实际放置的信标数
var beacon_count := 0
## 从点开始到结算的游戏内时间（秒）
var elapsed_time := 0.0


## 从单位列表快照。
##
## 【为什么统计"全部启用指令"而不是"实际生效的"】详设 08 的 4.1 明确：
## 否则「多写规则再用顺序覆盖」可以免费，评价体系会被绕过。
static func snapshot(units: Array, p_beacon_count: int, p_elapsed_time: float) -> RefCounted:
	var s := new()
	s.beacon_count = p_beacon_count
	s.elapsed_time = p_elapsed_time
	for u in units:
		if u == null:
			continue
		for r in (u.get("rules") as Array):
			if r == null:
				continue
			if not bool(r.get("enabled")):
				continue          # 禁用的指令完全不参与统计（FR-CMD-09）
			s.condition_count += (r.get("conditions") as Array).size()
			s.action_count += (r.get("actions") as Array).size()
	return s


## 指令复杂度用的"元素个数"：条件 + 行为
func complexity_elements() -> int:
	return condition_count + action_count


func to_dict() -> Dictionary:
	return {
		"condition_count": condition_count,
		"action_count": action_count,
		"beacon_count": beacon_count,
		"elapsed_time": elapsed_time,
	}
