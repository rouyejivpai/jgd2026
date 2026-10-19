extends Control
## 底栏：把地图上已放置的单位拖回这里 = 收回（01 §9 部署交互；收回后侧栏收起由 BattleRoot 处理）。
## P6：底栏不再是面板，而是局内 HUD 给战场让出的下方带（data/ui_layout/battle_hud.json 的 reserved.bottom）内的拖放区。

var controller: BattleController = null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if controller == null or controller.phase != SimTypes.Phase.DEPLOY or not data is Dictionary:
		return false
	return bool((data as Dictionary).get("from_map", false))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data as Dictionary
	if d.has("relic"):                   # 地图上的遗物地块拖回底栏 = 撤回
		if controller.remove_relic_tile():
			EventBus.toast.emit(DataRegistry.get_string("ui.relic_removed_toast").format({ "name": str(DataRegistry.get_relic(str(d["relic"])).get("name", "")) }))
		return
	controller.remove_unit(str(d["slot_id"]))
