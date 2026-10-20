class_name ConfirmDialog
extends Control
## 通用确认弹窗（目前用于主菜单「新游戏」清档确认）：节点、位置、贴图、字体全部来自 data/ui_layout/confirm_dialog.json 与
## assets/themes/ui_confirm_dialog.tres（tools/apply_ui_manifest.py 由 assets/ui/confirm_dialog/manifest.json 生成），
## 本脚本只做文字绑定与接线。文字由调用方以 strings key 传入（open）。
## 2026-10-21 按钮顺序：「取消」在左、「确定」在右（manifest 中两按钮 rect 互换）。
## 遮罩挡住下层点击，点击遮罩不关闭；Esc 或「取消」= 取消；打开时默认焦点在「取消」（防误触），焦点只在两个按钮间切换。

signal confirmed()
signal cancelled()

const SCREEN: String = "confirm_dialog"
const NODE_NAMES: Dictionary = {
	"mask": "Mask", "panel": "Panel", "title": "Title", "body": "Body",
	"btn_ok": "OkButton", "btn_cancel": "CancelButton",
}

var nodes: Dictionary = {}               ## 元素 id → Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)     # 挂在界面 Control 下：偏移也要清零，否则尺寸停在 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	nodes = UiKit.build_from_layout(self, SCREEN, NODE_NAMES)
	(nodes["mask"] as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	(nodes["body"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok: Button = nodes["btn_ok"] as Button
	var cancel: Button = nodes["btn_cancel"] as Button
	ok.pressed.connect(_on_ok)
	cancel.pressed.connect(_on_cancel)
	ok.set_meta("sfx_press", "ui_confirm_major")
	cancel.set_meta("sfx_press", "ui_back")
	_trap_focus(ok, cancel)
	_trap_focus(cancel, ok)
	resized.connect(_layout)
	visible = false


## 焦点只在弹窗内两个按钮间切换，不会跑到下层界面
static func _trap_focus(from: Button, to: Button) -> void:
	var path: NodePath = from.get_path_to(to)
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		from.set_focus_neighbor(side, path)
	from.focus_next = path
	from.focus_previous = path


## 打开：按 strings key 填文字并显示，焦点落在「取消」
func open(title_key: String, body_key: String, ok_key: String, cancel_key: String) -> void:
	(nodes["title"] as Label).text = DataRegistry.get_string(title_key)
	(nodes["body"] as Label).text = DataRegistry.get_string(body_key)
	(nodes["btn_ok"] as Button).text = DataRegistry.get_string(ok_key)
	(nodes["btn_cancel"] as Button).text = DataRegistry.get_string(cancel_key)
	var was_open: bool = visible
	visible = true
	_layout()
	(nodes["btn_cancel"] as Button).grab_focus()
	if not was_open:                         # 2026-10-19：面板与按钮一起滑入，遮罩淡入
		var group: Array = []
		for id: String in nodes.keys():
			if id != "mask":
				group.append(nodes[id])
		UiKit.slide_in(group, (nodes["panel"] as Control).get_global_rect(), [nodes.get("mask")])


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui("ui_back")
		_on_cancel()


func _layout() -> void:
	UiKit.relayout(SCREEN, nodes, size)
	# 自动换行的正文：设尺寸时按旧宽度（初始为 0）缓存的最小高度会把高度撑大、文字居中到框外；
	# 宽度到位后让最小尺寸按新宽度重算，再设一次
	var body: Label = nodes["body"] as Label
	body.update_minimum_size()
	body.size = UiKit.layout_text_rect(SCREEN, "body", size).size


func _on_ok() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()


func _on_cancel() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()
