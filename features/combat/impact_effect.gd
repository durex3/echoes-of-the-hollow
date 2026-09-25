extends Node2D
## Short-lived particles use local drawing only; no collision or timescale changes.
var age := 0.0
var strong := false

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= 0.24:
		queue_free()

func _draw() -> void:
	var alpha := 1.0 - age / 0.24
	var color := Color("f4ce82") if strong else Color("c9f4de")
	color.a = alpha
	for index: int in range(8 if strong else 5):
		var direction := Vector2.from_angle(index * 2.4 + 0.3)
		var start := direction * (4 + age * 80)
		draw_line(start, start + direction * (7 if strong else 4), color, 2)
