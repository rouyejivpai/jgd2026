class_name DataLoader
extends RefCounted
## 详细设计：[docs/design/11-数据配置.md](../../docs/design/11-数据配置.md) 4.1-4.5
##
## 把「策划改数值」与「程序改代码」彻底解耦：数值、关卡、评价系数都在
## `res://data/` 的 JSON 里，载入时**严格校验**，出错时报出**哪个文件、哪个字段**，
## 而不是静默用默认值兜底。
##
## 【三条硬性要求】见详设 11 的 1.3
## 1. 脚本里不出现魔法数字 —— 一律从这里取
## 2. 载入失败必须显式报错（给文件路径 + 字段名 + 问题）
## 3. 改数据不用重启引擎 —— 提供 `reload_all()`
##
## 【校验分两层】结构校验在本类（字段/类型/范围）；语义校验在 LevelData /
## BattleMap（跨字段约束）。两者都失败时报错信息能拼起来看。

const UNITS_PATH := "res://data/units.json"
const SCORING_PATH := "res://data/scoring.json"

## 本程序支持的数据文件版本上限（详设 11 的 3.4）
const SUPPORTED_VERSION := 1

## 允许的命中附带状态
const ALLOWED_STATUS := ["", "slowed"]

## 单位数值的必填字段
const REQUIRED_UNIT_FIELDS := ["name", "max_hp", "move_speed", "can_attack"]
## can_attack == true 时额外必填
const REQUIRED_ATTACK_FIELDS := ["range", "damage", "attack_interval"]
## 可选字段及其默认值。
## `op` 用显式比较符而不是「min + exclusive 布尔」——后者极易搞反：
## 我最初写 `exclusive=false` 表示「>= min」，于是 `max_hp: 0` 被放行，
## 而需求是「max_hp 必须 > 0」。显式写 `gt` 就没有歧义了（M3 实测踩到）。
const OPTIONAL_UNIT_FIELDS := {
	"projectile_speed": {"default": 12.0, "type": "number", "op": "gt", "value": 0.0},
	"projectile_radius": {"default": 0.3, "type": "number", "op": "gt", "value": 0.0},
	"vision_radius": {"default": 0.0, "type": "number", "op": "ge", "value": 0.0},
	"on_hit_status": {"default": "", "type": "string"},
	# 【buff 接口预留】(D-28)：只约定"是一个字符串数组"，**不解释含义**。
	# 目的是让后续版本加 buff 时**不用再改数据结构**（改数据就能开工）。
	"buffs": {"default": [], "type": "array"},
}

## 必填数值字段的取值约束：op 同 optional 字段
const REQUIRED_NUMBER_OPS := {
	"max_hp": {"op": "gt", "value": 0.0},
	"move_speed": {"op": "gt", "value": 0.0},
	"range": {"op": "gt", "value": 0.0},
	"damage": {"op": "gt", "value": 0.0},
	"attack_interval": {"op": "gt", "value": 0.0},
}

## 缓存（改数据后用 reload_all() 刷新）
var units: Dictionary = {}        ## type_id → 已校验的数值字典
var scoring: Dictionary = {}      ## complexity / beacon / time
var load_errors: Array[String] = []

var _loaded := false


# ---------------------------------------------------------------------------
# 载入
# ---------------------------------------------------------------------------

## 载入全部数据表。返回错误列表（空表示成功）。
func load_all() -> Array[String]:
	load_errors.clear()
	units.clear()
	scoring.clear()

	load_errors.append_array(_load_units())
	load_errors.append_array(_load_scoring())

	_loaded = load_errors.is_empty()
	return load_errors


## 热重载：重新读盘。**单表失败时保留该表的旧缓存**，不把游戏搞崩（详设 11 的 4.4）。
func reload_all() -> Array[String]:
	var old_units := units.duplicate(true)
	var old_scoring := scoring.duplicate(true)
	var errs := load_all()
	if not errs.is_empty():
		if units.is_empty():
			units = old_units
		if scoring.is_empty():
			scoring = old_scoring
	return errs


func is_loaded() -> bool:
	return _loaded


func _load_units() -> Array[String]:
	var errs: Array[String] = []
	var parsed = read_json(UNITS_PATH, errs)
	if parsed == null or not errs.is_empty():
		return errs

	if not (parsed is Dictionary):
		errs.append("%s: 顶层应为对象" % UNITS_PATH)
		return errs

	var root: Dictionary = parsed
	var unit_map = root.get("units")
	if not (unit_map is Dictionary):
		errs.append("%s: 缺少 units 对象" % UNITS_PATH)
		return errs

	var um: Dictionary = unit_map
	if um.is_empty():
		errs.append("%s: units 不能为空" % UNITS_PATH)

	# 逐条校验；**一次性报出全部错误**（详设 11 的 4.1 第 5 步）
	var validated: Dictionary = {}
	for type_id in um.keys():
		var entry = um[type_id]
		var path := "units.json: units.%s" % str(type_id)
		if not (entry is Dictionary):
			errs.append("%s: 期望对象" % path)
			continue
		var e: Dictionary = entry
		var before := errs.size()
		_validate_unit(str(type_id), e, errs)
		if errs.size() == before:
			validated[str(type_id)] = _fill_defaults(e)

	# 有任何错误就不接受这张表（避免半张表进缓存）
	if not errs.is_empty():
		return errs
	units = validated
	return errs


func _validate_unit(type_id: String, e: Dictionary, errs: Array[String]) -> void:
	# 错误格式统一为 `<文件名>: <字段路径>: <问题>`（详设 11 的 4.2），
	# 字段路径用点号表示层级，便于在编辑器里定位。
	var path := "units.json: units.%s" % type_id

	# 必填
	for f in REQUIRED_UNIT_FIELDS:
		if not e.has(f):
			errs.append("%s: 缺少必填字段 %s" % [path, f])

	# 类型与范围
	if e.has("name") and not (e["name"] is String):
		errs.append("%s.name: 期望 string，实际 %s" % [path, _type_of(e["name"])])
	if e.has("can_attack") and not (e["can_attack"] is bool):
		errs.append("%s.can_attack: 期望 bool，实际 %s" % [path, _type_of(e["can_attack"])])

	# 所有「必填的数值字段」统一走约束表（含攻击单位的 range/damage/attack_interval）
	for f in REQUIRED_NUMBER_OPS.keys():
		if not e.has(f):
			continue
		var spec: Dictionary = REQUIRED_NUMBER_OPS[f]
		_check_number_op(e[f], "%s.%s" % [path, f], str(spec["op"]), float(spec["value"]), errs)

	# 攻击单位额外必填
	#
	# 【必须先确认类型再比较】不能写 `e.get("can_attack") == true`：
	# 当 can_attack 是字符串（作者的笔误，例如 "yes"）时，GDScript 会报
	# 「Invalid operands 'String' and 'bool' in operator '=='」并**中断这一行**，
	# 于是「额外必填字段」的校验被静默跳过 —— 而且这个错误只在手写数据出错时
	# 才出现，极易漏掉（M3 实测：校验自己的错误用例把校验搞崩了）。
	# 先 is bool 判型，再取值比较，才安全。
	if e.has("can_attack") and e["can_attack"] is bool and bool(e["can_attack"]):
		for f in REQUIRED_ATTACK_FIELDS:
			if not e.has(f):
				errs.append("%s: can_attack 为 true 时缺少必填字段 %s" % [path, f])

	# 可选字段
	for f in OPTIONAL_UNIT_FIELDS.keys():
		if not e.has(f):
			continue
		var ospec: Dictionary = OPTIONAL_UNIT_FIELDS[f]
		var otype := str(ospec["type"])
		if otype == "number":
			_check_number_op(e[f], "%s.%s" % [path, f], str(ospec["op"]),
				float(ospec["value"]), errs)
		elif otype == "array":
			# 【buff 接口预留】只校验形状：是数组、且元素都是字符串。
			# **故意不校验取值** —— 现在没有任何 buff 生效，收窄取值只会过早限制后续设计。
			if not (e[f] is Array):
				errs.append("%s.%s: 期望 array，实际 %s" % [path, f, _type_of(e[f])])
			else:
				var arr: Array = e[f]
				for ai in arr.size():
					if not (arr[ai] is String):
						errs.append("%s.%s[%d]: 期望 string，实际 %s"
							% [path, f, ai, _type_of(arr[ai])])
		else:
			if not (e[f] is String):
				errs.append("%s.%s: 期望 string，实际 %s" % [path, f, _type_of(e[f])])

	if e.has("on_hit_status") and not ALLOWED_STATUS.has(str(e["on_hit_status"])):
		errs.append("%s.on_hit_status: 未知状态 \"%s\"（允许 %s）"
			% [path, str(e["on_hit_status"]), str(ALLOWED_STATUS)])


## 数值检查：op 为 gt/ge/lt/le/eq（与 RuleCondition 的 Compare 同一套命名）
func _check_number_op(v, path: String, op: String, bound: float, errs: Array[String]) -> void:
	if not (v is float or v is int):
		errs.append("%s: 期望 number，实际 %s" % [path, _type_of(v)])
		return
	var n := float(v)
	var ok := false
	var want := ""
	match op:
		"gt":
			ok = n > bound
			want = "必须 > %s" % _fmt(bound)
		"ge":
			ok = n >= bound
			want = "必须 >= %s" % _fmt(bound)
		"lt":
			ok = n < bound
			want = "必须 < %s" % _fmt(bound)
		"le":
			ok = n <= bound
			want = "必须 <= %s" % _fmt(bound)
		"eq":
			ok = is_equal_approx(n, bound)
			want = "必须 == %s" % _fmt(bound)
		_:
			ok = true
	if not ok:
		errs.append("%s: %s，实际 %s" % [path, want, _fmt(n)])


## 整数值不显示小数点（错误信息里 "0" 比 "0.0" 好读）
func _fmt(n: float) -> String:
	if is_equal_approx(n, round(n)):
		return str(int(round(n)))
	return str(n)


func _type_of(v) -> String:
	match typeof(v):
		TYPE_STRING: return "string"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_BOOL: return "bool"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "object"
		TYPE_NIL: return "null"
		_: return "unknown"


## 补上可选字段的默认值（缓存里存「完整」的数值字典，调用方不必再判缺失）
func _fill_defaults(e: Dictionary) -> Dictionary:
	var out := e.duplicate(true)
	for f in OPTIONAL_UNIT_FIELDS.keys():
		if not out.has(f):
			out[f] = OPTIONAL_UNIT_FIELDS[f]["default"]
	return out


func _load_scoring() -> Array[String]:
	var errs: Array[String] = []
	var parsed = read_json(SCORING_PATH, errs)
	if parsed == null or not errs.is_empty():
		return errs
	if not (parsed is Dictionary):
		errs.append("%s: 顶层应为对象" % SCORING_PATH)
		return errs

	var d: Dictionary = parsed
	var out: Dictionary = {}
	for key in ["complexity", "beacon", "time"]:
		if not d.has(key):
			errs.append("scoring.json: 缺少字段 %s" % key)
			continue
		_check_number_op(d[key], "scoring.json: %s" % key, "ge", 0.0, errs)
		if d[key] is float or d[key] is int:
			out[key] = float(d[key])

	# 【第 4 项系数是"可选"的】(D-24) 只加进必填列表的话，
	# 任何一份旧的 scoring.json 都会因为"少一个键"整表加载失败 ——
	# 那是把"数据升级"变成"启动即报错"。缺省时由 Scorer 的兜底值接管（10.0）。
	if d.has("units"):
		_check_number_op(d["units"], "scoring.json: units", "ge", 0.0, errs)
		if d["units"] is float or d["units"] is int:
			out["units"] = float(d["units"])

	if not errs.is_empty():
		return errs
	scoring = out
	return errs


# ---------------------------------------------------------------------------
# JSON 读取（含版本检查）
# ---------------------------------------------------------------------------

## 读一个 JSON 文件。失败时把错误塞进 errs 并返回 null。
## 错误格式统一为 `<文件>: <问题>`（详设 11 的 4.2）。
func read_json(path: String, errs: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errs.append("%s: 文件未找到" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errs.append("%s: 无法打开（错误码 %d）" % [path, FileAccess.get_open_error()])
		return null
	var text := f.get_as_text()
	f.close()
	return parse_json_text(text, path, errs)


## 解析一段 JSON 文本（语法 / 顶层类型 / 版本检查）。
##
## 【为什么和读文件分开】这几条规则是纯文本→对象的转换，与文件系统无关。
## 分开之后测试可以直接喂字符串，不依赖能否创建临时文件
## （本工程沙箱里 Godot 写 `user://` 会被拒，错误码 12，M3 实测）。
func parse_json_text(text: String, path: String, errs: Array[String]) -> Variant:
	# 用 JSON 类解析，才能拿到语法错误的行列号
	var parser := JSON.new()
	var err := parser.parse(text)
	if err != OK:
		errs.append("%s: JSON 语法错误（第 %d 行：%s）"
			% [path, parser.get_error_line(), parser.get_error_message()])
		return null

	var data = parser.data
	if not (data is Dictionary):
		errs.append("%s: 顶层应为对象，实际 %s" % [path, _type_of(data)])
		return null

	# 版本检查：过新则报错，而不是尝试解析（详设 11 的 3.4）
	var d: Dictionary = data
	if d.has("version"):
		var v := int(d["version"])
		if v > SUPPORTED_VERSION:
			errs.append("%s: 数据文件版本 %d 过新（本程序支持到 %d）"
				% [path, v, SUPPORTED_VERSION])
			return null
	return data


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

## 单位类型 id 列表（编辑器下拉与关卡校验用）
func unit_type_ids() -> Array:
	var out: Array = []
	for k in units.keys():
		out.append(str(k))
	out.sort()
	return out


func has_unit_type(type_id: String) -> bool:
	return units.has(type_id)


## 基础数值（**已复制**，调用方改它不会污染缓存）
## 单位类型 id → 中文显示名（来自 units.json 的 `name` 字段）。
##
## 【只用于显示】关卡/指令里存的始终是 id。编辑器拿它当下拉框标签，
## 免得玩家在界面上看到 `standard_attack` 这种内部标识。
## 取不到名字时**退回 id 本身** —— 宁可露出 id，也不要显示空白项。
func unit_display_names() -> Dictionary:
	var out: Dictionary = {}
	for tid in unit_type_ids():
		var st: Dictionary = base_unit_stats(str(tid))
		out[str(tid)] = str(st.get("name", str(tid)))
	return out


func base_unit_stats(type_id: String) -> Dictionary:
	if not units.has(type_id):
		return {}
	return (units[type_id] as Dictionary).duplicate(true)


## 评价系数
func scoring_coefficients() -> Dictionary:
	return scoring.duplicate()


# ---------------------------------------------------------------------------
# 关卡级覆盖的合成（详设 11 的 4.3）
# ---------------------------------------------------------------------------

## 把基础数值与关卡覆盖合成出最终数值。
##
## 返回 { stats: Dictionary, errors: Array[String] }
## **覆盖只能覆盖已存在的字段** —— 防止关卡写错字段名后被静默忽略
## （那样会出现「我明明调了射程却没生效」的幽灵 bug）。
## **覆盖不写回缓存**：units.json 的默认值永远不变（FR-UNIT-05）。
func get_unit_stats(type_id: String, overrides: Dictionary = {}) -> Dictionary:
	var errs: Array[String] = []
	if not units.has(type_id):
		errs.append("units.json: 单位类型 \"%s\" 不存在" % type_id)
		return {"stats": {}, "errors": errs}

	var stats: Dictionary = (units[type_id] as Dictionary).duplicate(true)
	for key in overrides.keys():
		var k := str(key)
		if not stats.has(k):
			errs.append("units.json: units.%s 没有字段 \"%s\"，无法覆盖" % [type_id, k])
			continue
		stats[k] = overrides[key]
	return {"stats": stats, "errors": errs}
