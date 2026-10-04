class_name RuleCondition
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 3.2
##
## 一个条件。字段用**字符串常量**而不是 class_name 引用，避免跨文件类型依赖
## （本沙箱里 class_name 不可用，见 tools/smoke_test.gd 顶部说明）。

const T_ENEMY_IN_VISION := "enemy_in_vision"
const T_SIGNAL_STATE := "signal_state"
const T_BEACON_DISTANCE := "beacon_distance"
const T_SELF_HP := "self_hp"
const T_ENEMY_HAS_STATUS := "enemy_has_status"

## 比较符（BEACON_DISTANCE / SELF_HP 用）
const OP_LT := "lt"
const OP_LE := "le"
const OP_EQ := "eq"
const OP_GE := "ge"
const OP_GT := "gt"

## 状态类型（MVP 只有减速）
const STATUS_SLOWED := "slowed"

var type := T_ENEMY_IN_VISION
var radius := 0.0            ## ENEMY_IN_VISION：<=0 表示取单位当前射程
var signal_index := 0        ## SIGNAL_STATE
var want := true             ## SIGNAL_STATE / ENEMY_HAS_STATUS
var beacon_index := 0        ## BEACON_DISTANCE
var op := OP_LE              ## BEACON_DISTANCE / SELF_HP
var value := 0.0             ## BEACON_DISTANCE 的距离
var percent := 0.0           ## SELF_HP 的百分比（0..100）
var status := STATUS_SLOWED  ## ENEMY_HAS_STATUS


## 从 UI/存档字典构建
static func from_dict(d: Dictionary) -> RefCounted:
	var c := new()
	c.type = str(d.get("type", T_ENEMY_IN_VISION))
	c.radius = float(d.get("radius", 0.0))
	c.signal_index = int(d.get("signal_index", 0))
	c.want = bool(d.get("want", true))
	c.beacon_index = int(d.get("beacon_index", 0))
	c.op = str(d.get("op", OP_LE))
	c.value = float(d.get("value", 0.0))
	c.percent = float(d.get("percent", 0.0))
	c.status = str(d.get("status", STATUS_SLOWED))
	return c


func to_dict() -> Dictionary:
	return {
		"type": type,
		"radius": radius,
		"signal_index": signal_index,
		"want": want,
		"beacon_index": beacon_index,
		"op": op,
		"value": value,
		"percent": percent,
		"status": status,
	}


## 全部条件类型（UI 下拉与校验用）
static func all_types() -> Array:
	return [T_ENEMY_IN_VISION, T_SIGNAL_STATE, T_BEACON_DISTANCE, T_SELF_HP, T_ENEMY_HAS_STATUS]


## 参数 schema：UI 据此动态生成控件（详设 09 的 3.2）
static func schema(type_id: String) -> Array:
	match type_id:
		T_ENEMY_IN_VISION:
			return [{"key": "radius", "type": "float", "label": "半径", "default": 0.0,
				"hint": "0 表示取本单位射程"}]
		T_SIGNAL_STATE:
			return [{"key": "signal_index", "type": "signal_ref", "label": "信号", "default": 1},
				{"key": "want", "type": "bool", "label": "状态", "default": true}]
		T_BEACON_DISTANCE:
			return [{"key": "beacon_index", "type": "beacon_ref", "label": "信标", "default": 1},
				{"key": "op", "type": "enum", "label": "比较", "default": OP_LE,
					"options": [OP_LT, OP_LE, OP_EQ, OP_GE, OP_GT]},
				{"key": "value", "type": "float", "label": "距离", "default": 2.0}]
		T_SELF_HP:
			return [{"key": "op", "type": "enum", "label": "比较", "default": OP_LT,
					"options": [OP_LT, OP_LE, OP_EQ, OP_GE, OP_GT]},
				{"key": "percent", "type": "float", "label": "血量百分比", "default": 60.0}]
		T_ENEMY_HAS_STATUS:
			return [{"key": "status", "type": "enum", "label": "状态", "default": STATUS_SLOWED,
					"options": [STATUS_SLOWED]},
				{"key": "want", "type": "bool", "label": "持有", "default": true}]
		_:
			return []


## 显示名
static func display_name(type_id: String) -> String:
	match type_id:
		T_ENEMY_IN_VISION: return "视野内出现敌人"
		T_SIGNAL_STATE: return "信号状态"
		T_BEACON_DISTANCE: return "与某信标距离"
		T_SELF_HP: return "血量状态"
		T_ENEMY_HAS_STATUS: return "敌人持有状态"
		_: return type_id


## 需要在求值前检查「引用的东西是否存在」的引用：返回 [kind, index]
## kind: "beacon" / "signal"；没有引用则返回空数组
##
## 【命名注意】不要叫 `reference()` —— RefCounted 已经有同名方法，
## 覆盖原生方法会直接编译失败（M2 实测）。
func reference_of() -> Array:
	match type:
		T_BEACON_DISTANCE:
			return ["beacon", beacon_index]
		T_SIGNAL_STATE:
			return ["signal", signal_index]
		_:
			return []
