extends Node
## 全局游戏状态 + 手感工具。autoload 名：Game
##
## 用法：
##   Game.new_run()          # 开局
##   Game.add_score(100)
##   await Game.hitstop()    # 命中瞬间冻几毫秒
##   await Game.slowmo()     # 慢动作演出
##   Game.pause_game(true)

var score := 0
var combo := 0
var run_seed := 0
var is_over := false

func new_run(seed_value := 0) -> void:
	score = 0
	combo = 0
	is_over = false
	run_seed = seed_value if seed_value != 0 else randi()
	seed(run_seed)
	EventBus.reset()

func add_score(amount: int) -> void:
	if amount == 0:
		return
	score += amount
	EventBus.score_changed.emit(score)

func set_combo(value: int) -> void:
	combo = maxi(value, 0)
	EventBus.combo_changed.emit(combo)

func pause_game(paused: bool) -> void:
	get_tree().paused = paused

## 顿帧：命中瞬间把时间冻住几毫秒。打击感里性价比最高的一招。
func hitstop(duration := 0.07) -> void:
	Engine.time_scale = 0.0
	# 第 4 个参数 ignore_time_scale = true。
	# 少了它，time_scale=0 时定时器永远不走，游戏就永久卡死了 —— 经典坑。
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

## 慢动作（大招 / 死亡演出）
func slowmo(scale_value := 0.25, duration := 0.5) -> void:
	Engine.time_scale = scale_value
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
