extends Node
## 数据注册表（01 §4、§5.2）：启动时加载 data/*.json，构建数据类并做 D01–D08 校验。
## has_errors 为真时主菜单显示错误条并禁止进入关卡。

const DATA_ROOT: String = "res://data"

var has_errors: bool = false

var _units: Dictionary = {}       ## id -> UnitDefinition
var _traits: Dictionary = {}      ## id -> TraitDefinition
var _commands: CommandCatalog = CommandCatalog.new()   ## 10 §5.1 data/commands.json（presets.json 第三阶段停止加载）
var _levels: Dictionary = {}      ## id -> LevelDefinition
var _level_order: Array[String] = []
var _strings: Dictionary = {}
var _progression: Dictionary = {}
var _chapters: Array[ChapterDef] = []
const STORY_DIR: String = "res://data/stories"
var story_dir: String = STORY_DIR        ## 剧情目录（测试可指向临时目录以模拟删除剧情文件）
var _biomes: Dictionary = {}
var _teaching: TeachingDef = TeachingDef.new()   ## 第五阶段：data/teaching.json（引导步骤 + 解锁 / 提示覆盖）
var _status_fx: Dictionary = {}                  ## 第五阶段：data/status_fx.json（异常状态粒子参数）
const STATUS_FX_FILE: String = "status_fx.json"
const STATUS_IDS: Array[String] = ["vulnerable", "paralysis", "slow"]
const TEACHING_FILE: String = "teaching.json"


func _ready() -> void:
	load_all()


## 加载并校验全部数据；返回是否无错误。可重复调用（测试用）。
func load_all(root: String = DATA_ROOT) -> bool:
	preview_active = false
	_units.clear()
	_traits.clear()
	_levels.clear()
	_level_order.clear()
	var errors_before: int = DataReader.error_count

	_strings = _load_json(root + "/strings.json")
	_progression = _load_json(root + "/progression.json")
	_biomes = _load_json(root + "/biomes.json")

	var traits_doc: Dictionary = _load_json(root + "/traits.json")
	var trait_dict: Dictionary = DataReader.opt_dict(traits_doc, "traits", "traits.json")
	for tid: String in trait_dict.keys():
		var ctx: String = "traits.json:%s" % tid
		_traits[tid] = TraitDefinition.from_dict(tid, DataReader.as_dict(trait_dict[tid], ctx), ctx)

	var units_doc: Dictionary = _load_json(root + "/units.json")
	var unit_dict: Dictionary = DataReader.opt_dict(units_doc, "units", "units.json")
	for uid: String in unit_dict.keys():
		var ctx: String = "units.json:%s" % uid
		_units[uid] = UnitDefinition.from_dict(uid, DataReader.as_dict(unit_dict[uid], ctx), ctx)
	DataValidator.validate_units(_units, _traits)

	_commands = CommandCatalog.from_dict(_load_json(root + "/commands.json"), "commands.json")

	_status_fx = _load_json(root + "/" + STATUS_FX_FILE) if FileAccess.file_exists(root + "/" + STATUS_FX_FILE) else {}
	_validate_status_fx()
	_teaching = TeachingDef.from_dict(_load_json(root + "/" + TEACHING_FILE) if FileAccess.file_exists(root + "/" + TEACHING_FILE) else {}, TEACHING_FILE)
	var level_files: Array[String] = _list_level_files(root + "/levels")
	var level_ids: Array[String] = []
	for f: String in level_files:
		level_ids.append(f.get_basename())
	var levels: Array[LevelDefinition] = []
	for f: String in level_files:
		var ctx: String = f
		var raw_level: Dictionary = TeachingDef.apply_overrides(_load_json(root + "/levels/" + f), _teaching.levels.get(f.get_basename(), {}) as Dictionary)
		var L: LevelDefinition = LevelDefinition.from_dict(raw_level, ctx)
		if L.id != f.get_basename():
			DataReader.report(ctx, "id '%s' 与文件名不一致" % L.id)
		levels.append(L)
	for L: LevelDefinition in levels:
		DataValidator.validate_level(L, _units, level_ids)
		_levels[L.id] = L
	DataValidator.validate_level_indices(levels)
	levels.sort_custom(func(a: LevelDefinition, b: LevelDefinition) -> bool: return a.index < b.index)
	for L: LevelDefinition in levels:
		_level_order.append(L.id)

	_teaching.validate_against(_levels, TEACHING_FILE)
	_validate_progression(level_ids)
	_validate_command_unlocks(levels)
	_validate_biomes(levels)
	_chapters.clear()
	if DirAccess.dir_exists_absolute(root + "/chapters"):
		for f: String in DirAccess.get_files_at(root + "/chapters"):
			if f.ends_with(".json"):
				var ch: ChapterDef = ChapterDef.from_dict(_load_json(root + "/chapters/" + f), "chapters/" + f)
				ch.validate(level_ids, "chapters/" + f)
				_chapters.append(ch)

	has_errors = DataReader.error_count > errors_before
	return not has_errors


## 第五阶段：教学与解锁配置
func get_teaching() -> TeachingDef:
	return _teaching


## 第五阶段（配置器）：按一份 teaching.json 内容重建涉及的关卡并做与正式加载相同的关卡校验，返回问题列表（不改当前数据）
func validate_teaching_doc(doc: Dictionary, root: String = DATA_ROOT) -> Array[String]:
	var before: int = DataReader.messages.size()
	var was: bool = DataReader.silent
	DataReader.silent = true
	var t: TeachingDef = TeachingDef.from_dict(doc, TEACHING_FILE)
	var built: Dictionary = _levels.duplicate()
	for lid: String in t.levels.keys():
		var path: String = root + "/levels/" + lid + ".json"
		if not FileAccess.file_exists(path):
			continue
		var L: LevelDefinition = LevelDefinition.from_dict(TeachingDef.apply_overrides(_load_json(path), t.levels[lid] as Dictionary), lid + ".json")
		DataValidator.validate_level(L, _units, _level_order)
		built[lid] = L
	t.validate_against(built, TEACHING_FILE)
	DataReader.silent = was
	var out: Array[String] = []
	out.assign(DataReader.messages.slice(before))
	return out


var preview_active: bool = false         ## 配置器「试玩本关」替换了某关的定义；回到配置器时 load_all() 还原


## 第五阶段（配置器）：用未保存的覆盖项临时替换某关定义（校验不通过则不替换），返回问题列表
func preview_level(level_id: String, entry: Dictionary, root: String = DATA_ROOT) -> Array[String]:
	var msgs: Array[String] = validate_teaching_doc({ "levels": { level_id: entry } }, root)
	if not msgs.is_empty():
		return msgs
	var was: bool = DataReader.silent
	DataReader.silent = true
	_levels[level_id] = LevelDefinition.from_dict(TeachingDef.apply_overrides(_load_json(root + "/levels/" + level_id + ".json"), entry), level_id + ".json")
	DataReader.silent = was
	preview_active = true
	return msgs


## 第五阶段：异常状态粒子参数
func get_status_fx() -> Dictionary:
	return _status_fx


func _validate_status_fx() -> void:
	var ctx: String = STATUS_FX_FILE
	for sid: String in DataReader.opt_dict(_status_fx, "statuses", ctx).keys():
		var sctx: String = "%s.statuses.%s" % [ctx, sid]
		if not STATUS_IDS.has(sid):
			DataReader.report(sctx, "未知异常状态（应为 %s 之一）" % str(STATUS_IDS))
		var spec: Dictionary = DataReader.as_dict((_status_fx["statuses"] as Dictionary)[sid], sctx)
		if not StatusParticles.EMISSION.has(str(spec.get("emission", "sphere"))):
			DataReader.report(sctx, "emission 必须是 %s 之一" % str(StatusParticles.EMISSION.keys()))
		for k: String in ["amount", "lifetime"]:
			if DataReader.req_num(spec, k, sctx) <= 0.0:
				DataReader.report(sctx, "%s 必须 > 0" % k)
		for k: String in ["velocity", "scale", "offset", "direction", "gravity"]:
			var a: Variant = spec.get(k, [0.0, 0.0])
			if not (a is Array and (a as Array).size() == 2):
				DataReader.report(sctx, "%s 必须是 [a, b]" % k)


func get_unit(id: String) -> UnitDefinition:
	return _units.get(id, null) as UnitDefinition


func get_trait(id: String) -> TraitDefinition:
	return _traits.get(id, null) as TraitDefinition


func get_level(id: String) -> LevelDefinition:
	return _levels.get(id, null) as LevelDefinition


## 按 index 排序的关卡 id 列表
func get_level_list() -> Array[String]:
	return _level_order.duplicate()


func get_units() -> Dictionary:
	return _units


func get_traits() -> Dictionary:
	return _traits


## 10 §5.1 指令目录
func get_commands() -> CommandCatalog:
	return _commands


## 存档初始化用的解锁（data/progression.json）
func get_initial_unlocks() -> Dictionary:
	return (_progression.get("initial_unlocks", {}) as Dictionary).duplicate(true)


func get_default_settings() -> Dictionary:
	return (_progression.get("default_settings", {}) as Dictionary).duplicate(true)


func get_initial_levels() -> Array[String]:
	return DataReader.string_array(_progression.get("initial_levels", []) as Array, "progression.json")


## 以点分路径取文案，例如 get_string("ui.menu_start")。缺失时返回键本身并告警。
func get_string(key: String) -> String:
	var node: Variant = _strings
	for part: String in key.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			push_warning("[DataRegistry] missing string key: %s" % key)
			return key
	if node is String:
		return node as String
	push_warning("[DataRegistry] string key is not a leaf: %s" % key)
	return key


## 生态可平铺地面贴图路径（data/biomes.json ground_textures，07 §1.3），无则空
func get_ground_textures(biome: String) -> Array[String]:
	return DataReader.string_array((_biomes.get("ground_textures", {}) as Dictionary).get(biome, []) as Array, "biomes.json")


## 生态障碍格地面标识贴片名（ground_marks；无该生态取 default）
func get_ground_marks(biome: String) -> Array[String]:
	var marks: Dictionary = _biomes.get("ground_marks", {}) as Dictionary
	return DataReader.string_array(marks.get(biome, marks.get("default", [])) as Array, "biomes.json")


## 07 §10.1 章节
func get_chapters() -> Array[ChapterDef]:
	return _chapters


## 2026-10-18：带一级地图（world）的章节——游戏主线（腐土平原七区域）；没有则 null
func world_chapter() -> ChapterDef:
	for c: ChapterDef in _chapters:
		if c.has_world():
			return c
	return null


func get_chapter(chapter_id: String) -> ChapterDef:
	for c: ChapterDef in _chapters:
		if c.id == chapter_id:
			return c
	return null


## 关卡所在章节（无则 null）
func chapter_of(level_id: String) -> ChapterDef:
	for c: ChapterDef in _chapters:
		if c.has_level(level_id):
			return c
	return null


## 07 §10.2 剧情：读取 <dir>/<story_id>.json；文件缺失、无法解析或 scenes 为空时返回 {}（调用方据此不触发剧情，不报错）
func load_story(story_id: String, dir: String = "") -> Dictionary:
	var path: String = (dir if dir != "" else story_dir).path_join("%s.json" % story_id)
	if story_id == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var d: Dictionary = parsed as Dictionary
	if not d.get("scenes", null) is Array or (d["scenes"] as Array).is_empty():
		return {}
	return d


## 顶层字符串数组（如 "mechanics"）
func get_string_list(key: String) -> Array[String]:
	return DataReader.string_array(_strings.get(key, []) as Array, "strings.json")


## biomes.json 地面项（07 §1.3）：ground_marks 有 default；每个关卡的 biome 都能取到地面标识
func _validate_biomes(levels: Array[LevelDefinition]) -> void:
	var marks: Dictionary = DataReader.opt_dict(_biomes, "ground_marks", "biomes.json")
	if not marks.has("default"):
		DataReader.report("biomes.json", "ground_marks 缺少 default")
	for key: String in ["ground_textures", "ground_marks"]:
		var d: Dictionary = DataReader.opt_dict(_biomes, key, "biomes.json")
		for k: String in d.keys():
			DataReader.string_array(DataReader.as_array(d[k], "biomes.json.%s.%s" % [key, k]), "biomes.json.%s.%s" % [key, k])
	for L: LevelDefinition in levels:
		if get_ground_marks(L.biome).is_empty():
			DataReader.report("%s.json" % L.id, "biome '%s' 没有地面标识（biomes.json ground_marks）" % L.biome)


func _validate_progression(level_ids: Array[String]) -> void:
	var ctx: String = "progression.json"
	var ini: Dictionary = DataReader.req_dict(_progression, "initial_unlocks", ctx)
	for f: String in DataReader.string_array(DataReader.req_array(ini, "forms", ctx), ctx):
		if not _units.has(f):
			DataReader.report(ctx, "initial_unlocks.forms '%s' 不存在" % f)
	DataReader.string_array(DataReader.req_array(ini, "presets", ctx), ctx)
	for raw: String in DataReader.string_array(DataReader.req_array(ini, "conditions", ctx), ctx):
		DataReader.enum_value(SimTypes.parse_condition(raw), raw, "条件类型", ctx)
	for raw: String in DataReader.string_array(DataReader.req_array(ini, "selectors", ctx), ctx):
		DataReader.enum_value(SimTypes.parse_selector(raw), raw, "选敌", ctx)
	for raw: String in DataReader.string_array(DataReader.req_array(ini, "actions", ctx), ctx):
		DataReader.enum_value(SimTypes.parse_action(raw), raw, "行为类型", ctx)
	for lid: String in DataReader.string_array(DataReader.req_array(_progression, "initial_levels", ctx), ctx):
		if not level_ids.has(lid):
			DataReader.report(ctx, "initial_levels '%s' 不存在" % lid)


## 10 §5.1：commands.json 的 unlock_key 必须可追溯——出现在 progression 初始解锁或任一关卡 rewards.unlock_presets 中
func _validate_command_unlocks(levels: Array[LevelDefinition]) -> void:
	var known: Array = (_progression.get("initial_unlocks", {}) as Dictionary).get("presets", []) as Array
	for L: LevelDefinition in levels:
		known = known + (L.rewards.get("unlock_presets", []) as Array)
	for k: String in _commands.unlock_keys():
		if not known.has(k):
			DataReader.report("commands.json", "unlock_key '%s' 不在 progression 初始解锁或任何关卡 rewards.unlock_presets 中" % k)


func _list_level_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir_path):
		if f.begins_with("level_") and f.ends_with(".json"):
			out.append(f)
	if out.is_empty():
		DataReader.report(dir_path, "没有找到关卡文件")
	out.sort()
	return out


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		DataReader.report(path, "文件不存在")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		DataReader.report(path, "JSON 解析失败")
		return {}
	return parsed as Dictionary
