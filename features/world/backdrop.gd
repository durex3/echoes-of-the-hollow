@tool
extends Node2D
## Seeded decorative geometry: never participates in collision.
@export var ruins := false
@export var room_width := 1280.0

func _draw() -> void:
	draw_rect(Rect2(0, 0, room_width, 576), Color("101c29") if ruins else Color("10292c"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 841
	for index: int in range(ceili(room_width / 60.0) + 2):
		var x := index * 60.0 + rng.randf_range(-20, 20)
		if ruins:
			draw_rect(Rect2(x, 90, 26, 440), Color("1b2a37"))
			draw_rect(Rect2(x-8, 90, 42, 12), Color("273544"))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(x-17, 520), Vector2(x+6, 120), Vector2(x+16, 50), Vector2(x+25, 120), Vector2(x+27, 520)]), Color("1a3838"))
			draw_circle(Vector2(x+12, rng.randf_range(70, 190)), rng.randf_range(44, 88), Color("173332"))
	for index: int in range(60):
		var p := Vector2(rng.randf_range(0, room_width), rng.randf_range(100, 450))
		draw_circle(p, 1, Color(0.6, 0.85, 0.72, rng.randf_range(0.08, 0.3)))
