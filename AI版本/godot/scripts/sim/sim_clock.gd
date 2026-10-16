class_name SimClock
extends RefCounted
## 模拟时钟（01 §6.1）：只在 SimWorld.step() 内推进，与真实时间、帧率无关。

var steps: int = 0
var time: float = 0.0


func advance() -> void:
	steps += 1
	time = float(steps) * SimTypes.SIM_DT   # 以步数换算，避免浮点累加漂移
