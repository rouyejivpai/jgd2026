class_name BossSystem
extends RefCounted
## 多阶段 Boss（2026-10-12 评审：两阶段；换阶段暂停 → 展示新指令 → 玩家重新编程 → 增援 → 恢复）。
## 关卡 boss 配置（见《Boss 规则页》）：
## {
##   "unit": "WITCH",                       Boss 的 initial_units id
##   "phases": [
##     { "cycle": 8, "warn": 2,              每 cycle 秒亮一次信号，亮起 warn 秒后放招
##       "signals": ["red", "yellow", ...],  按顺序循环（评审未定随机 / 固定，本版用固定序列，可预告）
##       "effects": { "red": {...}, "yellow": {...}, "blue": {...} },
##       "next_at_hp_ratio": 0.5 },          血量比例 ≤ 此值 → 进入下一阶段（暂停等待重编程）
##     { ... 第二阶段 ... }
##   ]
## }
## 招式效果（side = inside：radius 内；outside：radius 外）：
##   area_damage  {side, radius, damage}           范围伤害
##   area_status  {side, radius, status, duration} 范围施加异常
##   summon       {unit, count, rules}             在 Boss 身边召出敌人

const SIGNAL_HOLD: float = 0.5   ## 放招后信号再保留的秒数（便于表现层播放）


static func tick(world: SimWorld) -> void:
	if world.boss.is_empty():
		return
	var b: SimUnit = world.get_spawn(str(world.boss.get("unit", "")))
	if b == null or not b.alive:
		world.boss_signal = ""
		return
	var phases: Array = world.boss.get("phases", []) as Array
	if phases.is_empty():
		return
	var ph: Dictionary = phases[clampi(world.phase - 1, 0, phases.size() - 1)] as Dictionary
	# 阶段切换：暂停，等控制器处理（重新编程 / 增援），由控制器把 phase + 1 并清 phase_pending
	if world.phase < phases.size() and b.hp / b.max_hp <= float(ph.get("next_at_hp_ratio", 0.0)) + SimTypes.TIME_EPS:
		world.phase_pending = true
		world.boss_signal = ""
		world.boss_state = {}
		world.emit_event(SimTypes.EventType.OBJECTIVE_PROGRESS, { "boss_phase_change": world.phase + 1 })
		return
	var st: Dictionary = world.boss_state
	if not st.has("next_cycle"):
		st["next_cycle"] = world.clock.time + float(ph.get("first", ph.get("cycle", 8.0)))
		st["index"] = 0
		st["fire_at"] = -1.0
		st["clear_at"] = -1.0
	var now: float = world.clock.time
	if float(st["fire_at"]) < 0.0 and now >= float(st["next_cycle"]) - SimTypes.TIME_EPS:
		var sigs: Array = ph.get("signals", []) as Array
		if sigs.is_empty():
			return
		world.boss_signal = str(sigs[int(st["index"]) % sigs.size()])
		st["index"] = int(st["index"]) + 1
		st["fire_at"] = now + float(ph.get("warn", 2.0))
		st["next_cycle"] = now + float(ph.get("cycle", 8.0))
	if float(st["fire_at"]) >= 0.0 and now >= float(st["fire_at"]) - SimTypes.TIME_EPS:
		_fire(world, b, (ph.get("effects", {}) as Dictionary).get(world.boss_signal, {}) as Dictionary)
		st["fire_at"] = -1.0
		st["clear_at"] = now + SIGNAL_HOLD
	if float(st["clear_at"]) >= 0.0 and now >= float(st["clear_at"]) - SimTypes.TIME_EPS:
		world.boss_signal = ""
		st["clear_at"] = -1.0


static func _fire(world: SimWorld, b: SimUnit, e: Dictionary) -> void:
	match str(e.get("type", "")):
		"area_damage", "area_status":
			var r: float = float(e.get("radius", 5.0))
			var inside: bool = str(e.get("side", "inside")) == "inside"
			for u: SimUnit in world.units:
				if not u.alive or u.faction != SimTypes.Faction.ALLY or u.kind != SimTypes.UnitKind.UNIT:
					continue
				var d: float = b.pos.distance_to(u.pos)
				if (inside and d > r + SimTypes.DIST_EPS) or (not inside and d <= r + SimTypes.DIST_EPS):
					continue
				if str(e["type"]) == "area_damage":
					world.queue_damage(b.id, u.id, float(e.get("damage", 40.0)))
				else:
					u.add_status(str(e.get("status", "paralysis")), float(e.get("duration", 3.0)))
		"summon":
			var udef: UnitDefinition = DataRegistry.get_unit(str(e.get("unit", "husk")))
			if udef == null:
				return
			var rules: Array[RuleDef] = []
			for rd: Variant in e.get("rules", []) as Array:
				rules.append(RuleDef.from_dict(rd as Dictionary, "boss.summon"))
			var offsets: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(-2, 0), Vector2i(0, 2)]
			for i: int in int(e.get("count", 2)):
				var c: Vector2i = b.cell() + offsets[i % offsets.size()]
				if not world.grid.is_walkable(c):
					c = b.cell()
				var u: SimUnit = SimUnit.create(udef, SimTypes.Faction.ENEMY, SimTypes.cell_center(c), RuleDef.clone_array(rules) if not rules.is_empty() else RuleDef.clone_array(udef.default_rules))
				u.spawn_id = "ADD_%d" % world.next_blast_id
				world.next_blast_id += 1
				u.counts_for_annihilate = false
				world.add_unit(u)


## 换阶段暂停结束（控制器在玩家重新编程 / 增援后调用）：应用下一阶段的 Boss 数值覆盖，进入下一阶段并恢复推进
static func begin_next_phase(world: SimWorld) -> void:
	var phases: Array = world.boss.get("phases", []) as Array
	var b: SimUnit = world.get_spawn(str(world.boss.get("unit", "")))
	if world.phase < phases.size() and b != null:
		var nxt: Dictionary = phases[world.phase] as Dictionary
		var ov: Dictionary = nxt.get("boss_overrides", {}) as Dictionary
		for k: String in ov.keys():
			match k:
				"attack":
					b.attack = float(ov[k])
				"attack_speed":
					b.attack_speed = float(ov[k])
				"move_speed":
					b.move_speed = float(ov[k])
				"range":
					b.attack_range = float(ov[k])
				"vision":
					b.vision = float(ov[k])
	world.phase += 1
	world.phase_pending = false
	world.boss_state = {}
	world.boss_signal = ""


## 下一阶段的增援配置 { budget, max_units, zone: [x0, y0, x1, y1] }；没有为 {}
static func next_reinforce(world: SimWorld) -> Dictionary:
	var phases: Array = world.boss.get("phases", []) as Array
	if world.phase >= phases.size():
		return {}
	return (phases[world.phase] as Dictionary).get("reinforce", {}) as Dictionary
