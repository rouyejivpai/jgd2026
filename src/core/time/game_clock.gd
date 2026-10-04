class_name GameClock
extends Node
## 详细设计：[docs/design/01-时间与逻辑帧.md](../../docs/design/01-时间与逻辑帧.md)
##
## 与倍速无关的固定步长逻辑 tick。无论 1x/2x/3x，每个 tick 推进的游戏时间
## 恒为 TICK_DELTA，因此同一关在任意倍速下胜负与评价完全一致（FR-TEST-03）。
##
## 用法：
##   clock.tick.connect(_on_tick)      # 或由 LevelSession 直接连接
##   clock.set_speed_multiplier(3.0)   # 1x / 2x / 3x
##   clock.reset()                     # 重置关卡时归零
##
## 【重要】倍速**不用** Engine.time_scale —— 那个已被 Game.hitstop() 占用，
## 两者会互相踩。见详设 2.3。

const TICK_RATE := 60
const TICK_DELTA := 1.0 / 60.0
## 单帧 tick 上限。正常 1x 下为 1、3x 下为 3；16 对应约 11fps 的极端卡顿，
## 超出即丢弃积压，避免「卡顿 → 更多 tick → 更卡」的死亡螺旋。
const MAX_TICKS_PER_FRAME := 16
## 与 MAX_TICKS_PER_FRAME 同值。外部（如冒烟测试）通过 preload 拿到的是
## GDScript 资源，无法静态访问本类的 const，故提供这个可直接读的属性式常量，
## 避免把 16 这个数字散落在多处。
const MAX_TICKS_PER_FRAME_PUBLIC := 16
const SPEED_CHOICES: Array[float] = [1.0, 2.0, 3.0]

## 每个逻辑 tick 发一次（无参数，订阅者自行读 tick_index）
signal tick

## 已执行的 tick 数，从 0 开始
var tick_index := 0
## 当前倍速
var speed_multiplier := 1.0

var _accumulator := 0.0

## 已推进的游戏时间（秒）。由 tick_index 推导而非累加，避免浮点漂移。
var game_time: float:
	get:
		return float(tick_index) * TICK_DELTA

func _physics_process(delta: float) -> void:
	if speed_multiplier <= 0.0:
		return
	# 倍速只影响「多久攒够一个 tick」，不影响 tick 本身的大小
	_accumulator += delta * speed_multiplier
	var budget := MAX_TICKS_PER_FRAME
	while _accumulator >= TICK_DELTA and budget > 0:
		_accumulator -= TICK_DELTA
		tick_index += 1
		budget -= 1
		tick.emit()
	if budget == 0 and _accumulator >= TICK_DELTA:
		_accumulator = 0.0
		push_warning("GameClock: 单帧 tick 数超上限 %d，已丢弃积压时间" % MAX_TICKS_PER_FRAME)

## 切换倍速。**先清累加器再设值**：否则切换瞬间若累加器已接近满，
## 下一帧会连发多个 tick，表现为「切倍速时画面猛跳一下」。
func set_speed_multiplier(value: float) -> void:
	_accumulator = 0.0
	speed_multiplier = value

## 重置关卡用：时间归零。**不动**玩家的指令与信标（那些不在本系统内）。
func reset() -> void:
	_accumulator = 0.0
	tick_index = 0
