class_name Rule
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 3.1
## 状态：已实现（M2-2）。
##
## 一条指令：enabled + condition_logic + conditions + actions。
## **数组下标即优先级**——执行顺序 = 数组顺序，行号 1..n 由 UI 动态刷新。

## 跨文件引用必须走 preload，不能用 class_name（见 tools/smoke_test.gd 顶部说明）
const RuleEnumsScript := preload("res://src/core/rule/rule_enums.gd")
## 深拷贝要用到条件/行为的序列化（它们各自有 to_dict/from_dict）。
## 这两者都不回头引用本文件，所以不存在循环 preload。
const ConditionScript := preload("res://src/core/rule/condition.gd")
const ActionScript := preload("res://src/core/rule/action.gd")

var enabled := true
var condition_logic: int = RuleEnumsScript.Logic.AND
var conditions: Array = []
var actions: Array = []
## 运行时计算：引用不存在的信标/信号时填写，供 UI 标黄（不弹窗、不阻断）
var invalid_reason := ""


## 深拷贝：条件与行为都用各自的 `to_dict`/`from_dict` 重建。
##
## 【为什么必须有】D-20 的「指令复制到其它单位」要求**深拷贝** ——
## 浅拷贝（或直接引用同一个 Rule 对象）会让两个单位的指令联动：
## 改 B 的参数，A 也跟着变（详设 09 的 4.7 验收项明确写了这条）。
##
## 实现成静态方法而不是 `duplicate()`：本工程的 `class_name` 在运行期不可靠，
## 静态方法用 `new()` 自引用最稳（见 smoke_test 顶部的约定）。
static func clone(src) -> RefCounted:
	var out := new()
	if src == null:
		return out
	out.enabled = bool(src.get("enabled"))
	out.condition_logic = int(src.get("condition_logic"))
	# 引用类型必须逐个重建，不能直接把数组塞过去
	var conds: Array = []
	for c in (src.get("conditions") as Array):
		conds.append(ConditionScript.from_dict(c.to_dict()))
	out.conditions = conds
	var acts: Array = []
	for a in (src.get("actions") as Array):
		acts.append(ActionScript.from_dict(a.to_dict()))
	out.actions = acts
	out.invalid_reason = ""
	return out
