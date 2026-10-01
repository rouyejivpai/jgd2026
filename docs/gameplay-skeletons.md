# 玩法骨架备选（暂不载入，设计玩法时再取用）

这份文档是 2026-xx 那次准备工作里**刻意没有实现**的部分。
你当时的原话是「这些暂时留存在文档里，等我们设计玩法的时候再载入」。

工程里现在只有 `scenes/game/game_scene.tscn` 一个占位场景：一个会动的方块 + HUD + 暂停菜单 + Phantom Camera。
等玩法定了，从下面挑需要的骨架，我再补实现。

---

## 1. 打磨过的移动手感

**用途**：任何有角色移动的玩法都用得上。手感差距的 80% 来自这四个东西，不是来自速度数值。

| 技巧 | 作用 |
|---|---|
| 加速度 / 减速度 | 直接给速度会"像湿肥皂"，分开加/减速立刻有重量感 |
| 土狼时间 (coyote time) | 离开平台后仍有 ~0.1s 可以起跳，玩家不会觉得"我明明按了" |
| 跳跃缓冲 (jump buffer) | 落地前 ~0.1s 按跳跃，落地瞬间自动起跳 |
| 可变跳高 | 松开跳跃键立刻削减上升速度，轻点小跳、长按大跳 |

```gdscript
# 骨架示意
const SPEED := 320.0
const ACCEL := 1800.0
const DECEL := 2400.0
const JUMP_VELOCITY := -520.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const JUMP_CUT := 0.45   # 松手时把上升速度乘这个数

var _coyote := 0.0
var _buffer := 0.0
```

**依赖**：无。

---

## 2. 打击感工具箱

**用途**：让"打到了"这件事有反馈。`Game.hitstop()` 已经有了，剩下四件套。

| 手段 | 说明 |
|---|---|
| 屏幕震动 | Phantom Camera 的 `noise` 资源直接支持；或自研版做位置随机偏移 |
| 受击闪白 | `modulate` 白色 → tween 回原色，几行代码 |
| 击退 | 给目标一个反向速度，用 tween 或物理速度衰减 |
| 命中停顿 + 粒子 + 音高抖动 | `Game.hitstop()` + `GPUParticles2D` + `Audio.play()` 自带 pitch_jitter |

```gdscript
# 受击闪白骨架
func flash(target: CanvasItem) -> void:
	var t := target.create_tween()
	t.tween_property(target, "modulate", Color(8, 8, 8), 0.04)
	t.tween_property(target, "modulate", Color.WHITE, 0.12)
```

**依赖**：无（震动可选 Phantom Camera 的 `PhantomCameraNoise2D`）。

---

## 3. 自研相机跟随（不装 Phantom Camera 时的退路）

**用途**：如果 Phantom Camera 哪天不兼容了，或者你要的跟随逻辑很特殊。

```gdscript
extends Camera2D
@export var target: Node2D
@export var lookahead := 90.0   # 朝移动方向前瞻
@export var smooth := 8.0
var _offset := Vector2.ZERO

func _physics_process(delta: float) -> void:
	if target == null: return
	var vel := Vector2.ZERO
	if target is CharacterBody2D: vel = target.velocity
	var want := target.global_position + vel.normalized() * lookahead
	global_position = global_position.lerp(want, clampf(smooth * delta, 0.0, 1.0))
```

边界限制用 Camera2D 自带的 `limit_left/top/right/bottom` 即可。

**依赖**：无。**现状**：工程里已经在用 Phantom Camera，这个只是备份方案。

---

## 4. 角色 / 流程状态机

**用途**：角色状态（Idle/Run/Jump/Fall/Hurt）、游戏流程（主菜单→教学→战斗→结算）、Boss 阶段。

**两个选择**：

- **手写最小版**（~60 行，jam 里通常够了）：状态是一个 `enum` + `match`，
  或者每个状态一个小类 + `enter()/exit()/update()`。
- **Godot State Charts**（工程里已装，0.22.5）：可视化编辑、支持嵌套状态/并行状态/守卫条件，
  调试器能实时看到当前状态。流程复杂时优势明显。

```gdscript
# 手写版的形状
enum State { IDLE, RUN, JUMP, FALL, HURT }
var state: State = State.IDLE

func _change_state(next: State) -> void:
	if state == next: return
	_exit_state(state)
	state = next
	_enter_state(state)
```

**依赖**：State Charts 插件（已装）或纯手写。

---

## 5. 伤害 / 血量 / 受击组件

**用途**：把「会被打、能打死」做成可拖拽复用的子节点，而不是每个角色重写一遍。

```
Actor (CharacterBody2D)
├── Health (Node)          ← @export var max_hp := 3，signal died / hp_changed
├── Hurtbox (Area2D)       ← 接收伤害
└── Hitbox (Area2D)        ← 造成伤害
```

**关键点**：用 Godot 的 collision layer/mask 把 `Hitbox` 和 `Hurtbox` 分层，
让子弹只打敌人、敌人只打玩家，别靠代码里 `if target.is_in_group("enemy")` 判断。

**依赖**：无。

---

## 6. 关卡 / 场景切换触发器

**用途**：进门、传送、加载下一关、Boss 房封锁。

```gdscript
extends Area2D
@export_file("*.tscn") var next_scene: String

func _ready() -> void:
	body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			SceneLoader.goto(next_scene))
```

**依赖**：`SceneLoader`（已有，自带淡入淡出和防重入）。

---

## 什么时候回来找我

玩法方向定了之后告诉我，我把需要的骨架实际写进 `scenes/game/` 并补进 `tools/smoke_test.gd` 里验证。
