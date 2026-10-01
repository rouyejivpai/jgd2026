extends Node2D
## 玩法场景占位。它只证明「内核已经接通了」：
##   - 角色用输入映射移动
##   - 加分走 EventBus 信号
##   - 音效走 Audio（这里用程序化生成的音，见 Audio.make_beep）
##   - 顿帧走 Game.hitstop
##   - ESC 走 PauseMenu，R 走 SceneLoader.reload
##
## 真正开始做玩法时，把这个文件里的 _demo_hit() / _physics_process() 换掉，
## 把 Landmarks 节点删掉，保留 HUD 和 PauseMenu 的接线即可。

const SPEED := 520.0

@onready var _player: CharacterBody2D = $Player
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _score_label: Label = $HUD/ScoreLabel

var _blip: AudioStream

func _ready() -> void:
	# 没有音效素材时的占位音，一行就能验证音频链路是通的
	_blip = Audio.make_beep(760.0, 0.06)
	Game.new_run()
	EventBus.score_changed.connect(_on_score_changed)
	_on_score_changed(Game.score)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause_menu.open()
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		SceneLoader.reload()
	elif event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_demo_hit()

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_player.velocity = dir * SPEED
	_player.move_and_slide()

## 演示内核三件套。换成你自己的命中逻辑。
func _demo_hit() -> void:
	Game.add_score(10)
	Audio.play(_blip)
	Game.hitstop(0.05)

func _on_score_changed(score: int) -> void:
	_score_label.text = "分数 %d" % score
	Save.data["score"] = score

func _exit_tree() -> void:
	# 离开场景时落盘，避免每加一次分就写一次磁盘
	Save.save_data()
