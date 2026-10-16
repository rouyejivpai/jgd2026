class_name DataReader
extends RefCounted
## 数据加载的错误收集与字段读取工具（纯静态）。
## 所有数据错误经 report() 计数并 push_error；DataRegistry 以加载前后的计数差判断 has_errors。
## silent 模式用于校验存档等"可容错"输入：只记录不 push_error。

static var error_count: int = 0
static var messages: Array[String] = []
static var warnings: Array[String] = []   ## 不计入 error_count 的提醒（如已废弃但仍被忽略的字段）
static var silent: bool = false


static func reset() -> void:
	error_count = 0
	messages.clear()
	warnings.clear()


static func report(ctx: String, msg: String) -> void:
	error_count += 1
	var line: String = "[%s] %s" % [ctx, msg]
	messages.append(line)
	if not silent:
		push_error(line)


## 提醒：不影响 has_errors；silent 模式下只记录
static func warn(ctx: String, msg: String) -> void:
	var line: String = "[%s] %s" % [ctx, msg]
	warnings.append(line)
	if not silent:
		push_warning(line)


## 10 §6.3 信标 id：数字字符串原样返回；旧字母 A–H 映射为 "1"–"8" 并提醒 DEPRECATED_FIELD；其他为错误（原样返回）
static func beacon_id(raw: String, ctx: String, field: String) -> String:
	if SimTypes.is_beacon_id(raw):
		return raw
	var mapped: String = SimTypes.legacy_beacon_id(raw)
	if mapped != "":
		warn(ctx, "DEPRECATED_FIELD %s 使用旧字母信标「%s」，已按 %s 读取（信标改为数字编号）" % [field, raw, mapped])
		return mapped
	report(ctx, "%s 必须是正整数信标编号（\"1\"、\"2\"…）" % field)
	return raw


## 必填字段存在性
static func require(d: Dictionary, key: String, ctx: String) -> bool:
	if d.has(key):
		return true
	report(ctx, "缺少必填字段 %s" % key)
	return false


static func req_num(d: Dictionary, key: String, ctx: String) -> float:
	if not require(d, key, ctx):
		return 0.0
	var v: Variant = d[key]
	if v is float or v is int:
		return float(v)
	report(ctx, "字段 %s 必须是数字" % key)
	return 0.0


static func opt_num(d: Dictionary, key: String, default_value: float, ctx: String) -> float:
	if not d.has(key):
		return default_value
	var v: Variant = d[key]
	if v is float or v is int:
		return float(v)
	report(ctx, "字段 %s 必须是数字" % key)
	return default_value


static func req_str(d: Dictionary, key: String, ctx: String) -> String:
	if not require(d, key, ctx):
		return ""
	var v: Variant = d[key]
	if v is String:
		return v as String
	report(ctx, "字段 %s 必须是字符串" % key)
	return ""


static func opt_str(d: Dictionary, key: String, default_value: String, ctx: String) -> String:
	if not d.has(key):
		return default_value
	var v: Variant = d[key]
	if v is String:
		return v as String
	report(ctx, "字段 %s 必须是字符串" % key)
	return default_value


static func opt_bool(d: Dictionary, key: String, default_value: bool, ctx: String) -> bool:
	if not d.has(key):
		return default_value
	var v: Variant = d[key]
	if v is bool:
		return v as bool
	report(ctx, "字段 %s 必须是布尔值" % key)
	return default_value


static func req_dict(d: Dictionary, key: String, ctx: String) -> Dictionary:
	if not require(d, key, ctx):
		return {}
	return as_dict(d[key], "%s.%s" % [ctx, key])


static func opt_dict(d: Dictionary, key: String, ctx: String) -> Dictionary:
	if not d.has(key):
		return {}
	return as_dict(d[key], "%s.%s" % [ctx, key])


static func req_array(d: Dictionary, key: String, ctx: String) -> Array:
	if not require(d, key, ctx):
		return []
	return as_array(d[key], "%s.%s" % [ctx, key])


static func opt_array(d: Dictionary, key: String, ctx: String) -> Array:
	if not d.has(key):
		return []
	return as_array(d[key], "%s.%s" % [ctx, key])


static func as_dict(v: Variant, ctx: String) -> Dictionary:
	if v is Dictionary:
		return v as Dictionary
	report(ctx, "必须是对象")
	return {}


static func as_array(v: Variant, ctx: String) -> Array:
	if v is Array:
		return v as Array
	report(ctx, "必须是数组")
	return []


static func string_array(v: Array, ctx: String) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in v:
		if item is String:
			out.append(item as String)
		else:
			report(ctx, "数组元素必须是字符串: %s" % str(item))
	return out


## [x, y] → Vector2i；非法时报错并返回 (-1,-1)
static func cell(v: Variant, ctx: String) -> Vector2i:
	if v is Array:
		var a: Array = v as Array
		if a.size() == 2 and (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int):
			return Vector2i(int(a[0]), int(a[1]))
	report(ctx, "坐标必须是 [x, y]: %s" % str(v))
	return Vector2i(-1, -1)


static func cells(v: Array, ctx: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Variant in v:
		out.append(cell(item, ctx))
	return out


static func cell_to_array(c: Vector2i) -> Array:
	return [c.x, c.y]


## 枚举解析：parse 返回 -1 视为未知值（D01）
static func enum_value(parsed: int, raw: Variant, what: String, ctx: String) -> int:
	if parsed < 0:
		report(ctx, "未知的%s '%s' (D01)" % [what, str(raw)])
	return parsed
