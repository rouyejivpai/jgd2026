extends GutTest
## 倍速跨关继承：战斗场景（persist）里选的 1× / 2× 记进设置，下一关 setup 时沿用；测试（不 persist）恒从 1× 开始。

var _saved: Variant = null


func before_each() -> void:
	_saved = GameState.settings.get(BattleController.SPEED_KEY)
	GameState.settings.erase(BattleController.SPEED_KEY)


func after_each() -> void:
	if _saved == null:
		GameState.settings.erase(BattleController.SPEED_KEY)
	else:
		GameState.settings[BattleController.SPEED_KEY] = _saved


func _controller(persist: bool) -> BattleController:
	var c := BattleController.new()
	add_child_autofree(c)
	c.persist = persist
	return c


func test_speed_carries_to_next_level() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_c30")
	var first := _controller(true)
	first.setup(level)
	assert_eq(first.speed, 1, "没选过倍速时从 1× 开始")
	first.set_speed(2)
	var second := _controller(true)
	watch_signals(EventBus)
	second.setup(level)
	assert_eq(second.speed, 2, "下一关沿用 2×")
	assert_signal_emitted_with_parameters(EventBus, "battle_speed_changed", [2])      # HUD 按钮跟着亮 2×
	second.set_speed(1)
	var third := _controller(true)
	third.setup(level)
	assert_eq(third.speed, 1, "切回 1× 也会继承")


func test_non_persist_always_starts_1x() -> void:
	GameState.settings[BattleController.SPEED_KEY] = 2
	var c := _controller(false)
	c.setup(DataRegistry.get_level("level_c30"))
	assert_eq(c.speed, 1, "测试 / 工具不受玩家设置影响")
	c.set_speed(2)
	c.set_speed(1)
	assert_eq(int(GameState.settings[BattleController.SPEED_KEY]), 2, "不 persist 时不改写设置")
