extends Node
## 存档管理（01 §10）：user://save.json 读写（原子写）、版本迁移、关卡配置合法性校验。
## 启动时读取（无存档则按 data/progression.json 新建，不立即写盘）；退出关卡、关卡结束时写入。

const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 5              ## 2：level_configs 改为单位列表（07 §4.2），unlocks.slots 废弃；3：stories_seen（07 §10）；4：信标数字编号（10 §6.3）；5：指令双组口径 + tutorials_seen（第五阶段）
const TMP_SUFFIX: String = ".tmp"
const UNLOCK_LISTS: Array[String] = ["forms", "presets", "conditions", "selectors", "actions"]

var data: Dictionary = {}
var invalid_configs: Dictionary = {}    ## level_id -> Array[Dictionary] 问题列表（只标记，不删除）


func _ready() -> void:
	load_or_create()


## 读取存档；不存在或损坏时新建（仅内存），并校验各关配置
func load_or_create(path: String = SAVE_PATH) -> void:
	data = load_from(path)
	if data.is_empty():
		data = new_save(DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels())
	var settings: Dictionary = data["settings"] as Dictionary
	var defaults: Dictionary = DataRegistry.get_default_settings()
	for key: String in defaults.keys():
		if not settings.has(key):
			settings[key] = defaults[key]
	var levels: Dictionary = {}
	for lid: String in DataRegistry.get_level_list():
		levels[lid] = DataRegistry.get_level(lid)
	validate_level_configs(data, levels, DataRegistry.get_units())


func save(path: String = SAVE_PATH) -> Error:
	var err: Error = save_to(data, path)
	if err != OK:
		push_error("[SaveManager] save failed (%s): %s" % [error_string(err), path])
	return err


## 某关的玩家配置（存档原始结构 { units: [ { uid, form, slot?, pos?, rules, beacons } ], next_uid }），无则 {}
func get_level_config(level_id: String) -> Dictionary:
	var configs: Dictionary = data.get("level_configs", {}) as Dictionary
	return configs.get(level_id, {}) as Dictionary


func set_level_config(level_id: String, raw: Dictionary) -> void:
	var configs: Dictionary = data.get("level_configs", {}) as Dictionary
	configs[level_id] = raw
	data["level_configs"] = configs
	invalid_configs.erase(level_id)   # 玩家已用当前配置覆盖


func get_invalid_problems(level_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(invalid_configs.get(level_id, []) as Array)
	return out


## 第五阶段：某关的强制引导是否已完成（完成或跳过都算）
func is_tutorial_seen(level_id: String) -> bool:
	return bool((data.get("tutorials_seen", {}) as Dictionary).get(level_id, false))


func mark_tutorial_seen(level_id: String) -> void:
	if not data.get("tutorials_seen", null) is Dictionary:
		data["tutorials_seen"] = {}
	(data["tutorials_seen"] as Dictionary)[level_id] = true
	save()


func get_hints_seen(level_id: String) -> int:
	return int((data.get("hints_seen", {}) as Dictionary).get(level_id, 0))


func set_hints_seen(level_id: String, tier: int) -> void:
	var hs: Dictionary = data.get("hints_seen", {}) as Dictionary
	hs[level_id] = tier
	data["hints_seen"] = hs


## 「推荐阵型」是否已在该关使用过（07 §2：记入存档，重置不清除）
func get_recommend_used(level_id: String) -> bool:
	return bool((data.get("recommend_used", {}) as Dictionary).get(level_id, false))


func set_recommend_used(level_id: String, used: bool) -> void:
	var ru: Dictionary = data.get("recommend_used", {}) as Dictionary
	ru[level_id] = used
	data["recommend_used"] = ru


## 章节节点"解锁时播放"的剧情（07 §10.2 nodes[].story_on_unlock）是否已播放过
func is_story_seen(story_id: String) -> bool:
	return bool((data.get("stories_seen", {}) as Dictionary).get(story_id, false))


func mark_story_seen(story_id: String) -> void:
	var seen: Dictionary = data.get("stories_seen", {}) as Dictionary
	seen[story_id] = true
	data["stories_seen"] = seen


## 结算综合分（Scoring）：每关只留最低（最好）的一次；返回本次是否刷新纪录
func record_score(level_id: String, score: Dictionary) -> bool:
	if not data.get("best_scores", null) is Dictionary:
		data["best_scores"] = {}
	var best: Dictionary = data["best_scores"] as Dictionary
	var old: Variant = best.get(level_id, null)
	if old is Dictionary and int((old as Dictionary).get("total", 0)) <= int(score.get("total", 0)):
		return false
	best[level_id] = score.duplicate(true)
	return true


## 该关最好的综合分（没通关过返回 -1）
func best_score(level_id: String) -> int:
	var e: Variant = (data.get("best_scores", {}) as Dictionary).get(level_id, null)
	return int((e as Dictionary).get("total", -1)) if e is Dictionary else -1


## 关卡胜利：累加奖励、记完成、开放下一关并写盘
func complete_level(level_id: String, rewards: Dictionary) -> void:
	apply_rewards(data, level_id, rewards)
	save()


## 是否已有游戏进度（主菜单「继续游戏」可用的依据）：通关记录、各关配置、提示 / 推荐阵型、已播剧情、已看引导任一非空。
## 只改过设置不算进度（设置浮窗关闭时也会写盘）。
func has_progress() -> bool:
	for key: String in ["level_configs", "hints_seen", "recommend_used", "stories_seen", "tutorials_seen"]:
		if not (data.get(key, {}) as Dictionary).is_empty():
			return true
	return not ((data.get("progress", {}) as Dictionary).get("completed", []) as Array).is_empty()


## 新游戏：删除存档文件（含 .tmp），按初始解锁新建存档并立即写盘。设置项（音量、全屏等）保留，不算存档进度。
## 调用方需随后让 GameState 重新指向新字典（GameState.start_new_game 负责）。
func clear_all(path: String = SAVE_PATH) -> Error:
	var settings: Dictionary = (data.get("settings", {}) as Dictionary).duplicate(true)
	for p: String in [path, path + TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			var rm: Error = DirAccess.remove_absolute(p)
			if rm != OK:
				push_error("[SaveManager] remove failed (%s): %s" % [error_string(rm), p])
				return rm
	data = new_save(DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels())
	data["settings"] = settings
	invalid_configs = {}
	return save(path)


## 新存档：写入初始解锁（data/progression.json）
static func new_save(initial_unlocks: Dictionary, initial_levels: Array[String]) -> Dictionary:
	var unlocks: Dictionary = initial_unlocks.duplicate(true)
	for key: String in UNLOCK_LISTS:
		if not unlocks.has(key):
			unlocks[key] = []
	return {
		"version": SAVE_VERSION,
		"progress": { "completed": [], "unlocked_levels": initial_levels.duplicate() },
		"unlocks": unlocks,
		"level_configs": {},
		"hints_seen": {},
		"recommend_used": {},
		"stories_seen": {},
		"settings": {},
		"tutorials_seen": {},
		"best_scores": {},
	}


## 读取；文件不存在或损坏返回空字典（调用方据此新建存档）
func load_from(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		# 替换正式文件的瞬间中断：正式文件已删、.tmp 已完整写好 → 用 .tmp 恢复
		if FileAccess.file_exists(path + TMP_SUFFIX):
			var recovered: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + TMP_SUFFIX))
			if recovered is Dictionary:
				return migrate(recovered as Dictionary)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("[SaveManager] save file unreadable: %s" % path)
		return {}
	return migrate(parsed as Dictionary)


## 原子写：先写 .tmp 再替换正式文件
func save_to(d: Dictionary, path: String = SAVE_PATH) -> Error:
	var err: Error = write_tmp(d, path)
	if err != OK:
		return err
	return commit_tmp(path)


func write_tmp(d: Dictionary, path: String) -> Error:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk: Error = DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var f: FileAccess = FileAccess.open(path + TMP_SUFFIX, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(d, "  ", false))
	f.close()
	return OK


func commit_tmp(path: String) -> Error:
	var tmp: String = path + TMP_SUFFIX
	if not FileAccess.file_exists(tmp):
		return ERR_FILE_NOT_FOUND
	if FileAccess.file_exists(path):
		var rm: Error = DirAccess.remove_absolute(path)
		if rm != OK:
			return rm
	return DirAccess.rename_absolute(tmp, path)


## 版本迁移：补齐缺失的顶层键；v1 → v2（07 §4.2）：各关槽位配置转为单位列表（DeploymentValidator.migrate_v1_config），
## 无法转换的条目原样保留在该关的 legacy_v1 中、该关配置在读档校验时标记 invalid（不删除）；删除 unlocks.slots。
func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var version: int = int(out.get("version", 1))
	if version > SAVE_VERSION:
		push_warning("[SaveManager] save version newer than game: %s" % str(out.get("version")))
	for key: String in ["progress", "unlocks", "level_configs", "hints_seen", "recommend_used", "stories_seen", "settings", "tutorials_seen", "best_scores"]:
		if not out.get(key, null) is Dictionary:
			out[key] = {}
	if version < 2:
		(out["unlocks"] as Dictionary).erase("slots")
		var configs: Dictionary = out["level_configs"] as Dictionary
		for lid: String in configs.keys():
			var level: LevelDefinition = DataRegistry.get_level(lid)
			var raw: Dictionary = configs[lid] as Dictionary if configs[lid] is Dictionary else {}
			if level == null or raw.has("units"):
				continue
			configs[lid] = (DeploymentValidator.migrate_v1_config(level, raw)["config"] as Dictionary)
	if version < 4:
		var configs4: Dictionary = out["level_configs"] as Dictionary
		for lid: String in configs4.keys():
			if configs4[lid] is Dictionary:
				migrate_beacon_ids(configs4[lid] as Dictionary)
	if version < 5:
		var configs5: Dictionary = out["level_configs"] as Dictionary
		for lid: String in configs5.keys():
			if configs5[lid] is Dictionary:
				migrate_rules_v5(configs5[lid] as Dictionary)
		migrate_unlocks_v5(out["unlocks"] as Dictionary, DataRegistry.get_initial_unlocks())
	out["version"] = SAVE_VERSION
	return out


## 存档 v4 → v5（第五阶段）：各关玩家指令（旧单列表口径）经 RuleDef.migrate_legacy() 折算为双组口径。
## 某个单位的指令有无法解析的条目时，该单位原样保留（读档校验照常报 RULE_INVALID）。
static func migrate_rules_v5(config: Dictionary) -> void:
	var units: Array = config.get("units", []) as Array if config.get("units", null) is Array else []
	var was_silent: bool = DataReader.silent
	DataReader.silent = true
	for u: Variant in units:
		if not u is Dictionary or not (u as Dictionary).get("rules", null) is Array:
			continue
		var ud: Dictionary = u as Dictionary
		var before: int = DataReader.error_count
		var rules: Array[RuleDef] = []
		for r: Variant in ud["rules"] as Array:
			rules.append(RuleDef.from_dict(r as Dictionary if r is Dictionary else {}, "save.v5"))
		if DataReader.error_count == before:
			ud["rules"] = RuleDef.to_array(RuleDef.migrate_legacy(rules))
	DataReader.silent = was_silent


## 第五阶段解锁折算：已解锁「追击并攻击」→ 同时解锁「追击」「攻击」及追击的解锁键；并补上新版初始解锁中新增的条目（新选敌等）
static func migrate_unlocks_v5(unlocks: Dictionary, initial: Dictionary) -> void:
	for kind: String in initial.keys():
		var have: Array = unlocks.get(kind, []) as Array if unlocks.get(kind, null) is Array else []
		for v: Variant in initial[kind] as Array:
			if not have.has(v):
				have.append(v)
		unlocks[kind] = have
	var actions: Array = unlocks.get("actions", []) as Array
	if actions.has("chase_attack"):
		for a: String in ["chase", "attack"]:
			if not actions.has(a):
				actions.append(a)
	var presets: Array = unlocks.get("presets", []) as Array if unlocks.get("presets", null) is Array else []
	if presets.has("preset.chase_attack_nearest_visible") and not presets.has("preset.chase_nearest_visible"):
		presets.append("preset.chase_nearest_visible")
	unlocks["presets"] = presets


## 存档 v3 → v4（10 §6.3）：某关配置中的旧字母信标 id（A–H）就地改为数字（"1"–"8"）——信标列表的 id、
## at_beacon.beacon、follow_beacons.from。其他内容不动；无法识别的值原样保留（读档校验时报问题）。
static func migrate_beacon_ids(config: Dictionary) -> void:
	var units: Array = config.get("units", []) as Array if config.get("units", null) is Array else []
	for u: Variant in units:
		if not u is Dictionary:
			continue
		var ud: Dictionary = u as Dictionary
		for b: Variant in ud.get("beacons", []) as Array if ud.get("beacons", null) is Array else []:
			if b is Dictionary:
				_migrate_id(b as Dictionary, "id")
		for r: Variant in ud.get("rules", []) as Array if ud.get("rules", null) is Array else []:
			if not r is Dictionary:
				continue
			var rd: Dictionary = r as Dictionary
			for c: Variant in rd.get("conditions", []) as Array if rd.get("conditions", null) is Array else []:
				if c is Dictionary and str((c as Dictionary).get("type", "")) == "at_beacon":
					_migrate_id(c as Dictionary, "beacon")
			if rd.get("action", null) is Dictionary and str((rd["action"] as Dictionary).get("type", "")) == "follow_beacons":
				_migrate_id(rd["action"] as Dictionary, "from")


static func _migrate_id(d: Dictionary, key: String) -> void:
	var mapped: String = SimTypes.legacy_beacon_id(str(d.get(key, "")))
	if mapped != "":
		d[key] = mapped


## 关卡奖励累加到存档（去重）：解锁项、完成记录、下一关
static func apply_rewards(save_data: Dictionary, level_id: String, rewards: Dictionary) -> void:
	var unlocks: Dictionary = save_data.get("unlocks", {}) as Dictionary
	var pairs: Dictionary = {
		"forms": "unlock_forms", "presets": "unlock_presets", "conditions": "unlock_conditions",
		"selectors": "unlock_selectors", "actions": "unlock_actions",
	}
	for key: String in pairs.keys():
		var list: Array = unlocks.get(key, []) as Array
		for item: Variant in rewards.get(str(pairs[key]), []) as Array:
			if not list.has(item):
				list.append(item)
		unlocks[key] = list
	save_data["unlocks"] = unlocks
	var progress: Dictionary = save_data.get("progress", {}) as Dictionary
	var completed: Array = progress.get("completed", []) as Array
	if not completed.has(level_id):
		completed.append(level_id)
	progress["completed"] = completed
	var unlocked: Array = progress.get("unlocked_levels", []) as Array
	var next_level: String = str(rewards.get("unlock_level", ""))
	if next_level != "" and not unlocked.has(next_level):
		unlocked.append(next_level)
	progress["unlocked_levels"] = unlocked
	save_data["progress"] = progress


## 校验存档中所有关卡配置；有问题的关卡记入 invalid_configs，条目保留不删（策划已定）
func validate_level_configs(save_data: Dictionary, levels: Dictionary, unit_defs: Dictionary) -> Dictionary:
	invalid_configs = {}
	var unlocks: Dictionary = save_data.get("unlocks", {}) as Dictionary
	var configs: Dictionary = save_data.get("level_configs", {}) as Dictionary
	for lid: String in configs.keys():
		var level: LevelDefinition = levels.get(lid, null) as LevelDefinition
		if level == null:
			continue
		var raw: Dictionary = configs[lid] as Dictionary if configs[lid] is Dictionary else {}
		var problems: Array[Dictionary] = DeploymentValidator.check_saved_config(level, raw, unlocks, unit_defs, DataRegistry.get_commands())
		if not problems.is_empty():
			invalid_configs[lid] = problems
	return invalid_configs
