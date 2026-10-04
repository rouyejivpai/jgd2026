class_name Scorer
extends RefCounted
## 详细设计：[docs/design/08-评价与结算.md](../../docs/design/08-评价与结算.md) 4.2-4.5
##
## 把统计量 + 系数算成 `ResultData`。**游戏内时间**口径（`clock.game_time`），
## 所以 1x 与 3x 通关得分相同 —— 倍速不影响结算结果（FR-FLOW-06）。

const ResultDataScript := preload("res://src/core/score/result_data.gd")

## 与 LevelSession.Verdict 一致的取值
const VERDICT_NONE := 0
const VERDICT_WIN := 1
const VERDICT_LOSE := 2

## 缺省系数（`scoring.json` 读不到时的兜底，与 D-14 一致）
const DEFAULT_COEFFICIENTS := {"complexity": 10.0, "beacon": 10.0, "time": 1.0}


## 计算结算数据。
##
## level_id       关卡 id
## verdict        结算结果
## stats          LevelStatistics
## coefficients   scoring.json 的三个系数（缺失键用兜底值）
## best_before    该关历史最佳；没有记录传负数
##
## 返回 ResultData。**失败时不算分、不写记录**（FR-SCORE-06），
## 只返回一个 verdict 已知、computed=false 的对象，由 UI 显示"重试 / 返回"。
static func compute(level_id: String, verdict: int, stats, coefficients: Dictionary,
		best_before: float = ResultDataScript.UNCOMPUTED) -> RefCounted:
	var rd = ResultDataScript.new()
	rd.level_id = level_id
	rd.verdict = verdict
	rd.best_score = best_before

	if verdict != VERDICT_WIN:
		return rd            # 失败：不计分

	var c1 := _coef(coefficients, "complexity")
	var c2 := _coef(coefficients, "beacon")
	var c3 := _coef(coefficients, "time")

	rd.computed = true
	if stats != null:
		rd.condition_count = int(stats.get("condition_count"))
		rd.action_count = int(stats.get("action_count"))
		rd.beacon_count = int(stats.get("beacon_count"))
		rd.elapsed_time = float(stats.get("elapsed_time"))

	# 复杂度 = (行为数 + 条件数) × C1；信标 = 个数 × C2；时间 = 秒数 × C3
	rd.complexity_cost = float(rd.action_count + rd.condition_count) * c1
	rd.beacon_cost = float(rd.beacon_count) * c2
	rd.time_cost = rd.elapsed_time * c3
	rd.total_score = rd.complexity_cost + rd.beacon_cost + rd.time_cost

	# 最佳记录：首次通关即写入；之后只在更优时更新
	if best_before < 0.0 or rd.total_score < best_before:
		rd.best_score = rd.total_score
		rd.is_new_record = true
	else:
		rd.best_score = best_before
	return rd


static func _coef(coefficients: Dictionary, key: String) -> float:
	if coefficients != null and coefficients.has(key):
		return float(coefficients[key])
	return float(DEFAULT_COEFFICIENTS[key])


# ---------------------------------------------------------------------------
# 最佳记录持久化
# ---------------------------------------------------------------------------

## 从存档读该关历史最佳；没有记录返回负数。
##
## save_data 传 DSH 的 `Save` autoload（可为 null，便于纯逻辑测试）。
static func best_of(save_data, level_id: String) -> float:
	if save_data == null:
		return ResultDataScript.UNCOMPUTED
	# 【类型必须显式标注】`Dictionary.get()` 返回 Variant，
	# `:=` 会触发 "Cannot infer the type"（本工程警告即错误）。
	var best: Variant = (save_data as Dictionary).get("best_scores", {})
	if not (best is Dictionary):
		return ResultDataScript.UNCOMPUTED
	var v = (best as Dictionary).get(level_id)
	if v == null:
		return ResultDataScript.UNCOMPUTED
	return float(v)


## 若本次更优则写回内存里的存档字典。**返回是否写入**（不落盘，落盘时机由
## 调用方决定：详设 08 的 4.4 说在关卡退出时统一 save_data()）。
##
## 【为什么只改内存不落盘】本沙箱下 Godot 写不了 `user://`（实测 err=12），
## 落盘必然失败；把"算分"与"写盘"分开，得分与最佳记录在本局内仍然正确，
## 也不会因为写盘失败把结算流程搞崩。
static func apply_best(save_data, level_id: String, rd) -> bool:
	if save_data == null or rd == null or not bool(rd.get("computed")):
		return false
	var d: Dictionary = save_data
	if not (d.get("best_scores") is Dictionary):
		d["best_scores"] = {}
	var best: Dictionary = d["best_scores"]
	var cur := best_of(save_data, level_id)
	var total := float(rd.get("total_score"))
	if cur < 0.0 or total < cur:
		best[level_id] = total
		rd.set("best_score", total)
		rd.set("is_new_record", true)
		return true
	rd.set("best_score", cur)
	rd.set("is_new_record", false)
	return false
