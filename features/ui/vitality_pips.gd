class_name VitalityPips
extends Control
var current := 5
var maximum := 5

func _ready() -> void:
	custom_minimum_size = Vector2(120, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_health(value: int, total: int) -> void:
	current = clampi(value, 0, total)
	maximum = total
	queue_redraw()

func _draw() -> void:
	for index: int in range(maximum):
		var at := Vector2(index * 18 + 7, 8)
		var points := PackedVector2Array([at + Vector2(0,-7), at + Vector2(6,0), at + Vector2(0,7), at + Vector2(-6,0)])
		draw_colored_polygon(points, Color("efb6bb") if index < current else Color("28383e"))
		points.append(points[0])
		draw_polyline(points, Color("efb6bb") if index < current else Color("77918c"), 1)
