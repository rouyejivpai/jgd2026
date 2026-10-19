extends Node
## 全局信号总线（01_程序架构.md §4.1）。跨场景通信只走这里。

# 关卡/流程
@warning_ignore("unused_signal")
signal level_loaded(level_id: String)
@warning_ignore("unused_signal")
signal battle_phase_changed(phase: int)             ## SimTypes.Phase
@warning_ignore("unused_signal")
signal battle_speed_changed(multiplier: int)        ## 1 或 2
@warning_ignore("unused_signal")
signal battle_ended(result: int, reason_code: int)  ## SimTypes.BattleResult, SimTypes.ReasonCode
@warning_ignore("unused_signal")
signal level_completed(level_id: String, rewards: Dictionary)
# 部署与编辑
@warning_ignore("unused_signal")
signal unit_selected(unit_id: int)                  ## -1 = 取消选择
@warning_ignore("unused_signal")
signal deployment_changed()
@warning_ignore("unused_signal")
signal rules_changed(unit_id: int)
@warning_ignore("unused_signal")
signal validation_failed(problems: Array)           ## Array[Dictionary]{code, unit_id, text}
# 模拟事件转发（BattleController 逐条转发 SimEvent，供 UI 层使用）
@warning_ignore("unused_signal")
signal sim_event(event: Dictionary)
# UI
@warning_ignore("unused_signal")
signal hint_requested(tier: int)
@warning_ignore("unused_signal")
signal beacons_changed(unit_id: int)                ## 07 §3.1：部署阶段某单位的信标增删改
@warning_ignore("unused_signal")
signal relics_changed()                             ## 遗物状态变化（放置 / 撤回地块、使用、冷却结束、重置）
@warning_ignore("unused_signal")
signal relic_armed(relic_id: String)                ## 遗物进入「点选目标 / 落点」状态（"" = 取消）
@warning_ignore("unused_signal")
signal toast(text: String)
@warning_ignore("unused_signal")
signal toast_at(text: String, screen_pos: Vector2)   ## P6 ui_21：锚在某格上方的警示气泡（不可放置）；screen_pos = 格子上沿中点
