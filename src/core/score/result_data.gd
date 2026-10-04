class_name ResultData
extends RefCounted
## 详细设计：[docs/design/08-评价与结算.md](../../docs/design/08-评价与结算.md) 3.2
##
## 结算数据对象。**结算界面只渲染它、不做任何算术** —— 避免两边口径分叉
## （详设 10 的 2.3）。

## 未计算时的哨兵值。用负数而不是 0：0 是一个合法得分，
## 而"失败不算分"必须能与"得了 0 分"区分开（FR-SCORE-06）。
const UNCOMPUTED := -1.0

var level_id := ""
## 与 LevelSession.Verdict 一致：0 NONE / 1 WIN / 2 LOSE
var verdict := 0
## 是否算过分（失败时为 false，各分项都是 UNCOMPUTED）
var computed := false

var complexity_cost := UNCOMPUTED
var beacon_cost := UNCOMPUTED
var time_cost := UNCOMPUTED
var total_score := UNCOMPUTED

## 明细（FR-SCORE-05 要在结算界面展示，便于玩家核对）
var condition_count := 0
var action_count := 0
var beacon_count := 0
var elapsed_time := 0.0

## 该关历史最佳（含本次，如果刷新了）
var best_score := UNCOMPUTED
var is_new_record := false


func to_dict() -> Dictionary:
	return {
		"level_id": level_id,
		"verdict": verdict,
		"computed": computed,
		"complexity_cost": complexity_cost,
		"beacon_cost": beacon_cost,
		"time_cost": time_cost,
		"total_score": total_score,
		"condition_count": condition_count,
		"action_count": action_count,
		"beacon_count": beacon_count,
		"elapsed_time": elapsed_time,
		"best_score": best_score,
		"is_new_record": is_new_record,
	}


## 给 UI 用的一行摘要（避免 UI 自己拼算）
func summary() -> String:
	if not computed:
		return "未计分"
	return "总分 %.1f（指令 %.1f + 信标 %.1f + 时间 %.1f）" % [
		total_score, complexity_cost, beacon_cost, time_cost]
