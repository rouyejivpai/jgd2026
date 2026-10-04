class_name Hurtbox
extends Area2D
## 单位的受击区域。详细设计：[docs/design/05-战斗.md](../../docs/design/05-战斗.md) 第 3 章
##
## 【为什么要给它单独一个脚本】本来是 UnitActor 在 add_child 之后去设碰撞层，
## 但如果单位**已经在场景树里**，add_child 出去的 Area2D 会立刻进树，
## Godot 随后初始化它时**把碰撞层清回 0** —— 那次初始化发生在 UnitActor
## 设层之后，于是层被清掉、子弹永远打不中（M2 实测：setup 后立刻查是 32，
## 开火时已是 0，排查了两轮）。
##
## 解法：让 Hurtbox **自己在 _ready 里设层**。_ready 一定在引擎的 Area2D
## 初始化之后跑，所以这次赋值不会被覆盖，也不再依赖任何时序运气。
##
## 层号按阵营分：我方 5、敌方 6（概设 D8）。子弹掩码只含**对侧**那层，
## 因此「子弹不伤害友军」是掩码免费保证的，代码里不需要阵营判断。

const LAYER_HURTBOX_ALLY := 5
const LAYER_HURTBOX_ENEMY := 6

const TEAM_ALLY := 0

var team := TEAM_ALLY


func _ready() -> void:
	apply_team_layer()


## 由 UnitActor 在 setup 时调用；team 定了之后再套一次层
func configure(p_team: int) -> void:
	team = p_team
	apply_team_layer()


func apply_team_layer() -> void:
	collision_layer = 0
	collision_mask = 0                    # 受击区不主动探测
	if team == TEAM_ALLY:
		set_collision_layer_value(LAYER_HURTBOX_ALLY, true)
	else:
		set_collision_layer_value(LAYER_HURTBOX_ENEMY, true)
	monitorable = true                    # 要被子弹的 Area2D 探测到
	monitoring = false
	if trace:
		print("      [hb] apply_team_layer: team=%d layer=%d in_tree=%s" % [
			team, int(collision_layer), str(is_inside_tree())])


var trace := false


## 供外部排查用：谁把层清零了
func note_layer(tag: String) -> void:
	print("      [hb] %s: layer=%d team=%d" % [tag, int(collision_layer), team])
