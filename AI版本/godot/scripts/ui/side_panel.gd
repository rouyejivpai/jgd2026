extends Control
## 底栏：把地图上已放置的单位拖回这里 = 收回（01 §9 部署交互；收回后侧栏收起由 BattleRoot 处理）。
## P6：底栏不再是面板，而是局内 HUD 给战场让出的下方带（data/ui_layout/battle_hud.json 的 reserved.bottom）内的拖放区。
## 收回（单位 / 遗物地块）播 deploy_remove。

var controller: BattleController = null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if controller == null or not controller.editing() or not data is Dictionary:
		return false
	var d: Dictionary = data as Dictionary
	if d.has("relic"):
		return controller.phase == SimTypes.Phase.DEPLOY and bool(d.get("from_map", false))
	return bool(d.get("from_map", false)) and controller.can_move(str(d.get("slot_id", "")))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data as Dictionary
	if d.has("relic"):                   # 地图上的遗物地块拖回底栏 = 撤回
		if controller.remove_relic_tile():
			AudioManager.play_sfx("deploy_remove")
			EventBus.toast.emit(DataRegistry.get_string("ui.relic_removed_toast").format({ "name": str(DataRegistry.get_relic(str(d["relic"])).get("name", "")) }))
		return
	if controller.remove_unit(str(d["slot_id"])):
		AudioManager.play_sfx("deploy_remove")
