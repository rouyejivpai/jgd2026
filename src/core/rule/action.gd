class_name RuleAction
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 3.3
##
## 一个行为。字段用字符串常量，冲突键在 `conflict_key()` 里算。

const T_SET_FIRE_MODE := "set_fire_mode"
const T_MOVE_ALONG_BEACONS := "move_along_beacons"
const T_SET_SIGNAL := "set_signal"
const T_DELAY := "delay"
const T_INTERACT_DEVICE := "interact_device"   ## MVP 不实现（D-13）

## 冲突键：同类行为互斥的判定依据（详设 02 的 3.3 表）
const KEY_FIRE_MODE := "fire_mode"
const KEY_MOVE := "move"
const KEY_SIGNAL_PREFIX := "signal:"
const KEY_INTERACT_PREFIX := "interact:"

var type := T_SET_FIRE_MODE
var fire := true                  ## SET_FIRE_MODE
var beacon_indices: Array = []    ## MOVE_ALONG_BEACONS，有序
var signal_index := 0             ## SET_SIGNAL
var value := true                 ## SET_SIGNAL 的置开/置关
var seconds := 0.0                ## DELAY
var device_id := 0                ## INTERACT_DEVICE
var kind := ""                    ## INTERACT_DEVICE


static func from_dict(d: Dictionary) -> RefCounted:
	var a := new()
	a.type = str(d.get("type", T_SET_FIRE_MODE))
	a.fire = bool(d.get("fire", true))
	var bi = d.get("beacon_indices", [])
	if bi is Array:
		var out: Array = []
		for x in bi:
			out.append(int(x))
		a.beacon_indices = out
	a.signal_index = int(d.get("signal_index", 0))
	a.value = bool(d.get("value", true))
	a.seconds = float(d.get("seconds", 0.0))
	a.device_id = int(d.get("device_id", 0))
	a.kind = str(d.get("kind", ""))
	return a


func to_dict() -> Dictionary:
	return {
		"type": type,
		"fire": fire,
		"beacon_indices": beacon_indices.duplicate(),
		"signal_index": signal_index,
		"value": value,
		"seconds": seconds,
		"device_id": device_id,
		"kind": kind,
	}


## 冲突键。
## 【重要】DELAY 返回空串 —— 它是阻塞型，不参与冲突覆盖（详设 02 的 3.4）。
func conflict_key() -> String:
	match type:
		T_SET_FIRE_MODE:
			return KEY_FIRE_MODE
		T_MOVE_ALONG_BEACONS:
			return KEY_MOVE
		T_SET_SIGNAL:
			return KEY_SIGNAL_PREFIX + str(signal_index)
		T_INTERACT_DEVICE:
			return KEY_INTERACT_PREFIX + str(device_id)
		_:
			return ""


## 是否为持续型（会被 UnitActor 保持，不清空）
func is_persistent() -> bool:
	return type == T_SET_FIRE_MODE or type == T_MOVE_ALONG_BEACONS


## 是否为阻塞型（延迟）
func is_blocking() -> bool:
	return type == T_DELAY


static func all_types() -> Array:
	return [T_SET_FIRE_MODE, T_MOVE_ALONG_BEACONS, T_SET_SIGNAL, T_DELAY, T_INTERACT_DEVICE]


## 参数 schema（UI 动态生成控件用）
static func schema(type_id: String) -> Array:
	match type_id:
		T_SET_FIRE_MODE:
			return [{"key": "fire", "type": "bool", "label": "开火", "default": true}]
		T_MOVE_ALONG_BEACONS:
			return [{"key": "beacon_indices", "type": "beacon_seq", "label": "信标序列",
				"default": []}]
		T_SET_SIGNAL:
			return [{"key": "signal_index", "type": "signal_ref", "label": "信号", "default": 1},
				{"key": "value", "type": "bool", "label": "置为开", "default": true}]
		T_DELAY:
			return [{"key": "seconds", "type": "float", "label": "秒数", "default": 1.0,
				"min": 0.0}]
		T_INTERACT_DEVICE:
			return [{"key": "device_id", "type": "int", "label": "装置", "default": 0}]
		_:
			return []


static func display_name(type_id: String) -> String:
	match type_id:
		T_SET_FIRE_MODE: return "开火模式"
		T_MOVE_ALONG_BEACONS: return "沿着信标移动"
		T_SET_SIGNAL: return "设置信号"
		T_DELAY: return "延迟"
		T_INTERACT_DEVICE: return "与装置互动（未实现）"
		_: return type_id


## 需要在求值前检查的引用（信标序列里的每个信标都要存在）
func references() -> Array:
	var out: Array = []
	if type == T_MOVE_ALONG_BEACONS:
		for i in beacon_indices:
			out.append(["beacon", int(i)])
	elif type == T_SET_SIGNAL:
		out.append(["signal", signal_index])
	return out
