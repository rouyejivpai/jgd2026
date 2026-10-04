class_name RuleEnums
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 3.2-3.4
## 状态：已实现（M2-1）。
##
## 条件/行为枚举、冲突键表、参数 schema 与 UI 显示名。
## 只实现已确认的 5 条件 + 5 行为（D-13）；INTERACT_DEVICE 只留枚举不实现。

## 条件类型（5 种）
enum ConditionType {
	ENEMY_IN_VISION,     ## 视野内出现敌人（半径圆，半径 <=0 表示取射程）
	SIGNAL_STATE,        ## 信号状态（编号 + 开/关）
	BEACON_DISTANCE,     ## 与某信标距离（编号 + 比较符 + 值）
	SELF_HP,             ## 自身血量百分比
	ENEMY_HAS_STATUS,    ## 敌人持有/不持有某状态
}

## 行为类型（5 种）
enum ActionType {
	SET_FIRE_MODE,         ## 开火 / 停火
	MOVE_ALONG_BEACONS,    ## 沿信标序列移动
	SET_SIGNAL,            ## 把某信号置开/关
	DELAY,                 ## 延迟（阻塞型，不参与冲突键）
	INTERACT_DEVICE,       ## 与装置互动 —— MVP 不实现，UI 不出现
}

## 条件组合逻辑。一条指令只用一种，不做嵌套（需求 5.2）
enum Logic { AND, OR }
