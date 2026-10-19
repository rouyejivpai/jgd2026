extends Control
## 地图可视区的输入层（位于 HUD 三栏之间）：点击选中单位；部署阶段拖拽放置/移动/收回单位。
## 07 §1.1：命中测试只在玩法矩形内有效，矩形外的点击一律视为点击空地、拖起无效。
## 10 §4：拖拽虚影为形态精灵（落点合法金色、非法红色）；把已放置单位拖出战场（玩法矩形外）= 移除；
## 在战场内放到非法格：红闪 + toast「无法放置：原因」（原因由 DeploymentValidator.place_problem 给出），单位不动。
## 07 §3.1 信标（仅部署阶段，作用于当前选中的己方单位）：右键可行走格 = 追加下一个编号；右键已有信标 = 删除；
## 左键按住信标拖动 = 移动（松开时落点合法才生效）。
## 第四阶段（用户 2026-10-08）：
## - 部署阶段按下已放置的己方单位不立即打开详情：松开且没拖动 = 选中（打开侧栏）；拖动 = 移动，虚影吸附到最近的地块显示预览，
##   原位置的单位变淡；放下后不弹出详情。
## - 信标模式（HUD 底部信标边栏，数字键 / 「信标」按钮进入）：左键点地块 = 给该单位追加信标，右键 = 撤销最后一个；按住已有信标仍可拖动。
## - Ctrl + 左键拖动 = 平移镜头，Ctrl + 滚轮 = 缩放（BattleRoot.pan_by / zoom_at），不当作点击。
## 遗物（2026-10-19）：遗物栏点按后进入点选（HUD.relic_armed）——地块遗物左键点落点放下，骨刃 / 徽章左键点目标生效，右键取消；
## 地块遗物也可从遗物栏直接拖到地图上（同放置人偶：吸附预览、非法格红闪 + 原因气泡）；部署阶段按住已放下的地块可拖动挪位，
## 拖出战场 / 拖回底栏 = 撤回，未选中单位时右键地块也可撤回。

var _root: Node2D = null
var _controller: BattleController = null
var _drag_beacon: String = ""            ## 正在拖动的信标编号
var _drag_slot: String = ""
var _press_unit: int = -1                ## 部署阶段按下的己方单位（松开未拖动 = 选中）
var _cam_drag: bool = false              ## Ctrl + 左键拖动镜头中


func setup(root: Node2D, controller: BattleController) -> void:
	_root = root
	_controller = controller


func _gui_input(event: InputEvent) -> void:
	if _root == null:
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if _cam_drag:
			_root.call("pan_by", mm.relative)
			accept_event()
			return
		if _drag_beacon != "":
			var cell: Vector2i = _root.call("screen_to_cell", mm.global_position) as Vector2i
			var ok: bool = bool(_root.call("in_playfield", mm.global_position)) and _controller.can_place_beacon(_drag_slot, cell, _drag_beacon)
			_root.call("set_beacon_drag", _drag_beacon, cell, ok)
			accept_event()
			return
		if relic_armed() != "":
			_relic_hover(mm.global_position)
			accept_event()
			return
		_update_tooltip(mm.global_position)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.ctrl_pressed and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_root.call("zoom_at", mb.global_position, 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		accept_event()
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and (mb.ctrl_pressed and mb.pressed or _cam_drag and not mb.pressed):
		_cam_drag = mb.pressed
		_press_unit = -1
		accept_event()
		return
	if mb != null and relic_armed() != "" and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_relic_click(mb.global_position)
		else:
			_hud().call("disarm_relic")
		accept_event()
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _try_remove_relic(mb.global_position):
		accept_event()
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if beacon_mode_slot() != "":
			_undo_beacon()
		else:
			_on_right_click(mb.global_position)
		accept_event()
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _drag_beacon != "":
		_end_beacon_drag(mb.global_position)
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _hits_other_unit(mb.global_position) and _try_begin_beacon_drag(mb.global_position):
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and beacon_mode_slot() != "":
		_place_beacon_at(mb.global_position)
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var id: int = int(_root.call("unit_at_screen", mb.global_position))   # 矩形外恒为 -1
		if _controller != null and _controller.phase == SimTypes.Phase.DEPLOY and _controller.slot_of_unit(id) != "":
			_press_unit = id               # 部署阶段的己方单位：松开时（未拖动）才选中
		else:
			EventBus.unit_selected.emit(id)
		accept_event()
		return
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _press_unit >= 0:
		EventBus.unit_selected.emit(_press_unit)
		_press_unit = -1
		accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	if _controller == null or _controller.phase != SimTypes.Phase.DEPLOY or _drag_beacon != "":
		return null
	if not bool(_root.call("in_playfield", get_global_transform() * at_position)):
		return null
	var cell: Vector2i = _root.call("screen_to_cell", get_global_transform() * at_position) as Vector2i
	var sid: String = _controller.slot_at(cell)
	if sid == "" and not _cam_drag and beacon_mode_slot() == "" and relic_armed() == "":
		var rid: String = str(_root.call("relic_tile_at_screen", get_global_transform() * at_position))
		if rid != "":                          # 按住已放下的遗物地块拖动 = 挪位 / 拖出战场撤回
			_press_unit = -1
			set_drag_preview(RelicSlot.make_preview(rid, float(_root.call("cell_screen_px"))))
			AudioManager.play_sfx("ui_drag_pick", "UI")
			return { "relic": rid, "from_map": true }
	if sid == "" or _cam_drag or beacon_mode_slot() != "" or relic_armed() != "":
		return null
	_press_unit = -1                       # 拖动开始：松开时不再选中
	set_drag_preview(RosterCard.make_preview(_controller.form_of(sid), float(_root.call("cell_screen_px"))))
	_root.call("set_drag_source", _controller.unit_id_of_slot(sid))
	AudioManager.play_sfx("ui_drag_pick", "UI")
	return { "slot_id": sid, "from_map": true }


## 拖拽数据：{ slot_id, from_map }（地图上已放置的单位 / fixed 关槽位卡）或 { form }（free 关出场卡，放下即新建单位，07 §4.1）
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _controller == null or (_controller.phase != SimTypes.Phase.DEPLOY and not _controller.boss_pending) or not data is Dictionary:
		return false
	var d: Dictionary = data as Dictionary
	if d.has("relic"):
		return _can_drop_relic(at_position, d)
	if not d.has("form") and not d.has("slot_id"):
		return false
	if not bool(_root.call("in_playfield", get_global_transform() * at_position)):
		_root.call("clear_drag_hover")
		RosterCard.tint_preview(0)
		RosterCard.show_preview(true)
		return bool(d.get("from_map", false))
	var cell: Vector2i = _root.call("screen_to_cell", get_global_transform() * at_position) as Vector2i
	var legal: bool = drop_problem(d, cell) == ""
	var form: String = str(d["form"]) if d.has("form") else _controller.form_of(str(d["slot_id"]))
	_root.call("set_drag_hover", cell, legal, form)          # 第四阶段：虚影吸附到最近的地块显示预览
	RosterCard.tint_preview(1 if legal else -1)
	RosterCard.show_preview(false)                           # 战场内只显示吸附后的虚影，不再跟手
	return true      # 非法格也接收放下：红闪 + 原因 toast（10 §4）


## 拖拽数据放到 cell 的不可放置原因码，可放置为 ""
func drop_problem(d: Dictionary, cell: Vector2i) -> String:
	return _controller.place_problem(str(d["form"]) if d.has("form") else str(d["slot_id"]), cell)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data as Dictionary
	var screen: Vector2 = get_global_transform() * at_position
	var cell: Vector2i = _root.call("screen_to_cell", screen) as Vector2i
	var inside: bool = bool(_root.call("in_playfield", screen))
	AudioManager.play_sfx("ui_drag_drop", "UI")
	_root.call("clear_drag_hover")
	if d.has("relic"):
		_drop_relic(d, cell, inside)
		return
	if not inside:
		if bool(d.get("from_map", false)):
			_controller.remove_unit(str(d["slot_id"]))      # 拖出战场 = 移除（侧栏随之收起，见 BattleRoot）
		return
	var problem: String = drop_problem(d, cell)
	if problem != "":
		_root.call("flash_illegal", cell)
		EventBus.toast.emit(cannot_place_text(problem))
		if bool(_root.call("in_playfield", screen)) and _root.has_method("cell_top_screen"):
			EventBus.toast_at.emit(cannot_place_text(problem), _root.call("cell_top_screen", cell) as Vector2)
		return
	if d.has("form"):
		var uid: String = _controller.add_unit(str(d["form"]), cell)
		if uid != "":
			EventBus.unit_selected.emit(_controller.unit_id_of_slot(uid))
		return
	var sid: String = str(d["slot_id"])
	if _controller.place_unit(sid, cell) and not bool(d.get("from_map", false)):
		EventBus.unit_selected.emit(_controller.unit_id_of_slot(sid))   # 槽位卡首次放下才打开详情；地图上移动不弹出（第四阶段）


## 「无法放置：原因」（validation.cannot_place.*）
static func cannot_place_text(problem: String) -> String:
	return DataRegistry.get_string("validation.cannot_place.format").format({ "reason": DataRegistry.get_string("validation.cannot_place." + problem) })


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _root != null:
		_root.call("clear_drag_hover")
		_root.call("clear_relic_hover")
		_root.call("set_drag_source", -1)
		RosterCard.tint_preview(0)
	elif what == NOTIFICATION_MOUSE_EXIT and get_parent() != null:
		get_parent().call("hide_tooltip")


# ---- 信标模式（第四阶段）：HUD 底部信标边栏 ----
func beacon_mode_slot() -> String:
	var hud: Node = get_parent()
	return str(hud.call("beacon_mode_slot")) if hud != null and hud.has_method("beacon_mode_slot") else ""


func _place_beacon_at(screen_pos: Vector2) -> void:
	var sid: String = beacon_mode_slot()
	if not bool(_root.call("in_playfield", screen_pos)) or not _controller.can_edit_beacons(sid):
		return
	var cell: Vector2i = _root.call("screen_to_cell", screen_pos) as Vector2i
	if _controller.next_beacon_id(sid) == "":
		EventBus.toast.emit(DataRegistry.get_string("ui.beacon_soft_cap").format({ "n": SimTypes.BEACON_SOFT_CAP }))
	elif not _controller.can_place_beacon(sid, cell):
		if str(_root.call("beacon_at_screen", sid, screen_pos)) == "":
			EventBus.toast_at.emit(DataRegistry.get_string("ui.beacon_blocked"), _root.call("cell_top_screen", cell) as Vector2)
	elif not _controller.can_afford_beacon():
		EventBus.toast_at.emit(beacon_budget_text(_controller), _root.call("cell_top_screen", cell) as Vector2)
	else:
		_add_beacon(sid, cell)


func _undo_beacon() -> void:
	var sid: String = beacon_mode_slot()
	var bs: Array[Dictionary] = _controller.get_beacons(sid)
	if bs.is_empty() or not _controller.can_edit_beacons(sid):
		return
	_remove_beacon(sid, str(bs[bs.size() - 1]["id"]))


# ---- 信标（07 §3.1）----
func _on_right_click(screen_pos: Vector2) -> void:
	var sid: String = str(_root.call("selected_slot"))
	if _controller == null or sid == "" or not _controller.can_edit_beacons(sid) or not bool(_root.call("in_playfield", screen_pos)):
		return
	var existing: String = str(_root.call("beacon_at_screen", sid, screen_pos))
	if existing != "":
		_remove_beacon(sid, existing)
		return
	var cell: Vector2i = _root.call("screen_to_cell", screen_pos) as Vector2i
	if _controller.next_beacon_id(sid) == "":
		EventBus.toast.emit(DataRegistry.get_string("ui.beacon_soft_cap").format({ "n": SimTypes.BEACON_SOFT_CAP }))
	elif not _controller.can_place_beacon(sid, cell):
		EventBus.toast.emit(DataRegistry.get_string("ui.beacon_blocked"))
	elif not _controller.can_afford_beacon():
		EventBus.toast_at.emit(beacon_budget_text(_controller), _root.call("cell_top_screen", cell) as Vector2)
	else:
		_add_beacon(sid, cell)


## 放一个信标；用完库存时自动买了一包 → 提示扣费
func _add_beacon(sid: String, cell: Vector2i) -> void:
	var stock: int = _controller.beacon_stock()
	if _controller.add_beacon(sid, cell) == "":
		return
	AudioManager.play_sfx("deploy_place")
	if _controller.beacon_stock() > stock:
		EventBus.toast.emit(beacon_pack_text(_controller, "ui.beacon_pack_bought"))


## 删一个信标；整包用不着时自动退回 → 提示返还
func _remove_beacon(sid: String, beacon_id: String) -> void:
	var stock: int = _controller.beacon_stock()
	if not _controller.remove_beacon(sid, beacon_id):
		return
	AudioManager.play_sfx("deploy_remove")
	if _controller.beacon_stock() < stock:
		EventBus.toast.emit(beacon_pack_text(_controller, "ui.beacon_pack_refunded"))


## 「预算不足：再买一包信标需要 N Cost」
static func beacon_budget_text(c: BattleController) -> String:
	return DataRegistry.get_string("ui.beacon_pack_unaffordable").format({ "cost": c.level.beacon_cost, "bundle": c.level.beacon_bundle })


static func beacon_pack_text(c: BattleController, key: String) -> String:
	return DataRegistry.get_string(key).format({ "cost": c.level.beacon_cost, "bundle": c.level.beacon_bundle,
		"used": c.beacon_total(), "stock": c.beacon_stock() })


## 非信标模式下点中了另一个单位（敌人或别的己方）：优先切换选中，不去拖身后格子上的信标
## （用户 2026-10-18：信标放在人偶旁，点人偶身体却拖起了信标、侧栏不切换）
func _hits_other_unit(screen_pos: Vector2) -> bool:
	if beacon_mode_slot() != "":
		return false
	var id: int = int(_root.call("unit_at_screen", screen_pos))
	return id >= 0 and id != int(_root.get("selected_id"))


func _try_begin_beacon_drag(screen_pos: Vector2) -> bool:
	var sid: String = str(_root.call("selected_slot"))
	if _controller == null or sid == "" or not _controller.can_edit_beacons(sid):
		return false
	var id: String = str(_root.call("beacon_at_screen", sid, screen_pos))
	if id == "":
		return false
	_drag_beacon = id
	_drag_slot = sid
	_root.call("set_beacon_drag", id, _root.call("screen_to_cell", screen_pos), true)
	return true


func _end_beacon_drag(screen_pos: Vector2) -> void:
	var cell: Vector2i = _root.call("screen_to_cell", screen_pos) as Vector2i
	if bool(_root.call("in_playfield", screen_pos)):
		_controller.move_beacon(_drag_slot, _drag_beacon, cell)
	_drag_beacon = ""
	_drag_slot = ""
	_root.call("clear_beacon_drag")


## 运行/暂停中悬停在待机单位上：显示原因短句（05 §4.1）
func _update_tooltip(screen_pos: Vector2) -> void:
	var hud: Control = get_parent() as Control
	var running: bool = _controller != null and (_controller.phase == SimTypes.Phase.RUNNING or _controller.phase == SimTypes.Phase.PAUSED)
	var id: int = int(_root.call("unit_at_screen", screen_pos)) if running else -1
	var u: SimUnit = _controller.world.get_unit(id) if id >= 0 else null
	if u != null and RuleText.state_kind(u) > 0:
		hud.call("show_tooltip", RuleText.state_text(u), screen_pos)
	else:
		hud.call("hide_tooltip")



# ---- 遗物（HUD 遗物栏）----
func _hud() -> Node:
	return get_parent()


func relic_armed() -> String:
	var hud: Node = _hud()
	return str(hud.call("relic_armed")) if hud != null and hud.has_method("relic_armed") else ""


static func _relic_name(id: String) -> String:
	return str(DataRegistry.get_relic(id).get("name", ""))


static func _is_tile_relic(id: String) -> bool:
	return str(DataRegistry.get_relic(id).get("kind", "")) == "tile"


## 点选中移动鼠标：地块遗物 = 吸附预览；骨刃 / 徽章 = 悬停目标加粗
func _relic_hover(screen_pos: Vector2) -> void:
	var rid: String = relic_armed()
	if _is_tile_relic(rid):
		if not bool(_root.call("in_playfield", screen_pos)):
			_root.call("clear_relic_hover")
			return
		var cell: Vector2i = _root.call("screen_to_cell", screen_pos) as Vector2i
		_root.call("set_relic_hover", rid, cell, _controller.can_place_relic_tile(rid, cell))
	else:
		var id: int = int(_root.call("unit_at_screen", screen_pos))
		_root.call("set_relic_target_hover", rid, id if _controller.relic_target_ok(rid, id) else -1)


## 点选中左键：放下地块 / 对目标生效；点到矩形外 = 取消
func _relic_click(screen_pos: Vector2) -> void:
	var rid: String = relic_armed()
	if not bool(_root.call("in_playfield", screen_pos)):
		_hud().call("disarm_relic")
		return
	if _is_tile_relic(rid):
		var cell: Vector2i = _root.call("screen_to_cell", screen_pos) as Vector2i
		if _controller.place_relic_tile(rid, cell):
			AudioManager.play_sfx("deploy_place")
			EventBus.toast.emit(DataRegistry.get_string("ui.relic_placed_toast").format({ "name": _relic_name(rid) }))
			_hud().call("disarm_relic")
		else:
			_root.call("flash_illegal", cell)
			EventBus.toast_at.emit(DataRegistry.get_string("ui.relic_bad_cell"), _root.call("cell_top_screen", cell) as Vector2)
		return
	var id: int = int(_root.call("unit_at_screen", screen_pos))
	if _controller.use_relic_on(rid, id) >= 0.0:
		_hud().call("disarm_relic")
	else:
		var bad: String = "ui.relic_bad_target_enemy" if str(DataRegistry.get_relic(rid).get("kind", "")) == "strike" else "ui.relic_bad_target_ally"
		EventBus.toast.emit(DataRegistry.get_string(bad))
		AudioManager.play_sfx("ui_error", "UI")


## 部署阶段、未选中己方单位、不在信标模式时右键遗物地块 = 撤回
func _try_remove_relic(screen_pos: Vector2) -> bool:
	if _controller == null or _controller.phase != SimTypes.Phase.DEPLOY or beacon_mode_slot() != "" or str(_root.call("selected_slot")) != "":
		return false
	var rid: String = str(_root.call("relic_tile_at_screen", screen_pos))
	if rid == "" or not _controller.remove_relic_tile():
		return false
	AudioManager.play_sfx("deploy_remove")
	EventBus.toast.emit(DataRegistry.get_string("ui.relic_removed_toast").format({ "name": _relic_name(rid) }))
	return true


func _can_drop_relic(at_position: Vector2, d: Dictionary) -> bool:
	var rid: String = str(d["relic"])
	var from_map: bool = bool(d.get("from_map", false))
	var screen: Vector2 = get_global_transform() * at_position
	if not bool(_root.call("in_playfield", screen)):
		_root.call("clear_relic_hover")
		RosterCard.tint_preview(0)
		RosterCard.show_preview(true)
		return from_map
	var cell: Vector2i = _root.call("screen_to_cell", screen) as Vector2i
	var legal: bool = _controller.can_place_relic_tile(rid, cell, from_map)
	_root.call("set_relic_hover", rid, cell, legal)
	RosterCard.tint_preview(1 if legal else -1)
	RosterCard.show_preview(false)
	return true


func _drop_relic(d: Dictionary, cell: Vector2i, inside: bool) -> void:
	var rid: String = str(d["relic"])
	_root.call("clear_relic_hover")
	if not inside:
		if bool(d.get("from_map", false)) and _controller.remove_relic_tile():
			AudioManager.play_sfx("deploy_remove")
			EventBus.toast.emit(DataRegistry.get_string("ui.relic_removed_toast").format({ "name": _relic_name(rid) }))
		return
	if _controller.place_relic_tile(rid, cell):
		AudioManager.play_sfx("deploy_place")
		if not bool(d.get("from_map", false)):
			EventBus.toast.emit(DataRegistry.get_string("ui.relic_placed_toast").format({ "name": _relic_name(rid) }))
		_hud().call("disarm_relic")
	else:
		_root.call("flash_illegal", cell)
		EventBus.toast_at.emit(DataRegistry.get_string("ui.relic_bad_cell"), _root.call("cell_top_screen", cell) as Vector2)
