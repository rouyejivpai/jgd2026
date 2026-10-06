class_name LevelStatistics
extends RefCounted
## 详细设计：[docs/design/08-评价与结算.md](../../docs/design/08-评价与结算.md) 3.1 / 4.1
##
## 【阵营常量取自 `types.gd`】不要写死 0/1（编号变了会静默数错），
## 也**不要 preload `unit_actor.gd`** —— 那条依赖会成环，
## 结果是 `play_scene.gd` 整个解析失败（本轮实测：
## `Could not resolve script statistics.gd` + `Cannot infer the type of "StatisticsScript"`）。
## `types.gd` 是纯数据脚本、不依赖任何东西，正是为这种场合准备的。
const TeamScript := preload("res://src/core/types.gd")

## 阵营常量取自 UnitActor，**不要写死 0/1**（阵营编号变了会静默数错）
const UnitActorScript := preload("res://src/core/unit/unit_actor.gd")

## 一局的统计量。**结算时一次性快照**，不是每 tick 累加 —— 因为规则表可能在
## 编制期才最终确定，逐 tick 累加会把中途被改掉的指令算进去。

## 条件总数：**全部 enabled 指令**里的条件个数（含被覆盖而未生效的指令）
var condition_count := 0
## 行为总数，口径同上
var action_count := 0
## 本局实际放置的信标数
var beacon_count := 0
## **上场我方单位数**（D-24：结算第 4 项「所用人数」的口径）
##
## 口径说明：数的是"这一局真的上场的我方单位"（关卡预置 ＋ 之后若有召唤也算），
## **不含敌方**。用 `UnitActor.TEAM_ALLY` 比较而不是写死 0，避免阵营编号一变就静默数错。
var unit_count := 0
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
		if int(u.get("team")) == TeamScript.TEAM_ALLY:
			s.unit_count += 1
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
		"unit_count": unit_count,
		"elapsed_time": elapsed_time,
	}
