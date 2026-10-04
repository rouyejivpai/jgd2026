class_name Movement
extends RefCounted
## 详细设计：[docs/design/04-单位与移动.md](../../docs/design/04-单位与移动.md) 4.2
##
## 匀速直线走向目标信标；撞到障碍**完全停住**（不滑墙、不绕行）。
##
## 【为什么不用 move_and_slide】它会自动沿墙滑动，直接违反「撞墙完全停住」
## （需求 12.1 / D2）。必须用 move_and_collide。
##
## 本类做成**纯函数式**的步进器：不持有状态、不读 tick，只根据传入的载体与
## 目标算出这一步该移动多少并执行。这样能在冒烟测试里脱离 UnitActor 单独验收。

## 到达判定阈值（逻辑距离）。
##
## 【必须很小】它是「是否已经站在信标上」的判据，不是「够不够近」的宽容带。
## 早期取 0.15，结果单位一进入 0.15 范围就被判定到达、立刻停住，
## 永远停在离信标 0.1 的地方（M1-4 实测：x 卡在 2.899999）。
## 现在的规则很简单：**一步能跨到就精确吸附**，否则按剩余距离继续匀速走；
## 本阈值只负责识别「已经在信标上」这种等价情形。
const ARRIVE_EPSILON := 0.001


## 计算这一步该怎么走。**只做算术，不碰物理**。
##
## 为什么把物理调用留给调用方：单位的位置精度必须由 UnitActor 的 `position_logic`
## 兜住（以格为单位），不能依赖 `global_position / tile_px` 的往返——
## 那个往返在最后一段（残余位移 1e-3 格 = 0.06 px）会直接归零，
## 单位就卡在离信标一两步的地方不动了（M1-4 实测踩到）。
##
## 返回 {motion_logic, is_final, arrived}：
## · arrived     已经站在信标上（残余 <= ARRIVE_EPSILON）
## · is_final    这一步足以跨过目标，调用方应当**直接落到信标中心**
## · motion_logic 本步的位移（is_final 时为 null，由调用方直接吸附）
static func compute_step(from_logic: Vector2, target_logic: Vector2,
		speed: float, tick_delta: float) -> Dictionary:
	var to_target := target_logic - from_logic
	var dist := to_target.length()
	if dist <= ARRIVE_EPSILON:
		return {"arrived": true, "is_final": true, "motion_logic": Vector2.ZERO}
	var step_len := speed * tick_delta
	# 一步能跨到就交给调用方精确吸附。带一点容差吸收逐 tick 累加位置的浮点误差，
	# 否则「残余 0.100000858 / 步长 0.05」这类值会一直判不到 is_final，
	# 单位停在离信标一步的地方（M1-4 实测踩到）。
	if step_len * 1.02 >= dist:
		return {"arrived": false, "is_final": true, "motion_logic": to_target}
	return {"arrived": false, "is_final": false, "motion_logic": to_target.normalized() * step_len}
