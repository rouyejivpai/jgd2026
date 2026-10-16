class_name FacingTracker
extends RefCounted
## 朝向迟滞（07 §6 / A04，仅表现层）：朝当前背向一侧的横向移动累计 ≥ FLIP_CELLS 格或连续 ≥ FLIP_SECONDS 秒才翻转；
## 不足时视为后撤（backstep = true：不翻转，由视图做后仰）。朝面向一侧移动或停下会清空累计。
## 只读模拟坐标增量，不写模拟数据；时间用模拟步长累计，1×/2× 下表现一致。

const FLIP_CELLS: float = 0.5
const FLIP_SECONDS: float = 0.4
const MOVE_EPS: float = 0.002            ## 小于该横向位移（格）视为没有横向移动

var facing_left: bool = false
var backstep: bool = false
var _acc_cells: float = 0.0
var _acc_seconds: float = 0.0


func _init(start_left: bool = false) -> void:
	facing_left = start_left


## 推进一次；dx = 本次横向位移（格，向右为正），dt = 对应的模拟时间。返回 true 表示本次发生了翻转。
## flip_cells / flip_seconds：翻转阈值（第四阶段：撤离中用更大的阈值，避免来回翻身"抽搐"）
func update(dx: float, dt: float, flip_cells: float = FLIP_CELLS, flip_seconds: float = FLIP_SECONDS) -> bool:
	if absf(dx) <= MOVE_EPS:
		_reset()
		return false
	var moving_left: bool = dx < 0.0
	if moving_left == facing_left:
		_reset()
		return false
	_acc_cells += absf(dx)
	_acc_seconds += dt
	if _acc_cells >= flip_cells or _acc_seconds >= flip_seconds:
		facing_left = moving_left
		_reset()
		return true
	backstep = true
	return false


## 直接朝向（攻击时面向目标）；返回是否改变了朝向
func face(left: bool) -> bool:
	_reset()
	if left == facing_left:
		return false
	facing_left = left
	return true


func _reset() -> void:
	_acc_cells = 0.0
	_acc_seconds = 0.0
	backstep = false
