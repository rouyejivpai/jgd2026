extends PanelContainer
## 指令行的拖拽宿主。
## 详细设计：[docs/design/09-指令编辑界面.md](../../docs/design/09-指令编辑界面.md) 4.3
##
## 【为什么要单独一个脚本】Godot 的拖拽回调（`_get_drag_data` / `_can_drop_data` /
## `_drop_data`）是**逐控件**的 —— 必须挂在"一行"上，不能只在面板上实现。
## 这一层只做**翻译**：把引擎的拖拽事件转成面板能懂的几个信号，
## 真正的数据改动（数组顺序）由面板的 `move_rule()` 统一负责。
##
## 【行号由面板写入】排序后行号会变，所以 `row_index` 不是行自己算的，
## 而是面板 `_build_rule_row` 时传进来的。

## 开始拖这一行
signal drag_started(row: int)
## 拖到了这一行的上/下半区（用来画插入指示线）
signal drag_hover(row: int, before: bool)
## 在这一行落下
signal drag_dropped(row: int, before: bool)
## 拖拽结束（无论是否落下），用来收起指示线
signal drag_ended

var row_index := -1
## 最近一次 hover 落在上半区还是下半区。
## `_drop_data` 的签名里拿不到位置语义，所以在 `_can_drop_data` 里记下来。
var last_before := true


func _get_drag_data(_at_position: Vector2) -> Variant:
	drag_started.emit(row_index)
	# 拖拽预览：给玩家"正在搬第几条"的反馈
	var preview := Label.new()
	preview.text = "指令 %d" % (row_index + 1)
	preview.add_theme_font_size_override("font_size", 18)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.20, 0.28, 0.92)
	sb.border_color = Color(0.45, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	box.add_child(preview)
	set_drag_preview(box)
	return {"row": row_index}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has("row"):
		return false
	if int((data as Dictionary)["row"]) == row_index:
		return false              # 拖回自己身上没有意义
	# 落在行的**上半区** = 插到这一行之前；下半区 = 插到之后
	last_before = at_position.y < size.y * 0.5
	drag_hover.emit(row_index, last_before)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	drag_dropped.emit(row_index, last_before)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_ended.emit()
