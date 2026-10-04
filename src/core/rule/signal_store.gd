class_name SignalStore
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 3.2 / 4.4 决策 4
##
## 全局信号表。**关键时序（D4）**：本 tick 写入的信号，**下一 tick** 才能被条件读到。
##
## 实现方式：两份表 + 一个暂存区
## · `current`  本 tick 条件读的那份（本 tick 开始时就固定了）
## · `pending`  本 tick 行为要写的那些，攒着
## · `commit()` 在 tick 末把它并进 current
## 这样条件求值在整个 tick 内看到的是同一份快照，结果完全可预测、可复现。

var current: Dictionary = {}     ## index(int) → bool
var pending: Dictionary = {}     ## index(int) → bool

var count := 0                   ## 由关卡数据的 signal_count 决定


func setup(signal_count: int) -> void:
	count = maxi(signal_count, 0)
	current.clear()
	pending.clear()
	# 所有信号初始默认为关（需求 5.3）
	for i in range(1, count + 1):
		current[i] = false


## 本 tick 生效的值。越界或不存在一律当「关」。
func is_on(index: int) -> bool:
	return bool(current.get(index, false))


## 该信号是否存在（越界即不存在）
##
## 【命名注意】不要叫 `has_signal()` —— Object 已经有同名方法（且签名不同），
## 覆盖它会导致「函数签名与父类不匹配」的编译错误（M2 实测）。
func has_signal_index(index: int) -> bool:
	return current.has(index)


## 行为写入 → 进暂存区（下一 tick 才生效）
func request_write(index: int, value: bool) -> void:
	pending[index] = value


## tick 末提交：把暂存区并进 current
func commit() -> void:
	if pending.is_empty():
		return
	for k in pending.keys():
		current[k] = pending[k]
	pending.clear()


## 是否有待提交的写入（测试与调试用）
func has_pending() -> bool:
	return not pending.is_empty()


## 调试/快照用
func snapshot() -> Dictionary:
	return current.duplicate()
