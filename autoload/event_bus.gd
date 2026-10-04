extends Node
## 全局信号总线。用法：
##   EventBus.unit_died.emit(entity_id, team, pos)
##   EventBus.unit_died.connect(_on_unit_died)
##
## 为什么需要它：Godot 里跨节点通信最容易写成一大堆 get_node("../../X")，
## 场景一改就崩。信号总线让"谁发"和"谁收"互不认识。
##
## 【分流约定 · 概设 D9】只放「流程与 UI 关心」的事件。
## 高频内部状态（单位坐标、子弹位置、冷却剩余、意图刷新）**不要**上总线，
## 否则指令系统会每帧喷大量信号，调试器没法看、顺序也不可控。

## 分数变化（内核原有）
signal score_changed(score: int)
## 连击变化（内核原有）
signal combo_changed(combo: int)
## 敌人死亡（内核原有，玩法改用 unit_died 后此信号可保留兼容）
signal enemy_died(pos: Vector2, score: int)
## 玩家血量变化（内核原有）
signal player_hp_changed(hp: int, max_hp: int)
## 玩家死亡（内核原有）
signal player_died
## 波次开始（内核原有）
signal wave_started(index: int)

# ---------- 玩法流程（系统 06 关卡发起，系统 10 UI 接收）----------

## 关卡进入推演期。发：LevelSession　收：HUD / 计时显示
signal level_started(level_id: String)
## 关卡结束。verdict 见 LevelSession.Verdict；stats 为结算统计字典
## 发：LevelSession　收：结算界面 / 最佳记录
signal level_finished(verdict: int, stats: Dictionary)
## 会话状态变化（编制期/推演期/结算期）。发：LevelSession　收：工具条状态映射
signal session_state_changed(state: int)

# ---------- 局内状态（发：各系统　收：UI 与规则面板）----------

## 单位死亡。发：UnitActor.die()　收：胜负检查 / UI
signal unit_died(entity_id: int, team: int, pos: Vector2)
## 单位血量变化。发：UnitActor　收：指令面板标题栏
signal unit_hp_changed(entity_id: int, hp: float, max_hp: float)
## 信号表某个信号被提交为新值。发：SignalStore　收：UI 信号指示
signal signal_changed(signal_index: int, value: bool)
## 信标放置/撤回后。发：BeaconLayer　收：指令面板重算无效指令、工具条计数
signal beacon_changed(count: int, quota: int)

func reset() -> void:
	pass
