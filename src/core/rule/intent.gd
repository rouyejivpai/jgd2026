class_name Intent
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 4.1
## 状态：已实现（M2-2）。
##
## 规则引擎一个 tick 的产出。交给 UnitActor 在「应用意图」阶段落地。

var move_intent = null      ## null 或 {sequence: Array[int], 由单位保持序号}
var fire_intent = null      ## null 或 bool
var signal_writes: Array = []   ## [(signal_index, value), ...]
var delay_request = null    ## null 或 float（秒）
var matched_rule_indices: Array[int] = []   ## 本 tick 命中的指令下标（调试/UI 高亮）
