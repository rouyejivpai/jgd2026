extends Node2D
## 30 关战役的战斗提示层（盖在单位之上，随地图平移缩放）：
## - 异常状态：单位头顶的小圆牌（易 = 易伤、麻 = 麻痹、缓 = 减速），只读模拟状态，不改任何数据。
## - Boss 信号：亮起时在 Boss 周围画出本次招式的作用范围（内圈 / 外圈）和一行说明，颜色 = 信号色。
## - Boss 换阶段暂停：高亮增援区。
## 素材到位前用纯绘制占位（与 GroundLayer 的障碍占位同一思路）。
## 第五阶段：异常状态另加粒子反馈（StatusParticles，参数 data/status_fx.json）——每个"单位 × 状态"一个发射器，跟随单位，
## 状态结束 / 单位死亡后停止发射、粒子放完再回收；UI 动效总闸关闭时不发射。

const STATUS_STYLE: Dictionary = {
	"vulnerable": { "glyph": "易", "color": Color(1.0, 0.47, 0.41) },
	"paralysis": { "glyph": "麻", "color": Color(1.0, 0.86, 0.35) },
	"slow": { "glyph": "缓", "color": Color(0.47, 0.67, 1.0) },
}
const SIGNAL_COLOR: Dictionary = { "red": Color(1.0, 0.35, 0.3), "yellow": Color(1.0, 0.85, 0.3), "blue": Color(0.45, 0.65, 1.0) }
const PIP_RADIUS: float = 20.0

const REINFORCE_COLOR: Color = Color(0.5, 1.2, 0.9, 1.0)   ## 增援区青绿（略提亮抵消 CanvasModulate）
## 2026-10-20 战斗音效（只读模拟）：状态出现 → status_<id>，提前结束 → status_expire（站在净化台上 = shrine_cleanse）；
## Boss 信号亮起 → boss_warn（音高按颜色）、放招 → core_pulse
const STATUS_SFX_MSEC: int = 150          ## 同一状态音全局限频（光环同时罩住多名单位时只响一声）
const STATUS_REAPPLY_MSEC: int = 800      ## 同一单位同一状态结束后这么久内再出现不响（光环边缘进进出出）
const SIGNAL_PITCH: Dictionary = { "red": 0.9, "yellow": 1.0, "blue": 1.15 }
var controller: BattleController = null
var grid_height: int = 0
var _t: float = 0.0
var _emitters: Dictionary = {}           ## "单位 id:状态" -> CPUParticles2D
var _sfx_world: SimWorld = null          ## 音效跟踪所属的世界（重建后静默重置）
var _sfx_live: Dictionary = {}           ## "单位 id:状态" -> true（上一帧存在）
var _sfx_gone: Dictionary = {}           ## "单位 id:状态" -> 结束时刻 msec
var _last_signal: String = ""
var _signal_armed: bool = false          ## 信号亮起后尚未放招（boss_state.fire_at ≥ 0）


func _process(delta: float) -> void:
	_t += delta
	sync_particles()
	_sync_sfx()
	queue_redraw()


func _sync_sfx() -> void:
	var w: SimWorld = controller.world if controller != null else null
	var quiet: bool = controller == null or controller.phase == SimTypes.Phase.DEPLOY     # 部署 / 刚重建：只记录现状，不出声
	if w != _sfx_world:
		quiet = true
		_sfx_world = w
		_sfx_live.clear()
		_sfx_gone.clear()
		_last_signal = w.boss_signal if w != null else ""
		_signal_armed = false
	if w == null:
		return
	var now: int = Time.get_ticks_msec()
	var live: Dictionary = {}
	for u: SimUnit in w.units:
		if not u.alive:
			continue
		for s: Variant in u.statuses.keys():
			var sid: String = str(s)
			if not u.has_status(sid) or not STATUS_STYLE.has(sid):
				continue
			var key: String = "%d:%s" % [u.id, sid]
			live[key] = true
			if not quiet and not _sfx_live.has(key) and now - int(_sfx_gone.get(key, -STATUS_REAPPLY_MSEC)) >= STATUS_REAPPLY_MSEC:
				AudioManager.play_sfx("status_" + sid, "SFX", -2.0, 1.0, 0.04, STATUS_SFX_MSEC)
	for key: String in _sfx_live.keys():
		if live.has(key):
			continue
		_sfx_gone[key] = now
		var u: SimUnit = w.get_unit(int(key.get_slice(":", 0)))
		if quiet or u == null or not u.alive:
			continue
		if u.faction == SimTypes.Faction.ALLY and w.tile_at(u.cell()) == "shrine":
			AudioManager.play_sfx("shrine_cleanse", "SFX", 0.0, 1.0, 0.0, 300)
		else:
			AudioManager.play_sfx("status_expire", "SFX", -9.0, 1.0, 0.05, 200)
	_sfx_live = live
	var sig: String = w.boss_signal
	var firing: bool = float(w.boss_state.get("fire_at", -1.0)) >= 0.0
	if sig != _last_signal and sig != "" and not quiet:
		AudioManager.play_sfx("boss_warn", "SFX", 0.0, float(SIGNAL_PITCH.get(sig, 1.0)))
		_signal_armed = firing
	elif sig != "" and _signal_armed and not firing:
		AudioManager.play_sfx("core_pulse", "SFX", -3.0, float(SIGNAL_PITCH.get(sig, 1.0)))   # 放招（伤害 / 状态 / 召唤另有各自的音）
		_signal_armed = false
	if sig == "":
		_signal_armed = false
	_last_signal = sig


## 让发射器与当前异常状态一致：新状态建发射器并跟随单位；已结束的停止发射并在粒子放完后释放
func sync_particles() -> void:
	var fx: Dictionary = DataRegistry.get_status_fx()
	var specs: Dictionary = fx.get("statuses", {}) as Dictionary
	var live: Dictionary = {}
	if UiKit.motion_enabled and bool(fx.get("enabled", true)) and controller != null and controller.world != null:
		for u: SimUnit in controller.world.units:
			if not u.alive:
				continue
			for s: Variant in u.statuses.keys():
				var sid: String = str(s)
				if not u.has_status(sid) or not specs.has(sid):
					continue
				var key: String = "%d:%s" % [u.id, sid]
				live[key] = true
				var e: CPUParticles2D = _emitters.get(key, null) as CPUParticles2D
				if e == null:
					e = StatusParticles.make(specs[sid] as Dictionary)
					e.name = "StatusFx_%d_%s" % [u.id, sid]
					add_child(e)
					_emitters[key] = e
				e.position = SimTypes.sim_to_screen(u.pos, grid_height) + StatusParticles.offset_px(specs[sid] as Dictionary)
				e.emitting = true
	for key: String in _emitters.keys():
		if live.has(key):
			continue
		var old: CPUParticles2D = _emitters[key] as CPUParticles2D
		_emitters.erase(key)
		old.emitting = false
		get_tree().create_timer(old.lifetime + 0.1).timeout.connect(old.queue_free)


## 当前正在发射的发射器键（测试用）
func active_fx() -> Array[String]:
	var out: Array[String] = []
	out.assign(_emitters.keys())
	return out


func _draw() -> void:
	if controller == null or controller.world == null:
		return
	var world: SimWorld = controller.world
	var font: Font = ThemeDB.fallback_font
	var tile: float = float(SimTypes.TILE_SIZE)
	if controller.boss_pending:
		# 增援区（Boss 换阶段的出生点）：与部署区同为特殊地块——发光边线（光晕呼吸）+ 每格半透明出生点标志，不填色
		var rcells: Array[Vector2i] = controller.reinforce_cells()
		GlowLines.draw_cells(self, GlowLines.cell_set(rcells), grid_height, REINFORCE_COLOR, 1.6 + 0.8 * sin(_t * 4.0), true, 0.3, GlowLines.CORE_WIDTH * 1.4)
		var mark: Texture2D = GlowLines.mark_texture("spawn")
		if mark != null:
			for c: Vector2i in rcells:
				GlowLines.draw_mark(self, mark, c, grid_height, REINFORCE_COLOR)
		var first: Vector2i = controller.reinforce_zone.position
		var at: Vector2 = SimTypes.sim_to_screen(Vector2(first.x, controller.reinforce_zone.end.y), grid_height)
		var zl: String = "增援区 · 剩余 %d 点灵魂" % (controller.reinforce_budget - controller.reinforce_cost())
		var zf: int = int(tile * 0.5)
		var zs: Vector2 = font.get_string_size(zl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, zf)
		var zp: Vector2 = at + Vector2(0.0, -14.0)
		draw_rect(Rect2(zp + Vector2(-10.0, -zs.y * 0.85), zs + Vector2(20.0, zs.y * 0.3)), Color(0.04, 0.08, 0.06, 0.85))
		draw_string(font, zp, zl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, zf, Color(0.59, 0.96, 0.76))
	for u: SimUnit in world.units:
		if not u.alive or u.statuses.is_empty():
			continue
		var head: Vector2 = SimTypes.sim_to_screen(u.pos, grid_height) + Vector2(0.0, -tile * 1.55)
		var keys: Array = u.statuses.keys()
		for i: int in keys.size():
			var st: Dictionary = STATUS_STYLE.get(str(keys[i]), {}) as Dictionary
			if st.is_empty():
				continue
			var p: Vector2 = head + Vector2((float(i) - float(keys.size() - 1) * 0.5) * PIP_RADIUS * 2.3, 0.0)
			draw_circle(p, PIP_RADIUS, Color(0.08, 0.05, 0.07, 0.85))
			draw_arc(p, PIP_RADIUS, 0.0, TAU, 24, st["color"] as Color, 2.0)
			draw_string(font, p + Vector2(-13.0, 9.0), str(st["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, st["color"] as Color)
	_draw_boss_signal(world, font, tile)


func _draw_boss_signal(world: SimWorld, font: Font, tile: float) -> void:
	if world.boss.is_empty() or world.boss_signal == "":
		return
	var b: SimUnit = world.get_spawn(str(world.boss.get("unit", "")))
	if b == null or not b.alive:
		return
	var phases: Array = world.boss.get("phases", []) as Array
	var ph: Dictionary = phases[clampi(world.phase - 1, 0, phases.size() - 1)] as Dictionary
	var e: Dictionary = (ph.get("effects", {}) as Dictionary).get(world.boss_signal, {}) as Dictionary
	var col: Color = SIGNAL_COLOR.get(world.boss_signal, Color.WHITE) as Color
	var center: Vector2 = SimTypes.sim_to_screen(b.pos, grid_height)
	var pulse: float = 0.5 + 0.5 * sin(_t * 8.0)
	if e.has("radius"):
		var r: float = float(e["radius"]) * tile
		if str(e.get("side", "inside")) == "inside":
			draw_circle(center, r, Color(col, 0.12 + 0.1 * pulse))
		else:
			draw_circle(center, r, Color(0.0, 0.0, 0.0, 0.0))
			draw_arc(center, r + tile * 0.6, 0.0, TAU, 64, Color(col, 0.18 + 0.12 * pulse), tile * 1.2)
		draw_arc(center, r, 0.0, TAU, 64, Color(col, 0.9), 3.0)
	var label: String = "%s信号：%s" % [DataRegistry.get_string("names.signals." + world.boss_signal), str(e.get("cn", ""))]
	var fs: int = 34
	var sz: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var at: Vector2 = center + Vector2(-sz.x * 0.5, -tile * 2.2)
	draw_rect(Rect2(at + Vector2(-12.0, -sz.y * 0.85), sz + Vector2(24.0, sz.y * 0.35)), Color(0.06, 0.03, 0.05, 0.82))
	draw_rect(Rect2(at + Vector2(-12.0, -sz.y * 0.85), sz + Vector2(24.0, sz.y * 0.35)), col, false, 2.0)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
