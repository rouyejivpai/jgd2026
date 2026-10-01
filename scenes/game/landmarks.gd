extends Node2D
## 占位视觉参照物：在原点周围铺一片网格方块。
## 作用是让你一眼看出相机确实在跟随，而不是整个世界静止。
##
## 有了真正的美术资源后，把这个节点整个删掉即可。

@export var grid_size := 10
@export var spacing := 480.0
@export var square_size := 140.0

func _ready() -> void:
	var half := (grid_size - 1) * 0.5
	var h := square_size * 0.5
	for x in grid_size:
		for y in grid_size:
			var square := Polygon2D.new()
			square.polygon = PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
			])
			var checker := float((x + y) % 2)
			square.color = Color(0.16, 0.18, 0.24).lerp(Color(0.24, 0.27, 0.36), checker)
			square.position = Vector2(x - half, y - half) * spacing
			add_child(square)
