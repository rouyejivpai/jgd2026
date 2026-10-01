extends Node
## 全局信号总线。用法：
##   EventBus.enemy_died.emit(pos, 10)
##   EventBus.player_died.connect(_on_player_died)
##
## 为什么需要它：Godot 里跨节点通信最容易写成一大堆 get_node("../../X")，
## 场景一改就崩。信号总线让"谁发"和"谁收"互不认识。

signal score_changed(score: int)
signal combo_changed(combo: int)
signal enemy_died(pos: Vector2, score: int)
signal player_hp_changed(hp: int, max_hp: int)
signal player_died
signal wave_started(index: int)

## 信号本身不用重置，但每局相关的"历史状态"在这里清掉。
func reset() -> void:
	pass
